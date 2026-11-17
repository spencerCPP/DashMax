import { test } from 'node:test';
import assert from 'node:assert/strict';
import { designProblem, normalizeRows, layout, upgrade, PRESETS, METRICS } from './design.mjs';

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
  assert.ok(designProblem([row(1, 'graph', 'power')]));
  assert.equal(designProblem([row(1, 'graph')]), null);
  assert.ok(designProblem([{ size: 1, cells: [{ metric: 'power', zone: 'yes' }] }]));
  // A small row next to too much large content would fall below 40 px.
  assert.ok(designProblem([row(3, 'power'), row(3, 'speed'), row(3, 'grade'), row(1, 'ascent')]));
  assert.equal(designProblem([row(3, 'power'), row(1, 'speed'), row(1, 'grade'), row(1, 'ascent'), row(1, 'cadence'), row(1, 'elapsed')]), null);
});

test('zone is kept only on metrics that have zones', () => {
  const rows = normalizeRows([{ size: 2, extra: 1, cells: [{ metric: 'power', zone: true }, { metric: 'speed', zone: true, other: 2 }] }]);
  assert.deepEqual(rows, [{ size: 2, cells: [{ metric: 'power', zone: true }, { metric: 'speed' }] }]);
  assert.ok(METRICS.heartRate.zone && !METRICS.grade.zone);
});

test('layout fills the screen exactly with integer boxes', () => {
  const boxes = layout([row(3, 'power'), row(1, 'graph'), row(2, 'heartRate', 'cadence'), row(2, 'speed', 'distance')]);
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
  const current = { version: 2, rows: [] };
  assert.equal(upgrade(current), current);
});
