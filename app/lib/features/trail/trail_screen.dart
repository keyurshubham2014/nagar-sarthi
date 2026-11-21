import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/widgets/ui.dart';
import '../citizen/citizen_panels.dart' show pushComplaint;
import '../officer/officer_data.dart' show Json;
import '../officer/officer_panels.dart' show openRoad;

// Complaint trail: raw complaints -> issues -> work orders -> outcome, from the engine's linker.

Duration? _noRetry(int _, Object _) => null;

/// Funnel numbers for a ward ('' = all Mumbai).
final linkerProvider = FutureProvider.family<Json, String>(
  retry: _noRetry,
  (ref, ward) => ref.watch(apiClientProvider).linker(ward: ward.isEmpty ? null : ward),
);
final issueProvider = FutureProvider.family<Json, String>(retry: _noRetry, (ref, id) => ref.watch(apiClientProvider).issue(id));

/// Complaint trail page for [ward] (null opens on all Mumbai).
void openTrail(String? ward) => appRouter.push(Uri(path: '/trail', queryParameters: {'ward': ?ward}).toString());
void openIssue(String id) => appRouter.push(Uri(path: '/issue', queryParameters: {'id': id}).toString());

const Map<String, String> outcomeLabels = {
  'fixed_held': 'Fixed and held',
  'fixed_failed': 'Fixed, then failed',
  'in_progress': 'In progress',
  'never_fixed': 'Never fixed',
};
const String kInferredLink = 'Inferred link';

Color outcomeColor(SaartheeColors c, String? o) => switch (o) {
  'fixed_held' => c.success,
  'fixed_failed' => c.error,
  'in_progress' => c.info,
  _ => c.warning,
};

StatusTone _outcomeTone(String? o) => switch (o) {
  'fixed_held' => StatusTone.success,
  'fixed_failed' => StatusTone.error,
  'in_progress' => StatusTone.info,
  _ => StatusTone.warning,
};

String _hours(num? h) => h == null
    ? 'close to the first report'
    : h < 0
    ? '${(-h).round()} hours before the first report'
    : '${h.round()} hours after the first report';
String _day(Object? s) => '${s ?? '—'}'.split(' ').first;
String _plain(Object? name) => '${name ?? '—'}'.replaceAll(' (synthetic)', '');
String _plural(num n, String one, String many) => '${formatCount(n)} ${n == 1 ? one : many}';

PictogramKind _pictogram(Object? category) {
  final s = '${category ?? ''}'.toLowerCase();
  if (s.contains('water')) return PictogramKind.waterlogging;
  if (s.contains('manhole')) return PictogramKind.manhole;
  if (s.contains('drain')) return PictogramKind.drain;
  if (s.contains('cave') || s.contains('fail')) return PictogramKind.failedRepair;
  return PictogramKind.pothole;
}

Widget outcomeTag(BuildContext context, String? o) => StatusChip(outcomeLabels[o] ?? '$o', tone: _outcomeTone(o), dot: true);

Widget inferredTag(BuildContext context) => const StatusChip(kInferredLink, tone: StatusTone.info);

// ---------------------------------------------------------------- list page

/// Funnel, outcome chips, search and the issue list for one ward or all Mumbai.
class TrailPage extends ConsumerStatefulWidget {
  const TrailPage({super.key, this.ward});
  final String? ward;
  @override
  ConsumerState<TrailPage> createState() => _TrailPageState();
}

class _TrailPageState extends ConsumerState<TrailPage> {
  static const int _page = 30;
  late bool _allMumbai = widget.ward == null;
  String? _outcome;
  final _search = TextEditingController();
  Timer? _debounce;
  List<dynamic> _items = const [];
  int _total = 0;
  bool _loading = false;
  String? _error;
  int _request = 0; // newer requests win

