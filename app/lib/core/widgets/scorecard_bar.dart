import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Percentage bar for scorecards, from Saarthee's `ScorecardBar`: a filled pill
/// on a `surfaceAlt` track. The first-view grow animation was dropped.
class ScorecardBar extends StatelessWidget {
  const ScorecardBar({super.key, required this.fraction, this.height = 8, this.color});

  /// 0..1 (clamped).
  final double fraction;
  final double height;

  /// Defaults to `primary`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final radius = BorderRadius.circular(height);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          height: height,
          color: c.surfaceAlt,
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color ?? c.primary, borderRadius: radius),
            ),
          ),
        ),
      ),
    );
  }
}
