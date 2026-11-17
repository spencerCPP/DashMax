import { useEffect, useState } from 'react';
import { METRICS, PRESETS, MAX_ROWS, WIDTH, HEIGHT, designProblem, zonesProblem, normalizeRows, layout, type Row } from '../shared/design.mjs';
import './designer.css';

type Design = { id: string; revision: number; rows: Row[]; background: number; foreground: number; powerZones?: number[]; align?: string };

const SIZES = [[1, 'S'], [2, 'M'], [3, 'L']] as const;
// Stand-ins for the preview; on the device the colour follows the rider's Garmin zones.
const ZONE_PREVIEW: Record<string, string> = { power: '#faca48', heartRate: '#f27716' };
const copyRows = (rows: Row[]) => rows.map(row => ({ size: row.size, cells: row.cells.map(cell => ({ ...cell })) }));

function contrast(color: string) {
  const rgb = [1, 3, 5].map(i => parseInt(color.slice(i, i + 2), 16) / 255).map(n => (n <= .04045 ? n / 12.92 : ((n + .055) / 1.055) ** 2.4));
  const luminance = rgb[0] * .2126 + rgb[1] * .7152 + rgb[2] * .0722;
  return (luminance + .05) / .05 >= 1.05 / (luminance + .05) ? '#000000' : '#ffffff';
}

function Preview({ rows, background, foreground, center }: { rows: Row[]; background: string; foreground: string; center: boolean }) {
  return <div className={center ? 'design-screen centered' : 'design-screen'} style={{ width: WIDTH, height: HEIGHT, background, color: foreground }}>
    {layout(rows).map((box, r) => box.cells.map((cell, c) => {
      const metric = METRICS[cell.metric];
      const half = box.cells.length > 1;
      const compact = box.height < 70;
      const pad = half ? 8 : 12;
      const valueHeight = box.height - (compact ? 2 : 8) - (compact ? 15 : 18) - (compact ? 2 : 8);
      const fill = cell.zone ? ZONE_PREVIEW[cell.metric] : undefined;
      // Barlow Condensed digits are roughly 0.42 em wide.
      const size = Math.max(11, Math.min(valueHeight * 1.05, (cell.width - 2 * pad) / (Math.max(metric.sample.length, 1) * .42)));
      return <div key={`${r}-${c}`} className="design-cell" style={{ left: cell.left, top: box.top, width: cell.width, height: box.height, padding: `${compact ? 2 : 8}px ${pad}px`, background: fill, color: fill ? '#000000' : undefined, borderTop: r ? '1px solid' : undefined, borderLeft: c ? '1px solid' : undefined, borderColor: foreground }}>
        <div className="design-label">{center ? <span>{half ? metric.short : metric.label} {metric.unit}</span> : <><span>{half ? metric.short : metric.label}</span><span>{metric.unit}</span></>}</div>
        {cell.metric === 'graph'
          ? <svg className="design-graph" viewBox="0 0 100 20" preserveAspectRatio="none"><polyline points="0,9 8,7 16,10 24,6 32,8 40,5 48,9 56,7 64,11 72,6 80,8 88,5 100,7" fill="none" stroke="currentColor" strokeWidth="1" vectorEffect="non-scaling-stroke"/></svg>
          : <strong style={{ fontSize: size, height: valueHeight, lineHeight: `${valueHeight}px` }}>{metric.sample}</strong>}
      </div>;
    }))}
  </div>;
}

