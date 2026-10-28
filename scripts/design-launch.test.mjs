import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {parseDesignLaunchArgs} from './design-launch.mjs';
import {prepareBuildProject} from './garmin-project.mjs';

test('designer launch requires HTTPS and a valid ID, and preserves explicit FIT correction',()=>{
  assert.deepEqual(parseDesignLaunchArgs(['--server=https://example.com/','--design=abcdef123456']),{server:'https://example.com',id:'abcdef123456',fit:false,cadenceDivisor:1});
  assert.equal(parseDesignLaunchArgs(['--server=https://example.com','--design=abcdef123456','--fit','--cadence-divisor=2']).cadenceDivisor,2);
  for(const server of ['http://example.com','https://user:password@example.com','https://example.com/?token=abc']) assert.throws(()=>parseDesignLaunchArgs([`--server=${server}`,'--design=abcdef123456']));
  assert.throws(()=>parseDesignLaunchArgs(['--server=https://example.com','--design=bad']));
  assert.throws(()=>parseDesignLaunchArgs(['--server=https://example.com','--design=abcdef123456','--cadence-divisor=2']));
  assert.throws(()=>parseDesignLaunchArgs(['--server=https://example.com','--design=abcdef123456','--fit','--fit']));
});
test('designer bootstrap affects only generated build and can use mock data',()=>{
 const project=mkdtempSync(path.join(tmpdir(),'dashmax-design-build-'));
 try{
  for(const dir of ['source','test','resources'])mkdirSync(path.join(project,dir));
  writeFileSync(path.join(project,'manifest.xml'),'<manifest/>');writeFileSync(path.join(project,'monkey.jungle'),'base.sourcePath = source;test');
  writeFileSync(path.join(project,'source','BuildMode.mc'),'original');
  const design=parseDesignLaunchArgs(['--server=https://example.com','--design=abcdef123456']);
  const generated=prepareBuildProject(project,false,1,design);
  const code=readFileSync(path.join(generated,'source','BuildMode.mc'),'utf8');
  assert.match(code,/DESIGN_SYNC = true/);assert.match(code,/ACTIVITY_DATA = false/);assert.match(code,/DESIGN_ID = "abcdef123456"/);assert.match(code,/DESIGN_SERVER = "https:\/\/example.com"/);
  assert.equal(readFileSync(path.join(project,'source','BuildMode.mc'),'utf8'),'original');
 }finally{rmSync(project,{recursive:true,force:true})}
});
