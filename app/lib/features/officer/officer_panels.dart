import 'package:flutter/material.dart';
import '../../core/i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../core/auth/session.dart';
import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/claude_draft_sheet.dart';
import '../../core/widgets/saarthee.dart';
import '../audit/audit_screen.dart';
import '../citizen/citizen_panels.dart';
import '../citizen/report_card.dart';
import '../corporator/corporator_panels.dart';
import '../map/map_data.dart';
import '../map/map_layers.dart';
import '../trail/trail_screen.dart';
import 'next_rupee.dart';
import 'officer_data.dart';
import 'panel.dart';

/// Ward page (money trail). Ward codes can contain a slash, so they travel as a query parameter.
void openWard(String code) => appRouter.push(Uri(path: '/ward', queryParameters: {'code': code}).toString());

/// Road page; [wo] scrolls to that work order and opens its evidence.
void openRoad(String id, {String? wo}) => appRouter.push(Uri(path: '/road', queryParameters: {'id': id, 'wo': ?wo}).toString());

/// Recovery notice for one flag type on a road or across a ward. The server
/// picks the flag rows; the client sends only the scope.
Future<void> showNoticeSheet(BuildContext context, {required String type, String? roadId, String? wardCode}) async {
  if (!await ensureRole(context, roles: {'officer'}, why: 'Recovery notices are drafted by the ward officer. Sign in as a ward officer to draft one.')) return;
  if (!context.mounted) return;
  await showClaudeDraftSheet(
    context,
    title: 'Recovery notice',
    feature: 'notice',
    body: {'flag_type': type, 'road_id': ?roadId, 'ward_code': ?wardCode},
  );
}

/// Officer actions show for officers, and for signed-out visitors (who get a sign-in prompt on tap).
bool canDraftNotice(String? role) => role == null || role == 'officer';

Color flagColor(String type) => roadStatusColors[type] ?? const Color(0xFF8D6E63);

Widget _flagDot(String type) => Container(
  width: 12,
  height: 12,
  decoration: BoxDecoration(color: flagColor(type), shape: BoxShape.circle),
);

// ---------------------------------------------------------------- ward panel

class WardPanel extends ConsumerWidget {
  const WardPanel(this.code, {super.key, this.header});
  final String code;

  /// Shown above the figures (My Ward's change-ward card).
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) => asyncPage(
    ref.watch(wardDetailProvider(code)),
    onRetry: () => ref.invalidate(wardDetailProvider(code)),
    data: (w) => _body(context, ref, w),
  );

  Widget _body(BuildContext context, WidgetRef ref, Json w) {
    final role = ref.watch(sessionProvider)?.role;
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
        ?header,
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
            onTap: () => pushPanel(PanelPage('${flagLabel(type)} · Ward $code', AuditList(ward: code, type: type, allowAllMumbai: false))),
          ),
          if (noticeFlagTypes.contains(type) && canDraftNotice(role))
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
        // One list of tools; the corporator's brief comes first.
        SectionHeading(role == 'corporator' ? 'Your tools' : 'More about this ward'),
        if (role == 'corporator') NavCard(icon: Icons.description_outlined, title: kWardBrief, subtitle: 'One page in English, हिंदी or मराठी', onTap: () => showWardBrief(context, code)),
        if (role != 'citizen')
          NavCard(icon: Icons.place_outlined, title: kNextRupeeAction, subtitle: 'Open issues ranked by need, within the budget left', onTap: () => showNextRupee(ref, code)),
        NavCard(
          icon: Icons.account_tree_outlined,
          title: 'Complaint trail',
          subtitle: 'Complaints → issues → work orders → what happened',
          onTap: () => openTrail(code),
        ),
        NavCard(
          icon: Icons.engineering_outlined,
          title: kContractorsInWard,
          subtitle: 'Scorecards, A to Z',
          onTap: () => pushPanel(PanelPage('$kContractorsInWard · Ward $code', ScorecardList(ward: code))),
        ),
        if (role != 'corporator') NavCard(icon: Icons.description_outlined, title: kWardBrief, subtitle: 'One page in English, हिंदी or मराठी', onTap: () => showWardBrief(context, code)),
        NavCard(icon: Icons.ios_share, title: context.tr(kReportCard), subtitle: context.tr('A shareable card of your ward’s road repairs.'), onTap: () => pushPanel(PanelPage(kReportCard, ReportCardPage(ward: code)))),
        NavCard(icon: Icons.question_answer_outlined, title: context.tr(kAskWard), subtitle: context.tr('A polite question to the ward office, with the figures.'), onTap: () => pushPanel(PanelPage(kAskWard, AskWardPage(ward: code)))),
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

// ---------------------------------------------------------------- road panel

