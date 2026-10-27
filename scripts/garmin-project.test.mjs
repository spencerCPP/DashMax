import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { prepareBuildProject, cadenceDivisorFor } from './garmin-project.mjs';

test('FIT build forces activity data without changing source or copying private keys', () => {
  const project = mkdtempSync(path.join(tmpdir(), 'dashmax-build-'));
  try {
    for (const dir of ['source', 'test', 'resources', '.keys']) mkdirSync(path.join(project, dir));
    writeFileSync(path.join(project, 'manifest.xml'), '<manifest/>');
    writeFileSync(path.join(project, 'monkey.jungle'), 'base.sourcePath = source;test');
    const original = 'module BuildMode { const ACTIVITY_DATA = false; }';
    writeFileSync(path.join(project, 'source', 'BuildMode.mc'), original);
    writeFileSync(path.join(project, '.keys', 'private.der'), 'test fixture');
    assert.equal(prepareBuildProject(project, false), project);
    const generated = prepareBuildProject(project, true);
    assert.match(readFileSync(path.join(generated, 'source', 'BuildMode.mc'), 'utf8'), /ACTIVITY_DATA = true/);
    assert.equal(readFileSync(path.join(project, 'source', 'BuildMode.mc'), 'utf8'), original);
    assert.equal(existsSync(path.join(generated, '.keys')), false);
    assert.equal(existsSync(path.join(generated, 'manifest.xml')), true);
    assert.match(readFileSync(path.join(generated, 'source', 'BuildMode.mc'), 'utf8'), /CADENCE_DIVISOR = 1/);
    prepareBuildProject(project, true, 2);
    assert.match(readFileSync(path.join(generated, 'source', 'BuildMode.mc'), 'utf8'), /CADENCE_DIVISOR = 2/);
    assert.equal(readFileSync(path.join(project, 'source', 'BuildMode.mc'), 'utf8'), original);
    // A subsequent refresh of sources must still produce a forced FIT build.
    assert.equal(prepareBuildProject(project, true), generated);
    assert.match(readFileSync(path.join(generated, 'source', 'BuildMode.mc'), 'utf8'), /CADENCE_DIVISOR = 1/);
    assert.match(readFileSync(path.join(generated, 'source', 'BuildMode.mc'), 'utf8'), /ACTIVITY_DATA = true/);
  } finally { rmSync(project, { recursive: true, force: true }); }
});

test('cadence correction is explicit, constrained, and available only for FIT replay', () => {
  assert.equal(cadenceDivisorFor('fit', []), 1);
  assert.equal(cadenceDivisorFor('fit', ['--cadence-divisor=2']), 2);
  assert.equal(cadenceDivisorFor('fit', ['--cadence-divisor=1']), 1);
  for (const args of [['--cadence-divisor=0'], ['--cadence-divisor=3'], ['--unknown'], ['--cadence-divisor=2', '--unknown']]) {
    assert.throws(() => cadenceDivisorFor('fit', args));
  }
  assert.throws(() => cadenceDivisorFor('sim', ['--cadence-divisor=2']));
  assert.throws(() => cadenceDivisorFor('test', ['--cadence-divisor=2']));
});