  String? get _ward => _allMumbai ? null : widget.ward;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final id = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _items = const [];
    });
    try {
      final q = _search.text.trim();
      final r = await ref.read(apiClientProvider).issues(
        ward: _ward,
        outcome: _outcome,
        q: q.isEmpty ? null : q,
        offset: reset ? 0 : _items.length,
        limit: _page,
      );
      if (!mounted || id != _request) return;
      setState(() {
        _items = [..._items, ...(r['items'] as List)];
        _total = r['total'] as int? ?? 0;
      });
    } on ApiException catch (e) {
      if (mounted && id == _request) setState(() => _error = e.message);
    } finally {
      if (mounted && id == _request) setState(() => _loading = false);
    }
  }

  void _set(VoidCallback f) {
    setState(f);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTypeScale.of(context);
    final header = <Widget>[
      if (widget.ward != null) ...[
        Gutter(
          child: SegmentedControl<bool>(
            segments: [(false, 'Ward ${widget.ward}'), (true, 'All Mumbai')],
            value: _allMumbai,
            onChanged: (v) => _set(() => _allMumbai = v),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
      ],
      Gutter(
        child: AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.standard),
          child: _Funnel(key: ValueKey(_ward), ward: _ward ?? ''),
        ),
      ),
      const SectionBreak(),
      const Gutter(child: SectionHeading('Issues')),
      FilterChipRow(
        children: [
          for (final (k, label) in [
            (null, 'All'),
            ...outcomeLabels.entries.map((e) => (e.key, e.value)),
            ('social_only', 'Social media only'),
          ])
            FilterPill(label: label, selected: _outcome == k, onTap: () => _set(() => _outcome = k)),
        ],
      ),
      const SizedBox(height: AppSpacing.s8),
      Gutter(
        child: SearchField(
          controller: _search,
          hint: 'Place, road or any id',
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 350), () => _load(reset: true));
          },
          onSubmitted: (_) => _load(reset: true),
        ),
      ),
      const SizedBox(height: AppSpacing.s12),
      Gutter(
        child: Text(
          '${_total == 1 ? '1 issue' : '${formatCount(_total)} issues'} · most reported first',
          style: t.caption,
        ),
      ),
      const SizedBox(height: AppSpacing.s4),
    ];
    final footer = <Widget>[
      if (_error != null)
        ErrorState(message: 'Could not load issues. $_error', onRetry: () => _load(reset: _items.isEmpty))
      else if (_loading)
        Skeleton.rows(count: _items.isEmpty ? 6 : 2)
      else if (_items.isEmpty)
        const EmptyState(pictogram: PictogramKind.trail, message: 'No issues match these filters.')
      else if (_items.length < _total)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s16, AppSpacing.gutter, 0),
          child: SecondaryButton(
            label: 'Load more (${_items.length} of ${formatCount(_total)} shown)',
            onPressed: () => _load(reset: false),
          ),
        ),
    ];
    return LargeTitleScaffold(
      title: 'Complaint trail',
      caption: 'From a citizen’s report to a finished repair',
      onRefresh: () async {
        ref.invalidate(linkerProvider(_ward ?? ''));
        await _load(reset: true);
      },
      slivers: [
        SliverList.list(children: header),
        SliverList.builder(
          itemCount: _items.length,
          itemBuilder: (context, i) {
            final it = _items[i] as Json;
            return StaggeredEntrance(
              key: ValueKey('${it['id']}'),
              index: i,
              child: IssueRow(it),
            );
          },
        ),
        SliverList.list(children: footer),
      ],
    );
  }
}

/// Raw complaints -> cleaned -> issues -> work orders -> held, as five narrowing bars,
/// the other outcomes beside it, and the "How we link" note.
class _Funnel extends ConsumerWidget {
  const _Funnel({super.key, required this.ward});
  final String ward;
  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(linkerProvider(ward))) {
    AsyncData(:final value) => _FunnelBody(l: value, ward: ward),
    AsyncError(:final error) => ErrorState(
      message: 'Could not load the funnel. $error',
      onRetry: () => ref.invalidate(linkerProvider(ward)),
    ),
    _ => Skeleton(
      child: Column(
        children: [
          for (final w in const [1.0, 0.9, 0.6, 0.5, 0.35]) ...[
            const SkeletonBox(height: 18, widthFactor: 0.6),
            const SizedBox(height: AppSpacing.s8),
            Center(child: SkeletonBox(height: 14, widthFactor: w, radius: 7)),
            const SizedBox(height: AppSpacing.s16),
          ],
        ],
      ),
    ),
  };
}

