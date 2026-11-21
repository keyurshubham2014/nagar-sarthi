/// Shared wording for flags and money (REQ-N-006). Every screen that names a
/// flag or a rupee amount under review takes its words from here.
/// Binding rule: flags "need review"; money is "to be claimed and verified".
/// Never "fraud", "scam", "corrupt" or "overcharged by".
library;

const String kNeedsReview = 'Needs review';
const String kToBeClaimed = 'To be claimed and verified';
const String kNoFlags = 'No flags';

/// Road status chip when the road is otherwise clean but some jobs ran slow (sla_missed only).
const String kSlowerSomeJobs = 'Slower than typical on some jobs';

/// Display order, most serious first (matches the engine's road status tie-break).
const List<String> flagOrder = ['dlp_paid', 'fix_failed', 'over_rate', 'double_billing', 'sla_missed'];

const Map<String, String> flagLabels = {
  'over_rate': 'Billed above the standard rate',
  'double_billing': 'Repeat job with no complaint linked',
  'dlp_paid': 'Billed while the road is under warranty',
  'fix_failed': 'Repair failed within 30 days',
  'sla_missed': 'Slower than typical for this work',
};

/// Short form for chips.
const Map<String, String> flagShortLabels = {
  'over_rate': 'Above rate',
  'double_billing': 'Repeat job',
  'dlp_paid': 'Under warranty',
  'fix_failed': 'Failed in 30 days',
  'sla_missed': 'Slower than typical',
};

String flagLabel(String type) => flagLabels[type] ?? type;
String flagStanding(String type) => type == 'dlp_paid' ? kToBeClaimed : kNeedsReview;

/// Flag types a recovery notice can be drafted for from the ward and road panels.
const Set<String> noticeFlagTypes = {'dlp_paid', 'over_rate'};
const String kDraftNotice = 'Draft recovery notice';

/// sla_missed is about timing, so it is never shown as rupees needing review.
const String kSlaNoMoney = 'Timing only, not counted in rupees to review';
const String kFlagsOverlap = 'A job can carry more than one flag, so rows can add up to more than the total.';

String heroLine(String amount) => '$amount billed on roads under warranty — to be claimed and verified';

const String kUnderWarranty = 'Under warranty';
const String kWarrantyClaimTag = 'Under warranty: claim from contractor, ₹0 to ward';
const String kBudgetEnds = 'Budget ends here';
const String kNextRupeeAction = 'Where should the next rupee go?';

/// Next-rupee score parts, in display order.
const Map<String, String> scorePartLabels = {
  'severity': 'Severity of the problem',
  'access': 'Near a hospital or school',
  'accidents': 'Accidents on this road',
  'flood': 'Flood hotspot nearby',
  'traffic': 'Traffic',
};

const Map<String, String> evidenceLabels = {
  'area_sqm': 'Area (sq m)',
  'unit': 'Rate basis',
  'standard_rate_inr': 'Standard rate',
  'expected_inr': 'Expected cost',
  'billed_inr': 'Billed',
  'ratio': 'Billed ÷ expected',
  'threshold': 'Review threshold',
  'under_dlp': 'Road under warranty',
  'last_resurfaced': 'Last resurfaced',
  'previous_work_order_id': 'Earlier work order',
  'previous_assigned_at': 'Earlier job assigned',
  'assigned_at': 'This job assigned',
  'days_apart': 'Days apart',
  'linked_complaint_ids': 'Linked complaints',
  'repair_method': 'Repair method',
  'reopened_within_30d': 'Re-opened within 30 days',
  'completed_at': 'Completed',
  'method_reopen_rate': 'Typical re-open rate, same method',
  'sla_hours': 'Time allowed (hours)',
  'method_miss_rate': 'Share of same-method jobs running late',
};

// ---- Corporator scorecards and ward brief (TASK-05). Neutral wording only: no ranks, no "best/worst".

const String kScorecardsTitle = 'Contractor scorecards';
const String kWardBrief = 'Ward brief';
const String kContractorsInWard = 'Contractors in this ward';
const String kFairnessTitle = 'How this is kept fair';
const List<String> kFairnessPoints = [
  'Each contractor is compared with the same kind of repair, not with all work.',
  'Repairs in low-lying wards and in heavy-rain weeks count less against a contractor. The "After allowing for…" line shows this, and "Doing well" and "To look at" use it.',
  'No rating is given where a contractor has fewer than 15 jobs in a ward.',
  'Contractors are listed A to Z. This is not a ranking.',
];
const String kDoingWell = 'Doing well';
const String kToLookAt = 'To look at';
const String kNotRatedInWard = 'Not rated in this ward';
const String kThisContractor = 'This contractor';
const String kTypicalSameWork = 'Typical, same kind of work';
const String kAfterAllowance = 'After allowing for heavy rain and low-lying wards';

/// The three scorecard measures, in display order: title, what the figure is,
/// which way is better, and what the drill-down lists.
const Map<String, ({String title, String what, String better, String listed, String counted})> scorecardMeasures = {
  'speed': (
    title: 'Speed (SLA)',
    what: 'Finished on time',
    better: 'Higher is better',
    listed: 'Jobs finished late',
    counted: 'late',
  ),
  'durability': (
    title: 'Durability (repairs that last)',
    what: 'Re-opened within 30 days',
    better: 'Lower is better',
    listed: 'Repairs re-opened within 30 days',
    counted: 're-opened',
  ),
  'pricing': (
    title: 'Pricing against the rate card',
    what: 'Jobs billed above 1.5× the rate card',
    better: 'Lower is better',
    listed: 'Jobs billed above the standard rate',
    counted: 'above rate',
  ),
};

/// Ward brief languages: code -> name in its own script.
const Map<String, String> briefLanguages = {'en': 'English', 'hi': 'हिंदी', 'mr': 'मराठी'};

// Play the monsoon (TASK-04). Neutral: what happened, not who is to blame.
const String kMonsoonPlay = 'Play the 2025 monsoon';
const String kMonsoonNoRain = 'No rainfall data';
const String kMonsoonExit = 'Exit';
const String kMonsoonComplaints = 'complaints';
const String kMonsoonRepairs = 'repairs';
const String kMonsoonFailed = 'failed within 30 days';
const String kMonsoonPaidAgain = 'roads paid for more than once';
const String kMonsoonNotYet = 'Not repaired yet this season';
const String kMonsoonRecent = 'Repaired in the last 7 days';
const String kRepairedAgain = 'Repaired again';
const String kMonsoonDots = 'New complaint (fades over 5 days)';
const String kMonsoonRainTint = 'Blue wash: Orange or Red rain alert';

// Complaints heat layer.
const String kHeatOpen = 'open';
const String kRepairReopened = 'repair re-opened';
const String kHeatRepeat = 'Open or repeat complaints (repair re-opened)';