class RoadPanel extends ConsumerWidget {
  const RoadPanel(this.id, {super.key, this.focusWo});
  final String id;

  /// Work order opened from a flag row: shown first with its evidence open, and marked in the timeline.
  final String? focusWo;

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
    return _body(context, road.requireValue, flags.requireValue, canDraftNotice(ref.watch(sessionProvider)?.role));
  }

  Widget _body(BuildContext context, Json r, List<dynamic> flags, bool canNotice) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final status = r['status'] as String? ?? 'clean';
    final wos = [...(r['work_orders'] as List? ?? const [])]
      ..sort((a, b) => '${a['assigned_at']}'.compareTo('${b['assigned_at']}'));
    final noticeTypes = [
      if (canNotice)
        for (final k in flagOrder) if (noticeFlagTypes.contains(k) && flags.any((f) => f['type'] == k)) k,
    ];
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
        // One filled button per screen: the first notice; any second one is outlined.
        for (final (i, type) in noticeTypes.indexed) ...[
          const SizedBox(height: AppSpacing.s8),
          (i == 0 ? FilledButton.icon : OutlinedButton.icon)(
            onPressed: () => showNoticeSheet(context, type: type, roadId: id),
            icon: const Icon(Icons.edit_note),
            label: Text('$kDraftNotice · ${flagShortLabels[type]}'),
          ),
        ],
        if (wos.cast<Json>().where((w) => w['id'] == focusWo).firstOrNull case final focus?) ...[
          const SectionTitle('The work order you opened'),
          _WorkOrderCard(wo: focus, flagFor: flagFor, focused: true),
        ],
        SectionTitle(context.tr('What happened')),
        if (wos.isEmpty) const Text('No work orders on this road.'),
        for (final (i, wo) in wos.indexed)
          _TimelineStep(
            date: '${wo['assigned_at']}'.split(' ').first,
            color: (wo['flags'] as List? ?? const []).isEmpty ? c.success : flagColor(flagOrder.firstWhere((k) => (wo['flags'] as List).contains(k), orElse: () => 'sla_missed')),
            last: i == wos.length - 1,
            child: _WorkOrderCard(wo: wo as Json, flagFor: flagFor, marked: wo['id'] == focusWo),
          ),
      ],
    );
  }
}

/// One step of the road's timeline: dot, date, connector line and the work order card.
class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.date, required this.color, required this.child, this.last = false});
  final String date;
  final Color color;
  final Widget child;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: AppSpacing.s24,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.s4),
                Container(
                  width: AppSpacing.timelineDot,
                  height: AppSpacing.timelineDot,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                ),
                if (!last) Expanded(child: Container(width: 2, color: c.border)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.textSecondary)),
                const SizedBox(height: AppSpacing.s4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard({required this.wo, required this.flagFor, this.focused = false, this.marked = false});
  final Json wo;
  final Json? Function(String wo, String type) flagFor;

  /// Evidence open from the start.
  final bool focused;

  /// Outlined in the timeline (the work order the page was opened for).
  final bool marked;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final types = [for (final k in flagOrder) if ((wo['flags'] as List? ?? const []).contains(k)) k];
    final onTime = wo['sla_met'] == true;
    final reopened = wo['reopened'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.cardRadius,
        side: BorderSide(color: focused || marked ? c.primary : c.border, width: focused || marked ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s12, AppSpacing.s12, AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('${wo['id']} · ${wo['method']}', style: t.titleSmall)),
                const SizedBox(width: AppSpacing.s8),
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
                // Timing is already shown by the on-time tag.
                for (final type in types.where((t) => t != 'sla_missed'))
                  Tag(flagShortLabels[type] ?? type, bg: flagColor(type).withValues(alpha: 0.12), fg: flagColor(type)),
              ],
            ),
            for (final type in types)
              ExpansionTile(
                shape: const Border(),
                tilePadding: EdgeInsets.zero,
                dense: true,
                initiallyExpanded: focused,
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
              Text('Complaints: ${(wo['linked_complaint_ids'] as List).join(', ')}', style: t.bodySmall?.copyWith(color: c.textSecondary)),
            for (final issue in (wo['issue_ids'] as List? ?? const []))
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => openIssue('$issue'),
                icon: const Icon(Icons.account_tree_outlined),
                label: Text('Complaint trail: $issue'),
              ),
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
        onTap: () => pushPanel(PanelPage('Billed under warranty, by ward', DlpWardRanking(data))),
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
                    Text(context.tr(heroLine('{amount}'), {'amount': formatInr(inr)}), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(context.tr('{n} jobs across Mumbai · tap to see wards', {'n': dlp['count'] ?? 0}), style: t.bodySmall),
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
            onTap: () => openWard(w.code),
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