class _FunnelBody extends StatefulWidget {
  const _FunnelBody({required this.l, required this.ward});
  final Json l;
  final String ward;
  @override
  State<_FunnelBody> createState() => _FunnelBodyState();
}

class _FunnelBodyState extends State<_FunnelBody> with SingleTickerProviderStateMixin {
  static const _step = Duration(milliseconds: 60);
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.standard + _step * 4);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (AppMotion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final l = widget.l;
    final raw = l['raw_complaints'] as int;
    final issues = l['issues'] as int;
    final links = l['links'] as Map;
    final by = l['issues_by_outcome'] as Map;
    num count(String o) => (by[o] as Map)['count'] as num? ?? 0;
    num inr(String o) => (by[o] as Map)['inr'] as num? ?? 0;
    final held = inr('fixed_held');
    final steps = [
      (raw, 'complaints received', null, c.primary),
      (
        l['in_issues'] as int,
        'after removing noise and out-of-scope',
        '${formatCount(l['noise'] as int)} not about roads (street lights, garbage, tests) · '
            '${formatCount(l['out_of_scope'] as int)} not BMC’s road (MMRDA, PWD)',
        c.primary,
      ),
      (issues, 'distinct issues', '${formatCount(l['social_only_issues'] as int)} from social posts only', c.primary),
      (l['with_work_order'] as int, 'with a work order', '${formatCount(links['inferred'] as int)} inferred', c.primary),
      (count('fixed_held'), 'fixed and held', held == 0 ? null : formatInr(held), c.success),
    ];
    final total = _c.duration!.inMilliseconds;
    Widget dot(Color col) => Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.ward.isEmpty ? 'All Mumbai' : 'Ward ${widget.ward}', style: t.label.copyWith(color: c.textSecondary)),
        const SizedBox(height: AppSpacing.s12),
        for (final (i, (n, label, note, col)) in steps.indexed) ...[
          Semantics(
            label: '${formatCount(n)} $label${note == null ? '' : ', $note'}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: formatCount(n), style: t.title.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                      TextSpan(text: '  $label', style: t.body),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                AnimatedBuilder(
                  animation: _c,
                  builder: (_, _) {
                    final start = (_step * i).inMilliseconds / total;
                    final end = (_step * i + AppMotion.standard).inMilliseconds / total;
                    final k = Interval(start, end, curve: AppMotion.standardCurve).transform(_c.value);
                    final share = raw <= 0 ? 0.0 : (n / raw).clamp(0.04, 1.0).toDouble();
                    return Container(
                      height: 14,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(7)),
                      child: FractionallySizedBox(
                        widthFactor: share * k,
                        heightFactor: 1,
                        child: DecoratedBox(decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(7))),
                      ),
                    );
                  },
                ),
                if (note != null) ...[const SizedBox(height: AppSpacing.s4), Text(note, style: t.caption)],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
        ],
        Text('The other ${_plural(issues - count('fixed_held'), 'issue', 'issues')}', style: t.label.copyWith(color: c.textSecondary)),
        const SizedBox(height: AppSpacing.s4),
        for (final o in ['fixed_failed', 'in_progress', 'never_fixed'])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            child: Row(
              children: [
                dot(outcomeColor(c, o)),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    '${formatCount(count(o))} ${outcomeLabels[o]!.toLowerCase()}${inr(o) == 0 ? '' : ' · ${formatInr(inr(o))}'}',
                    style: t.body,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.s12),
        Text(
          '${formatPercent(l['categories_corrected_share'] as num)} of categories corrected '
          '(${formatCount(l['categories_corrected'] as int)} of ${formatCount(raw)} complaints).',
          style: t.bodyStrong,
        ),
        Text('Rupees count recorded links only.', style: t.caption),
        const SizedBox(height: AppSpacing.s16),
        CollapsiblePanel(title: 'How we link, and how often it is right', icon: Icons.link, child: HowWeLink(l)),
      ],
    );
  }
}

