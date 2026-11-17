import { test } from 'node:test';
import assert from 'node:assert/strict';
import { designProblem, zonesProblem, alignProblem, normalizeRows, layout, upgrade, PRESETS, METRICS } from './design.mjs';

const row = (size, ...metrics) => ({ size, cells: metrics.map(metric => ({ metric })) });

test('every preset is a valid design', () => {
  for (const preset of PRESETS) assert.equal(designProblem(preset.rows), null, preset.name);
});

test('row and cell rules', () => {
  assert.equal(designProblem([row(2, 'power')]), null);
  assert.equal(designProblem([row(3, 'power'), row(3, 'speed'), row(3, 'grade')]), null);
  assert.equal(designProblem(Array.from({ length: 6 }, () => row(1, 'power', 'speed'))), null);
  assert.ok(designProblem([]));
  assert.ok(designProblem(Array.from({ length: 7 }, () => row(1, 'power'))));
  assert.ok(designProblem([row(4, 'power')]));
  assert.ok(designProblem([row(1, 'power', 'speed', 'grade')]));
  assert.ok(designProblem([row(1)]));
  assert.ok(designProblem([row(1, 'wind')]));
  assert.ok(designProblem([row(1, 'constructor')]));
  // The stand-alone graph row no longer exists.
  assert.ok(designProblem([row(1, 'graph')]));
  assert.equal(designProblem([row(1, 'wkg', 'clock')]), null);
  assert.ok(designProblem([{ size: 1, cells: [{ metric: 'power', zone: 'yes' }] }]));
  // A small row next to too much large content would fall below 40 px.
  assert.ok(designProblem([row(3, 'power'), row(3, 'speed'), row(3, 'grade'), row(1, 'ascent')]));
  assert.equal(designProblem([row(3, 'power'), row(1, 'speed'), row(1, 'grade'), row(1, 'ascent'), row(1, 'cadence'), row(1, 'elapsed')]), null);
});

test('zone is kept only on metrics that have zones', () => {
  const rows = normalizeRows([{ size: 2, extra: 1, cells: [{ metric: 'power', zone: true }, { metric: 'speed', zone: true, other: 2 }] }]);
  assert.deepEqual(rows, [{ size: 2, cells: [{ metric: 'power', zone: true }, { metric: 'speed' }] }]);
  assert.ok(METRICS.heartRate.zone && METRICS.grade.zone && !METRICS.speed.zone);
});

test('layout fills the screen exactly with integer boxes', () => {
  const boxes = layout([row(3, 'power'), row(1, 'speed'), row(2, 'heartRate', 'cadence'), row(2, 'speed', 'distance')]);
  assert.deepEqual(boxes.map(box => [box.top, box.height]), [[0, 120], [120, 41], [161, 80], [241, 81]]);
  assert.deepEqual(boxes[2].cells.map(cell => [cell.left, cell.width]), [[0, 123], [123, 123]]);
  assert.deepEqual(boxes[0].cells.map(cell => [cell.left, cell.width]), [[0, 246]]);
  for (const preset of PRESETS) {
    const laid = layout(preset.rows);
    assert.equal(laid.at(-1).top + laid.at(-1).height, 322);
    assert.ok(laid.every(box => box.height >= 40), preset.name);
  }
});

test('version 1 designs upgrade to three equal rows', () => {
  const upgraded = upgrade({ version: 1, id: 'abcdef123456', revision: 4, fields: ['power', 'distance', 'elapsed'], background: 0, foreground: 0xffffff });
  assert.equal(upgraded.version, 2);
  assert.equal(upgraded.revision, 4);
  assert.equal(upgraded.fields, undefined);
  assert.equal(designProblem(upgraded.rows), null);
  assert.deepEqual(upgraded.rows.map(r => r.cells[0].metric), ['power', 'distance', 'elapsed']);
  const current = { version: 2, rows: [row(2, 'power')] };
  assert.equal(upgrade(current), current);
  // Stored designs lose their stand-alone graph rows and stay valid.
  const graphed = upgrade({ version: 2, revision: 9, rows: [row(3, 'power'), row(1, 'graph'), row(2, 'speed')] });
  assert.deepEqual(graphed.rows.map(r => r.cells[0].metric), ['power', 'speed']);
  assert.equal(graphed.revision, 9);
  assert.equal(designProblem(graphed.rows), null);
  assert.deepEqual(upgrade({ version: 2, rows: [row(1, 'graph')] }).rows.map(r => r.cells[0].metric), ['power']);
});

test('power zones are optional, six rising whole-watt limits', () => {
  assert.equal(zonesProblem(undefined), null);
  assert.equal(zonesProblem(null), null);
  assert.equal(zonesProblem([126, 167, 206, 236, 277, 342]), null);
  assert.ok(zonesProblem([126, 167, 206, 236, 277]));
  assert.ok(zonesProblem([126, 167, 206, 236, 277, 277]));
  assert.ok(zonesProblem([126, 167, 206, 236, 342, 277]));
  assert.ok(zonesProblem([0, 167, 206, 236, 277, 342]));
  assert.ok(zonesProblem([126.5, 167, 206, 236, 277, 342]));
  assert.ok(zonesProblem([126, 167, 206, 236, 277, 6000]));
  assert.ok(zonesProblem('126,167'));
});

test('alignment is optional, left or centre', () => {
  for (const align of [undefined, null, 'left', 'center']) assert.equal(alignProblem(align), null);
  for (const align of ['right', 'centre', 1, true]) assert.ok(alignProblem(align));
  for (const preset of PRESETS) assert.equal(alignProblem(preset.align), null);
});

test('avg/max is kept only on full-width cells of metrics that have it', () => {
  const rows = normalizeRows([
    { size: 3, cells: [{ metric: 'power', zone: true, stats: true }] },
    { size: 2, cells: [{ metric: 'heartRate', stats: true }, { metric: 'cadence', stats: true }] },
    { size: 2, cells: [{ metric: 'ascent', stats: true }] },
  ]);
  assert.deepEqual(rows, [
    { size: 3, cells: [{ metric: 'power', zone: true, stats: true }] },
    { size: 2, cells: [{ metric: 'heartRate' }, { metric: 'cadence' }] },
    { size: 2, cells: [{ metric: 'ascent' }] },
  ]);
  assert.ok(designProblem([{ size: 1, cells: [{ metric: 'power', stats: 'yes' }] }]));
});

test('the graph layout is kept only on full-width power and heart-rate cells', () => {
  const rows = normalizeRows([
    { size: 3, cells: [{ metric: 'power', graph: true }] },
    { size: 3, cells: [{ metric: 'speed', graph: true }] },
    { size: 2, cells: [{ metric: 'heartRate', graph: true }, { metric: 'cadence' }] },
  ]);
  assert.deepEqual(rows.map(row => row.cells[0]), [{ metric: 'power', graph: true }, { metric: 'speed' }, { metric: 'heartRate' }]);
  assert.ok(designProblem([{ size: 3, cells: [{ metric: 'power', graph: 1 }] }]));
});

test('a graph cell can switch average and max off; other cells cannot store false', () => {
  const rows = normalizeRows([
    { size: 2, cells: [{ metric: 'power', graph: true, stats: false }] },
    { size: 2, cells: [{ metric: 'heartRate', graph: true }] },
    { size: 2, cells: [{ metric: 'speed', stats: false }] },
  ]);
  assert.deepEqual(rows.map(row => row.cells[0]), [{ metric: 'power', stats: false, graph: true }, { metric: 'heartRate', graph: true }, { metric: 'speed' }]);
});
