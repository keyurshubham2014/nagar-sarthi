import { badRequest, notFound } from './errors.js';

// Ward brief for a corporator. The server picks every figure from audit.json;
// Claude (or the saved template in fallbacks/brief.json) only words them.

const LANGS = { en: 'English', hi: 'Hindi (Devanagari script)', mr: 'Marathi (Devanagari script)' };
// fix_failed has its own line; sla_missed is timing, not rupees.
const TYPES = ['dlp_paid', 'over_rate', 'double_billing'];

const L = {
  en: {
    lakh: 'lakh',
    crore: 'crore',
    over: (s, d) => `Spending reached ${s}, which is ${d} over budget.`,
    left: (s, d) => `Spending was ${s}, leaving ${d}.`,
    jobs: (n) => `${n} jobs`,
    types: {
      dlp_paid: 'Billed while the road was under warranty, to be claimed and verified',
      over_rate: 'Billed above the standard rate',
      double_billing: 'Repeat jobs with no complaint linked',
    },
    none: 'None',
    warranty: 'under warranty, claim from contractor',
    categories: {},
    reasons: [[/^Severity (\d) of 5 for .*$/, 'severity $1 of 5']],
  },
  hi: {
    lakh: 'लाख',
    crore: 'करोड़',
    over: (s, d) => `खर्च ${s} हुआ, जो बजट से ${d} ज़्यादा है।`,
    left: (s, d) => `खर्च ${s} हुआ, और ${d} बचे हैं।`,
    jobs: (n) => `${n} काम`,
    types: {
      dlp_paid: 'वारंटी वाली सड़कों पर भुगतान, जिसका दावा और सत्यापन किया जाना है',
      over_rate: 'मानक दर से ज़्यादा बिल',
      double_billing: 'बिना शिकायत के दोबारा किया गया काम',
    },
    none: 'कोई नहीं',
    warranty: 'वारंटी में, खर्च ठेकेदार से',
    categories: {
      'Road cave-in': 'सड़क धँसना',
      Waterlogging: 'जलभराव',
      Other: 'अन्य समस्या',
      Pothole: 'गड्ढा',
      'Road related': 'सड़क से जुड़ी समस्या',
      'Open or broken manhole': 'खुला या टूटा मैनहोल',
      'Choked drain / nullah overflow': 'जाम नाली / उफनता नाला',
      'Broken paver blocks': 'टूटे पेवर ब्लॉक',
    },
    reasons: [
      [/^Severity (\d) of 5 for .*$/, 'गंभीरता 5 में से $1'],
      [/^Near hospital: (.*)$/, 'अस्पताल के पास: $1'],
      [/^Near school: (.*)$/, 'स्कूल के पास: $1'],
      [/^(\d+) recorded accidents on this road$/, 'इस सड़क पर $1 दर्ज दुर्घटनाएँ'],
      [/^Flood hotspot: (.*)$/, 'जलभराव वाला स्थान: $1'],
      [/^Congestion index ([\d.]+) of 10$/, 'ट्रैफ़िक भीड़ 10 में से $1'],
      [/^Road under warranty:.*$/, 'सड़क वारंटी में है'],
    ],
  },
  mr: {
    lakh: 'लाख',
    crore: 'कोटी',
    over: (s, d) => `खर्च ${s} झाला, जो अर्थसंकल्पापेक्षा ${d} जास्त आहे.`,
    left: (s, d) => `खर्च ${s} झाला, आणि ${d} शिल्लक आहेत.`,
    jobs: (n) => `${n} कामे`,
    types: {
      dlp_paid: 'वॉरंटी असलेल्या रस्त्यांवर दिलेली रक्कम, जिचा दावा करून पडताळणी करायची आहे',
      over_rate: 'मानक दरापेक्षा जास्त बिल',
      double_billing: 'तक्रार नसताना पुन्हा केलेले काम',
    },
    none: 'एकही नाही',
    warranty: 'वॉरंटीत, खर्च कंत्राटदाराकडून',
    categories: {
      'Road cave-in': 'रस्ता खचणे',
      Waterlogging: 'पाणी साचणे',
      Other: 'इतर समस्या',
      Pothole: 'खड्डा',
      'Road related': 'रस्त्याशी संबंधित समस्या',
      'Open or broken manhole': 'उघडे किंवा तुटलेले मॅनहोल',
      'Choked drain / nullah overflow': 'तुंबलेले गटार / ओसंडणारा नाला',
      'Broken paver blocks': 'तुटलेले पेव्हर ब्लॉक',
    },
    reasons: [
      [/^Severity (\d) of 5 for .*$/, 'तीव्रता 5 पैकी $1'],
      [/^Near hospital: (.*)$/, 'रुग्णालयाजवळ: $1'],
      [/^Near school: (.*)$/, 'शाळेजवळ: $1'],
      [/^(\d+) recorded accidents on this road$/, 'या रस्त्यावर $1 नोंदवलेले अपघात'],
      [/^Flood hotspot: (.*)$/, 'पाणी साचणारे ठिकाण: $1'],
      [/^Congestion index ([\d.]+) of 10$/, 'वाहतूक कोंडी 10 पैकी $1'],
      [/^Road under warranty:.*$/, 'रस्ता वॉरंटीत आहे'],
    ],
  },
};

