// The design format shared by the web designer and the design server. The
// Garmin field implements the same rules natively in garmin/source/DesignSync.mc;
// change them together.

export const SCHEMA = 2;
export const WIDTH = 246;
export const HEIGHT = 322;
export const MAX_ROWS = 6;
export const MAX_CELLS = 2;

// label: full-width cell. short: half-width cell. sample: web preview only.
export const METRICS = {
  power: { name: 'Power', label: 'POWER', short: 'POWER', unit: 'W', sample: '312', zone: true },
  avgPower: { name: 'Average power', label: 'AVG POWER', short: 'AVG PWR', unit: 'W', sample: '284' },
  heartRate: { name: 'Heart rate', label: 'HEART RATE', short: 'HR', unit: 'bpm', sample: '158', zone: true },
  avgHeartRate: { name: 'Average heart rate', label: 'AVG HEART RATE', short: 'AVG HR', unit: 'bpm', sample: '142' },
  cadence: { name: 'Cadence', label: 'CADENCE', short: 'CADENCE', unit: 'rpm', sample: '92' },
  speed: { name: 'Speed', label: 'SPEED', short: 'SPEED', unit: 'km/h', sample: '26.8' },
  avgSpeed: { name: 'Average speed', label: 'AVG SPEED', short: 'AVG SPD', unit: 'km/h', sample: '24.1' },
  distance: { name: 'Distance', label: 'DISTANCE', short: 'DISTANCE', unit: 'km', sample: '42.7' },
  elapsed: { name: 'Elapsed time', label: 'ELAPSED', short: 'ELAPSED', unit: '', sample: '1:36:24' },
  grade: { name: 'Current grade', label: 'GRADE', short: 'GRADE', unit: '%', sample: '3.2' },
  ascent: { name: 'Elevation climbed', label: 'ASCENT', short: 'ASCENT', unit: 'm', sample: '486' },
  heading: { name: 'Direction', label: 'DIRECTION', short: 'DIRECTION', unit: '42 deg', sample: 'NE' },
  graph: { name: 'Power graph (needs a full row)', label: 'POWER 90s', short: 'POWER 90s', unit: '', sample: '', fullRow: true },
};

// Returns a message describing why rows cannot be drawn, or null if they can.
export function designProblem(rows) {
  if (!Array.isArray(rows) || rows.length < 1 || rows.length > MAX_ROWS) return `Use between one and ${MAX_ROWS} rows.`;
  let total = 0;
  let smallest = 3;
  for (const [index, row] of rows.entries()) {
    const at = `Row ${index + 1}`;
    if (!row || ![1, 2, 3].includes(row.size)) return `${at} needs a size of small, medium or large.`;
    if (!Array.isArray(row.cells) || row.cells.length < 1 || row.cells.length > MAX_CELLS) return `${at} needs one or two cells.`;
    for (const cell of row.cells) {
      if (!cell || !Object.hasOwn(METRICS, cell.metric)) return `${at} has an unsupported metric.`;
      if (METRICS[cell.metric].fullRow && row.cells.length !== 1) return `${at}: the power graph needs a full row.`;
      if (cell.zone !== undefined && typeof cell.zone !== 'boolean') return `${at} has an invalid zone setting.`;
    }
    total += row.size;
    smallest = Math.min(smallest, row.size);
  }
  // Keeps the shortest row at 40 px or more on the 322 px screen.
  if (total > 8 * smallest) return 'Some rows would be too short to read. Remove a row or make the large rows smaller.';
  return null;
}

// Optional power zones: the top of zones 1 to 6 in watts, lowest first. Zone 7
// is everything above. Used by the device only when Garmin supplies none.
export function zonesProblem(zones) {
  if (zones === undefined || zones === null) return null;
  if (!Array.isArray(zones) || zones.length !== 6) return 'Enter all six power zone limits, or clear them all.';
  if (!zones.every(watts => Number.isInteger(watts) && watts >= 1 && watts <= 5000)) return 'Power zone limits must be whole watts between 1 and 5000.';
  if (zones.some((watts, index) => index > 0 && watts <= zones[index - 1])) return 'Each power zone limit must be higher than the one before.';
  return null;
}

// Canonical copy: known keys only, zone kept only where it applies.
export function normalizeRows(rows) {
  return rows.map(row => ({
    size: row.size,
    cells: row.cells.map(cell => (cell.zone === true && METRICS[cell.metric].zone ? { metric: cell.metric, zone: true } : { metric: cell.metric })),
  }));
}

// Pixel boxes on the 246 x 322 screen. Integer maths, matching the device.
export function layout(rows) {
  const total = rows.reduce((sum, row) => sum + row.size, 0);
  let before = 0;
  return rows.map(row => {
    const top = Math.floor((HEIGHT * before) / total);
    before += row.size;
    const bottom = Math.floor((HEIGHT * before) / total);
    const count = row.cells.length;
    return {
      top,
      height: bottom - top,
      cells: row.cells.map((cell, index) => {
        const left = Math.floor((WIDTH * index) / count);
        return { ...cell, left, width: Math.floor((WIDTH * (index + 1)) / count) - left };
      }),
    };
  });
}

const row = (size, ...cells) => ({ size, cells: cells.map(cell => (typeof cell === 'string' ? { metric: cell } : cell)) });
const zoned = metric => ({ metric, zone: true });

export const PRESETS = [
  { id: 'balanced', name: 'Balanced', rows: [row(3, zoned('power')), row(1, 'graph'), row(2, zoned('heartRate'), 'cadence'), row(2, 'speed', 'distance')] },
  { id: 'climbing', name: 'Climbing', rows: [row(3, zoned('power')), row(2, 'grade', 'ascent'), row(2, zoned('heartRate'), 'cadence'), row(1, 'speed', 'distance')] },
  { id: 'three', name: 'Three rows', rows: [row(2, 'power'), row(2, 'heartRate'), row(2, 'speed')] },
  { id: 'big-two', name: 'Big two', rows: [row(3, zoned('power')), row(3, zoned('heartRate'))] },
  { id: 'dense', name: 'Data dense', rows: [row(1, 'power', 'heartRate'), row(1, 'cadence', 'speed'), row(1, 'distance', 'elapsed'), row(1, 'grade', 'ascent'), row(1, 'avgPower', 'heading')] },
];

// Version 1 designs were three full-width rows of equal height.
export function upgrade(design) {
  if (!design || design.version !== 1 || !Array.isArray(design.fields)) return design;
  const { fields, ...rest } = design;
  return { ...rest, version: SCHEMA, rows: fields.map(metric => row(2, metric)) };
}
