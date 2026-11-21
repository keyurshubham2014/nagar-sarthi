/// Rupees in Indian units: ₹950, ₹8.9 L, ₹2.6 Cr.
String formatInr(num v) {
  final a = v.abs();
  final sign = v < 0 ? '−' : '';
  if (a >= 1e7) return '$sign₹${(a / 1e7).toStringAsFixed(2)} Cr';
  if (a >= 1e5) return '$sign₹${(a / 1e5).toStringAsFixed(1)} L';
  return '$sign₹${a.round()}';
}

String formatPercent(num share) => '${(share * 100).round()}%';
