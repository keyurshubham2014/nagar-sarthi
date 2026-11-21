import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/claude_draft_sheet.dart';
import '../corporator/corporator_panels.dart';
import '../map/map_data.dart';
import '../map/map_layers.dart';
import 'next_rupee.dart';
import 'officer_data.dart';
import 'panel.dart';

PanelStack _panel(BuildContext context) => ProviderScope.containerOf(context, listen: false).read(panelProvider.notifier);

/// Opens the ward money trail as the only panel page.
void openWardPanel(BuildContext context, String code, String name) =>
    _panel(context).open(PanelPage('Ward $code · $name', WardPanel(code), ward: code));

void openRoadPanel(BuildContext context, String id, String name) =>
    _panel(context).open(PanelPage(name, RoadPanel(id)));

/// Recovery notice for one flag type on a road or across a ward. The server
/// picks the flag rows; the client sends only the scope.
void showNoticeSheet(BuildContext context, {required String type, String? roadId, String? wardCode}) =>
    showClaudeDraftSheet(
      context,
      title: 'Recovery notice',
      feature: 'notice',
      body: {'flag_type': type, 'road_id': ?roadId, 'ward_code': ?wardCode},
    );

Color flagColor(String type) => roadStatusColors[type] ?? const Color(0xFF8D6E63);

Widget _flagDot(String type) => Container(
  width: 12,
  height: 12,
  decoration: BoxDecoration(color: flagColor(type), shape: BoxShape.circle),
);

// ---------------------------------------------------------------- ward panel

