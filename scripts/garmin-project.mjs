import { cpSync, mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';

export function cadenceDivisorFor(action, args) {
  if (!args.length) return 1;
  if (action !== 'fit' || args.length !== 1 || !/^--cadence-divisor=[12]$/.test(args[0])) {
    throw new Error('Only garmin:fit accepts --cadence-divisor=1 or --cadence-divisor=2.');
  }
  return Number(args[0].split('=')[1]);
}

export function prepareBuildProject(project, activityData, cadenceDivisor = 1, design = null, colorTest = false) {
  if (![1, 2].includes(cadenceDivisor)) throw new Error('Cadence divisor must be 1 or 2.');
  if (!activityData && !design && !colorTest) return project;
  const destination = path.join(project, 'bin', colorTest ? 'color-project' : design ? 'design-project' : 'fit-project');
  mkdirSync(destination, { recursive: true });
  // Copy only build inputs; never copy signing keys, outputs, or node_modules.
  for (const entry of ['manifest.xml', 'monkey.jungle', 'source', 'test', 'resources']) {
    cpSync(path.join(project, entry), path.join(destination, entry), { recursive: true });
  }
  // Force the data source regardless of any previously saved simulator settings.
  writeFileSync(path.join(destination, 'source', 'BuildMode.mc'),
    `module BuildMode {\n    const ACTIVITY_DATA = ${activityData};\n    const CADENCE_DIVISOR = ${cadenceDivisor};\n    const DESIGN_SYNC = ${Boolean(design)};\n    const DESIGN_SERVER = ${JSON.stringify(design?.server || "")};\n    const DESIGN_ID = ${JSON.stringify(design?.id || "")};\n    const COLOR_TEST = ${Boolean(colorTest)};\n}\n`);
  return destination;
}

// monkeydo's exit code is not a reliable test verdict, so read the runner's
// summary line. Returns null when there is no summary to judge by.
export function testOutcome(output) {
  if (/^FAILED\b/m.test(output)) return false;
  const passed = /^PASSED \(passed=(\d+), failed=0, errors=0\)/m.exec(output);
  if (!passed) return null;
  // An empty run is not a pass.
  return Number(passed[1]) > 0;
}
