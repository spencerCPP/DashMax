#!/usr/bin/env node
// Cross-platform Connect IQ launcher. No npm packages or credentials required.
import { existsSync, readFileSync, mkdirSync, writeFileSync, openSync, closeSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync, spawn } from 'node:child_process';
import { generateKeyPairSync } from 'node:crypto';
import net from 'node:net';
import { prepareBuildProject, cadenceDivisorFor } from './garmin-project.mjs';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'garmin');
const simulatorLog = path.join(project, 'bin', 'simulator.log');
const windows = process.platform === 'win32';
const ciqRoot = windows
  ? path.join(process.env.APPDATA || path.join(homedir(), 'AppData', 'Roaming'), 'Garmin', 'ConnectIQ')
  : process.platform === 'darwin'
    ? path.join(homedir(), 'Library', 'Application Support', 'Garmin', 'ConnectIQ')
    : path.join(homedir(), '.Garmin', 'ConnectIQ');
const config = path.join(ciqRoot, 'current-sdk.cfg');
const sdk = process.env.CIQ_SDK_HOME || (existsSync(config) ? readFileSync(config, 'utf8').trim() : '');
const action = process.argv[2] || 'doctor';

function run(command, args, cwd = project) {
  let result;
  if (windows && /\.bat$/i.test(command)) {
    // cmd.exe expands these even inside quotes; reject rather than execute them.
    const quote = value => {
      if (/["%!&|<>^\r\n]/.test(value)) throw new Error('Use SDK/project paths without cmd.exe metacharacters.');
      return `"${value}"`;
    };
    const line = `"${[command, ...args].map(quote).join(' ')}"`;
    result = spawnSync(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', line], {
      cwd, stdio: 'inherit', windowsVerbatimArguments: true,
    });
  } else {
    result = spawnSync(command, args, { cwd, stdio: 'inherit' });
  }
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${path.basename(command)} failed (exit ${result.status ?? result.signal}).`);
}

function checkSdk() {
  if (!sdk || !existsSync(path.join(sdk, 'bin', 'monkeybrains.jar'))) {
    throw new Error('Connect IQ SDK not found. Install/select an SDK in Garmin SDK Manager, or set CIQ_SDK_HOME to its directory. See garmin/README.md.');
  }
  run('java', ['-version']);
  if (!existsSync(path.join(ciqRoot, 'Devices', 'edge840', 'compiler.json'))) {
    throw new Error(`Edge 840 device package not found under ${ciqRoot}. Install Edge 840 in Garmin SDK Manager.`);
  }
  console.log(`SDK: ${sdk}\nTarget: edge840\nProject: ${project}`);
}

function build(tests, activityData = false, cadenceDivisor = 1) {
  const key = process.env.CIQ_DEVELOPER_KEY || path.join(project, '.keys', 'developer_key.der');
  if (!existsSync(key)) {
    if (process.env.CIQ_DEVELOPER_KEY) throw new Error('CIQ_DEVELOPER_KEY points to a missing file.');
    mkdirSync(path.dirname(key), { recursive: true });
    const { privateKey } = generateKeyPairSync('rsa', {
      modulusLength: 4096,
      privateKeyEncoding: { type: 'pkcs8', format: 'der' },
      publicKeyEncoding: { type: 'spki', format: 'pem' },
    });
    writeFileSync(key, privateKey, { mode: 0o600, flag: 'wx' });
    console.log('Created an ignored local development signing key.');
  }
  mkdirSync(path.join(project, 'bin'), { recursive: true });
  const program = path.join(project, 'bin', tests ? 'DashMax-tests.prg' : activityData ? 'DashMax-fit.prg' : 'DashMax.prg');
  const buildProject = prepareBuildProject(project, activityData, cadenceDivisor);
  console.log(activityData ? 'Data source: ACTIVITY / FIT PLAYBACK (forced)' : 'Data source: app properties (mock by default)');
  if (activityData) console.log(`Replay cadence divisor: ${cadenceDivisor}`);
  // Use the SDK Java compiler directly; avoids Windows .bat quoting for builds.
  run('java', ['-Dfile.encoding=UTF-8', '-jar', path.join(sdk, 'bin', 'monkeybrains.jar'),
    '-f', 'monkey.jungle', '-d', 'edge840', '-y', key, '-o', program, ...(tests ? ['-t'] : [])], buildProject);
  console.log(`Built ${program}`);
  return program;
}

async function simulatorReady() {
  const results = await Promise.all([1234, 1235, 1236, 1237, 1238].map(port => new Promise(resolve => {
    const socket = net.createConnection({ host: '127.0.0.1', port });
    let banner = '';
    socket.setTimeout(400);
    socket.on('connect', () => socket.end());
    socket.on('data', data => { banner += data.toString(); });
    socket.on('end', () => resolve(banner.includes('A garmin device')));
    socket.on('timeout', () => { socket.destroy(); resolve(false); });
    socket.on('error', () => { socket.destroy(); resolve(false); });
  })));
  return results.some(Boolean);
}

async function launchSimulator() {
  if (await simulatorReady()) {
    if (!existsSync(simulatorLog)) console.log('Existing simulator has no captured log. Quit it once and rerun to enable persistent console output.');
    return;
  }
  const executable = path.join(sdk, 'bin', windows ? 'simulator.exe' : 'connectiq');
  if (!existsSync(executable)) throw new Error(`Simulator launcher missing: ${executable}`);
  let error;
  mkdirSync(path.dirname(simulatorLog), { recursive: true });
  const logFd = openSync(simulatorLog, 'a', 0o600);
  let child;
  try {
    child = spawn(executable, [], { cwd: project, stdio: ['ignore', logFd, logFd], detached: true });
  } finally { closeSync(logFd); }
  child.on('error', e => { error = e; });
  child.unref();
  for (let attempt = 0; attempt < 40; attempt++) {
    if (error) throw error;
    if (await simulatorReady()) return;
    await new Promise(resolve => setTimeout(resolve, 250));
  }
  throw new Error('Simulator did not become ready. Open it from Garmin SDK Manager, check its errors, then rerun this command.');
}

try {
  if (!['doctor', 'build', 'sim', 'fit', 'test'].includes(action)) throw new Error('Usage: node scripts/garmin.mjs doctor|build|sim|fit|test');
  const cadenceDivisor = cadenceDivisorFor(action, process.argv.slice(3));
  checkSdk();
  if (action !== 'doctor') {
    const tests = action === 'test';
    const program = build(tests, action === 'fit', cadenceDivisor);
    if (action === 'sim' || action === 'fit' || tests) {
      const offset = existsSync(simulatorLog) ? statSync(simulatorLog).size : 0;
      await launchSimulator();
      console.log(`Simulator console log: ${simulatorLog}`);
      const follower = spawn(process.execPath,
        [fileURLToPath(new URL('./simulator-output.mjs', import.meta.url)), simulatorLog, String(offset)],
        { stdio: ['ignore', 'inherit', 'inherit'] });
      follower.on('error', error => console.error(`Console streaming failed: ${error.message}`));
      try {
        run(path.join(sdk, 'bin', windows ? 'monkeydo.bat' : 'monkeydo'),
          [program, 'edge840', ...(tests ? [windows ? '/t' : '-t'] : [])]);
      } finally { follower.kill(); }
    }
  }
} catch (error) {
  console.error(`\nDashMax: ${error.message}`);
  process.exitCode = 1;
}
