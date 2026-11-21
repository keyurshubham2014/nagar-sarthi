import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../officer/officer_panels.dart';
import 'map_data.dart';

// Map taps open the officer panels (TASK-03): ward money trail and road work orders.
void showWardSheet(BuildContext context, Ward ward) => openWardPanel(context, ward.code, ward.name);

void showRoadSheet(BuildContext context, Road road) => openRoadPanel(context, road.id, road.name);

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
