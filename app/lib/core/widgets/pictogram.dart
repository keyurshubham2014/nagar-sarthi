import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The app's pictogram set: Material outlined line icons (2 px stroke) in
/// the text colour, with at most one accent dot. One consistent family; no
/// stock art.
enum PictogramKind {
  report(Icons.campaign_outlined, 'Report a problem'),
  track(Icons.manage_search_outlined, 'Track a complaint'),
  chat(Icons.chat_bubble_outline, 'Ask about a complaint'),
  reportCard(Icons.assessment_outlined, 'Report card'),
  ask(Icons.question_answer_outlined, 'Ask my ward'),
  monsoon(Icons.thunderstorm_outlined, 'Monsoon'),
  trail(Icons.route_outlined, 'Complaint trail'),
  about(Icons.info_outline, 'About the data'),
  audit(Icons.fact_check_outlined, 'Audit'),
  nextRupee(Icons.currency_rupee_outlined, 'Next rupee'),
  contractors(Icons.engineering_outlined, 'Contractors'),
  ward(Icons.location_city_outlined, 'Ward'),
  brief(Icons.description_outlined, 'Ward brief'),
  map(Icons.map_outlined, 'Map'),
  pothole(Icons.edit_road_outlined, 'Pothole'),
  waterlogging(Icons.waves_outlined, 'Waterlogging'),
  manhole(Icons.adjust_outlined, 'Manhole'),
  drain(Icons.water_outlined, 'Drain'),
  failedRepair(Icons.construction_outlined, 'Failed repair'),
  warranty(Icons.verified_user_outlined, 'Warranty'),
  hospital(Icons.local_hospital_outlined, 'Hospital'),
  school(Icons.school_outlined, 'School'),
  flood(Icons.flood_outlined, 'Flood'),
  traffic(Icons.traffic_outlined, 'Traffic');

  const PictogramKind(this.icon, this.label);
  final IconData icon;

  /// English name, for semantics and the gallery.
  final String label;
}

/// One pictogram at [size] (28 by default) with an optional [accent] dot
/// top-right (a status colour; never more than one).
class Pictogram extends StatelessWidget {
  const Pictogram(this.kind, {super.key, this.size = AppSpacing.pictogram, this.accent, this.color, this.semanticLabel});
  final PictogramKind kind;
  final double size;
  final Color? accent;
  final Color? color;

  /// Null = decorative (excluded from semantics).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final dot = size * 0.3;
    final icon = SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(kind.icon, size: size, color: color ?? c.textPrimary),
          if (accent != null)
            Positioned(
              right: -dot * 0.15,
              top: -dot * 0.15,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.surfaceAlt, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
    return semanticLabel == null ? ExcludeSemantics(child: icon) : Semantics(label: semanticLabel, image: true, child: icon);
  }
}
