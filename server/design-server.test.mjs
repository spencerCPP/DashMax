import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { once } from 'node:events';
import { createDesignServer, foregroundFor } from './design-server.mjs';

const rows = (...metrics) => metrics.map(metric => ({ size: 2, cells: [{ metric }] }));

test('design API validates, updates the same ID, and persists across server restarts', async () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'dashmax-designs-'));
  const options = { dataDir: path.join(dir, 'data'), distDir: path.join(dir, 'dist'), logger: () => {} };
  mkdirSync(options.distDir); writeFileSync(path.join(options.distDir, 'index.html'), '<title>Designer</title>');
  let server;
  const start = async () => { server=createDesignServer(options); server.listen(0,'127.0.0.1');await once(server,'listening');return `http://127.0.0.1:${server.address().port}`; };
  const close = () => new Promise(resolve=>server.close(resolve));
  const request = (url,method,body)=>fetch(url,{method,headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
  try {
    let base=await start();
    assert.equal((await fetch(`${base}/designer`)).status,200);
    for(const body of [{fields:['power','heartRate','distance'],background:0},{rows:[],background:0},{rows:rows('power','heartRate','unknown'),background:0},{rows:[{size:1,cells:[{metric:'graph'},{metric:'power'}]}],background:0},{rows:rows('power','heartRate','distance'),background:-1},{rows:rows('power','heartRate','distance'),background:0x1000000}]) assert.equal((await request(`${base}/api/designs`,'POST',body)).status,400);
    const response=await request(`${base}/api/designs`,'POST',{rows:[{size:3,cells:[{metric:'power',zone:true}]},{size:2,cells:[{metric:'ascent',zone:true},{metric:'grade',zone:true}]}],background:0xffffff});
    assert.equal(response.status,201);const initial=await response.json();assert.match(initial.id,/^[a-f0-9]{12}$/);assert.equal(initial.foreground,0);assert.equal(initial.version,2);assert.deepEqual(initial.rows,[{size:3,cells:[{metric:'power',zone:true}]},{size:2,cells:[{metric:'ascent'},{metric:'grade',zone:true}]}]);assert.ok(Number.isInteger(initial.savedAt)&&Math.abs(initial.savedAt-Date.now()/1000)<5);
    const updated=await (await request(`${base}/api/designs/${initial.id}`,'PUT',{rows:rows('cadence','speed','elapsed'),background:0,powerZones:[126,167,206,236,277,342],align:'center'})).json();
    assert.equal(updated.align,'center');assert.equal(initial.align,undefined);
    assert.equal((await request(`${base}/api/designs/${initial.id}`,'PUT',{rows:rows('cadence','speed','elapsed'),background:0,align:'right'})).status,400);
    assert.deepEqual(updated.powerZones,[126,167,206,236,277,342]);assert.equal(initial.powerZones,undefined);
    assert.equal((await request(`${base}/api/designs/${initial.id}`,'PUT',{rows:rows('cadence','speed','elapsed'),background:0,powerZones:[126,167,206]})).status,400);
    assert.equal(updated.id,initial.id);assert.equal(updated.revision,2);assert.equal(updated.foreground,0xffffff);
    assert.equal((await request(`${base}/api/designs/${initial.id}`,'PUT',{rows:[],background:0})).status,400);
    const fetched=await fetch(`${base}/api/designs/${initial.id}`);assert.equal(fetched.headers.get('cache-control'),'no-store');assert.deepEqual(await fetched.json(),updated);
    await close();base=await start();assert.deepEqual(await (await fetch(`${base}/api/designs/${initial.id}`)).json(),updated);
    assert.equal((await fetch(`${base}/api/designs/aaaaaaaaaaaa`)).status,404);
    assert.equal((await request(`${base}/api/designs`,'POST',{rows:rows('power','heartRate','distance'),background:0,padding:'x'.repeat(9000)})).status,413);
  } finally { if(server?.listening) await close();rmSync(dir,{recursive:true,force:true}); }
});
test('foreground contrast follows light and dark backgrounds',()=>{assert.equal(foregroundFor(0xffffff),0);assert.equal(foregroundFor(0),0xffffff);assert.equal(foregroundFor(0x6f42f3),0xffffff);assert.equal(foregroundFor(0xfaca48),0)});

test('server logs when a device reports the current revision', async () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'dashmax-designs-'));
  const lines = [];
  const server = createDesignServer({ dataDir: path.join(dir, 'data'), distDir: dir, logger: line => lines.push(line) });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    const design = await (await fetch(`${base}/api/designs`, { method: 'POST', body: JSON.stringify({ rows: rows('power', 'speed', 'cadence'), background: 0 }) })).json();
    const showing = () => lines.filter(line => line.includes('Device showing')).length;
    await fetch(`${base}/api/designs/${design.id}`);
    await fetch(`${base}/api/designs/${design.id}?have=abc`);
    assert.equal(showing(), 0);
    await fetch(`${base}/api/designs/${design.id}?have=1`);
    await fetch(`${base}/api/designs/${design.id}?have=1`);
    assert.equal(showing(), 1);
    assert.match(lines.find(line => line.includes('Device showing')), /^\d\d:\d\d:\d\d Device showing: [a-f0-9]{12} revision 1, \d+ s after save$/);
    await fetch(`${base}/api/designs/${design.id}`, { method: 'PUT', body: JSON.stringify({ rows: rows('power', 'speed', 'elapsed'), background: 0 }) });
    await fetch(`${base}/api/designs/${design.id}?have=1`);
    assert.equal(showing(), 1);
    await fetch(`${base}/api/designs/${design.id}?have=2`);
    assert.equal(showing(), 2);
    const zoneLines = () => lines.filter(line => line.includes('Device power zones'));
    await fetch(`${base}/api/designs/${design.id}?have=2&pz=8-0/120/165/200/230/270/330/2000`);
    await fetch(`${base}/api/designs/${design.id}?have=2&pz=8-0/120/165/200/230/270/330/2000`);
    await fetch(`${base}/api/designs/${design.id}?have=2&pz=${encodeURIComponent('<script>')}`);
    assert.equal(zoneLines().length, 1);
    assert.match(zoneLines()[0], /Device power zones: 8-0\/120\/165\/200\/230\/270\/330\/2000$/);
  } finally { await new Promise(resolve => server.close(resolve)); rmSync(dir, { recursive: true, force: true }); }
});

test('stored version 1 designs are upgraded, and older builds are refused', async () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'dashmax-designs-'));
  mkdirSync(path.join(dir, 'data'));
  writeFileSync(path.join(dir, 'data', 'designs.json'), JSON.stringify({ abcdef123456: { version: 1, id: 'abcdef123456', revision: 3, fields: ['power', 'distance', 'elapsed'], background: 0, foreground: 0xffffff } }));
  const server = createDesignServer({ dataDir: path.join(dir, 'data'), distDir: dir, logger: () => {} });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}/api/designs/abcdef123456`;
  try {
    const design = await (await fetch(base)).json();
    assert.equal(design.version, 2); assert.equal(design.revision, 3);
    assert.deepEqual(design.rows.map(row => row.cells[0].metric), ['power', 'distance', 'elapsed']);
    assert.equal((await fetch(`${base}?schema=2`)).status, 200);
    assert.equal((await fetch(`${base}?schema=3`)).status, 200);
    assert.equal((await fetch(`${base}?schema=1`)).status, 409);
  } finally { await new Promise(resolve => server.close(resolve)); rmSync(dir, { recursive: true, force: true }); }
});