/** Rupees in lakh / crore: ₹47,630 · ₹12.1 lakh · ₹1.34 crore. */
function money(n, t) {
  const a = Math.abs(n);
  if (a >= 1e7) return `₹${+(a / 1e7).toFixed(2)} ${t.crore}`;
  if (a >= 1e5) return `₹${+(a / 1e5).toFixed(1)} ${t.lakh}`;
  return `₹${Math.round(a).toLocaleString('en-IN')}`;
}
const pct = (share) => `${Math.round(share * 100)}%`;
// The closing line says contractors are fictional; dropping the tag keeps the brief short.
const plain = (name) => name.replace(/ \(synthetic\)/g, '');

function reason(r, t) {
  for (const [re, out] of t.reasons) if (re.test(r)) return r.replace(re, out);
  return r;
}

/** Ward figures, worded in [lang]. Same numbers for every language. */
function figures(code, audit, lang) {
  const t = L[lang];
  const w = audit.wards[code];
  const jobs = (w.by_method ?? []).reduce((s, m) => s + m.jobs, 0);
  const bft = w.by_flag_type ?? {};
  const failed = bft.fix_failed?.count ?? 0;
  const types = TYPES.filter((k) => (bft[k]?.count ?? 0) > 0);
  const top = [...(w.by_contractor ?? [])].sort((a, b) => b.inr - a.inr).slice(0, 3);
  const items = [...(audit.next_rupee[code]?.items ?? [])].sort((a, b) => a.rank - b.rank).slice(0, 3);
  return {
    ward: code,
    name: w.name,
    budget: money(w.budget, t),
    spend_line: w.remaining < 0 ? t.over(money(w.spend, t), money(-w.remaining, t)) : t.left(money(w.spend, t), money(w.remaining, t)),
    review_total: money(w.flagged_inr, t),
    review_share: pct(w.flagged_share),
    review_lines: types.length
      ? types.map((k) => `- ${t.types[k]}: ${money(bft[k].inr, t)} (${t.jobs(bft[k].count)})`).join('\n')
      : `- ${t.none}`,
    jobs: String(jobs),
    failed_count: String(failed),
    failed_share: pct(jobs ? failed / jobs : 0),
    failed_inr: money(bft.fix_failed?.inr ?? 0, t),
    contractors: top.length ? top.map((c) => `${plain(c.name)} ${money(c.inr, t)}`).join('; ') : t.none,
    never_fixed: String(w.never_fixed?.length ?? 0),
    next_items: items.length
      ? items
          .map((it, i) => {
            const cat = t.categories[it.issue.category] ?? it.issue.category;
            // Category already says what is wrong; give the first reason beyond severity.
            const why = reason(it.reasons.find((r) => !r.startsWith('Severity')) ?? it.reasons[0] ?? '', t);
            const dlp = it.claim_under_dlp ? `, ${t.warranty}` : '';
            return `${i + 1}. ${cat}, ${it.issue.locality}, ${money(it.est_cost_inr, t)}${dlp}: ${why}`;
          })
          .join('\n')
      : `- ${t.none}`,
  };
}

export const brief = {
  prepare(body, audit) {
    const code = body.ward_code;
    if (typeof code !== 'string') throw badRequest('Send ward_code');
    if (!Object.hasOwn(audit.wards, code)) throw notFound(`Ward '${code}'`);
    const lang = body.language ?? 'en';
    if (typeof lang !== 'string' || !Object.hasOwn(LANGS, lang)) throw badRequest('language must be en, hi or mr');
    return { lang, facts: figures(code, audit, 'en'), vars: figures(code, audit, lang) };
  },
  buildPrompt(_body, audit, { lang, facts: f }) {
    return {
      system:
        'You write one-page ward briefs for elected corporators in Mumbai. You never accuse anyone; ' +
        'flagged spending "needs review" and money billed under warranty is "to be claimed and verified".',
      prompt: `Write a brief on road repairs in Ward ${f.ward} (${f.name}) for its corporator.

Figures (the only numbers you may use; do not calculate new ones):
- Road repair budget: ${f.budget}. ${f.spend_line}
- Spending that needs review: ${f.review_total} (${f.review_share} of spend). By type (a job can carry more than one flag):
${f.review_lines}
- Repairs that failed within 30 days: ${f.failed_count} of ${f.jobs} repairs (${f.failed_share}), costing ${f.failed_inr} (needs review).
- Largest contractors by spend: ${f.contractors}.
- Open complaints never fixed: ${f.never_fixed}.
- Where the next rupee should go first, with reasons:
${f.next_items}

Rules:
- Write in ${LANGS[lang]}. Plain language a citizen can read.
- At most 200 words.
- Use only the figures above. Keep rupee amounts in lakh and crore as given.
- No accusations. Say "needs review" and "to be claimed and verified".
- End with one line saying the data is synthetic, not BMC data.
Return only the brief.`,
      maxTokens: 900,
    };
  },
  fallbackKey: (body) => (typeof body.language === 'string' ? body.language : 'en'),
};
