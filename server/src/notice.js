import { badRequest, notFound } from './errors.js';

// Rule numbers follow the flag table in the PRD (F1), in that order.
const RULES = {
  over_rate: 'Rule 1: billed above 1.5 times the standard rate for the work',
  double_billing: 'Rule 2: same road and repair method billed again within 5 days, with no complaint linked',
  dlp_paid: 'Rule 3: road under defect liability (warranty) and the job was billed to the ward',
  fix_failed: 'Rule 4: repair re-opened within 30 days of completion',
};
const MAX_ROWS = 15;

const inr = (n) => `₹${Math.round(n).toLocaleString('en-IN')}`;
const day = (s) => (s ? String(s).slice(0, 10) : 'n/a');

let woIndex;
export function workOrder(audit, id) {
  woIndex ??= new Map(
    Object.entries(audit.roads).flatMap(([roadId, r]) =>
      r.work_orders.map((wo) => [wo.id, { ...wo, road_id: roadId, road_name: r.road_name, ward_code: r.ward_code }]),
    ),
  );
  return woIndex.get(id);
}

/**
 * Picks the flag rows for {flag_type, road_id} or {flag_type, ward_code} from audit.json.
 * Throws 400/404 for bad input, so the client only ever names a scope, never figures.
 */
export function selectNotice(body, audit) {
  const type = body.flag_type;
  if (typeof type !== 'string' || !Object.hasOwn(RULES, type)) {
    throw badRequest(`flag_type must be one of ${Object.keys(RULES).join(', ')}`);
  }
  const { road_id: roadId, ward_code: wardCode } = body;
  if (typeof roadId === 'string') {
    if (!Object.hasOwn(audit.roads, roadId)) throw notFound(`Road '${roadId}'`);
  } else if (typeof wardCode === 'string') {
    if (!Object.hasOwn(audit.wards, wardCode)) throw notFound(`Ward '${wardCode}'`);
  } else {
    throw badRequest('Send road_id or ward_code');
  }

  const all = audit.flags
    .filter((f) => f.type === type && (roadId ? f.road_id === roadId : f.ward_code === wardCode))
    .sort((a, b) => b.cost_inr - a.cost_inr);
  if (!all.length) throw notFound(`${type} flags for ${roadId ?? `ward ${wardCode}`}`);

  const rows = all.slice(0, MAX_ROWS).map((f) => {
    const wo = workOrder(audit, f.work_order_id) ?? {};
    return {
      id: f.work_order_id,
      assigned: day(wo.assigned_at),
      completed: day(wo.completed_at),
      amount: inr(f.cost_inr),
      contractor: f.contractor_name,
      road: `${wo.road_name ?? audit.roads[f.road_id]?.road_name ?? ''} (${f.road_id})`,
    };
  });
  const more = all.length - rows.length;
  const contractors = [...new Set(rows.map((r) => r.contractor))];
  const ward = audit.wards[wardCode ?? audit.roads[roadId].ward_code];
  const scope = roadId ? `${audit.roads[roadId].road_name} (${roadId})` : `Ward ${wardCode}, ${ward.name}`;

  const table = rows
    .map((r) => `- Work order ${r.id}: assigned ${r.assigned}, completed ${r.completed}, ${r.amount}, ${r.contractor}, ${r.road}`)
    .join('\n');
  const total = inr(all.slice(0, MAX_ROWS).reduce((s, f) => s + f.cost_inr, 0));

  return {
    type,
    rows,
    more,
    vars: {
      ward_office: `Ward Office ${wardCode ?? audit.roads[roadId].ward_code} (${ward.name})`,
      addressee: contractors.length === 1 ? contractors[0] : 'Each contractor named in the table below',
      scope,
      rule: RULES[type],
      table,
      total,
      count: String(rows.length),
      more: more > 0 ? `\n${more} more work orders of this kind exist and will be listed in a separate notice.` : '',
    },
  };
}

export const notice = {
  prepare: selectNotice,
  buildPrompt(_body, _audit, sel) {
    const { vars } = sel;
    return {
      system:
        'You draft formal letters for a municipal ward office in Mumbai. You never accuse anyone of fraud, ' +
        'corruption or wrongdoing; you describe items as needing review and to be claimed and verified.',
      prompt: `Draft a formal, polite letter from ${vars.ward_office} to ${vars.addressee}.

Subject: work on ${vars.scope}, flagged under ${vars.rule}.

Work orders (the only figures you may use):
${vars.table}
Total of the rows above: ${vars.total}${vars.more}

Rules for the letter:
- Cite every work order id, date and amount in the table above.
- Add no numbers that are not in the table.
- State that the amount is "to be claimed and verified", and ask the contractor to respond with records within 15 days.
- Do not use the words fraud, scam, corrupt or overcharged.
- Under 250 words.
- End with one line noting that this draft uses synthetic data from a prototype and is not a BMC document.
Return only the letter text.`,
      maxTokens: 700,
    };
  },
  fallbackKey: (body) => body.flag_type,
};
