import 'package:flutter/material.dart';

import '../../core/i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../core/auth/session.dart';
import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/widgets/claude_draft_sheet.dart';
import '../../core/widgets/ui.dart';
import '../audit/audit_screen.dart';
import '../citizen/citizen_panels.dart' show AskWardPage;
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
  const why = 'Recovery notices are drafted by the ward officer. Sign in as a ward officer to draft one.';
  if (!await ensureRole(context, roles: {'officer'}, why: why) || !context.mounted) return;
  await showClaudeDraftSheet(
    context,
    title: 'Recovery notice',
    feature: 'notice',
    body: {'flag_type': type, 'road_id': ?roadId, 'ward_code': ?wardCode},
  );
}

/// Officer actions show for officers, and for signed-out visitors (who get a sign-in prompt on tap).
bool canDraftNotice(String? role) => role == null || role == 'officer';

/// Map line colour of a flag (legacy; the map and About use it). Screens use [flagTone].
Color flagColor(String type) => roadStatusColors[type] ?? const Color(0xFF8D6E63);

/// Status tone of a flag (plan §1): warranty = info, above rate and repeat = review,
/// failed = error, slower = warning, clean = success.
StatusTone flagTone(String type) => switch (type) {
  'dlp_paid' => StatusTone.info,
  'over_rate' || 'double_billing' => StatusTone.review,
  'fix_failed' => StatusTone.error,
  'sla_missed' => StatusTone.warning,
  'clean' => StatusTone.success,
  _ => StatusTone.neutral,
};

Color flagToneColor(BuildContext context, String type) => StatusChip.colors(SaartheeColors.of(context), flagTone(type)).$1;

/// 40 px grey well with the flag's 12 px colour dot (leading of a ListRow).
Widget _flagWell(BuildContext context, String type) => Container(
  width: 40,
  height: 40,
  alignment: Alignment.center,
  decoration: BoxDecoration(color: SaartheeColors.of(context).surfaceAlt, shape: BoxShape.circle),
  child: Container(
    width: AppSpacing.timelineDot,
    height: AppSpacing.timelineDot,
    decoration: BoxDecoration(color: flagToneColor(context, type), shape: BoxShape.circle),
  ),
);

/// "2024-02-24" or "2025-06-10 07:51" -> "24 Feb 2024".
String _day(Object? s) {
  final d = DateTime.tryParse('${s ?? ''}');
  if (d == null) return '—';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// Section heading inside a page body (headline 24/700, 12 below).
Widget _heading(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.sectionTitleBottom),
  child: Semantics(header: true, child: Text(text, style: context.type.headline)),
);

/// Draft a recovery notice: straight away for one flag type, else pick the type in a sheet.
Future<void> _draftNotice(BuildContext context, List<String> types, {String? roadId, String? wardCode}) async {
  final type = types.length == 1
      ? types.single
      : await showAppSheet<String>(
          context,
          title: kDraftNotice,
          builder: (sheet) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final k in types)
                ListRow(leading: _flagWell(sheet, k), title: flagLabel(k), caption: flagStanding(k), onTap: () => Navigator.pop(sheet, k)),
            ],
          ),
        );
  if (type != null && context.mounted) await showNoticeSheet(context, type: type, roadId: roadId, wardCode: wardCode);
}

// ---------------------------------------------------------------- ward panel

/// Ward page body (also My Ward's): spend against budget, rupees to review by flag
/// type, tools, never-fixed complaints, top contractors and repair methods.
class WardPanel extends ConsumerWidget {
  const WardPanel(this.code, {super.key, this.header});
  final String code;

