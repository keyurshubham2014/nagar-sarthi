import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
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

String _hours(BuildContext context, num? h) => h == null
    ? context.tr('close to the first report')
    : h < 0
    ? context.tr('{n} hours before the first report', {'n': (-h).round()})
    : context.tr('{n} hours after the first report', {'n': h.round()});
String _day(Object? s) => '${s ?? '—'}'.split(' ').first;
String _plain(Object? name) => '${name ?? '—'}'.replaceAll(' (synthetic)', '');

/// "{n} report" / "{n} reports" templates, translated, with the count in Indian grouping.
String _plural(BuildContext context, num n, String one, String many) => context.tr(n == 1 ? one : many, {'n': formatCount(n)});

/// The engine's category-correction note ("photo: 'manhole'", "text (hi-en): 'khadd'"): the source word translates.
String _why(BuildContext context, Object? r) =>
    '$r'.replaceFirstMapped(RegExp(r'^(text|photo)'), (m) => context.tr(m[1]!));

PictogramKind _pictogram(Object? category) {
  final s = '${category ?? ''}'.toLowerCase();
  if (s.contains('water')) return PictogramKind.waterlogging;
  if (s.contains('manhole')) return PictogramKind.manhole;
  if (s.contains('drain')) return PictogramKind.drain;
  if (s.contains('cave') || s.contains('fail')) return PictogramKind.failedRepair;
  return PictogramKind.pothole;
}

Widget outcomeTag(BuildContext context, String? o) => StatusChip(context.tr(outcomeLabels[o] ?? '$o'), tone: _outcomeTone(o), dot: true);

