import { badRequest, notFound } from './errors.js';
import { L, money, figures } from './brief.js';

// A citizen's question to the ward office. The server picks the ward's figures;
// Claude (or the saved template in fallbacks/question.json) only words them.

const LANGS = { en: 'English', hi: 'Hindi (Devanagari script)', mr: 'Marathi (Devanagari script)' };
const TOPICS = {
  failed_repairs: (f) =>
    `Repairs that failed again within 30 days: ${f.failed_count} of ${f.jobs} road repairs (${f.failed_share}), costing ${f.failed_inr}. Ask which roads, whether contractors redid the work at their own cost, and what checks are planned.`,
  warranty: (f) =>
    `Billed while the road was still under the contractor's warranty: ${f.dlp_inr} across ${f.dlp_count} jobs (to be claimed and verified). Ask whether this money has been claimed back from the contractors and by when.`,
  open_issues: (f) =>
    `Complaints in this ward never fixed, with no work order linked: ${f.never_fixed} (oldest received ${f.oldest}). Ask when these will be assigned and how citizens can follow their progress.`,
  budget: (f) =>
    `Road repair budget ${f.budget}. ${f.spend_line} Spending that needs review: ${f.review_total} (${f.review_share}). Ask how the overspend or balance will be handled and when the review will be done.`,
};

function vars(code, audit, lang) {
  const w = audit.wards[code];
  const dlp = w.by_flag_type?.dlp_paid ?? {};
  const oldest = (w.never_fixed ?? []).reduce((m, c) => (!m || c.received_at < m ? c.received_at : m), '');
  return {
    ...figures(code, audit, lang),
    dlp_inr: money(dlp.inr ?? 0, L[lang]),
    dlp_count: String(dlp.count ?? 0),
    oldest: oldest ? oldest.slice(0, 10) : '-',
  };
}

export const question = {
  prepare(body, audit) {
    const code = body.ward_code;
    if (typeof code !== 'string') throw badRequest('Send ward_code');
    if (!Object.hasOwn(audit.wards, code)) throw notFound(`Ward '${code}'`);
    if (typeof body.topic !== 'string' || !Object.hasOwn(TOPICS, body.topic)) {
      throw badRequest(`topic must be one of ${Object.keys(TOPICS).join(', ')}`);
    }
    const lang = body.language ?? 'en';
    if (typeof lang !== 'string' || !Object.hasOwn(LANGS, lang)) throw badRequest('language must be en, hi or mr');
    return { lang, topic: body.topic, facts: vars(code, audit, 'en'), vars: vars(code, audit, lang) };
  },
  buildPrompt(_body, _audit, { lang, topic, facts: f }) {
    return {
      system:
        'You help Mumbai citizens write short, polite questions to their ward office. ' +
        'You never accuse anyone; flagged spending "needs review" and money billed under warranty is "to be claimed and verified".',
      prompt: `Write a question a resident of Ward ${f.ward} (${f.name}) can send to the ward office.

Topic and figures (the only numbers you may use):
${TOPICS[topic](f)}

Rules:
- Write in ${LANGS[lang]}.
- Under 120 words. Polite and specific; cite the figures above.
- No accusations and no new numbers.
- Address it to the Ward ${f.ward} office and end with a thank-you.
Return only the message.`,
      maxTokens: 800,
    };
  },
  // Devanagari splits into more tokens; allow some slack over the 120 words asked for.
  validate: (text) => text.trim().split(/\s+/).length <= 150,
  fallbackKey: (body) => `${body.topic}.${typeof body.language === 'string' ? body.language : 'en'}`,
};
