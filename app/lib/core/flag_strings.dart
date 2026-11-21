/// Shared wording for flags and money (REQ-N-006). Every screen that names a
/// flag or a rupee amount under review takes its words from here.
/// Binding rule: flags "need review"; money is "to be claimed and verified".
/// Never "fraud", "scam", "corrupt" or "overcharged by".
library;

const String kNeedsReview = 'Needs review';
const String kToBeClaimed = 'To be claimed and verified';
const String kNoFlags = 'No flags';

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
