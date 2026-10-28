export function heading(degrees: number | null) {
  if (degrees === null || !Number.isFinite(degrees)) return null;
  const normalized = ((degrees % 360) + 360) % 360;
  return { degrees: Math.round(normalized) % 360, cardinal: ['N','NE','E','SE','S','SW','W','NW'][Math.floor((normalized + 22.5) / 45) % 8] };
}
export const convert = (km: number, imperial: boolean) => km * (imperial ? 0.621371192 : 1);
export const distanceText = (km: number, imperial: boolean) => { const n = convert(km, imperial); return Number(n.toFixed(1)) >= 1000 ? n.toFixed(0) : n.toFixed(1); };
export const elapsedText = (s: number) => `${Math.floor(s / 3600)}:${String(Math.floor(s / 60) % 60).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
export const powerAt = (t: number) => Math.round(290 + Math.sin(t * .37) * 32 + Math.sin(t * 1.13) * 17 + Math.cos(t * .17) * 22);
