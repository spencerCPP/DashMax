import {test} from 'node:test';
import assert from 'node:assert/strict';
import {heading,convert,distanceText,elapsedText} from './domain.ts';
test('heading uses compass bearings, handles wraparound and missing course',()=>{assert.deepEqual(heading(0),{degrees:0,cardinal:'N'});assert.deepEqual(heading(90),{degrees:90,cardinal:'E'});assert.deepEqual(heading(-90),{degrees:270,cardinal:'W'});assert.deepEqual(heading(359.9),{degrees:0,cardinal:'N'});assert.equal(heading(180)?.cardinal,'S');assert.equal(heading(45)?.cardinal,'NE');assert.equal(heading(null),null);assert.equal(heading(NaN),null)});
test('units and long-ride formatting',()=>{assert.equal(elapsedText(38184),'10:36:24');assert.equal(elapsedText(86400),'24:00:00');assert.equal(distanceText(999.9,false),'999.9');assert.equal(distanceText(1000,false),'1000');assert.equal(distanceText(1609.344,true),'1000');assert.ok(Math.abs(convert(19.312128,true)-12)<.00001)});
