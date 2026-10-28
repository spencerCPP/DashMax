import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { once } from 'node:events';
import { createDesignServer, foregroundFor } from './design-server.mjs';

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
    for(const body of [{fields:['power','power','distance'],background:0},{fields:['power'],background:0},{fields:['power','heartRate','unknown'],background:0},{fields:['power','heartRate','distance'],background:-1},{fields:['power','heartRate','distance'],background:0x1000000}]) assert.equal((await request(`${base}/api/designs`,'POST',body)).status,400);
    const response=await request(`${base}/api/designs`,'POST',{fields:['power','heartRate','distance'],background:0xffffff});
    assert.equal(response.status,201);const initial=await response.json();assert.match(initial.id,/^[a-f0-9]{12}$/);assert.equal(initial.foreground,0);
    const updated=await (await request(`${base}/api/designs/${initial.id}`,'PUT',{fields:['cadence','speed','elapsed'],background:0})).json();
    assert.equal(updated.id,initial.id);assert.equal(updated.revision,2);assert.equal(updated.foreground,0xffffff);
    assert.equal((await request(`${base}/api/designs/${initial.id}`,'PUT',{fields:[],background:0})).status,400);
    const fetched=await fetch(`${base}/api/designs/${initial.id}`);assert.equal(fetched.headers.get('cache-control'),'no-store');assert.deepEqual(await fetched.json(),updated);
    await close();base=await start();assert.deepEqual(await (await fetch(`${base}/api/designs/${initial.id}`)).json(),updated);
    assert.equal((await fetch(`${base}/api/designs/aaaaaaaaaaaa`)).status,404);
    assert.equal((await request(`${base}/api/designs`,'POST',{fields:['power','heartRate','distance'],background:0,padding:'x'.repeat(5000)})).status,413);
  } finally { if(server?.listening) await close();rmSync(dir,{recursive:true,force:true}); }
});
test('foreground contrast follows light and dark backgrounds',()=>{assert.equal(foregroundFor(0xffffff),0);assert.equal(foregroundFor(0),0xffffff);assert.equal(foregroundFor(0x6f42f3),0xffffff);assert.equal(foregroundFor(0xfaca48),0)});
