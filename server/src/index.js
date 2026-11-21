import express from 'express';
import cors from 'cors';
import compression from 'compression';
import { config, anthropicKey } from './config.js';
import { audit } from './audit.js';
import { dbStatus } from './db.js';
import { relay } from './claude.js';
import { scorecards, contractorWards, contractorWorkOrders } from './scorecards.js';
import { errorHandler, notFound, badRequest } from './errors.js';
import { login, seedUsers, session, needUser, needRole } from './auth.js';
import { compactTimeline, complaintsHeat } from './timeline.js';
import { issuesList, issueDetail, linkerSummary, issuesForWorkOrder } from './issues.js';
import { localities, understand, findMatches, localityByName, createComplaint, complaintDetail, complaintsAt } from './citizen.js';

const app = express();
app.use(cors());
app.use(compression());
app.use(express.json({ limit: '1mb' }));

// Request log: method, path, status, time. No bodies, so no personal data.
app.use((req, res, next) => {
  const t = Date.now();
  res.on('finish', () => console.log(`${req.method} ${req.originalUrl} ${res.statusCode} ${Date.now() - t}ms`));
  next();
});
app.use(session);

const lookup = (table, id, what) => {
  if (!Object.hasOwn(table, id)) throw notFound(what);
  return table[id];
};

app.get('/api/health', async (_req, res) => {
  const db = await dbStatus();
  res.json({ ok: true, audit_generated_at: audit.meta.generated_at, db });
});