Widget inferredTag(BuildContext context) => StatusChip(context.tr(kInferredLink), tone: StatusTone.info);

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
            segments: [(false, context.tr('Ward {w}', {'w': widget.ward})), (true, context.tr('All Mumbai'))],
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
      Gutter(child: SectionHeading(context.tr('Issues'))),
      FilterChipRow(
        children: [
          for (final (k, label) in [
            (null, 'All'),
            ...outcomeLabels.entries.map((e) => (e.key, e.value)),
            ('social_only', 'Social media only'),
          ])
            FilterPill(label: context.tr(label), selected: _outcome == k, onTap: () => _set(() => _outcome = k)),
        ],
      ),
      const SizedBox(height: AppSpacing.s8),
      Gutter(
        child: SearchField(
          controller: _search,
          hint: context.tr('Place, road or any id'),
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
          '${_plural(context, _total, '1 issue', '{n} issues')} · ${context.tr('most reported first')}',
          style: t.caption,
        ),
      ),
      const SizedBox(height: AppSpacing.s4),
    ];
    final footer = <Widget>[
      if (_error != null)
        ErrorState(message: '${context.tr('Could not load issues.')} $_error', onRetry: () => _load(reset: _items.isEmpty))
      else if (_loading)
        Skeleton.rows(count: _items.isEmpty ? 6 : 2)
      else if (_items.isEmpty)
        EmptyState(pictogram: PictogramKind.trail, message: context.tr('No issues match these filters.'))
      else if (_items.length < _total)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s16, AppSpacing.gutter, 0),
          child: SecondaryButton(
            label: context.tr('Load more ({n} of {total} shown)', {'n': _items.length, 'total': formatCount(_total)}),
            onPressed: () => _load(reset: false),
          ),
        ),
    ];
    return LargeTitleScaffold(
      title: context.tr('Complaint trail'),
      caption: context.tr('From a citizen’s report to a finished repair'),
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
      message: '${context.tr('Could not load the funnel.')} $error',
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
    String tr(String s, [int? n]) => context.tr(s, {'n': formatCount(n ?? 0)});
    final steps = [
      (raw, tr('complaints received'), null, c.primary),
      (
        l['in_issues'] as int,
        tr('after removing noise and out-of-scope'),
        '${tr('{n} not about roads (street lights, garbage, tests)', l['noise'] as int)} · '
            '${tr('{n} not BMC’s road (MMRDA, PWD)', l['out_of_scope'] as int)}',
        c.primary,
      ),
      (issues, tr('distinct issues'), tr('{n} from social posts only', l['social_only_issues'] as int), c.primary),
      (l['with_work_order'] as int, tr('with a work order'), tr('{n} inferred', links['inferred'] as int), c.primary),
      (count('fixed_held'), tr('fixed and held'), held == 0 ? null : formatInr(held), c.success),
    ];
    final total = _c.duration!.inMilliseconds;
    Widget dot(Color col) => Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.ward.isEmpty ? context.tr('All Mumbai') : context.tr('Ward {w}', {'w': widget.ward}), style: t.label.copyWith(color: c.textSecondary)),
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
        Text(_plural(context, issues - count('fixed_held'), 'The other 1 issue', 'The other {n} issues'), style: t.label.copyWith(color: c.textSecondary)),
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
                    '${formatCount(count(o))} ${context.tr(outcomeLabels[o]!.toLowerCase())}${inr(o) == 0 ? '' : ' · ${formatInr(inr(o))}'}',
                    style: t.body,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.s12),
        Text(
          context.tr('{p} of categories corrected ({n} of {total} complaints).', {
            'p': formatPercent(l['categories_corrected_share'] as num),
            'n': formatCount(l['categories_corrected'] as int),
            'total': formatCount(raw),
          }),
          style: t.bodyStrong,
        ),
        Text(context.tr('Rupees count recorded links only.'), style: t.caption),
        const SizedBox(height: AppSpacing.s16),
        CollapsiblePanel(title: context.tr('How we link, and how often it is right'), icon: Icons.link, child: HowWeLink(l)),
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
        // The engine's method lines are a fixed set: each one has a translation.
        for (final m in (l['method'] as List? ?? const [])) bullet(context.tr('$m')),
        const SizedBox(height: AppSpacing.s16),
        Semantics(header: true, child: Text(context.tr('How often it is right'), style: t.bodyStrong)),
        bullet(context.tr(
          'Category: the category people picked matched the repair BMC actually did {p} of the time; after our correction, {q}.',
          {'p': formatPercent(cat['reported_vs_work_type'] as num? ?? 0), 'q': formatPercent(cat['clean_vs_work_type'] as num? ?? 0)},
        )),
        bullet(context.tr(
          'Grouping: tested blind against BMC’s own links, our rules put the right complaints together {p} of the time and found {q} of the true pairs. '
          'So complaints BMC linked are grouped by BMC’s work order; the rules only group the ones BMC never linked.',
          {'p': formatPercent(grp['precision'] as num? ?? 0), 'q': formatPercent(grp['recall'] as num? ?? 0)},
        )),
        bullet(context.tr(
          'Inferred links: tested blind on issues with a recorded link, our best match picked BMC’s own work order {p} of the time. '
          'About 1 in {n} inferred links may be wrong, so each is marked “{tag}”.',
          {
            'p': formatPercent(inf['accuracy_when_matched'] as num? ?? 0),
            'n': ((1 / (1 - ((inf['accuracy_when_matched'] as num?) ?? 0.8))).round()),
            'tag': context.tr(kInferredLink),
          },
        )),
        const SizedBox(height: AppSpacing.s12),
        Text(context.tr('Synthetic data. Not BMC data. Contractors are fictional.'), style: t.caption),
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
      if (fixedCats > 0) _plural(context, fixedCats, '1 category corrected', '{n} categories corrected'),
      if (i['link'] == 'inferred') context.tr(kInferredLink),
      if (i['source'] == 'social_only') context.tr('Social media only'),
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
      title: '${context.tr('${i['category']}')} · ${place.isEmpty ? context.tr('Ward {w}', {'w': i['ward_code']}) : place}',
      caption: [
        [if (n > 0) _plural(context, n, '1 report', '{n} reports'), if (p > 0) _plural(context, p, '1 post', '{n} posts')].join(' + '),
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
      title: d == null
          ? context.tr('Issue {id}', {'id': widget.id})
          : '${context.tr('${d['category']}')} · ${place.isEmpty ? context.tr('Ward {w}', {'w': d['ward_code']}) : place}',
      caption: d == null
          ? null
          : '${d['id']} · ${context.tr('Ward {w}', {'w': d['ward_code']})} · '
                '${context.tr('{a} to {b}', {'a': _day(d['first_seen']), 'b': _day(d['last_seen'])})}',
      onRefresh: () => ref.refresh(issueProvider(widget.id).future),
      children: [
        if (d != null)
          ..._body(context, d)
        else if (v.error case ApiException(status: 404))
          EmptyState(pictogram: PictogramKind.track, message: context.tr('No issue with id {id}.', {'id': widget.id}))
        else if (v.hasError)
          ErrorState(message: '${context.tr('Could not load this issue.')}\n${v.error}', onRetry: () => ref.invalidate(issueProvider(widget.id)))
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
          title: context.tr('+{n} same report', {'n': folded.length}),
          meta: context.tr('Closed by BMC as duplicates of the first report.'),
          state: TimelineNodeState.pending,
          child: TextButton(style: link, onPressed: () => setState(() => _showAll = true), child: Text(context.tr('Show them'))),
        ),
      for (final p in posts)
        TimelineStep(
          title: context.tr('Social post · reach {n}', {'n': formatCount(p['reach'] as num? ?? 0)}),
          meta: _day(p['posted_at']),
          chip: StatusChip(p['source'] == null ? context.tr('Social post') : '${p['source']}'),
          child: Text('“${p['text'] ?? ''}”', style: t.body),
        ),
      if (wos.isEmpty)
        TimelineStep(
          title: context.tr('No work order found'),
          state: TimelineNodeState.pending,
          meta: context.tr(
            d['source'] == 'social_only'
                ? 'These posts matched no complaint in BMC’s system and no repair job.'
                : 'No repair job is recorded for these complaints, and none matched by road, type and date.',
          ),
        ),
      for (final wo in wos)
        TimelineStep(
          title: context.tr('Work order {id}', {'id': wo['id']}),
          amount: formatInr(wo['cost_inr'] as num? ?? 0),
          meta: '${context.tr('${wo['method']}')} · ${_plain(wo['contractor_name'])}\n'
              '${context.tr('Assigned {a}, completed {b}', {'a': _day(wo['assigned_at']), 'b': _day(wo['completed_at'])})}'
              '${wo['under_dlp'] == 'Y' ? '\n${context.tr('Road under warranty')}' : ''}',
          chip: inferred ? inferredTag(context) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inferred && ev != null)
                Text(
                  context.tr('Our best match, not BMC’s record: same road and repair type, assigned {when}{nearest}.', {
                    'when': _hours(context, ev['hours_after_first_report'] as num?),
                    'nearest': (ev['candidates'] as num? ?? 1) > 1 ? context.tr(', nearest in time of {n} jobs', {'n': ev['candidates']}) : '',
                  }),
                  style: t.caption,
                ),
              TextButton.icon(
                style: link,
                onPressed: () => openRoad(wo['road_id'] as String, wo: wo['id'] as String),
                icon: const Icon(Icons.alt_route, size: AppSpacing.iconSmall),
                label: Text(context.tr('Open road: {name}', {'name': wo['road_name']})),
              ),
            ],
          ),
        ),
      TimelineStep(
        title: context.tr(outcomeLabels[d['outcome']] ?? '${d['outcome']}'),
        state: TimelineNodeState.outcome,
        color: outcomeColor(c, d['outcome'] as String?),
        meta: switch (d['outcome']) {
          'fixed_held' => d['days_to_fix'] == null
              ? context.tr('Not reported again within 30 days of the repair.')
              : context.tr('Not reported again within 30 days of the repair (fixed {n} days after the first report).', {'n': d['days_to_fix']}),
          'fixed_failed' => context.tr('Reported again within 30 days of the repair: needs review.'),
          'in_progress' => context.tr('BMC marked a complaint In Progress; no work order is recorded yet.'),
          _ => context.tr('No repair is recorded for this issue.'),
        },
      ),
    ];
    final summary = [
      if (complaints.isNotEmpty) _plural(context, complaints.length, '1 complaint', '{n} complaints'),
      if ((d['channels'] as List? ?? const []).isNotEmpty)
        context.tr('via {channels}', {'channels': (d['channels'] as List).map((ch) => context.tr('$ch')).join(', ')}),
      if (posts.isNotEmpty) _plural(context, posts.length, '1 social post', '{n} social posts'),
    ].join(' · ');
    return [
      Gutter(
        child: Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            outcomeTag(context, d['outcome'] as String?),
            if (inferred) inferredTag(context),
            if (d['source'] == 'social_only') StatusChip(context.tr('Social media only')),
          ],
        ),
      ),
      if (summary.isNotEmpty) ...[const SizedBox(height: AppSpacing.s12), Gutter(child: Text(summary, style: t.body))],
      if (d['source'] == 'social_only') Gutter(child: Text(context.tr('No matching complaint in BMC’s system.'), style: t.caption)),
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
                    [
                      context.tr('An inferred link is our best match by road, repair type and date, not a link recorded by BMC.'),
                      if (accuracy != null)
                        context.tr('Tested blind on recorded links, such matches were right {p} of the time.', {'p': formatPercent(accuracy)}),
                    ].join(' '),
                    style: t.body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      const SectionBreak(),
      Gutter(child: SectionHeading(context.tr('Timeline'))),
      Gutter(child: Timeline(steps: steps)),
    ];
  }

  TimelineStep _complaintStep(BuildContext context, Json x, ButtonStyle link) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final corrected = x['category_corrected'] == true;
    return TimelineStep(
      title: '${context.tr('Complaint {id}', {'id': x['id']})}${x['channel'] == null ? '' : ' · ${context.tr('${x['channel']}')}'}',
      meta: '${_day(x['received_at'])} · ${context.tr('${x['status']}')}'
          '${(x['upvotes'] as num? ?? 0) > 0 ? ' · ${context.tr('{n} upvotes', {'n': x['upvotes']})}' : ''}',
      chip: corrected
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
              decoration: BoxDecoration(color: c.infoTint, borderRadius: AppRadii.controlRadius),
              child: Text(
                context.tr('Reported as {a} → corrected to {b}', {
                  'a': context.tr('${x['category_reported']}'),
                  'b': context.tr('${x['category_clean']}'),
                }),
                style: t.label.copyWith(color: c.info),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('“${x['description']}”', style: t.body),
          if (corrected && x['category_reason'] != null)
            Text(context.tr('Why: {r}', {'r': _why(context, x['category_reason'])}), style: t.caption)
          else if (!corrected)
            Text(context.tr('Category: {c}', {'c': context.tr('${x['category_clean']}')}), style: t.caption),
          TextButton(style: link, onPressed: () => pushComplaint(context, x['id'] as String), child: Text(context.tr('Open complaint'))),
        ],
      ),
    );
  }
}
