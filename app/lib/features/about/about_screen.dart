import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flag_strings.dart';
import '../../core/i18n.dart';
import '../../core/widgets/ui.dart';
import '../map/map_data.dart';
import '../officer/officer_panels.dart' show flagColor;

/// About this data: synthetic-data statement, not a BMC product, where the
/// data comes from, how flags are computed in plain words, departments, credits.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final meta = ref.watch(mapDataProvider).value?.meta ?? const {};
    final th = (meta['thresholds'] as Map?) ?? const {};
    final disclaimer = meta['disclaimer'] as String? ?? kDefaultDisclaimer;
    final boundaries = (meta['ward_boundaries'] as Map?) ?? const {};

    Widget heading(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s32, AppSpacing.gutter, AppSpacing.s12),
      child: Semantics(header: true, child: Text(s, style: t.headline)),
    );
    Widget para(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.s12),
      child: Text(s, style: t.body),
    );
    Widget flag(String type, String how) => Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(width: 10, height: 10, decoration: BoxDecoration(color: flagColor(type), shape: BoxShape.circle)),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(flagLabel(type), style: t.bodyStrong),
                const SizedBox(height: 2),
                Text(how, style: t.caption.copyWith(fontSize: 15, height: 22 / 15)),
              ],
            ),
          ),
        ],
      ),
    );

    return LargeTitleScaffold(
      title: context.tr('About this data'),
      maxWidth: 600,
      children: [
        Gutter(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(color: c.infoTint, borderRadius: AppRadii.tileRadius),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: c.info),
                const SizedBox(width: AppSpacing.s12),
                Expanded(child: Text(context.tr(disclaimer), style: t.bodyStrong.copyWith(color: c.textPrimary))),
              ],
            ),
          ),
        ),
        heading('What Nagar Sarthi is'),
        para("A hackathon prototype that follows the rupee on Mumbai's monsoon road repairs: what was spent, "
            'which jobs need a second look, and where the next rupee should go.'),
        para('It is not made, run or endorsed by BMC. Every figure comes from a synthetic dataset; contractors are fictional.'),
        para('A flag means a work order needs review. It is not a finding of wrongdoing. Money billed under warranty is '
            '"to be claimed and verified", because the contractor may still owe the repair.'),
        if (boundaries['note'] != null) ...[
          heading('Where the data comes from'),
          para('${boundaries['note']}'),
        ],
        heading('How flags are worked out'),
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
        heading('Departments'),
        ListRow(
          title: 'Roads and monsoon repairs',
          caption: 'Audit of road repair spend',
          icon: Icons.add_road,
          chip: const StatusChip('Live', tone: StatusTone.success, dot: true),
        ),
        for (final (name, icon) in const [
          ('Water', Icons.water_drop_outlined),
          ('Solid waste', Icons.delete_outline),
          ('Drains', Icons.water_outlined),
          ('Health', Icons.local_hospital_outlined),
        ])
          ListRow(title: name, icon: icon, trailing: const StatusChip('Coming'), divider: name != 'Health'),
        heading('Credits'),
        const ListRow(title: 'Map', caption: '© OpenStreetMap contributors', icon: Icons.map_outlined),
        const ListRow(title: 'Ward boundaries', caption: 'OpenCity / Oorvani Foundation via bharatlas (CC0)', icon: Icons.layers_outlined),
        const ListRow(title: 'Drafting', caption: 'Claude (Anthropic), on the server', icon: Icons.edit_note),
        const ListRow(title: 'Design', caption: 'Based on the Saarthee app', icon: Icons.palette_outlined, divider: false),
        const SizedBox(height: AppSpacing.s16),
        para('Complaint understanding, notices, briefs and questions are drafted by Claude (Anthropic) on the server, '
            'with saved drafts when it is not reachable.'),
      ],
    );
  }
}