/// The engine's method lines and its measured accuracy, worded plainly.
class HowWeLink extends StatelessWidget {
  const HowWeLink(this.l, {super.key});
  final Json l;
  @override
  Widget build(BuildContext context) {
    final t = AppTypeScale.of(context);
    final v = (l['validation'] as Map?) ?? const {};
    final cat = (v['category'] as Map?) ?? const {};
    final grp = ((v['grouping'] as Map?)?['without_work_order_rule'] as Map?) ?? const {};
    final inf = (v['inferred_link_rule_on_recorded_issues'] as Map?) ?? const {};
    Widget bullet(String s) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('•  '), Expanded(child: Text(s))]),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in (l['method'] as List? ?? const [])) bullet('$m'),
        const SizedBox(height: AppSpacing.s16),
        Semantics(header: true, child: Text('How often it is right', style: t.bodyStrong)),
        bullet('Category: the category people picked matched the repair BMC actually did ${formatPercent(cat['reported_vs_work_type'] as num? ?? 0)} '
            'of the time; after our correction, ${formatPercent(cat['clean_vs_work_type'] as num? ?? 0)}.'),
        bullet('Grouping: tested blind against BMC’s own links, our rules put the right complaints together '
            '${formatPercent(grp['precision'] as num? ?? 0)} of the time and found ${formatPercent(grp['recall'] as num? ?? 0)} of the true pairs. '
            'So complaints BMC linked are grouped by BMC’s work order; the rules only group the ones BMC never linked.'),
        bullet('Inferred links: tested blind on issues with a recorded link, our best match picked BMC’s own work order '
            '${formatPercent(inf['accuracy_when_matched'] as num? ?? 0)} of the time. About 1 in '
            '${((1 / (1 - ((inf['accuracy_when_matched'] as num?) ?? 0.8))).round())} inferred links may be wrong, so each is marked “$kInferredLink”.'),
        const SizedBox(height: AppSpacing.s12),
        Text('Synthetic data. Not BMC data. Contractors are fictional.', style: t.caption),
      ],
    );
  }
}

/// One issue in the list: category and place, report-count badge, work order,
/// corrected-category note and outcome chip.
class IssueRow extends StatelessWidget {
  const IssueRow(this.i, {super.key});
  final Json i;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final n = i['complaint_count'] as int? ?? 0;
    final p = i['social_post_count'] as int? ?? 0;
    final fixedCats = i['corrected_categories'] as int? ?? 0;
    final wos = (i['work_order_ids'] as List?) ?? const [];
    final place = [i['road_name'], i['locality']].whereType<String>().toSet().join(', ');
    final notes = [
      if (fixedCats > 0) _plural(fixedCats, 'category corrected', 'categories corrected'),
      if (i['link'] == 'inferred') kInferredLink,
      if (i['source'] == 'social_only') 'Social media only',
    ];
    return ListRow(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
            child: Pictogram(_pictogram(i['category']), size: 20),
          ),
          if (n + p > 0)
            PositionedDirectional(
              top: -4,
              end: -6,
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: ShapeDecoration(color: c.primary, shape: AppRadii.pill),
                  child: Text('${n + p}', style: t.label.copyWith(color: c.onPrimary, fontSize: 11, height: 14 / 11)),
                ),
              ),
            ),
        ],
      ),
      title: '${i['category']} · ${place.isEmpty ? 'Ward ${i['ward_code']}' : place}',
      caption: [
        [if (n > 0) _plural(n, 'report', 'reports'), if (p > 0) _plural(p, 'post', 'posts')].join(' + '),
        '${i['id']}',
        if (wos.isNotEmpty) '${wos.join(', ')} · ${_plain(i['contractor_name'])}',
      ].where((s) => s.isNotEmpty).join(' · '),
      chip: Wrap(
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          outcomeTag(context, i['outcome'] as String?),
          if (notes.isNotEmpty) Text(notes.join(' · '), style: t.caption),
        ],
      ),
      amount: wos.isEmpty ? null : formatInr(i['cost_inr'] as num? ?? 0),
      onTap: () => openIssue(i['id'] as String),
    );
  }
}

// ---------------------------------------------------------------- issue page

/// One issue's trail as a vertical timeline: complaints, social posts, work order, outcome.
class IssueDetail extends ConsumerStatefulWidget {
  const IssueDetail(this.id, {super.key});
  final String id;
  @override
  ConsumerState<IssueDetail> createState() => _IssueDetailState();
}

