import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Percentage bar for scorecards: a filled pill on a `surfaceAlt` track that
/// grows from zero on first view (standard motion), with an optional [marker]
/// tick (e.g. the peer median).
class ScorecardBar extends StatelessWidget {
  const ScorecardBar({super.key, required this.fraction, this.height = 8, this.color, this.marker, this.trackColor});

  /// 0..1 (clamped).
  final double fraction;
  final double height;

  /// Defaults to `primary`.
  final Color? color;

  /// Defaults to `surfaceAlt` (pass the page colour on a grey card).
  final Color? trackColor;

  /// 0..1 position of a thin tick that stands a little above and below the track.
  final double? marker;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final radius = BorderRadius.circular(height);
    final tick = height + AppSpacing.s8;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.of(context, AppMotion.standard),
        curve: AppMotion.standardCurve,
        builder: (_, k, _) => SizedBox(
          height: marker == null ? height : tick,
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              ClipRRect(
                borderRadius: radius,
                child: Container(
                  height: height,
                  color: trackColor ?? c.surfaceAlt,
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: fraction.clamp(0.0, 1.0) * k,
                    heightFactor: 1,
                    child: DecoratedBox(decoration: BoxDecoration(color: color ?? c.primary, borderRadius: radius)),
                  ),
                ),
              ),
              if (marker != null)
                Positioned.fill(
                  child: Align(
                    alignment: AlignmentDirectional(marker!.clamp(0.0, 1.0) * 2 - 1, 0),
                    child: Container(
                      width: AppSpacing.focusWidth,
                      height: tick,
                      decoration: BoxDecoration(color: c.textSecondary, borderRadius: BorderRadius.circular(1)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