  /// Shown above the figures (My Ward's title and change-ward pill); stays while loading.
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(wardDetailProvider(code));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContent),
        child: ListView(
          primary: true,
          padding: EdgeInsets.only(top: header == null ? AppSpacing.s16 : 0, bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.s32),
          children: [
            ?header,
            ...switch (v) {
              AsyncData(:final value) => _body(context, ref, value),
              AsyncError(:final error) => [
                ErrorState(message: 'Could not load this ward.\n$error', onRetry: () => ref.invalidate(wardDetailProvider(code))),
              ],
              _ => [
                Gutter(
                  child: Skeleton(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(height: 14, widthFactor: 0.4),
                        SizedBox(height: AppSpacing.s8),
                        SkeletonBox(height: 40, widthFactor: 0.6),
                        SizedBox(height: AppSpacing.s16),
                        SkeletonBox(height: 8),
                        SizedBox(height: AppSpacing.s32),
                        SkeletonBox(height: 24, widthFactor: 0.5),
                        SizedBox(height: AppSpacing.s16),
                        SkeletonBox(height: 12),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                Skeleton.rows(count: 4),
              ],
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, WidgetRef ref, Json w) {
    final role = ref.watch(sessionProvider)?.role;
    final t = context.type;
    final budget = w['budget'] as num? ?? 0;
    final spend = w['spend'] as num? ?? 0;
    final remaining = w['remaining'] as num? ?? budget - spend;
    final byType = (w['by_flag_type'] as Map?) ?? const {};
    num count(String k) => (byType[k] as Map?)?['count'] as num? ?? 0;
    num inr(String k) => (byType[k] as Map?)?['inr'] as num? ?? 0;
    final types = [
      for (final k in flagOrder)
        if (count(k) > 0) k,
    ];
    final moneyTypes = [
      for (final k in types)
        if (k != 'sla_missed' && inr(k) > 0) k,
    ];
    final noticeTypes = [
      for (final k in types)
        if (noticeFlagTypes.contains(k)) k,
    ];
    final contractors = ((w['by_contractor'] as List?) ?? const []).take(5).toList();
    final methods = ((w['by_method'] as List?) ?? const []).take(5).toList();
    final maxC = contractors.isEmpty ? 1 : contractors.first['inr'] as num;
    final maxM = methods.isEmpty ? 1 : methods.first['inr'] as num;
    final neverFixed = (w['never_fixed'] as List? ?? const []).length;

    // (label, pictogram or art, tap)
    final toolList = <(String, PictogramKind?, Widget?, VoidCallback)>[
      (kWardBrief, PictogramKind.brief, null, () => showWardBrief(context, code)),
      (context.tr(kReportCard), PictogramKind.reportCard, null, () => pushPanel(PanelPage(kReportCard, ReportCardPage(ward: code)))),
      (context.tr(kAskWard), PictogramKind.ask, null, () => pushPanel(PanelPage(kAskWard, AskWardPage(ward: code)))),
      ('Complaint trail', PictogramKind.trail, null, () => openTrail(code)),
      if (role != 'citizen') ('Next rupee', PictogramKind.nextRupee, null, () => showNextRupee(ref, code)),
      (
        kContractorsInWard,
        PictogramKind.contractors,
        null,
        () => pushPanel(PanelPage('$kContractorsInWard · Ward $code', ScorecardList(ward: code))),
      ),
      if (noticeTypes.isNotEmpty && canDraftNotice(role))
        (
          kDraftNotice,
          null,
          const Icon(Icons.edit_note, size: AppSpacing.pictogram),
          () => _draftNotice(context, noticeTypes, wardCode: code),
        ),
    ];
    // Lead with enough wide tiles (in pairs) that the square rows of three come out full.
    final wide = [0, 2, 4].firstWhere((k) => (toolList.length - k) % 3 == 0, orElse: () => 0);
    final tools = [
      for (final (i, (label, pic, art, tap)) in toolList.indexed)
        Tile(label: label, pictogram: pic, art: art, onTap: tap, size: i < wide ? TileSize.wide : TileSize.square),
    ];

    return [
      Gutter(
        child: HeroFigure(
          caption: 'Spent of ${formatInr(budget)} budget',
          value: spend,
          format: formatInr,
          explanation: remaining < 0 ? 'Over budget by ${formatInr(-remaining)}' : '${formatInr(remaining)} left this season',
          action: ProgressBar(value: budget <= 0 ? 1 : (spend / budget).toDouble(), height: 8, semanticLabel: 'Spend against budget'),
        ),
      ),
      const SectionBreak(space: AppSpacing.s32),
      Gutter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text('To review: ${formatInr(w['flagged_inr'] as num? ?? 0)}', style: t.headline)),
            const SizedBox(height: AppSpacing.s4),
            Text('${formatPercent(w['flagged_share'] as num? ?? 0)} of spend in this ward needs review', style: t.caption),
            if (moneyTypes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s16),
              _StackedBar([for (final k in moneyTypes) (flagToneColor(context, k), inr(k))]),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.s8),
      if (types.isEmpty)
        const Gutter(
          child: InfoPanel(icon: Icons.verified_outlined, tone: StatusTone.success, text: 'No flags in this ward.'),
        ),
      for (final (i, type) in types.indexed)
        StaggeredEntrance(
          index: i,
          child: ListRow(
            leading: _flagWell(context, type),
            title: flagLabel(type),
            caption: type == 'sla_missed' ? '${count(type)} jobs · $kSlaNoMoney' : '${count(type)} jobs · ${flagStanding(type)}',
            amount: type == 'sla_missed' ? null : formatInr(inr(type)),
            divider: i < types.length - 1,
            onTap: () => pushPanel(PanelPage('${flagLabel(type)} · Ward $code', AuditList(ward: code, type: type, allowAllMumbai: false))),
          ),
        ),
      if (types.isNotEmpty) Gutter(child: Text(kFlagsOverlap, style: t.caption)),
      const SectionBreak(space: AppSpacing.s32),
      // One set of tools; the brief comes first for everyone.
      Gutter(child: _heading(context, role == 'corporator' ? 'Your tools' : 'More about this ward')),
      Gutter(child: TileGrid(tiles: tools, squareColumns: 3)),
      if (neverFixed > 0) ...[
        const SizedBox(height: AppSpacing.s12),
        ListRow(
          icon: Icons.report_outlined,
          title: '$neverFixed complaints never fixed',
          caption: 'Open the complaint trail for this ward',
          divider: false,
          onTap: () => openTrail(code),
        ),
      ],
      const SectionBreak(space: AppSpacing.s32),
      Gutter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(context, 'Top contractors by spend'),
            if (contractors.isEmpty) Text('No work orders in this ward.', style: t.caption),
            for (final k in contractors)
              LabelledBar(
                label: '${k['name']} · ${k['jobs']} jobs',
                value: k['inr'] as num,
                max: maxC,
                trailing: formatInr(k['inr'] as num),
              ),
            const SizedBox(height: AppSpacing.s32),
            _heading(context, 'Repair methods by spend'),
            if (methods.isEmpty) Text('No work orders in this ward.', style: t.caption),
            for (final m in methods)
              LabelledBar(
                label: '${m['method']} · ${m['jobs']} jobs',
                value: m['inr'] as num,
                max: maxM,
                trailing: formatInr(m['inr'] as num),
              ),
          ],
        ),
      ),
    ];
  }
}

