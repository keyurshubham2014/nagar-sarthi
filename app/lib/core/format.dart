/// Rupees in Indian units: ₹950, ₹15,787, ₹8.9 L, ₹2.62 Cr.
String formatInr(num v) {
  final a = v.abs();
  final sign = v < 0 ? '−' : '';
  if (a >= 1e7) return '$sign₹${(a / 1e7).toStringAsFixed(2)} Cr';
  if (a >= 1e5) return '$sign₹${(a / 1e5).toStringAsFixed(1)} L';
  final s = '${a.round()}'; // under 1 lakh: at most one comma
  return '$sign₹${s.length > 3 ? '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}' : s}';
}

String formatPercent(num share) => '${(share * 100).round()}%';

/// Whole numbers with Indian grouping: 950, 6,501, 1,23,456.
String formatCount(num v) {
  final s = '${v.round().abs()}';
  if (s.length <= 3) return '${v < 0 ? '−' : ''}$s';
  final head = s.substring(0, s.length - 3).replaceAllMapped(RegExp(r'\B(?=(\d{2})+$)'), (_) => ',');
  return '${v < 0 ? '−' : ''}$head,${s.substring(s.length - 3)}';
}
