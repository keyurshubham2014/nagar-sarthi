import { readFileSync } from 'node:fs';
import path from 'node:path';
import { serverRoot } from './config.js';
import { badRequest, notFound } from './errors.js';
import { workOrder } from './notice.js';

// Complaint -> issue -> work order -> outcome, read from the engine's linker output in audit.json.
// Channel, upvotes and social post text are not copied into audit.json, so they come from data/.

/** Minimal RFC 4180 reader: quoted fields may hold commas, newlines and "" escapes. */
function readCsv(file) {
  const text = readFileSync(path.join(serverRoot, '..', 'data', file), 'utf8');
  const rows = [];
  let row = [];
  let field = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') (field += '"'), i++;
      else if (ch === '"') quoted = false;
      else field += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',') row.push(field), (field = '');
    else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i++;
      row.push(field), rows.push(row), (row = []), (field = '');
    } else field += ch;
  }
  if (field || row.length) row.push(field), rows.push(row);
  const [head, ...body] = rows.filter((r) => r.length > 1);
  return body.map((r) => Object.fromEntries(head.map((h, j) => [h, r[j] ?? ''])));
}

const complaintCsv = new Map(readCsv('complaints.csv').map((r) => [r.complaint_id, { channel: r.channel, upvotes: Number(r.upvotes) || 0 }]));
// author_handle is left out on purpose: the app never needs who posted.
const posts = new Map(
  readCsv('social_posts.csv').map((r) => [
    r.post_id,
    { id: r.post_id, posted_at: r.posted_at, source: r.source, text: r.text, reach: Number(r.likes_or_forwards) || 0 },
  ]),
);

let byId;
let byWo;
const index = (audit) => {
  byId ??= new Map(audit.issues.map((i) => [i.id, i]));
  byWo ??= audit.issues.reduce((m, i) => {
    for (const w of i.work_order_ids) (m.get(w) ?? m.set(w, []).get(w)).push(i.id);
    return m;
  }, new Map());
};

/** Issue ids that point at work order [wo] (recorded or inferred). */
export function issuesForWorkOrder(audit, wo) {
  index(audit);
  return byWo.get(wo) ?? [];
}

const OUTCOMES = ['fixed_held', 'fixed_failed', 'in_progress', 'never_fixed'];
const wardOrUndefined = (audit, v) => {
  if (v === undefined || v === '') return undefined;
  if (typeof v !== 'string') throw badRequest('ward must be one ward code');
  if (!Object.hasOwn(audit.wards, v)) throw notFound(`Ward '${v}'`);
  return v;
};

/** The funnel for one ward, or the city when [ward] is undefined. Same counting as the engine's linker{}. */
export function linkerSummary(audit, rawWard) {
  const ward = wardOrUndefined(audit, rawWard);
  const cs = Object.values(audit.complaints).filter((c) => !ward || c.ward_code === ward);
  const iss = audit.issues.filter((i) => !ward || i.ward_code === ward);
  const count = (xs, f) => xs.filter(f).length;
  const byOutcome = Object.fromEntries(
    OUTCOMES.map((o) => {
      const xs = iss.filter((i) => i.outcome === o);
      // Rupees count recorded links only, as the engine does: an inferred job usually belongs to a recorded issue too.
      return [o, { count: xs.length, inr: xs.filter((i) => i.link === 'recorded').reduce((s, i) => s + (i.cost_inr ?? 0), 0) }];
    }),
  );
  const L = audit.linker;
  return {
    ward: ward ?? null,
    raw_complaints: cs.length,
    noise: count(cs, (c) => c.scope === 'noise'),
    out_of_scope: count(cs, (c) => c.scope === 'out_of_scope'),
    in_issues: count(cs, (c) => c.scope === 'in_scope'),
    categories_corrected: count(cs, (c) => c.category_corrected),
    categories_corrected_share: cs.length ? +(count(cs, (c) => c.category_corrected) / cs.length).toFixed(4) : 0,
    issues: iss.length,
    issues_from_complaints: count(iss, (i) => i.source === 'complaints'),
    social_only_issues: count(iss, (i) => i.source === 'social_only'),
    with_work_order: count(iss, (i) => i.link !== 'none'),
    links: {
      recorded: count(iss, (i) => i.link === 'recorded'),
      inferred: count(iss, (i) => i.link === 'inferred'),
      none: count(iss, (i) => i.link === 'none'),
    },
    issues_by_outcome: byOutcome,
    // City-wide only: how well the method checks out, and the plain-language steps.
    validation: L.validation,
    thresholds: L.thresholds,
    method: L.method,
  };
}

