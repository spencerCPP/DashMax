import { useEffect, useState } from 'react';
import './designer.css';
const METRICS = [ ['power','Power','312','W'], ['heartRate','Heart rate','158','bpm'], ['distance','Distance','42.7','km'], ['cadence','Cadence','92','rpm'], ['speed','Speed','26.8','km/h'], ['elapsed','Elapsed time','1:36:24',''] ];
type Design = {id: string; revision: number; fields: string[]; background: number; foreground: number};
export function Designer() {
  const [fields,setFields] = useState(['power','heartRate','distance']);
  const [color,setColor] = useState('#ffffff');
  const [saved,setSaved] = useState<Design|null>(null);
  const [saving,setSaving] = useState(false), [error,setError] = useState(''), [copied,setCopied] = useState(false);
  const foreground = (() => { const rgb = [1,3,5].map(i=>parseInt(color.slice(i,i+2),16)/255).map(n=>n<=.04045?n/12.92:((n+.055)/1.055)**2.4); const l=rgb[0]*.2126+rgb[1]*.7152+rgb[2]*.0722; return (l+.05)/.05>=1.05/(l+.05)?'#000000':'#ffffff'; })();
  const dirty = !saved || saved.background !== parseInt(color.slice(1),16) || saved.fields.join() !== fields.join();
  useEffect(() => {
    const id = new URLSearchParams(window.location.search).get('design');
    if (!id || !/^[a-f0-9]{12}$/.test(id)) return;
    let active = true;
    void fetch(`/api/designs/${id}`).then(async response => { const data = await response.json(); if (!response.ok) throw new Error(data.error); if (active) { setSaved(data);setFields(data.fields);setColor('#'+data.background.toString(16).padStart(6,'0')); } }).catch(e => {if(active)setError(e.message);});
    return () => { active = false; };
  }, []);
  async function save() {
    setSaving(true);setError('');setCopied(false);
    try { const response = await fetch(saved?`/api/designs/${saved.id}`:'/api/designs',{method:saved?'PUT':'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({fields,background:parseInt(color.slice(1),16)})}); const data=await response.json(); if(!response.ok) throw new Error(data.error||'Could not save design.');setSaved(data);window.history.replaceState(null,'',`/designer?design=${data.id}`); }
    catch(e) {setError(e instanceof Error?e.message:'Could not save design.');} finally {setSaving(false);}
  }
  return <div className="designer-page"><header><a href="/" className="brand">↗ DASHMAX <span className="beta">DESIGNER TEST</span></a><a className="back-link" href="/">Dashboard concept ↗</a></header><main className="designer-main"><div className="eyebrow">WEB → GARMIN</div><h1>Three fields.<br/><em>Your screen.</em></h1><p className="designer-intro">Choose three metrics and a background. Save once, then edit the same design to update the connected test field.</p><div className="designer-grid"><section className="designer-form"><h2>Build your test screen</h2>{[0,1,2].map(index=><label key={index}>Field {index+1}<select aria-label={`Field ${index+1}`} value={fields[index]} onChange={e=>{const next=[...fields];next[index]=e.target.value;setFields(next);}}>{METRICS.map(([id,label])=><option key={id} value={id} disabled={fields.includes(id)&&fields[index]!==id}>{label}</option>)}</select></label>)}<label className="designer-color">Background <span><input aria-label="Background color" type="color" value={color} onChange={e=>setColor(e.target.value)}/><code>{color.toUpperCase()}</code></span></label><button className="save-design" disabled={saving||!dirty||new Set(fields).size!==3} onClick={save}>{saving?'Saving…':saved?'Save changes':'Save design'}</button>{error&&<p role="alert">{error}</p>}{saved&&<div className="design-saved" role="status"><span>{dirty?'Unsaved changes':'Saved'} · Revision {saved.revision}</span><h3>Design ID</h3><div><code>{saved.id}</code><button onClick={async()=>{try{await navigator.clipboard.writeText(saved.id);setCopied(true);}catch{setError('Select and copy the design ID shown above.');}}}>{copied?'Copied':'Copy'}</button></div><p>Keep this ID. Saving changes updates the same screen; no new code or rebuild is needed after the simulator is connected.</p></div>}</section><section className="designer-preview"><div className="panel-heading"><span>LAYOUT PREVIEW · MOCK VALUES</span><span>246 × 322 PX</span></div><div className="three-screen" style={{background:color,color:foreground}}>{fields.map((id,index)=>{const metric=METRICS.find(m=>m[0]===id)!;return <div className="three-metric" key={index}><span>{metric[1]}</span><div><strong>{metric[2]}</strong><small>{metric[3]}</small></div></div>;})}</div><p>Device units follow Garmin. This test screen uses the chosen background across all three rows.</p></section></div><section className="designer-next"><h2>Connect the Garmin simulator</h2><p>Keep this server running. Use the HTTPS tunnel and <code>garmin:design</code> steps in <code>docs/designer-test.md</code>. The native field fetches the design every 15 seconds and caches the last valid version. No Store publication is required.</p></section></main></div>;
}
