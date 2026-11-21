import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'scorecard_bar.dart';

/// Scorecard stat tile, from Saarthee's `ScorecardStatTile`: `surfaceAlt`
/// tile with a numeric value, a small label and an optional bar below.
/// The count-up animation was dropped; semantics read the final value.
class ScorecardStatTile extends StatelessWidget {
  const ScorecardStatTile({
    super.key,
    required this.value,
    required this.label,
    this.emptyText = '—',
    this.barFraction,
    this.barColor,
  });

  /// Already formatted (e.g. `47%`); null shows [emptyText].
  final String? value;
  final String label;
  final String emptyText;
  final double? barFraction;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final v = value;
    return Semantics(
      container: true,
      label: '$label: ${v ?? emptyText}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s14),
          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: AppRadii.tileRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (v == null)
                Text(emptyText, style: text.bodyMedium?.copyWith(color: c.textSecondary))
              else
                Text(v, style: AppTypography.numeric(c)),
              const SizedBox(height: AppSpacing.s4),
              Text(label, style: text.bodySmall),
              if (v != null && barFraction != null) ...[
                const SizedBox(height: AppSpacing.s8),
                ScorecardBar(fraction: barFraction!, color: barColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
