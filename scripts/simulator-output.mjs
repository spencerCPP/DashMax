import { openSync, closeSync, readSync, statSync } from 'node:fs';
import { StringDecoder } from 'node:string_decoder';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

// The simulator owns the file descriptor; each launcher follows new bytes.
// A separate process keeps streaming while monkeydo runs synchronously.
export function followSimulatorLog(file, write, from = 0, interval = 100) {
  let offset = from;
  let decoder = new StringDecoder('utf8');
  const poll = () => {
    let fd;
    try {
      const size = statSync(file).size;
      if (size < offset) { offset = 0; decoder = new StringDecoder('utf8'); }
      if (size === offset) return;
      fd = openSync(file, 'r');
      const buffer = Buffer.alloc(65536);
      while (offset < size) {
        const count = readSync(fd, buffer, 0, Math.min(buffer.length, size - offset), offset);
        if (!count) break;
        offset += count;
        const chunk = decoder.write(buffer.subarray(0, count));
        if (chunk) write(chunk);
      }
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    } finally { if (fd !== undefined) closeSync(fd); }
  };
  poll();
  const timer = setInterval(poll, interval);
  return () => { clearInterval(timer); poll(); };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const stop = followSimulatorLog(process.argv[2], text => process.stdout.write(text), Number(process.argv[3] || 0));
  const shutdown = () => { stop(); process.exit(); };
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}
