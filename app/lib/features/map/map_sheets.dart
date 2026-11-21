import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import 'map_data.dart';
import 'map_layers.dart';

// TASK-02 placeholder sheets. TASK-03 replaces the ward and road sheet bodies
// with detail panels; the map calls these through MapHomeScreen's tap callbacks.

Future<void> showWardSheet(BuildContext context, Ward ward) => _sheet(
  context,
  title: '${ward.code} · ${ward.name}',
  headline: formatInr(ward.flaggedInr),
  caption: '${formatPercent(ward.flaggedShare)} of ${formatInr(ward.spend)} spend needs review',
);

Future<void> showRoadSheet(BuildContext context, Road road) => _sheet(
  context,
  title: road.name,
  headline: roadStatusLabels[road.status] ?? road.status,
  headlineColor: roadStatusColors[road.status],
  caption: 'Ward ${road.wardCode} · ${formatInr(road.spend)} spent on this segment',
);

Future<void> _sheet(
  BuildContext context, {
  required String title,
  required String headline,
  required String caption,
  Color? headlineColor,
}) {
  final t = Theme.of(context).textTheme;
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.titleLarge),
            const SizedBox(height: AppSpacing.s12),
            Text(headline, style: t.displaySmall?.copyWith(color: headlineColor)),
            const SizedBox(height: AppSpacing.s4),
            Text(caption, style: t.bodyMedium),
          ],
        ),
      ),
    ),
  );
}

/// Departments: only roads has data; the rest are listed with no figures.
Future<void> showDepartmentsSheet(BuildContext context) {
  final c = SaartheeColors.of(context);
  const coming = [
    ('Water', Icons.water_drop_outlined),
    ('Solid waste', Icons.delete_outline),
    ('Drains', Icons.water_outlined),
    ('Health', Icons.local_hospital_outlined),
  ];
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s8, 0, AppSpacing.s8, AppSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
              child: Text('Departments', style: Theme.of(context).textTheme.titleLarge),
            ),
            ListTile(
              leading: Icon(Icons.add_road, color: c.primary),
              title: const Text('Roads and monsoon repairs'),
              subtitle: const Text('Audit of road repair spend, on the map now'),
              trailing: _Badge('Live', c.successTint, c.success),
              onTap: () => Navigator.pop(context),
            ),
            for (final (name, icon) in coming)
              ListTile(
                enabled: false,
                leading: Icon(icon),
                title: Text(name),
                trailing: _Badge('Coming', c.surfaceAlt, c.textSecondary),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: AppRadii.controlRadius),
    child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
  );
}

Future<void> showDataNotice(BuildContext context, String disclaimer) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('About this data'),
    content: Text(
      '$disclaimer\n\nNagar Sarthi is a hackathon prototype. It is not made or endorsed by BMC. '
      'Flags mark spending that needs review; they are not findings of wrongdoing.',
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
  ),
);
