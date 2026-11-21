import { badRequest, notFound } from './errors.js';
import { workOrder } from './notice.js';

// Display shapes for the corporator scorecards. Every figure is the engine's;
// "typical" is the engine's own same-method average (value minus its *_vs_method_avg).
// value/typical are plain shares of jobs, matching the work-order lists; adjusted_* carry the
// rain and low-lying allowance the engine's strength/improve sentences use.

/** Measure -> the engine's work_order_ids list behind it. */
const METRIC_IDS = { speed: 'sla_missed', durability: 'reopened', pricing: 'over_rate' };
const MAX_ROWS = 100;
const r2 = (n) => Math.round(n * 100) / 100;

const inWard = (audit, ids, ward) => (ward ? ids.filter((id) => workOrder(audit, id)?.ward_code === ward) : ids);

function measures(audit, m, c, ward, jobs) {
  const a = m.adjusted;
  const t = audit.meta.totals;
  const ids = (k) => inWard(audit, c.work_order_ids[k], ward);
  const over = ids('over_rate').length;
  return {
    speed: {
      value: m.sla_rate, typical: r2(m.sla_rate - m.sla_vs_method_avg),
      adjusted_value: a.sla_rate, adjusted_typical: r2(a.sla_rate - a.sla_vs_method_avg),
      count: ids('sla_missed').length,
    },
    durability: {
      value: m.reopen_rate, typical: r2(m.reopen_rate - m.reopen_vs_method_avg),
      adjusted_value: a.reopen_rate, adjusted_typical: r2(a.reopen_rate - a.reopen_vs_method_avg),
      count: ids('reopened').length,
    },
    pricing: {
      value: r2(jobs ? over / jobs : 0), typical: r2(t.flags.over_rate.count / t.work_orders),
      median_cost_ratio: a.median_cost_ratio,
      count: over,
    },
  };
}

/** Contractors alphabetically, city-wide or for one ward (only those who worked there). */
export function scorecards(audit, ward) {
  if (ward && !Object.hasOwn(audit.wards, ward)) throw notFound(`Ward '${ward}'`);
  const rows = Object.entries(audit.contractors)
    .filter(([, c]) => !ward || Object.hasOwn(c.by_ward, ward))
    .map(([id, c]) => {
      const scope = ward ? c.by_ward[ward] : { jobs: c.jobs, rated: true, metrics: c.metrics, reason_if_not_rated: null };
      return {
        id,
        name: c.name,
        jobs: scope.jobs,
        spend: ward ? audit.wards[ward].by_contractor.find((b) => b.contractor_id === id)?.inr ?? null : c.spend,
        strength: c.strength,
        improve: c.improve,
        rated: scope.rated,
        reason_if_not_rated: scope.reason_if_not_rated,
        measures: scope.rated ? measures(audit, scope.metrics, c, ward, scope.jobs) : null,
      };
    })
    .sort((a, b) => a.name.localeCompare(b.name));
  return { ward: ward ?? null, min_jobs: audit.meta.thresholds.min_jobs_per_ward, contractors: rows };
}

let overRatio;
/** The work orders behind one measure: late, re-opened or above-rate jobs. */
export function contractorWorkOrders(audit, id, metric, ward) {
  if (!Object.hasOwn(audit.contractors, id)) throw notFound(`Contractor '${id}'`);
  if (typeof metric !== 'string' || !Object.hasOwn(METRIC_IDS, metric)) {
    throw badRequest(`metric must be one of ${Object.keys(METRIC_IDS).join(', ')}`);
  }
  if (ward && !Object.hasOwn(audit.wards, ward)) throw notFound(`Ward '${ward}'`);
  overRatio ??= new Map(audit.flags.filter((f) => f.type === 'over_rate').map((f) => [f.work_order_id, f.ratio]));
  const c = audit.contractors[id];
  const all = inWard(audit, c.work_order_ids[METRIC_IDS[metric]], ward)
    .map((wid) => workOrder(audit, wid))
    .filter(Boolean)
    .sort((a, b) => (a.assigned_at < b.assigned_at ? 1 : -1));
  return {
    contractor: { id, name: c.name },
    metric,
    ward: ward ?? null,
    jobs: ward ? c.by_ward[ward]?.jobs ?? 0 : c.jobs,
    total: all.length,
    rows: all.slice(0, MAX_ROWS).map((w) => ({
      id: w.id,
      road_id: w.road_id,
      road_name: w.road_name,
      ward_code: w.ward_code,
      method: w.method,
      assigned_at: w.assigned_at,
      completed_at: w.completed_at,
      cost_inr: w.cost_inr,
      sla_met: w.sla_met,
      reopened: w.reopened,
      rate_ratio: overRatio.get(w.id) ?? null,
    })),
  };
}
