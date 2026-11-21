import express from 'express';
import cors from 'cors';
import { config, anthropicKey } from './config.js';
import { audit } from './audit.js';
import { dbStatus } from './db.js';
import { relay } from './claude.js';
import { scorecards, contractorWorkOrders } from './scorecards.js';
import { errorHandler, notFound } from './errors.js';

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

// Request log: method, path, status, time. No bodies, so no personal data.
app.use((req, res, next) => {
  const t = Date.now();
  res.on('finish', () => console.log(`${req.method} ${req.originalUrl} ${res.statusCode} ${Date.now() - t}ms`));
  next();
});

const lookup = (table, id, what) => {
  if (!Object.hasOwn(table, id)) throw notFound(what);
  return table[id];
};

app.get('/api/health', async (_req, res) => {
  const db = await dbStatus();
  res.json({ ok: true, audit_generated_at: audit.meta.generated_at, db });
});

app.get('/api/meta', (_req, res) => res.json(audit.meta));

// Shading values only; detail comes from /api/wards/:code.
app.get('/api/wards', (_req, res) => {
  res.json(
    Object.entries(audit.wards).map(([code, w]) => ({
      code,
      name: w.name,
      budget: w.budget,
      spend: w.spend,
      remaining: w.remaining,
      flagged_inr: w.flagged_inr,
      flagged_share: w.flagged_share,
      dlp_paid_inr: w.by_flag_type?.dlp_paid?.inr ?? 0,
      dlp_paid_count: w.by_flag_type?.dlp_paid?.count ?? 0,
      centroid_lat: w.centroid_lat,
      centroid_lon: w.centroid_lon,
    })),
  );
});

// Ward codes contain slashes (H/E): clients send them URL-encoded (H%2FE); Express decodes params.
app.get('/api/wards/:code', (req, res) => {
  res.json({ code: req.params.code, ...lookup(audit.wards, req.params.code, `Ward '${req.params.code}'`) });
});

app.get('/api/roads', (_req, res) => {
  res.json(
    Object.entries(audit.roads).map(([road_id, r]) => ({
      road_id,
      road_name: r.road_name,
      ward_code: r.ward_code,
      road_type: r.road_type,
      under_dlp: r.under_dlp,
      status: r.status,
      spend: r.spend,
    })),
  );
});

app.get('/api/roads/:id', (req, res) => {
  res.json({ road_id: req.params.id, ...lookup(audit.roads, req.params.id, `Road '${req.params.id}'`) });
});

app.get('/api/contractors', (_req, res) => {
  res.json(Object.entries(audit.contractors).map(([id, c]) => ({ id, ...c })));
});

// Fair scorecards, alphabetical; ?ward= scopes to one ward (not-rated below the minimum jobs).
app.get('/api/scorecards', (req, res) => {
  res.json(scorecards(audit, typeof req.query.ward === 'string' ? req.query.ward : undefined));
});

// Work orders behind one scorecard measure: ?metric=speed|durability|pricing[&ward=CODE], max 100 rows + total.
app.get('/api/contractors/:id/work-orders', (req, res) => {
  const { metric, ward } = req.query;
  res.json(contractorWorkOrders(audit, req.params.id, metric, typeof ward === 'string' ? ward : undefined));
});

// Includes the ward's hospitals, schools and flood hotspots for the pin layer.
app.get('/api/next-rupee/:ward', (req, res) => {
  const ward = req.params.ward;
  res.json({
    ward,
    ...lookup(audit.next_rupee, ward, `Ward '${ward}'`),
    facilities: audit.facilities.filter((f) => f.ward_code === ward),
    hotspots: audit.hotspots.filter((h) => h.ward_code === ward),
  });
});

// Flag rows filtered by ?ward=, ?road=, ?type= (all optional, combined with AND).
app.get('/api/flags', (req, res) => {
  const { ward, road, type } = req.query;
  res.json(
    audit.flags.filter(
      (f) => (!ward || f.ward_code === ward) && (!road || f.road_id === road) && (!type || f.type === type),
    ),
  );
});

app.get('/api/timeline', (_req, res) => res.json(audit.timeline));

app.post('/api/claude/:feature', async (req, res) => {
  res.json(await relay(req.params.feature, req.body ?? {}, audit));
});

app.use((req, _res, next) => next(notFound(`Route ${req.method} ${req.path}`)));
app.use(errorHandler);

app.listen(config.port, async () => {
  console.log(`Nagar Sarthi API on http://localhost:${config.port} (audit ${audit.meta.generated_at})`);
  console.log(`Claude: ${anthropicKey() ? 'key present' : 'no key, fallbacks only'}, model ${config.claudeModel}`);
  const db = await dbStatus();
  if (!db.ok) console.warn(`[db] Postgres not ready (${db.error ?? `tables: ${db.tables.join(',')}`}); read endpoints still work`);
  else console.log('[db] Postgres ok, tables:', db.tables.join(', '));
});