class WardPanel extends ConsumerWidget {
  const WardPanel(this.code, {super.key});
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) => asyncPage(
    ref.watch(wardDetailProvider(code)),
    onRetry: () => ref.invalidate(wardDetailProvider(code)),
    data: (w) => _body(context, ref, w),
  );

  Widget _body(BuildContext context, WidgetRef ref, Json w) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final budget = w['budget'] as num? ?? 0;
    final spend = w['spend'] as num? ?? 0;
    final remaining = w['remaining'] as num? ?? budget - spend;
    final byType = (w['by_flag_type'] as Map?) ?? const {};
    final types = [for (final k in flagOrder) if (((byType[k] as Map?)?['count'] as num? ?? 0) > 0) k];
    final contractors = ((w['by_contractor'] as List?) ?? const []).take(5).toList();
    final methods = ((w['by_method'] as List?) ?? const []).take(5).toList();
    final maxC = contractors.isEmpty ? 1 : contractors.first['inr'] as num;
    final maxM = methods.isEmpty ? 1 : methods.first['inr'] as num;

    return PanelList(
      children: [
        const SectionTitle('Budget and spend'),
        LinearProgressIndicator(
          value: budget <= 0 ? 1 : (spend / budget).clamp(0, 1).toDouble(),
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
          color: remaining < 0 ? c.error : c.primary,
        ),
        const SizedBox(height: AppSpacing.s4),
        Row(
          children: [
            Expanded(child: Text('Spent ${formatInr(spend)}', style: t.bodyMedium)),
            Text('Budget ${formatInr(budget)}', style: t.bodyMedium),
          ],
        ),
        Text(
          remaining < 0 ? 'Over budget by ${formatInr(-remaining)}' : '${formatInr(remaining)} left this season',
          style: t.bodySmall?.copyWith(color: remaining < 0 ? c.error : c.textSecondary),
        ),
        const SectionTitle('Rupees to review'),
        Text(formatInr(w['flagged_inr'] as num? ?? 0), style: t.headlineMedium?.copyWith(color: c.error)),
        Text('${formatPercent(w['flagged_share'] as num? ?? 0)} of spend in this ward needs review', style: t.bodyMedium),
        const SizedBox(height: AppSpacing.s8),
        if (types.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
            child: Row(
              children: [
                Icon(Icons.verified_outlined, color: c.success),
                const SizedBox(width: AppSpacing.s8),
                const Expanded(child: Text('No flags in this ward.')),
              ],
            ),
          ),
        for (final type in types) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _flagDot(type),
            minLeadingWidth: 12,
            title: Text(flagLabel(type)),
            subtitle: Text(
              type == 'sla_missed'
                  ? '${byType[type]['count']} jobs · $kSlaNoMoney'
                  : '${byType[type]['count']} jobs · ${flagStanding(type)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (type != 'sla_missed') Text(formatInr(byType[type]['inr'] as num), style: t.labelLarge),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => ref
                .read(panelProvider.notifier)
                .push(PanelPage('${flagLabel(type)} · Ward $code', WardFlagList(ward: code, type: type))),
          ),
          if (noticeFlagTypes.contains(type))
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s20, bottom: AppSpacing.s4),
                child: TextButton.icon(
                  onPressed: () => showNoticeSheet(context, type: type, wardCode: code),
                  icon: const Icon(Icons.edit_note),
                  label: const Text(kDraftNotice),
                ),
              ),
            ),
        ],
        if (types.isNotEmpty) Text(kFlagsOverlap, style: t.bodySmall?.copyWith(color: c.textSecondary)),
        const SizedBox(height: AppSpacing.s16),
        FilledButton.icon(
          onPressed: () => showNextRupee(ref, code),
          icon: const Icon(Icons.place_outlined),
          label: const Text(kNextRupeeAction),
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            OutlinedButton.icon(
              onPressed: () => showWardBrief(context, code),
              icon: const Icon(Icons.description_outlined),
              label: const Text(kWardBrief),
            ),
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(panelProvider.notifier)
                  .push(PanelPage('$kContractorsInWard · Ward $code', ScorecardList(ward: code))),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text(kContractorsInWard),
            ),
          ],
        ),
        const SectionTitle('Top contractors by spend'),
        if (contractors.isEmpty) const Text('No work orders in this ward.'),
        for (final k in contractors)
          LabelledBar(
            label: '${k['name']} · ${k['jobs']} jobs',
            value: k['inr'] as num,
            max: maxC,
            trailing: formatInr(k['inr'] as num),
          ),
        const SectionTitle('Repair methods by spend'),
        if (methods.isEmpty) const Text('No work orders in this ward.'),
        for (final m in methods)
          LabelledBar(
            label: '${m['method']} · ${m['jobs']} jobs',
            value: m['inr'] as num,
            max: maxM,
            trailing: formatInr(m['inr'] as num),
            color: c.info,
          ),
      ],
    );
  }
}

/// The work orders behind one flag type in a ward.
class WardFlagList extends ConsumerWidget {
  const WardFlagList({super.key, required this.ward, required this.type});
  final String ward;
  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = (ward: ward, type: type);
    return asyncPage(
      ref.watch(wardFlagsProvider(q)),
      onRetry: () => ref.invalidate(wardFlagsProvider(q)),
      data: (flags) {
        if (flags.isEmpty) return const PanelMessage.empty('No work orders with this flag in this ward.');
        final roads = ref.watch(mapDataProvider).value?.roadById ?? const {};
        return PanelList(
          children: [
            Text('${flags.length} work orders · ${flagStanding(type)}', style: Theme.of(context).textTheme.bodyMedium),
            if (noticeFlagTypes.contains(type)) ...[
              const SizedBox(height: AppSpacing.s8),
              FilledButton.icon(
                onPressed: () => showNoticeSheet(context, type: type, wardCode: ward),
                icon: const Icon(Icons.edit_note),
                label: const Text(kDraftNotice),
              ),
            ],
            const SizedBox(height: AppSpacing.s8),
            for (final f in flags)
              _FlagCard(
                flag: f as Json,
                roadName: roads[f['road_id']]?.name ?? f['road_id'] as String,
                onOpenRoad: () => ref
                    .read(panelProvider.notifier)
                    .push(PanelPage(roads[f['road_id']]?.name ?? f['road_id'] as String, RoadPanel(f['road_id'] as String))),
              ),
          ],
        );
      },
    );
  }
}

