import React, { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { convert, distanceText, elapsedText, powerAt, heading } from './domain';
import '@fontsource/barlow-condensed/500.css';
import '@fontsource/barlow-condensed/600.css';
import '@fontsource/dm-sans/400.css';
import '@fontsource/dm-sans/500.css';
import '@fontsource/dm-sans/600.css';
import '@fontsource/dm-sans/700.css';
import './style.css';

function Fit({ children, max = 20, min = 12 }: {children: string; max?: number; min?: number}) {
  const ref = useRef<HTMLSpanElement>(null);
  useLayoutEffect(() => {
    const el = ref.current; if (!el) return;
    const canvas = document.createElement('canvas').getContext('2d')!;
    const style = getComputedStyle(el); let size = max;
    const fit = () => { size = max; while (size > min) { canvas.font = `${style.fontWeight} ${size}px ${style.fontFamily}`; if (canvas.measureText(children).width <= el.clientWidth) break; size -= .5; } el.style.fontSize = `${size}px`; };
    let active = true; fit(); void document.fonts.ready.then(() => { if (active) fit(); }); const observer = new ResizeObserver(fit); observer.observe(el); return () => { active = false; observer.disconnect(); };
  }, [children, max, min]);
  return <span ref={ref} className="fit" style={{fontSize: max}}>{children}</span>;
}
function App() {
  const [imperial, setImperial] = useState(false), [dark, setDark] = useState(false), [live, setLive] = useState(false), [tick, setTick] = useState(0);
  const [course, setCourse] = useState(0);
  const [distance, setDistance] = useState(42.7), [elapsed, setElapsed] = useState(5784), [scale, setScale] = useState(() => window.innerWidth < 760 ? 1 : 1.5), [sensor, setSensor] = useState('connected');
  useEffect(() => { const media = matchMedia('(max-width: 760px)'); const update = () => setScale(media.matches ? 1 : 1.5); media.addEventListener('change', update); return () => media.removeEventListener('change', update); }, []);
  const direction = heading(sensor === 'no-course' || sensor === 'paused' ? null : course), unit = imperial ? 'mph' : 'km/h';
  useEffect(() => { if (!live || sensor === 'paused') return; const id = setInterval(() => setTick(t => t + 1), 1000); return () => clearInterval(id); }, [live, sensor]);
  const power = tick ? powerAt(tick) : 312;
  const history = Array.from({length: 90}, (_, i) => powerAt(i + tick - 89));
  const points = history.map((p, i) => `${i * 218 / 89},${35 - Math.max(0, Math.min(450, p)) / 450 * 34}`).join(' ');
  return <div className="app">
    <header><a className="brand" href="#"><span className="brand-icon"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M6 18 18 6M6 6h12v12"/></svg></span> DASHMAX<span className="beta">LAB</span></a><div className="header-right"><span className="desktop">DESIGNED FOR THE RIDE</span><span className="version">CONCEPT 01</span></div></header>
    <main><section className="intro"><div><div className="eyebrow"><span/> THE CYCLING DISPLAY, RECONSIDERED</div><h1>More ride.<br/><em>Less noise.</em></h1><p>Your essential numbers, in the right order.<br/>A focused dashboard concept for Garmin Edge 840.</p></div><div className="intro-note"><span>01 / BALANCED</span><p>Built around attention.<br/>Not data density.</p></div></section>
    <div className="workspace"><section className="preview-panel"><div className="panel-heading"><span><i className={live ? 'dot live' : 'dot'}/>{live ? 'LIVE SIMULATION' : 'DETERMINISTIC PREVIEW'}</span><span>246 × 322 PX</span></div>
      <div className="device-stage"><div className="device" style={{width:246*scale+38,height:322*scale+106}}><div className="device-top"><span>GARMIN</span><span>▪ ▪ ▪</span></div><div className="screen-slot" style={{width:246*scale,height:322*scale}}><div className={`dashboard ${dark?'dark':''}`} style={{transform:`scale(${scale})`}}>
      <div className="power-block"><div className="metric-label">3s POWER <span>WATTS</span></div><div className="hero-row"><strong className="hero">{sensor==='missing'?'—':sensor==='paused'?'0':power}</strong><div className="average"><span>RIDE AVG</span><b>{sensor==='missing'?'—':'284'}<small> W</small></b></div></div><div className="graph"><svg viewBox="0 0 218 38" role="img" aria-label="90-second mock power history, fixed 0 to 450 watt scale"><path d="M0 12H218 M0 27H218" stroke="currentColor" opacity=".10"/><polyline opacity={sensor==='missing'?0:1} points={points} stroke="var(--accent)" strokeWidth="1.5" fill="none"/></svg><span>90s</span></div></div>
      <div className="hr-row"><div><div className="metric-label"><span className="heart">♥</span> HEART RATE</div><strong>{sensor==='missing'?'—':'158'}<small> bpm</small></strong></div><div className="average"><span>RIDE AVG</span><b>{sensor==='missing'?'—':'142'}<small> bpm</small></b></div></div>
      <div className="motion-row"><div className="cadence"><div className="metric-label">CADENCE</div><strong>{sensor==='missing'?'—':sensor==='paused'?'0':'92'}<small> rpm</small></strong></div><div className="speed"><div className="metric-label">SPEED <span>{unit}</span></div><strong>{sensor==='paused'?'0.0':convert(26.8,imperial).toFixed(1)}</strong><span className="speed-avg">AVG {convert(24.1,imperial).toFixed(1)}</span></div></div>
      <div className="ride-footer"><div className="heading-cell"><div className="metric-label">HEADING</div><div className="heading-summary">{direction ? <><svg className="heading-arrow" viewBox="0 0 24 24" role="img" aria-label="Travel direction, north up" style={{transform:`rotate(${direction.degrees}deg)`}}><path d="M12 3 5 19l7-4 7 4Z" fill="none" stroke="currentColor" strokeWidth="1.8"/></svg><b>{direction.cardinal}</b></> : <b>—</b>}</div><span className="heading-degrees">{direction ? `${direction.degrees}°` : 'NO COURSE'}</span></div><div className="distance-cell"><div className="metric-label">DISTANCE</div><Fit max={21}>{distanceText(distance,imperial)}</Fit><small>{imperial?'mi':'km'}</small></div><div className="time-cell"><div className="metric-label">ELAPSED</div><Fit max={17}>{elapsedText(elapsed + tick)}</Fit><small>{sensor==='paused'?'PAUSED':'RIDE TIME'}</small></div></div>
      </div></div><div className="device-bottom"><span>EDGE 840</span><span className="device-button"/></div></div></div>
      <div className="preview-toolbar"><div className="zoom-control">SCALE {[1,1.5,2].map(s=><button key={s} className={scale===s?'selected':''} onClick={()=>setScale(s)}>{s===1?'1:1':`${s}×`}</button>)}</div><button className="play" onClick={()=>setLive(!live)}>{live?'Ⅱ Pause telemetry':'▷ Play telemetry'}</button></div>
      <div className="preview-caption"><span className="tiny-cross">+</span> Native pixel geometry. Mock telemetry. Real priorities.</div></section>
      <aside className="controls"><div className="control-header"><div className="eyebrow">MAKE IT YOUR RIDE</div><h2>The cockpit.</h2><p>Explore the display. Every change stays in the demo.</p></div>
      <section className="control-section"><div className="section-title"><span>01</span><h3>Display</h3></div><div className="setting"><span>Appearance</span><div className="segmented"><button className={!dark?'active':''} onClick={()=>setDark(false)}>Light</button><button className={dark?'active':''} onClick={()=>setDark(true)}>Dark</button></div></div><div className="setting"><span>Units</span><div className="segmented"><button className={!imperial?'active':''} onClick={()=>setImperial(false)}>Metric</button><button className={imperial?'active':''} onClick={()=>setImperial(true)}>Imperial</button></div></div></section>
      <section className="control-section"><div className="section-title"><span>02</span><h3>Rider heading</h3><span className="tag">DEMO</span></div><Range label="Riding course" value={course} max={359} unit="°" onChange={setCourse}/><p className="heading-note">North stays at the top. The arrow shows your direction of travel, with a compass bearing in degrees. On Garmin this uses GPS course; a missing course shows a dash.</p></section>
      <section className="control-section"><div className="section-title"><span>03</span><h3>Put the layout to work</h3></div><p className="section-description">Long rides deserve room, too.</p><div className="two-selects"><label className="select-label">Distance ({imperial?'mi':'km'})<select aria-label={`Distance (${imperial ? 'mi' : 'km'})`} value={distance} onChange={e=>setDistance(Number(e.target.value))}>{[9.7,42.7,142.7,999.9,1000,1609.344].map(n=><option key={n} value={n}>{distanceText(n,imperial)}</option>)}</select></label><label className="select-label">Elapsed time<select aria-label="Elapsed time" value={elapsed} onChange={e=>{setElapsed(Number(e.target.value));setTick(0);}}>{[3599,5784,38184,86400].map(n=><option key={n} value={n}>{elapsedText(n)}</option>)}</select></label></div><label className="select-label sensor-select">Ride state<select aria-label="Ride state" value={sensor} onChange={e=>setSensor(e.target.value)}><option value="connected">Sensors connected</option><option value="missing">Sensors unavailable</option><option value="paused">Stopped / paused activity</option><option value="no-course">GPS course unavailable</option></select></label></section>
      <button className="reset" onClick={()=>{setDark(false);setImperial(false);setCourse(0);setDistance(42.7);setElapsed(5784);setSensor('connected');setLive(false);setTick(0);setScale(window.innerWidth < 760 ? 1 : 1.5);}}>↺ Reset to the starting line</button></aside></div>
      <section className="principles"><div><span>01 / HIERARCHY</span><h3>The numbers that matter.</h3><p>Power leads. Heart rate supports. Whole-ride averages keep the bigger picture close.</p></div><div><span>02 / CLARITY</span><h3>Sunlight is the standard.</h3><p>Warm white, bold figures, and restrained color. Designed to be understood at a glance.</p></div><div><span>03 / CONTEXT</span><h3>Know what’s ahead.</h3><p>A compact heading keeps your direction of travel close, with room left for the ride.</p></div></section>
      <footer><span className="footer-brand">DASHMAX <span> / RIDE IN FOCUS</span></span><span>WEB CONCEPT · NOT CONNECTED TO A DEVICE</span></footer>
    </main></div>;
}
function Range({label,value,max,unit,onChange}:{label:string;value:number;max:number;unit:string;onChange:(n:number)=>void}) { return <label className="range-label"><span>{label}<b>{Math.round(value)}{unit}</b></span><input type="range" min="0" max={max} step="1" value={value} onChange={e=>onChange(Number(e.target.value))}/></label>; }
createRoot(document.getElementById('root')!).render(<App/>);
