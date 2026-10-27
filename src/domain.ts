export const normalize180 = (d: number) => ((d + 180) % 360 + 360) % 360 - 180;
export function wind(course: number, from: number, speed: number) {
  const relative = normalize180(from - course);
  const component = speed * Math.cos(relative * Math.PI / 180);
  return { relative, component, label: speed === 0 ? 'CALM' : Math.abs(component) < speed * 0.15 ? 'CROSSWIND' : component >= 0 ? 'HEADWIND' : 'TAILWIND' };
}
export const convert = (km: number, imperial: boolean) => km * (imperial ? 0.621371192 : 1);
export const distanceText = (km: number, imperial: boolean) => { const n = convert(km, imperial); return Number(n.toFixed(1)) >= 1000 ? n.toFixed(0) : n.toFixed(1); };
export const elapsedText = (s: number) => `${Math.floor(s / 3600)}:${String(Math.floor(s / 60) % 60).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
export const powerAt = (t: number) => Math.round(290 + Math.sin(t * .37) * 32 + Math.sin(t * 1.13) * 17 + Math.cos(t * .17) * 22);
