import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flag_strings.dart';
import '../../core/i18n.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/saarthee.dart';
import '../map/map_data.dart';
import '../officer/officer_panels.dart' show flagColor;
import '../officer/panel.dart';

/// About this data: synthetic-data statement, not a BMC product, how flags are
/// computed in plain words, departments and credits.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final meta = ref.watch(mapDataProvider).value?.meta ?? const {};
    final th = (meta['thresholds'] as Map?) ?? const {};
    final disclaimer = meta['disclaimer'] as String? ?? kDefaultDisclaimer;
    Widget para(String s) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.s8), child: Text(s, style: t.bodyMedium));
    Widget flag(String type, String how) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: CircleAvatar(radius: 6, backgroundColor: flagColor(type)),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(flagLabel(type), style: t.titleMedium),
                Text(how, style: t.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );

    return DetailPage(
      title: 'About this data',
      body: PanelList(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(color: c.infoTint, borderRadius: AppRadii.cardRadius),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: c.info),
                const SizedBox(width: AppSpacing.s12),
                Expanded(child: Text(context.tr(disclaimer), style: t.bodyLarge)),
              ],
            ),
          ),
          const SectionHeading('What Nagar Sarthi is'),
          para('A hackathon prototype that follows the rupee on Mumbai\'s monsoon road repairs: what was spent, '
              'which jobs need a second look, and where the next rupee should go.'),
          para('It is not made, run or endorsed by BMC. Every figure comes from a synthetic dataset; contractors are fictional.'),
          para('A flag means a work order needs review. It is not a finding of wrongdoing. Money billed under warranty is '
              '"to be claimed and verified", because the contractor may still owe the repair.'),
          const SectionHeading('How flags are worked out'),
          flag('dlp_paid', 'The road was still under its defect-liability (warranty) period, so the repair should be '
              'claimed from the contractor who laid it, not paid by the ward.'),
          flag('fix_failed', 'The same spot was reported again within 30 days of the repair being completed.'),
          flag('over_rate', 'The bill is more than ${th['over_rate_ratio'] ?? 1.5}× the standard rate for that repair '
              'and area.'),
          flag('double_billing', 'The same road was billed again within ${th['double_billing_days'] ?? 5} days '
              'and no complaint was linked to the second job.'),
          flag('sla_missed', 'The job took longer than the time allowed for that kind of repair. This is timing only and '
              'is never counted in rupees to review.'),
          para('Contractor scorecards compare each contractor with the same kind of repair, allow for heavy-rain weeks '
              'and low-lying wards, and give no rating below ${th['min_jobs_per_ward'] ?? 15} jobs in a ward.'),
          const SectionHeading('Departments'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add_road, color: c.primary),
            title: const Text('Roads and monsoon repairs'),
            subtitle: const Text('Audit of road repair spend: live'),
          ),
          for (final (name, icon) in const [
            ('Water', Icons.water_drop_outlined),
            ('Solid waste', Icons.delete_outline),
            ('Drains', Icons.water_outlined),
            ('Health', Icons.local_hospital_outlined),
          ])
            ListTile(contentPadding: EdgeInsets.zero, enabled: false, leading: Icon(icon), title: Text(name), subtitle: const Text('Coming')),
          const SectionHeading('Credits'),
          para('Map: © OpenStreetMap contributors.'),
          para('Ward boundaries: OpenCity / Oorvani Foundation via bharatlas (CC0).'),
          para('Complaint understanding, notices, briefs and questions are drafted by Claude (Anthropic) on the server, '
              'with saved drafts when it is not reachable.'),
          para('Design based on the Saarthee app.'),
        ],
      ),
    );
  }
}