class _IssueDetailState extends ConsumerState<IssueDetail> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(issueProvider(widget.id));
    final d = v.value;
    final place = d == null ? '' : [d['road_name'], d['locality']].whereType<String>().toSet().join(', ');
    return LargeTitleScaffold(
      title: d == null ? 'Issue ${widget.id}' : '${d['category']} · ${place.isEmpty ? 'Ward ${d['ward_code']}' : place}',
      caption: d == null ? null : '${d['id']} · Ward ${d['ward_code']} · ${_day(d['first_seen'])} to ${_day(d['last_seen'])}',
      onRefresh: () => ref.refresh(issueProvider(widget.id).future),
      children: [
        if (d != null)
          ..._body(context, d)
        else if (v.error case ApiException(status: 404))
          EmptyState(pictogram: PictogramKind.track, message: 'No issue with id ${widget.id}.')
        else if (v.hasError)
          ErrorState(message: 'Could not load this issue.\n${v.error}', onRetry: () => ref.invalidate(issueProvider(widget.id)))
        else
          Gutter(
            child: Skeleton(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 120, height: 24, radius: 12),
                  const SizedBox(height: AppSpacing.s24),
                  for (var i = 0; i < 4; i++) ...[
                    const SkeletonBox(height: 16, widthFactor: 0.7),
                    const SizedBox(height: AppSpacing.s8),
                    const SkeletonBox(height: 12, widthFactor: 0.5),
                    const SizedBox(height: AppSpacing.s24),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _body(BuildContext context, Json d) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final complaints = [for (final x in (d['complaints'] as List? ?? const [])) x as Json];
    final posts = [for (final x in (d['social_posts'] as List? ?? const [])) x as Json];
    final wos = [for (final x in (d['work_orders'] as List? ?? const [])) x as Json];
    final inferred = d['link'] == 'inferred';
    final ev = d['link_evidence'] as Map?;
    // The honest accuracy figure comes from the engine's city-wide check, never hardcoded.
    final accuracy = ((ref.watch(linkerProvider('')).value?['validation'] as Map?)?['inferred_link_rule_on_recorded_issues'] as Map?)?['accuracy_when_matched'] as num?;
    // Duplicates collapse: keep the first report, every corrected one and every one not closed as duplicate.
    final shown = <Json>[];
    final folded = <Json>[];
    for (final (k, x) in complaints.indexed) {
      (k == 0 || x['category_corrected'] == true || x['status'] != 'Closed - Duplicate' || _showAll ? shown : folded).add(x);
    }
    final link = TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, AppSpacing.touchTarget),
      alignment: AlignmentDirectional.centerStart,
    );
    final steps = <TimelineStep>[
      for (final x in shown) _complaintStep(context, x, link),
      if (folded.isNotEmpty)
        TimelineStep(
          title: '+${folded.length} same report',
          meta: 'Closed by BMC as duplicates of the first report.',
          state: TimelineNodeState.pending,
          child: TextButton(style: link, onPressed: () => setState(() => _showAll = true), child: const Text('Show them')),
        ),
      for (final p in posts)
        TimelineStep(
          title: 'Social post · reach ${formatCount(p['reach'] as num? ?? 0)}',
          meta: _day(p['posted_at']),
          chip: StatusChip('${p['source'] ?? 'Social post'}'),
          child: Text('“${p['text'] ?? ''}”', style: t.body),
        ),
      if (wos.isEmpty)
        TimelineStep(
          title: 'No work order found',
          state: TimelineNodeState.pending,
          meta: d['source'] == 'social_only'
              ? 'These posts matched no complaint in BMC’s system and no repair job.'
              : 'No repair job is recorded for these complaints, and none matched by road, type and date.',
        ),
      for (final wo in wos)
        TimelineStep(
          title: 'Work order ${wo['id']}',
          amount: formatInr(wo['cost_inr'] as num? ?? 0),
          meta: '${wo['method']} · ${_plain(wo['contractor_name'])}\n'
              'Assigned ${_day(wo['assigned_at'])}, completed ${_day(wo['completed_at'])}'
              '${wo['under_dlp'] == 'Y' ? '\nRoad under warranty' : ''}',
          chip: inferred ? inferredTag(context) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inferred && ev != null)
                Text(
                  'Our best match, not BMC’s record: same road and repair type, assigned ${_hours(ev['hours_after_first_report'] as num?)}'
                  '${(ev['candidates'] as num? ?? 1) > 1 ? ', nearest in time of ${ev['candidates']} jobs' : ''}.',
                  style: t.caption,
                ),
              TextButton.icon(
                style: link,
                onPressed: () => openRoad(wo['road_id'] as String, wo: wo['id'] as String),
                icon: const Icon(Icons.alt_route, size: AppSpacing.iconSmall),
                label: Text('Open road: ${wo['road_name']}'),
              ),
            ],
          ),
        ),
      TimelineStep(
        title: outcomeLabels[d['outcome']] ?? '${d['outcome']}',
        state: TimelineNodeState.outcome,
        color: outcomeColor(c, d['outcome'] as String?),
        meta: switch (d['outcome']) {
          'fixed_held' => 'Not reported again within 30 days of the repair${d['days_to_fix'] == null ? '' : ' (fixed ${d['days_to_fix']} days after the first report)'}.',
          'fixed_failed' => 'Reported again within 30 days of the repair: needs review.',
          'in_progress' => 'BMC marked a complaint In Progress; no work order is recorded yet.',
          _ => 'No repair is recorded for this issue.',
        },
      ),
    ];
    final summary = [
      if (complaints.isNotEmpty) _plural(complaints.length, 'complaint', 'complaints'),
      if ((d['channels'] as List? ?? const []).isNotEmpty) 'via ${(d['channels'] as List).join(', ')}',
      if (posts.isNotEmpty) _plural(posts.length, 'social post', 'social posts'),
    ].join(' · ');
    return [
      Gutter(
        child: Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            outcomeTag(context, d['outcome'] as String?),
            if (inferred) inferredTag(context),
            if (d['source'] == 'social_only') const StatusChip('Social media only'),
          ],
        ),
      ),
      if (summary.isNotEmpty) ...[const SizedBox(height: AppSpacing.s12), Gutter(child: Text(summary, style: t.body))],
      if (d['source'] == 'social_only') Gutter(child: Text('No matching complaint in BMC’s system.', style: t.caption)),
      if (inferred) ...[
        const SizedBox(height: AppSpacing.s16),
        Gutter(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(color: c.infoTint, borderRadius: AppRadii.tileRadius),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.link, size: AppSpacing.iconSmall, color: c.info),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'An inferred link is our best match by road, repair type and date, not a link recorded by BMC.'
                    '${accuracy == null ? '' : ' Tested blind on recorded links, such matches were right ${formatPercent(accuracy)} of the time.'}',
                    style: t.body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      const SectionBreak(),
      const Gutter(child: SectionHeading('Timeline')),
      Gutter(child: Timeline(steps: steps)),
    ];
  }

  TimelineStep _complaintStep(BuildContext context, Json x, ButtonStyle link) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final corrected = x['category_corrected'] == true;
    return TimelineStep(
      title: 'Complaint ${x['id']}${x['channel'] == null ? '' : ' · ${x['channel']}'}',
      meta: '${_day(x['received_at'])} · ${x['status']}${(x['upvotes'] as num? ?? 0) > 0 ? ' · ${x['upvotes']} upvotes' : ''}',
      chip: corrected
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
              decoration: BoxDecoration(color: c.infoTint, borderRadius: AppRadii.controlRadius),
              child: Text(
                'Reported as ${x['category_reported']} → corrected to ${x['category_clean']}',
                style: t.label.copyWith(color: c.info),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('“${x['description']}”', style: t.body),
          if (corrected && x['category_reason'] != null)
            Text('Why: ${x['category_reason']}', style: t.caption)
          else if (!corrected)
            Text('Category: ${x['category_clean']}', style: t.caption),
          TextButton(style: link, onPressed: () => pushComplaint(context, x['id'] as String), child: const Text('Open complaint')),
        ],
      ),
    );
  }
}