/// One horizontal bar split by flag type (rupees), growing in on first paint.
class _StackedBar extends StatelessWidget {
  const _StackedBar(this.parts);
  final List<(Color, num)> parts;
  @override
  Widget build(BuildContext context) {
    final total = parts.fold<num>(0, (s, p) => s + p.$2);
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.of(context, AppMotion.count),
        curve: AppMotion.countCurve,
        builder: (_, k, _) => ClipRRect(
          borderRadius: AppRadii.pillRadius,
          child: SizedBox(
            height: AppSpacing.s12,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: k,
                child: Row(
                  children: [
                    for (final (i, p) in parts.indexed)
                      Expanded(
                        flex: total <= 0 ? 1 : (p.$2 / total * 1000).round().clamp(1, 1000),
                        child: Container(
                          margin: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 2),
                          color: p.$1,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- road panel

class RoadPanel extends ConsumerWidget {
  const RoadPanel(this.id, {super.key, this.focusWo});
  final String id;

  /// Work order opened from a flag row: scrolled into view with its evidence open, flashed once.
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
    final r = road.requireValue;
    final fs = flags.requireValue;
    final noticeTypes = [
      if (canDraftNotice(ref.watch(sessionProvider)?.role))
        for (final k in flagOrder)
          if (noticeFlagTypes.contains(k) && fs.any((f) => f['type'] == k)) k,
    ];
    return Scaffold(
      backgroundColor: SaartheeColors.of(context).background,
      body: _RoadBody(road: r, flags: fs, focusWo: focusWo),
      bottomNavigationBar: noticeTypes.isEmpty
          ? null
          : BottomActionBar(
              child: PrimaryButton(
                label: kDraftNotice,
                icon: Icons.edit_note,
                onPressed: () => _draftNotice(context, noticeTypes, roadId: id),
              ),
            ),
    );
  }
}

class _RoadBody extends StatelessWidget {
  const _RoadBody({required this.road, required this.flags, this.focusWo});
  final Json road;
  final List<dynamic> flags;
  final String? focusWo;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final r = road;
    final status = r['status'] as String? ?? 'clean';
    // Newest first.
    final wos = [...(r['work_orders'] as List? ?? const [])]..sort((a, b) => '${b['assigned_at']}'.compareTo('${a['assigned_at']}'));
    final failed = wos.where((w) => w['reopened'] == true).length;
    Json? flagFor(String wo, String type) =>
        flags.cast<Json?>().firstWhere((f) => f!['work_order_id'] == wo && f['type'] == type, orElse: () => null);
    final resurfaced = flags
        .cast<Json>()
        .where((f) => f['type'] == 'dlp_paid')
        .map((f) => (f['evidence'] as Map?)?['last_resurfaced'])
        .nonNulls
        .firstOrNull;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContent),
        child: ListView(
          primary: true,
          padding: const EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s32),
          children: [
            Gutter(
              child: Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  if (status == 'clean' && flags.any((f) => f['type'] == 'sla_missed'))
                    const StatusChip(kSlowerSomeJobs, tone: StatusTone.warning, dot: true)
                  else
                    StatusChip(roadStatusLabels[status] ?? status, tone: flagTone(status), dot: true),
                  StatusChip('Ward ${r['ward_code']} · ${r['road_type'] ?? ''}'),
                ],
              ),
            ),
            if (r['under_dlp'] == 'Y') ...[
              const SizedBox(height: AppSpacing.s16),
              Gutter(
                child: InfoPanel(
                  icon: Icons.verified_user_outlined,
                  tone: StatusTone.info,
                  text:
                      'Under contractor warranty.${resurfaced == null ? '' : ' Resurfaced ${_day(resurfaced)}.'} '
                      'Repairs in this period are to be claimed and verified.',
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s16),
            Gutter(
              child: StatRow(
                tiles: [
                  StatTile.count(count: r['spend'] as num? ?? 0, format: formatInr, label: 'spent'),
                  StatTile.count(count: wos.length, label: wos.length == 1 ? 'job' : 'jobs'),
                  StatTile.count(count: failed, label: 'failed', color: failed > 0 ? c.error : null, dot: failed > 0 ? c.error : null),
                ],
              ),
            ),
            const SectionBreak(space: AppSpacing.s32),
            Gutter(child: _heading(context, 'Work orders')),
            if (wos.isEmpty)
              const EmptyState(message: 'No work orders on this road.', pictogram: PictogramKind.pothole)
            else
              Gutter(
                child: Timeline(
                  steps: [
                    for (final wo in wos.cast<Json>())
                      () {
                        final types = [
                          for (final k in flagOrder)
                            if ((wo['flags'] as List? ?? const []).contains(k)) k,
                        ];
                        return TimelineStep(
                          title: '${wo['id']} · ${wo['contractor_name']}',
                          meta: '${_day(wo['assigned_at'])} · ${wo['method']}',
                          amount: formatInr(wo['cost_inr'] as num? ?? 0),
                          state: TimelineNodeState.outcome,
                          color: types.isEmpty ? c.success : flagToneColor(context, types.first),
                          chip: types.isEmpty
                              ? const StatusChip(kNoFlags, tone: StatusTone.success)
                              : StatusChip(
                                  flagShortLabels[types.first] ?? types.first,
                                  tone: flagTone(types.first),
                                  more: types.length - 1,
                                ),
                          child: _Evidence(wo: wo, types: types, flagFor: flagFor, focused: wo['id'] == focusWo),
                        );
                      }(),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s16, AppSpacing.gutter, 0),
              child: Text(kFlagsOverlap, style: t.caption),
            ),
          ],
        ),
      ),
    );
  }
}

/// A work order's evidence, collapsed behind "Show evidence". The focused one starts
/// open, scrolls into view and flashes its background once.
class _Evidence extends StatefulWidget {
  const _Evidence({required this.wo, required this.types, required this.flagFor, this.focused = false});
  final Json wo;
  final List<String> types;
  final Json? Function(String wo, String type) flagFor;
  final bool focused;
  @override
  State<_Evidence> createState() => _EvidenceState();
}

class _EvidenceState extends State<_Evidence> {
  late bool _open = widget.focused;
  bool _flash = false;
  final _toggle = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (!widget.focused) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Aim at the small toggle so the step's title stays in view above it.
      final target = _toggle.currentContext;
      if (target == null) return;
      await Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: AppMotion.of(context, AppMotion.pageIn),
        curve: AppMotion.standardCurve,
      );
      if (!mounted) return;
      setState(() => _flash = true);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) setState(() => _flash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final wo = widget.wo;
    final complaints = (wo['linked_complaint_ids'] as List? ?? const []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Pressable(
          key: _toggle,
          onTap: () => setState(() => _open = !_open),
          scale: false,
          borderRadius: AppRadii.pillRadius,
          semanticLabel: _open ? 'Hide evidence for ${wo['id']}' : 'Show evidence for ${wo['id']}',
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_open ? 'Hide evidence' : 'Show evidence', style: t.label.copyWith(fontWeight: FontWeight.w700)),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: AppMotion.of(context, AppMotion.quick),
                  child: const Icon(Icons.expand_more, size: AppSpacing.iconSmall + 2),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.of(context, AppMotion.standard),
          curve: AppMotion.standardCurve,
          alignment: AlignmentDirectional.topStart,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.standard),
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.s14),
                  decoration: BoxDecoration(color: _flash ? c.warningTint : c.surfaceAlt, borderRadius: AppRadii.tileRadius),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EvidenceTable({
                        'Billed': formatInr(wo['cost_inr'] as num? ?? 0),
                        'Assigned': _day(wo['assigned_at']),
                        'Completed': _day(wo['completed_at']),
                        'Timing': wo['sla_met'] == true ? 'On time' : 'Slower than typical',
                        'Re-opened within 30 days': wo['reopened'] == true ? 'Yes' : 'No',
                        'Linked complaints': complaints.isEmpty ? 'None' : '${complaints.length}: ${complaints.join(', ')}',
                      }),
                      for (final type in widget.types) ...[
                        const SizedBox(height: AppSpacing.s12),
                        Row(
                          children: [
                            _flagWellSmall(context, type),
                            const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: Text(flagLabel(type), style: t.label.copyWith(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        Text(flagStanding(type), style: t.caption),
                        if (widget.flagFor('${wo['id']}', type) case final f?)
                          EvidenceTable(f['evidence'] as Map? ?? const {})
                        else
                          Text('No evidence row found for this flag.', style: t.caption),
                      ],
                      for (final issue in (wo['issue_ids'] as List? ?? const []))
                        TextButton.icon(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => openIssue('$issue'),
                          icon: const Icon(Icons.account_tree_outlined),
                          label: Text('Complaint trail: $issue'),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

Widget _flagWellSmall(BuildContext context, String type) => Container(
  width: AppSpacing.s8,
  height: AppSpacing.s8,
  decoration: BoxDecoration(color: flagToneColor(context, type), shape: BoxShape.circle),
);

// ---------------------------------------------------------------- warranty by ward

class DlpWardRanking extends ConsumerWidget {
  const DlpWardRanking(this.data, {super.key});
  final MapData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wards = [...data.wards.where((w) => (w.data['dlp_paid_inr'] as num? ?? 0) > 0)]
      ..sort((a, b) => (b.data['dlp_paid_inr'] as num).compareTo(a.data['dlp_paid_inr'] as num));
    if (wards.isEmpty) return const PanelMessage.empty('No ward has work billed under warranty.');
    final max = wards.first.data['dlp_paid_inr'] as num;
    final c = SaartheeColors.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContent),
        child: ListView(
          primary: true,
          padding: const EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s32),
          children: [
            Gutter(child: Text('$kToBeClaimed. Tap a ward to see its work orders.', style: context.type.caption)),
            const SizedBox(height: AppSpacing.s8),
            for (final (i, w) in wards.indexed)
              StaggeredEntrance(
                index: i,
                child: ListRow(
                  initials: '${i + 1}',
                  title: '${w.code} · ${w.name}',
                  caption: '${w.data['dlp_paid_count']} jobs',
                  chip: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s4),
                    child: ProgressBar(
                      value: (w.data['dlp_paid_inr'] as num) / max,
                      color: c.info,
                      semanticLabel: 'Share of the largest ward',
                    ),
                  ),
                  amount: formatInr(w.data['dlp_paid_inr'] as num),
                  onTap: () => openWard(w.code),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
