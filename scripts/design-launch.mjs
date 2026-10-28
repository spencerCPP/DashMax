export function parseDesignLaunchArgs(args) {
  const result = { server: '', id: '', fit: false, cadenceDivisor: 1 };
  const seen = new Set();
  for (const arg of args) {
    const key = arg.split('=')[0];
    if (seen.has(key)) throw new Error(`Duplicate option: ${key}`);
    seen.add(key);
    if (arg.startsWith('--server=')) result.server = arg.slice(9);
    else if (arg.startsWith('--design=')) result.id = arg.slice(9);
    else if (arg === '--fit') result.fit = true;
    else if (/^--cadence-divisor=[12]$/.test(arg)) result.cadenceDivisor = Number(arg.split('=')[1]);
    else throw new Error(`Unknown designer option: ${arg}`);
  }
  const url = new URL(result.server);
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) throw new Error('Design server must be an HTTPS URL without credentials, query, or fragment.');
  if (!/^[a-f0-9]{12}$/.test(result.id)) throw new Error('Use the 12-character design ID shown in the web designer.');
  if (!result.fit && result.cadenceDivisor !== 1) throw new Error('Cadence correction requires --fit.');
  result.server = url.toString().replace(/\/+$/, '');
  return result;
}