class _FlagCard extends StatelessWidget {
  const _FlagCard({required this.flag, required this.roadName, required this.onOpenRoad});
  final Json flag;
  final String roadName;
  final VoidCallback onOpenRoad;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.s8),
    child: ExpansionTile(
      shape: const Border(),
      title: Text('${flag['work_order_id']} · ${formatInr(flag['cost_inr'] as num)}'),
      subtitle: Text('$roadName · ${flag['contractor_name']}'),
      childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, AppSpacing.s8),
      children: [
        EvidenceTable(flag['evidence'] as Map? ?? const {}),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(onPressed: onOpenRoad, icon: const Icon(Icons.add_road), label: const Text('Open road')),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- road panel

class RoadPanel extends ConsumerWidget {
  const RoadPanel(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final road = ref.watch(roadDetailProvider(id));
    final flags = ref.watch(roadFlagsProvider(id));
    void retry() {
      ref.invalidate(roadDetailProvider(id));
      ref.invalidate(roadFlagsProvider(id));
    }

    if (road.hasError || flags.hasError) {
      return PanelMessage.error('Could not load this road.\n${road.error ?? flags.error}', onRetry: retry);
    }
    if (!road.hasValue || !flags.hasValue) return const PanelMessage.loading();
    return _body(context, road.requireValue, flags.requireValue);
  }

  Widget _body(BuildContext context, Json r, List<dynamic> flags) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final status = r['status'] as String? ?? 'clean';
    final wos = [...(r['work_orders'] as List? ?? const [])]
      ..sort((a, b) => '${a['assigned_at']}'.compareTo('${b['assigned_at']}'));
    final noticeTypes = [for (final k in flagOrder) if (noticeFlagTypes.contains(k) && flags.any((f) => f['type'] == k)) k];
    Json? flagFor(String wo, String type) =>
        flags.cast<Json?>().firstWhere((f) => f!['work_order_id'] == wo && f['type'] == type, orElse: () => null);

    return PanelList(
      children: [
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s4,
          children: [
            if (status == 'clean' && flags.any((f) => f['type'] == 'sla_missed'))
              Tag(kSlowerSomeJobs, bg: c.warningTint, fg: c.warning)
            else
              Tag(roadStatusLabels[status] ?? status, bg: flagColor(status).withValues(alpha: 0.12), fg: flagColor(status)),
            if (r['under_dlp'] == 'Y') Tag(kUnderWarranty, bg: c.infoTint, fg: c.info, icon: Icons.verified_user_outlined),
            Tag('Ward ${r['ward_code']} · ${r['road_type'] ?? ''}', bg: c.surfaceAlt, fg: c.textSecondary),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Text(formatInr(r['spend'] as num? ?? 0), style: t.headlineMedium),
        Text('spent on this segment across ${wos.length} work orders', style: t.bodyMedium),
        for (final type in noticeTypes) ...[
          const SizedBox(height: AppSpacing.s8),
          FilledButton.icon(
            onPressed: () => showNoticeSheet(context, type: type, roadId: id),
            icon: const Icon(Icons.edit_note),
            label: Text('$kDraftNotice · ${flagShortLabels[type]}'),
          ),
        ],
        const SectionTitle('Work orders, oldest first'),
        if (wos.isEmpty) const Text('No work orders on this road.'),
        for (final wo in wos) _WorkOrderCard(wo: wo as Json, flagFor: flagFor),
      ],
    );
  }
}

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard({required this.wo, required this.flagFor});
  final Json wo;
  final Json? Function(String wo, String type) flagFor;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final types = [for (final k in flagOrder) if ((wo['flags'] as List? ?? const []).contains(k)) k];
    final onTime = wo['sla_met'] == true;
    final reopened = wo['reopened'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s12, AppSpacing.s12, AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('${wo['id']} · ${wo['method']}', style: t.titleSmall)),
                Text(formatInr(wo['cost_inr'] as num? ?? 0), style: t.titleSmall),
              ],
            ),
            Text('${wo['contractor_name']}', style: t.bodySmall),
            Text('Assigned ${'${wo['assigned_at']}'.split(' ').first}, completed ${'${wo['completed_at'] ?? '—'}'.split(' ').first}',
                style: t.bodySmall?.copyWith(color: c.textSecondary)),
            const SizedBox(height: AppSpacing.s4),
            Wrap(
              spacing: AppSpacing.s4,
              runSpacing: AppSpacing.s4,
              children: [
                Tag(onTime ? 'On time' : 'Slower than typical', bg: onTime ? c.successTint : c.warningTint, fg: onTime ? c.success : c.warning),
                Tag(reopened ? 'Re-opened' : 'Not re-opened', bg: reopened ? c.errorTint : c.surfaceAlt, fg: reopened ? c.error : c.textSecondary),
              ],
            ),
            for (final type in types)
              ExpansionTile(
                shape: const Border(),
                tilePadding: EdgeInsets.zero,
                dense: true,
                leading: _flagDot(type),
                minTileHeight: 40,
                title: Text(flagLabel(type)),
                subtitle: Text('${flagStanding(type)} · tap for the numbers'),
                childrenPadding: const EdgeInsets.only(left: AppSpacing.s24, bottom: AppSpacing.s8),
                children: [
                  if (flagFor('${wo['id']}', type) case final f?)
                    EvidenceTable(f['evidence'] as Map? ?? const {})
                  else
                    const Text('No evidence row found for this flag.'),
                ],
              ),
            if ((wo['linked_complaint_ids'] as List? ?? const []).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: Text('Complaints: ${(wo['linked_complaint_ids'] as List).join(', ')}',
                    style: t.bodySmall?.copyWith(color: c.textSecondary)),
              )
            else
              const SizedBox(height: AppSpacing.s8),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- hero