const row = (i) => ({
  id: i.id,
  source: i.source,
  category: i.category,
  ward_code: i.ward_code,
  locality: i.locality,
  road_id: i.road_id,
  road_name: i.road_name,
  first_seen: i.first_seen,
  last_seen: i.last_seen,
  complaint_count: i.complaint_count,
  social_post_count: i.social_post_ids.length,
  social_reach: i.social_reach,
  corrected_categories: i.corrected_categories,
  work_order_ids: i.work_order_ids,
  cost_inr: i.cost_inr,
  contractor_name: i.contractor_name,
  outcome: i.outcome,
  link: i.link,
});

/**
 * ?ward= ?outcome= (fixed_held|fixed_failed|in_progress|never_fixed|social_only) ?q= (issue, complaint or
 * work order id, place or road) ?offset= ?limit= (default 50, max 100). Most-reported first.
 */
export function issuesList(audit, query) {
  const str = (v) => (typeof v === 'string' && v.trim() ? v.trim() : undefined);
  const ward = wardOrUndefined(audit, str(query.ward));
  const outcome = str(query.outcome);
  if (outcome && outcome !== 'social_only' && !OUTCOMES.includes(outcome)) {
    throw badRequest(`outcome must be one of ${[...OUTCOMES, 'social_only'].join(', ')}`);
  }
  const q = str(query.q)?.toLowerCase();
  const offset = Math.max(0, Number.parseInt(query.offset, 10) || 0);
  const limit = Math.min(100, Math.max(1, Number.parseInt(query.limit, 10) || 50));
  const hit = (i) =>
    [i.id, i.locality, i.road_name, ...i.complaint_ids, ...i.work_order_ids].some((s) => s && s.toLowerCase().includes(q));
  const rows = audit.issues
    .filter(
      (i) =>
        (!ward || i.ward_code === ward) &&
        (!outcome || (outcome === 'social_only' ? i.source === 'social_only' : i.outcome === outcome)) &&
        (!q || hit(i)),
    )
    .sort(
      (a, b) =>
        b.complaint_count + b.social_post_ids.length - (a.complaint_count + a.social_post_ids.length) || a.id.localeCompare(b.id),
    );
  return { total: rows.length, items: rows.slice(offset, offset + limit).map(row) };
}

/** Full trail: complaints (reported vs clean category, channel), social posts, work orders, outcome. */
export function issueDetail(audit, rawId) {
  index(audit);
  const id = String(rawId).trim().toUpperCase();
  const i = byId.get(id);
  if (!i) throw notFound(`Issue '${id}'`);
  const complaints = i.complaint_ids
    .map((cid) => {
      const c = audit.complaints[cid];
      return {
        id: cid,
        received_at: c.received_at,
        channel: complaintCsv.get(cid)?.channel ?? null,
        upvotes: complaintCsv.get(cid)?.upvotes ?? 0,
        language: c.language,
        locality: c.locality,
        description: c.description,
        status: c.status,
        category_reported: c.category,
        category_clean: c.category_clean,
        category_corrected: c.category_corrected,
        category_reason: c.category_reason ?? null,
        link: c.link ?? null,
      };
    })
    .sort((a, b) => a.received_at.localeCompare(b.received_at) || a.id.localeCompare(b.id));
  const work_orders = i.work_order_ids.map((w) => {
    const wo = workOrder(audit, w);
    return wo && { ...wo, under_dlp: audit.roads[wo.road_id]?.under_dlp ?? null };
  });
  return {
    ...row(i),
    lat: i.lat,
    lon: i.lon,
    channels: i.channels,
    languages: i.languages,
    upvotes_total: i.upvotes_total,
    link_evidence: i.link_evidence,
    repair_method: i.repair_method,
    sla_met: i.sla_met,
    reopened: i.reopened,
    days_to_fix: i.days_to_fix,
    complaints,
    social_posts: i.social_post_ids.map((p) => posts.get(p) ?? { id: p }).sort((a, b) => `${a.posted_at}`.localeCompare(`${b.posted_at}`)),
    work_orders: work_orders.filter(Boolean),
  };
}

export const issueById = (audit, id) => (index(audit), byId.get(id));
