import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, appendFileSync, statSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { followSimulatorLog } from './simulator-output.mjs';

test('new launcher followers receive new output from the same simulator log', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'dashmax-logs-'));
  const file = path.join(dir, 'simulator.log');
  try {
    writeFileSync(file, 'old output\n');
    let first = '';
    const stopFirst = followSimulatorLog(file, chunk => { first += chunk; }, statSync(file).size);
    appendFileSync(file, 'Dark value: false\n');
    stopFirst();
    assert.equal(first, 'Dark value: false\n');
    let second = '';
    const stopSecond = followSimulatorLog(file, chunk => { second += chunk; }, statSync(file).size);
    appendFileSync(file, 'Dark value: true\n');
    stopSecond();
    assert.equal(second, 'Dark value: true\n');
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('log following tolerates missing files and restarts after truncation', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'dashmax-logs-'));
  const file = path.join(dir, 'simulator.log');
  try {
    let output = '';
    const stop = followSimulatorLog(file, chunk => { output += chunk; }, 100);
    writeFileSync(file, 'new\n');
    stop();
    assert.equal(output, 'new\n');
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
