// Monsoon slider and complaints heat: compact shapes for the phone.

const r4 = (n) => Math.round(n * 1e4) / 1e4;

/** Per day: {d, rain, alert, tide, n, c:[[lat,lon]], r:[road_id], x:[road_id]}. n = all complaints that day. */
export function compactTimeline(audit) {
  // The engine dates a re-open at completion + 30 days; those past the last day are folded into it
  // so the slider ends on the same failed-repair total (611) as every other screen.
  const last = audit.timeline.at(-1).date;
  const placed = new Set(audit.timeline.flatMap((t) => t.reopens.map((x) => x.work_order_id)));
  const late = audit.flags
    .filter((f) => f.type === 'fix_failed' && !placed.has(f.work_order_id))
    .filter((f) => addDays(f.evidence.completed_at.slice(0, 10), 30) > last)
    .map((f) => f.road_id);
  return audit.timeline.map((t, i, all) => ({
    d: t.date,
    rain: t.rainfall_mm,
    alert: t.alert,
    tide: t.big_tide,
    n: t.complaints.length,
    c: t.complaints.filter((c) => c.lat != null && c.lon != null).map((c) => [r4(c.lat), r4(c.lon)]),
    r: t.repairs.map((x) => x.road_id),
    x: [...t.reopens.map((x) => x.road_id), ...(i === all.length - 1 ? late : [])],
  }));
}

const addDays = (iso, n) => new Date(Date.parse(`${iso}T00:00:00Z`) + n * 864e5).toISOString().slice(0, 10);

const OPEN = new Set(['Open', 'In Progress']);
const CELL = 0.01; // grid cell in degrees, about 1 km

/** Open and repeat (work order re-opened) complaints, clustered on a grid; [ward] scopes to one ward. Sample = latest 5. */
export function complaintsHeat(audit, ward) {
  const where = new Map();
  for (const t of audit.timeline) for (const c of t.complaints) if (c.lat != null) where.set(c.id, [c.lat, c.lon]);
  const cells = new Map();
  for (const [id, c] of Object.entries(audit.complaints)) {
    if (ward && c.ward_code !== ward) continue;
    const open = OPEN.has(c.status);
    if (!open && !c.reopened) continue;
    const w = audit.wards[c.ward_code];
    const [lat, lon] = where.get(id) ?? (w ? [w.centroid_lat, w.centroid_lon] : []);
    if (lat == null) continue;
    const key = `${Math.floor(lat / CELL)}:${Math.floor(lon / CELL)}`;
    const cell = cells.get(key) ?? { lat: 0, lon: 0, count: 0, open: 0, all: [] };
    cell.lat += lat;
    cell.lon += lon;
    cell.count++;
    if (open) cell.open++;
    cell.all.push({ id, category: c.category, locality: c.locality, status: c.status, received_at: c.received_at, repeat: !!c.reopened });
    cells.set(key, cell);
  }
  return [...cells.values()]
    .map(({ all, ...k }) => ({
      lat: r4(k.lat / k.count),
      lon: r4(k.lon / k.count),
      count: k.count,
      open: k.open,
      sample: all.sort((a, b) => b.received_at.localeCompare(a.received_at)).slice(0, 5),
    }))
    .sort((a, b) => b.count - a.count);
}