export function Designer() {
  const [rows, setRows] = useState<Row[]>(() => copyRows(PRESETS[0].rows));
  const [color, setColor] = useState('#ffffff');
  const [center, setCenter] = useState(PRESETS[0].align === 'center');
  // Six text boxes; all empty means the design carries no power zones.
  const [zoneText, setZoneText] = useState<string[]>(() => Array(6).fill(''));
  const [saved, setSaved] = useState<Design | null>(null);
  const [saving, setSaving] = useState(false), [error, setError] = useState(''), [copied, setCopied] = useState(false);
  const foreground = contrast(color);
  const background = parseInt(color.slice(1), 16);
  const powerZones = zoneText.every(text => text.trim() === '') ? undefined : zoneText.map(text => (/^\d+$/.test(text.trim()) ? Number(text.trim()) : NaN));
  const problem = designProblem(rows) || zonesProblem(powerZones);
  const dirty = !saved || saved.background !== background || JSON.stringify(saved.rows) !== JSON.stringify(designProblem(rows) ? rows : normalizeRows(rows)) || JSON.stringify(saved.powerZones ?? null) !== JSON.stringify(powerZones ?? null) || (saved.align === 'center') !== center;
  // Applies an edit to a copy; edits that would break the layout rules are ignored.
  const change = (edit: (next: Row[]) => void) => { const next = copyRows(rows); edit(next); if (!designProblem(next)) setRows(next); };
  const allowed = (edit: (next: Row[]) => void) => { const next = copyRows(rows); edit(next); return !designProblem(next); };

  useEffect(() => {
    const id = new URLSearchParams(window.location.search).get('design');
    if (!id || !/^[a-f0-9]{12}$/.test(id)) return;
    let active = true;
    void fetch(`/api/designs/${id}`).then(async response => {
      const data = await response.json();
      if (!response.ok) throw new Error(data.error);
      if (active) { setSaved(data); setRows(copyRows(data.rows)); setColor('#' + data.background.toString(16).padStart(6, '0')); setZoneText(data.powerZones ? data.powerZones.map(String) : Array(6).fill('')); setCenter(data.align === 'center'); }
    }).catch(e => { if (active) setError(e.message); });
    return () => { active = false; };
  }, []);

  async function save() {
    setSaving(true); setError(''); setCopied(false);
    try {
      const response = await fetch(saved ? `/api/designs/${saved.id}` : '/api/designs', { method: saved ? 'PUT' : 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ rows: normalizeRows(rows), background, powerZones, align: center ? 'center' : 'left' }) });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || 'Could not save design.');
      setSaved(data); setRows(copyRows(data.rows));
      window.history.replaceState(null, '', `/designer?design=${data.id}`);
    } catch (e) { setError(e instanceof Error ? e.message : 'Could not save design.'); } finally { setSaving(false); }
  }

  return <div className="designer-page">
    <header><a href="/" className="brand">↗ DASHMAX <span className="beta">DESIGNER</span></a><a className="back-link" href="/">Dashboard concept ↗</a></header>
    <main className="designer-main">
      <div className="eyebrow">WEB → GARMIN</div>
      <h1>Your rows.<br/><em>Your screen.</em></h1>
      <p className="designer-intro">Start from a preset, then stack up to {MAX_ROWS} rows. Each row is small, medium or large and holds one or two metrics. Save, and the connected Edge picks it up before your next ride.</p>
      <div className="designer-grid">
        <section className="designer-form">
          <h2>Start from a preset</h2>
          <div className="preset-list">{PRESETS.map(preset => <button key={preset.id} className={JSON.stringify(preset.rows) === JSON.stringify(rows) && (preset.align === 'center') === center ? 'selected' : ''} onClick={() => { setRows(copyRows(preset.rows)); setCenter(preset.align === 'center'); }}>{preset.name}</button>)}</div>
          <h2>Rows</h2>
          {rows.map((row, r) => <div className="row-editor" key={r}>
            <div className="row-tools">
              <span className="row-name">Row {r + 1}</span>
              <div className="segmented" role="group" aria-label={`Row ${r + 1} height`}>{SIZES.map(([size, name]) => <button key={size} className={row.size === size ? 'active' : ''} disabled={!allowed(next => { next[r].size = size; })} onClick={() => change(next => { next[r].size = size; })}>{name}</button>)}</div>
              <span className="row-actions">
                <button aria-label={`Move row ${r + 1} up`} disabled={r === 0} onClick={() => change(next => { [next[r - 1], next[r]] = [next[r], next[r - 1]]; })}>↑</button>
                <button aria-label={`Move row ${r + 1} down`} disabled={r === rows.length - 1} onClick={() => change(next => { [next[r + 1], next[r]] = [next[r], next[r + 1]]; })}>↓</button>
                <button aria-label={`Remove row ${r + 1}`} disabled={rows.length === 1} onClick={() => change(next => { next.splice(r, 1); })}>✕</button>
              </span>
            </div>
            <div className="row-cells">
              {row.cells.map((cell, c) => <div className="cell-editor" key={c}>
                <select aria-label={`Row ${r + 1} metric ${c + 1}`} value={cell.metric} onChange={e => change(next => { next[r].cells[c] = { metric: e.target.value }; })}>
                  {Object.entries(METRICS).map(([id, metric]) => <option key={id} value={id} disabled={metric.fullRow && row.cells.length > 1}>{metric.name}</option>)}
                </select>
                {METRICS[cell.metric].zone && <label className="zone-toggle"><input type="checkbox" checked={cell.zone === true} onChange={e => change(next => { next[r].cells[c] = e.target.checked ? { metric: cell.metric, zone: true } : { metric: cell.metric }; })}/> Zone colour</label>}
              </div>)}
              {row.cells.length === 1
                ? <button className="split" disabled={METRICS[row.cells[0].metric].fullRow} onClick={() => change(next => { next[r].cells.push({ metric: Object.keys(METRICS).find(id => id !== row.cells[0].metric && !METRICS[id].fullRow)! }); })}>+ Split</button>
                : <button className="split" onClick={() => change(next => { next[r].cells.pop(); })}>Merge</button>}
            </div>
          </div>)}
          <button className="add-row" disabled={!allowed(next => { next.push({ size: 1, cells: [{ metric: 'speed' }] }); })} onClick={() => change(next => { next.push({ size: 1, cells: [{ metric: 'speed' }] }); })}>+ Add row</button>
          <p className="row-hint">Buttons grey out when a change would make a row too short to read on the device.</p>
          <div className="setting-line"><span>Text</span><div className="segmented" role="group" aria-label="Text alignment"><button className={!center ? 'active' : ''} onClick={() => setCenter(false)}>Left</button><button className={center ? 'active' : ''} onClick={() => setCenter(true)}>Centred</button></div></div>
          <h2>Power zones <span className="optional">optional</span></h2>
          <p className="row-hint">Enter the top of zones 1 to 6 in watts, as shown in Garmin Connect. Zone 7 is everything above. The device uses its own Garmin power zones when it can read them, then zones worked out from its Garmin FTP, and these only when it has neither.</p>
          <div className="zone-inputs">{zoneText.map((text, z) => <label key={z}>Z{z + 1} up to<input aria-label={`Top of power zone ${z + 1} in watts`} inputMode="numeric" value={text} placeholder="W" onChange={e => setZoneText(zoneText.map((old, i) => (i === z ? e.target.value : old)))}/></label>)}</div>
          <label className="designer-color">Background <span><input aria-label="Background color" type="color" value={color} onChange={e => setColor(e.target.value)}/><code>{color.toUpperCase()}</code></span></label>
          <button className="save-design" disabled={saving || !dirty || problem !== null} onClick={save}>{saving ? 'Saving…' : saved ? 'Save changes' : 'Save design'}</button>
          {(error || problem) && <p role="alert">{error || problem}</p>}
          {saved && <div className="design-saved" role="status">
            <span>{dirty ? 'Unsaved changes' : 'Saved'} · Revision {saved.revision}</span>
            <h3>Design ID</h3>
            <div><code>{saved.id}</code><button onClick={async () => { try { await navigator.clipboard.writeText(saved.id); setCopied(true); } catch { setError('Select and copy the design ID shown above.'); } }}>{copied ? 'Copied' : 'Copy'}</button></div>
            <p>Keep this ID. Saving changes updates the same screen; no new code or rebuild is needed once a device is connected.</p>
          </div>}
        </section>
        <section className="designer-preview">
          <div className="panel-heading"><span>LAYOUT PREVIEW · MOCK VALUES</span><span>{WIDTH} × {HEIGHT} PX</span></div>
          <Preview rows={rows} background={color} foreground={foreground} center={center}/>
          <p>Units follow the device's Garmin settings. Zone-coloured cells take their colour from the rider's Garmin power and heart-rate zones; the colours shown here are examples. Fonts differ on the device.</p>
        </section>
      </div>
      <section className="designer-next">
        <h2>Connect a device</h2>
        <p>Keep this server running. Use the HTTPS tunnel and <code>garmin:design</code> steps in <code>docs/designer-test.md</code>. Before a ride, the field checks for a new design every 30 seconds, and every 5 seconds for a few minutes after a change. Nothing changes once the ride timer has started.</p>
      </section>
    </main>
  </div>;
}