// Sign-in: {phone, code} -> {token, role, ward_code, phone}; 401 on a wrong code.
app.post('/api/auth/login', async (req, res) => res.json(await login(req.body ?? {})));
// Demo shortcuts only: the code from config, so the app never hardcodes it. 404 when DEMO_SHORTCUTS=off.
app.get('/api/auth/demo', (_req, res) => {
  if (!config.demoShortcuts) throw notFound('Demo sign-in');
  res.json({ code: config.demoLoginCode, users: { citizen: '9000000001', corporator: '9000000002', officer: '9000000003' } });
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
      // Same source as the ward detail (by_flag_type), so the map card, ward page and list agree.
      fix_failed_count: w.by_flag_type?.fix_failed?.count ?? 0,
      fix_failed_inr: w.by_flag_type?.fix_failed?.inr ?? 0,
      jobs: w.by_contractor.reduce((s, c) => s + c.jobs, 0),
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

// Each work order carries issue_ids: the linker issues that point at it (complaint trail).
app.get('/api/roads/:id', (req, res) => {
  const r = lookup(audit.roads, req.params.id, `Road '${req.params.id}'`);
  res.json({
    road_id: req.params.id,
    ...r,
    work_orders: r.work_orders.map((wo) => ({ ...wo, issue_ids: issuesForWorkOrder(audit, wo.id) })),
  });
});

app.get('/api/contractors', (_req, res) => {
  res.json(Object.entries(audit.contractors).map(([id, c]) => ({ id, ...c })));
});

// Fair scorecards, alphabetical; ?ward= scopes to one ward (not-rated below the minimum jobs).
app.get('/api/scorecards', (req, res) => {
  res.json(scorecards(audit, typeof req.query.ward === 'string' ? req.query.ward : undefined));
});

// One contractor ward by ward (every ward it worked in): jobs, spend, rated or why not, the three measures.
app.get('/api/contractors/:id/wards', (req, res) => res.json(contractorWards(audit, req.params.id)));

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

// Flag rows, biggest rupees first. Filters (all optional, AND): ?ward= ?road= ?contractor= (id)
// ?type= (one or comma-separated) ?q= (work order id or road name, case-insensitive).
// Paged with ?offset= and ?limit= (default 50, max 100). Returns {total, total_inr, items}; items carry road_name.
app.get('/api/flags', (req, res) => {
  const str = (v) => (typeof v === 'string' && v.trim() ? v.trim() : undefined);
  const ward = str(req.query.ward);
  const road = str(req.query.road);
  const contractor = str(req.query.contractor);
  const types = str(req.query.type)?.split(',');
  const q = str(req.query.q)?.toLowerCase();
  const offset = Math.max(0, Number.parseInt(req.query.offset, 10) || 0);
  const limit = Math.min(100, Math.max(1, Number.parseInt(req.query.limit, 10) || 50));
  const roadName = (id) => audit.roads[id]?.road_name ?? id;
  const rows = audit.flags
    .filter(
      (f) =>
        (!ward || f.ward_code === ward) &&
        (!road || f.road_id === road) &&
        (!contractor || f.contractor_id === contractor) &&
        (!types || types.includes(f.type)) &&
        (!q || f.work_order_id.toLowerCase().includes(q) || roadName(f.road_id).toLowerCase().includes(q)),
    )
    .sort((a, b) => b.cost_inr - a.cost_inr || a.work_order_id.localeCompare(b.work_order_id));
  // Rupees to review: each work order once (a job can carry several flags); sla_missed is timing only.
  const money = new Map(rows.filter((f) => f.type !== 'sla_missed').map((f) => [f.work_order_id, f.cost_inr]));
  res.json({
    total: rows.length,
    total_inr: [...money.values()].reduce((s, v) => s + v, 0),
    items: rows.slice(offset, offset + limit).map((f) => ({ ...f, road_name: roadName(f.road_id) })),
  });
});

// Complaint trail (engine linker): issues paged and filtered, one issue's full trail, the funnel numbers.
// /api/issues?ward=&outcome=&q=&offset=&limit= (max 100) -> {total, items}; /api/linker?ward= (empty = city).
app.get('/api/issues', (req, res) => res.json(issuesList(audit, req.query)));
app.get('/api/issues/:id', (req, res) => res.json(issueDetail(audit, req.params.id)));
app.get('/api/linker', (req, res) => res.json(linkerSummary(audit, req.query.ward)));

// Compact per-day shape for the monsoon slider (see timeline.js), built once.
const timeline = compactTimeline(audit);
app.get('/api/timeline', (_req, res) => res.json(timeline));

// Open and repeat complaints clustered on a ~1 km grid; ?ward=CODE scopes to one ward.
app.get('/api/complaints/heat', (req, res) => {
  const ward = typeof req.query.ward === 'string' && req.query.ward ? req.query.ward : undefined;
  if (ward) lookup(audit.wards, ward, `Ward '${ward}'`);
  res.json(complaintsHeat(audit, ward));
});

// Citizen side (TASK-06). Gazetteer for the locality picker.
app.get('/api/localities', (_req, res) => {
  res.json(localities.map(({ locality, ward_code, aliases }) => ({ locality, ward_code, aliases })));
});

// File a complaint (validated; 400 with fields, 503 when Postgres is down).
app.post('/api/complaints', async (req, res) => {
  const user = needUser(req, 'file a complaint');
  const b = req.body && typeof req.body === 'object' && !Array.isArray(req.body) ? req.body : {};
  res.status(201).json(await createComplaint(audit, b, user.uid));
});

// Track: ?locality= lists, /:id gives the full trail. After /heat so that route still matches.
app.get('/api/complaints', async (req, res) => res.json(await complaintsAt(audit, req.query.locality)));
// Re-run matching after the citizen corrects category or locality on the intake card.
app.get('/api/complaints/matches', async (req, res) => {
  const loc = localityByName(req.query.locality);
  if (!loc) throw notFound(`Locality '${req.query.locality}'`);
  if (typeof req.query.category !== 'string') throw badRequest('Send ?category=');
  res.json(await findMatches(audit, req.query.category, loc.locality));
});
app.get('/api/complaints/:id', async (req, res) => res.json(await complaintDetail(audit, req.params.id)));

// Intake: Claude (or the device rules) gives category, place text and language; the server
// resolves the locality from the gazetteer and finds matching complaints.
app.post('/api/claude/intake', async (req, res) => {
  const reply = await relay('intake', req.body ?? {}, audit);
  res.json(await understand(audit, req.body, reply));
});

app.post('/api/claude/:feature', async (req, res) => {
  // Checked here, not on a separate route, so no spelling of the path can skip it.
  if (req.params.feature.toLowerCase() === 'notice') needRole(req, 'officer', 'draft a recovery notice');
  res.json(await relay(req.params.feature, req.body ?? {}, audit));
});

app.use((req, _res, next) => next(notFound(`Route ${req.method} ${req.path}`)));
app.use(errorHandler);

app.listen(config.port, async () => {
  console.log(`Nagar Sarthi API on http://localhost:${config.port} (audit ${audit.meta.generated_at})`);
  console.log(`Claude: ${anthropicKey() ? 'key present' : 'no key, fallbacks only'}, model ${config.claudeModel}`);
  const db = await dbStatus();
  if (!db.ok) console.warn(`[db] Postgres not ready (${db.error ?? `tables: ${db.tables.join(',')}`}); read endpoints still work`);
  else {
    console.log('[db] Postgres ok, tables:', db.tables.join(', '));
    await seedUsers().catch((e) => console.warn('[auth] could not seed demo users:', e.message));
  }
});
