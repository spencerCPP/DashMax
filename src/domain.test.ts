import {test} from 'node:test';
import assert from 'node:assert/strict';
import {wind,normalize180,convert,distanceText,elapsedText} from './domain.ts';
test('rider-relative wind handles all directions and course wrap',()=>{assert.equal(wind(0,0,12).component,12);assert.equal(wind(0,180,12).component,-12);assert.equal(wind(270,0,12).relative,90);assert.equal(wind(90,0,12).relative,-90);assert.equal(wind(359,1,12).relative,2);assert.equal(normalize180(720),0);assert.equal(wind(0,90,12).label,'CROSSWIND');assert.equal(wind(0,180,12).label,'TAILWIND');assert.ok(Math.abs(wind(0,48.19,12).component-8)<.01)});
test('units and long-ride formatting',()=>{assert.equal(elapsedText(38184),'10:36:24');assert.equal(elapsedText(86400),'24:00:00');assert.equal(distanceText(999.9,false),'999.9');assert.equal(distanceText(1000,false),'1000');assert.equal(distanceText(1609.344,true),'1000');assert.ok(Math.abs(convert(19.312128,true)-12)<.00001)});
