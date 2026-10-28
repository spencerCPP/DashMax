import http from 'node:http';
import { existsSync, readFileSync, mkdirSync, writeFileSync, renameSync } from 'node:fs';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const metrics = new Set(['power', 'heartRate', 'distance', 'cadence', 'speed', 'elapsed']);
export function validateSelection(value) {
  if (!value || !Array.isArray(value.fields) || value.fields.length !== 3 || new Set(value.fields).size !== 3 || !value.fields.every(field => metrics.has(field))) throw new Error('Choose exactly three different supported metrics.');
  if (!Number.isInteger(value.background) || value.background < 0 || value.background > 0xffffff) throw new Error('Background must be an RGB color.');
  return { fields: [...value.fields], background: value.background };
}
export function foregroundFor(color) {
  const channels = [color >> 16 & 255, color >> 8 & 255, color & 255].map(n => n / 255).map(n => n <= .04045 ? n / 12.92 : ((n + .055) / 1.055) ** 2.4);
  const luminance = channels[0] * .2126 + channels[1] * .7152 + channels[2] * .0722;
  return (luminance + .05) / .05 >= 1.05 / (luminance + .05) ? 0 : 0xffffff;
}
export function createDesignServer({ dataDir = path.join(root, '.dashmax-designs'), distDir = path.join(root, 'dist'), logger = console.log } = {}) {
  const file = path.join(dataDir, 'designs.json');
  const designs = existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : {};
  const persist = () => { mkdirSync(dataDir, { recursive: true }); writeFileSync(`${file}.tmp`, JSON.stringify(designs, null, 2), { mode: 0o600 }); renameSync(`${file}.tmp`, file); };
  const json = (res, status, data) => { res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(data)); };
  return http.createServer(async (req, res) => {
    try {
      const pathname = new URL(req.url, 'http://localhost').pathname;
      if (pathname === '/api/health' && req.method === 'GET') return json(res, 200, { ok: true });
      const match = /^\/api\/designs\/([a-f0-9]{12})$/.exec(pathname);
      if (match && req.method === 'GET') {
        const design = designs[match[1]];
        if (!design) return json(res, 404, { error: 'Design not found.' });
        logger(`Design fetched: ${design.id} revision ${design.revision}`);
        return json(res, 200, design);
      }
      if ((pathname === '/api/designs' && req.method === 'POST') || (match && req.method === 'PUT')) {
        let body = '';
        for await (const chunk of req) { body += chunk; if (Buffer.byteLength(body) > 4096) return json(res, 413, { error: 'Design is too large.' }); }
        let selection;
        try { selection = validateSelection(JSON.parse(body)); } catch (error) { return json(res, 400, { error: error.message }); }
        const id = match ? match[1] : randomBytes(6).toString('hex');
        if (match && !designs[id]) return json(res, 404, { error: 'Design not found.' });
        const previous = designs[id];
        const design = { version: 1, id, revision: (previous?.revision || 0) + 1, ...selection, foreground: foregroundFor(selection.background) };
        designs[id] = design;
        try { persist(); } catch (error) { if (previous) designs[id] = previous; else delete designs[id]; throw error; }
        logger(`Design saved: ${id} revision ${design.revision}`);
        return json(res, match ? 200 : 201, design);
      }
      if (pathname.startsWith('/api/')) return json(res, 404, { error: 'Endpoint not found.' });
      if (req.method !== 'GET') return json(res, 405, { error: 'Method not allowed.' });
      const asset = pathname === '/' || pathname === '/designer' ? 'index.html' : decodeURIComponent(pathname).replace(/^\/+/, '');
      const resolved = path.resolve(distDir, asset);
      if (!resolved.startsWith(path.resolve(distDir) + path.sep)) return json(res, 403, { error: 'Invalid path.' });
      if (!existsSync(resolved)) return json(res, 404, { error: 'Build the web app first.' });
      const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.woff2': 'font/woff2', '.woff': 'font/woff', '.svg': 'image/svg+xml' };
      res.writeHead(200, { 'Content-Type': types[path.extname(resolved)] || 'application/octet-stream' }); res.end(readFileSync(resolved));
    } catch (error) { logger(`Design server error: ${error.message}`); if (!res.headersSent) json(res, 500, { error: 'Server could not complete the request.' }); else res.end(); }
  });
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const port = Number(process.env.DASHMAX_DESIGN_PORT || 4175);
  createDesignServer().listen(port, '127.0.0.1', () => console.log(`DashMax designer: http://localhost:${port}/designer\nKeep this server running while the simulator syncs.`));
}