/// The city-wide rupees billed on roads under warranty; tapping lists wards.
class WarrantyHeroCard extends ConsumerWidget {
  const WarrantyHeroCard({super.key, required this.data});
  final MapData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final dlp = (((data.meta['totals'] as Map?)?['flags'] as Map?)?['dlp_paid'] as Map?) ?? const {};
    final inr = dlp['inr'] as num? ?? 0;
    return Card(
      color: c.surface,
      elevation: 3,
      child: InkWell(
        borderRadius: AppRadii.cardRadius,
        onTap: () => ref.read(panelProvider.notifier).open(PanelPage('Billed under warranty, by ward', DlpWardRanking(data))),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Row(
            children: [
              Container(width: 4, height: 44, color: flagColor('dlp_paid')),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heroLine(formatInr(inr)), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${dlp['count'] ?? 0} jobs across Mumbai · tap to see wards', style: t.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class DlpWardRanking extends ConsumerWidget {
  const DlpWardRanking(this.data, {super.key});
  final MapData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wards = [...data.wards.where((w) => (w.data['dlp_paid_inr'] as num? ?? 0) > 0)]
      ..sort((a, b) => (b.data['dlp_paid_inr'] as num).compareTo(a.data['dlp_paid_inr'] as num));
    if (wards.isEmpty) return const PanelMessage.empty('No ward has work billed under warranty.');
    final max = wards.first.data['dlp_paid_inr'] as num;
    return PanelList(
      children: [
        Text('$kToBeClaimed. Tap a ward to see its work orders.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.s8),
        for (final (i, w) in wards.indexed)
          InkWell(
            onTap: () => ref.read(panelProvider.notifier).push(PanelPage('Ward ${w.code} · ${w.name}', WardPanel(w.code), ward: w.code)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
              child: LabelledBar(
                label: '${i + 1}. ${w.code} · ${w.name} · ${w.data['dlp_paid_count']} jobs',
                value: w.data['dlp_paid_inr'] as num,
                max: max,
                trailing: formatInr(w.data['dlp_paid_inr'] as num),
                color: flagColor('dlp_paid'),
              ),
            ),
          ),
      ],
    );
  }
}
