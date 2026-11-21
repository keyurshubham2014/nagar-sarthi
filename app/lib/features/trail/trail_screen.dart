import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../citizen/citizen_panels.dart';
import '../officer/officer_data.dart';
import '../officer/officer_panels.dart';
import '../officer/panel.dart';

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

String _hours(num? h) => h == null
    ? 'close to the first report'
    : h < 0
    ? '${(-h).round()} hours before the first report'
    : '${h.round()} hours after the first report';
String _day(Object? s) => '${s ?? '—'}'.split(' ').first;
String _plain(Object? name) => '${name ?? '—'}'.replaceAll(' (synthetic)', '');

Widget outcomeTag(BuildContext context, String? o) {
  final c = SaartheeColors.of(context);
  final col = outcomeColor(c, o);
  return Tag(outcomeLabels[o] ?? '$o', bg: col.withValues(alpha: 0.12), fg: col);
}

Widget inferredTag(BuildContext context) {
  final c = SaartheeColors.of(context);
  return Tag(kInferredLink, bg: c.warningTint, fg: c.warning, icon: Icons.link);
}

// ---------------------------------------------------------------- list page

/// Funnel header, outcome chips, search and the issue list for one ward or all Mumbai.
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
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final header = <Widget>[
      if (widget.ward != null)
        Wrap(
          spacing: AppSpacing.s8,
          children: [
            ChoiceChip(label: Text('Ward ${widget.ward}'), selected: !_allMumbai, onSelected: (_) => _set(() => _allMumbai = false)),
            ChoiceChip(label: const Text('All Mumbai'), selected: _allMumbai, onSelected: (_) => _set(() => _allMumbai = true)),
          ],
        ),
      const SizedBox(height: AppSpacing.s8),
      _Funnel(ward: _ward ?? ''),
      const SectionTitle('Issues'),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (k, label) in [
              (null, 'All'),
              ...outcomeLabels.entries.map((e) => (e.key, e.value)),
              ('social_only', 'Social posts only'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.s8),
                child: ChoiceChip(
                  avatar: k == null || k == 'social_only' ? null : CircleAvatar(backgroundColor: outcomeColor(c, k), radius: 5),
                  label: Text(label),
                  selected: _outcome == k,
                  onSelected: (_) => _set(() => _outcome = k),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.s12),
      TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Place, road or any id',
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close), onPressed: () => _set(_search.clear)),
        ),
        onChanged: (_) {
          setState(() {});
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 350), () => _load(reset: true));
        },
        onSubmitted: (_) => _load(reset: true),
      ),
      const SizedBox(height: AppSpacing.s12),
      Text(_total == 1 ? '1 issue' : '${formatCount(_total)} issues', style: t.titleMedium),
      Text('Most reported first.', style: t.bodySmall),
      const SizedBox(height: AppSpacing.s8),
    ];
    final footer = <Widget>[
      if (_error != null)
        Card(
          color: c.errorTint,
          child: ListTile(
            leading: Icon(Icons.error_outline, color: c.error),
            title: Text('Could not load issues. $_error'),
            trailing: TextButton(onPressed: () => _load(reset: _items.isEmpty), child: const Text('Retry')),
          ),
        )
      else if (_loading)
        const Padding(padding: EdgeInsets.all(AppSpacing.s16), child: Center(child: CircularProgressIndicator()))
      else if (_items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.s32),
          child: Text('No issues match these filters.', textAlign: TextAlign.center),
        )
      else if (_items.length < _total)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
          child: OutlinedButton(
            onPressed: () => _load(reset: false),
            child: Text('Load more (${_items.length} of ${formatCount(_total)} shown)'),
          ),
        ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.max(AppSpacing.gutter, (box.maxWidth - AppSpacing.maxContent) / 2 + AppSpacing.gutter);
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(side, AppSpacing.s16, side, AppSpacing.s32),
          itemCount: header.length + _items.length + footer.length,
          itemBuilder: (context, i) {
            if (i < header.length) return header[i];
            i -= header.length;
            if (i < _items.length) return IssueRow(_items[i] as Json);
            return footer[i - _items.length];
          },
        );
      },
    );
  }
}

/// Raw complaints -> set aside -> issues -> work orders -> outcomes, with the "How we link" note.
class _Funnel extends ConsumerWidget {
  const _Funnel({required this.ward});
  final String ward;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    return switch (ref.watch(linkerProvider(ward))) {
      AsyncData(:final value) => Builder(
        builder: (context) {
          final l = value;
          final raw = l['raw_complaints'] as int;
          final issues = l['issues'] as int;
          final links = l['links'] as Map;
          final by = l['issues_by_outcome'] as Map;
          final social = l['social_only_issues'] as int;
          Widget bar(String label, int v, int max, {Color? color, num? inr}) => LabelledBar(
            label: label,
            value: v,
            max: max,
            trailing: inr == null || inr == 0 ? formatCount(v) : '${formatCount(v)} · ${formatInr(inr)}',
            color: color,
          );
          return Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: AppElevation.cardDecoration(c),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ward.isEmpty ? 'All Mumbai' : 'Ward $ward', style: t.labelMedium?.copyWith(color: c.primary)),
                Text('${formatCount(raw)} complaints became ${formatCount(issues)} issues', style: t.titleMedium),
                const SizedBox(height: AppSpacing.s8),
                bar('Complaints received', raw, raw),
                bar('Not about roads (street lights, garbage, tests)', l['noise'] as int, raw, color: c.textSecondary),
                bar('Not BMC’s road (MMRDA, PWD)', l['out_of_scope'] as int, raw, color: c.textSecondary),
                bar('Kept and grouped into issues', l['in_issues'] as int, raw),
                const SizedBox(height: AppSpacing.s12),
                bar('Issues (${formatCount(social)} from social posts only)', issues, issues, color: c.info),
                bar('Reached a work order (${formatCount(links['inferred'] as int)} inferred)', l['with_work_order'] as int, issues, color: c.info),
                for (final o in outcomeLabels.keys)
                  bar(outcomeLabels[o]!, (by[o] as Map)['count'] as int, issues, color: outcomeColor(c, o), inr: (by[o] as Map)['inr'] as num?),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  '${formatPercent(l['categories_corrected_share'] as num)} of complaints had their category corrected '
                  '(${formatCount(l['categories_corrected'] as int)} of ${formatCount(raw)}).',
                  style: t.bodyMedium,
                ),
                Text('Rupees count recorded links only.', style: t.bodySmall?.copyWith(color: c.textSecondary)),
                const SizedBox(height: AppSpacing.s4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => pushPanel(PanelPage('How we link', HowWeLink(l))),
                    icon: const Icon(Icons.info_outline),
                    label: const Text('How we link, and how often it is right'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      AsyncError(:final error) => ListTile(
        title: Text('Could not load the funnel. $error'),
        trailing: TextButton(onPressed: () => ref.invalidate(linkerProvider(ward)), child: const Text('Retry')),
      ),
      _ => const LinearProgressIndicator(),
    };
  }
}

/// The engine's method lines and its measured accuracy, worded plainly.
class HowWeLink extends StatelessWidget {
  const HowWeLink(this.l, {super.key});
  final Json l;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = SaartheeColors.of(context);
    final v = (l['validation'] as Map?) ?? const {};
    final cat = (v['category'] as Map?) ?? const {};
    final grp = ((v['grouping'] as Map?)?['without_work_order_rule'] as Map?) ?? const {};
    final inf = (v['inferred_link_rule_on_recorded_issues'] as Map?) ?? const {};
    Widget bullet(String s) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('•  '), Expanded(child: Text(s))]),
    );
    return PanelList(
      children: [
        for (final m in (l['method'] as List? ?? const [])) bullet('$m'),
        const SectionTitle('How often it is right'),
        bullet('Category: the category people picked matched the repair BMC actually did ${formatPercent(cat['reported_vs_work_type'] as num? ?? 0)} '
            'of the time; after our correction, ${formatPercent(cat['clean_vs_work_type'] as num? ?? 0)}.'),
        bullet('Grouping: tested blind against BMC’s own links, our rules put the right complaints together '
            '${formatPercent(grp['precision'] as num? ?? 0)} of the time and found ${formatPercent(grp['recall'] as num? ?? 0)} of the true pairs. '
            'So complaints BMC linked are grouped by BMC’s work order; the rules only group the ones BMC never linked.'),
        bullet('Inferred links: tested blind on issues with a recorded link, our best match picked BMC’s own work order '
            '${formatPercent(inf['accuracy_when_matched'] as num? ?? 0)} of the time. About 1 in '
            '${((1 / (1 - ((inf['accuracy_when_matched'] as num?) ?? 0.8))).round())} inferred links may be wrong, so each is marked “$kInferredLink”.'),
        const SizedBox(height: AppSpacing.s8),
        Text('Synthetic data. Not BMC data. Contractors are fictional.', style: t.bodySmall?.copyWith(color: c.textSecondary)),
      ],
    );
  }
}

/// One issue in the list: what and where, counts, work order and outcome.
class IssueRow extends StatelessWidget {
  const IssueRow(this.i, {super.key});
  final Json i;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final n = i['complaint_count'] as int? ?? 0;
    final p = i['social_post_count'] as int? ?? 0;
    final fixedCats = i['corrected_categories'] as int? ?? 0;
    final wos = (i['work_order_ids'] as List?) ?? const [];
    final place = [i['road_name'], i['locality']].whereType<String>().toSet().join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius, side: BorderSide(color: c.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openIssue(i['id'] as String),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i['category']} · ${place.isEmpty ? 'Ward ${i['ward_code']}' : place}', style: t.titleMedium),
                Text(
                  [
                    '${i['id']} · Ward ${i['ward_code']}',
                    if (n > 0) n == 1 ? '1 complaint' : '$n complaints',
                    if (p > 0) p == 1 ? '1 post' : '$p posts',
                    if (fixedCats > 0) '$fixedCats corrected',
                  ].join(' · '),
                  style: t.bodySmall,
                ),
                if (wos.isNotEmpty)
                  Text('${wos.join(', ')} · ${formatInr(i['cost_inr'] as num? ?? 0)} · ${_plain(i['contractor_name'])}',
                      style: t.bodySmall?.copyWith(color: c.textSecondary)),
                const SizedBox(height: AppSpacing.s8),
                Wrap(
                  spacing: AppSpacing.s4,
                  runSpacing: AppSpacing.s4,
                  children: [
                    outcomeTag(context, i['outcome'] as String?),
                    if (i['link'] == 'inferred') inferredTag(context),
                    if (i['source'] == 'social_only') Tag('Social posts only', bg: c.surfaceAlt, fg: c.textSecondary, icon: Icons.forum_outlined),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
    if (v case AsyncError(:final error) when error is ApiException && error.status == 404) {
      return PanelMessage.empty('No issue with id ${widget.id}.', icon: Icons.search_off);
    }
    return asyncPage(v, onRetry: () => ref.invalidate(issueProvider(widget.id)), data: (d) => _body(context, d));
  }

  Widget _body(BuildContext context, Json d) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
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
    final place = [d['road_name'], d['locality']].whereType<String>().toSet().join(', ');
    final steps = <Widget>[
      for (final x in shown) _complaintStep(context, x),
      if (folded.isNotEmpty)
        TimelineStep(
          icon: Icons.layers_outlined,
          color: c.textSecondary,
          title: '${folded.length} more ${folded.length == 1 ? 'report' : 'reports'} of the same problem',
          sub: 'Closed by BMC as duplicates of the first report.',
          action: TextButton(onPressed: () => setState(() => _showAll = true), child: const Text('Show them')),
        ),
      for (final p in posts)
        TimelineStep(
          icon: Icons.forum_outlined,
          color: c.info,
          title: '${p['source'] ?? 'Social post'} · reach ${formatCount(p['reach'] as num? ?? 0)}',
          sub: '${_day(p['posted_at'])}\n“${p['text'] ?? ''}”',
        ),
      if (wos.isEmpty)
        TimelineStep(
          icon: Icons.hourglass_empty,
          color: c.warning,
          title: 'No work order found',
          sub: d['source'] == 'social_only'
              ? 'These posts matched no complaint in BMC’s system and no repair job.'
              : 'No repair job is recorded for these complaints, and none matched by road, type and date.',
        ),
      for (final wo in wos)
        TimelineStep(
          icon: Icons.assignment_outlined,
          color: c.primary,
          title: 'Work order ${wo['id']}',
          sub: '${wo['method']} · ${formatInr(wo['cost_inr'] as num? ?? 0)}\n${_plain(wo['contractor_name'])}\n'
              'Assigned ${_day(wo['assigned_at'])}, completed ${_day(wo['completed_at'])}'
              '${wo['under_dlp'] == 'Y' ? '\nRoad under warranty' : ''}',
          action: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inferred) ...[
                const SizedBox(height: AppSpacing.s4),
                inferredTag(context),
                if (ev != null)
                  Text(
                    'Our best match, not BMC’s record: same road and repair type, assigned ${_hours(ev['hours_after_first_report'] as num?)}'
                    '${(ev['candidates'] as num? ?? 1) > 1 ? ', nearest in time of ${ev['candidates']} jobs' : ''}.',
                    style: t.bodySmall?.copyWith(color: c.textSecondary),
                  ),
              ],
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => openRoad(wo['road_id'] as String, wo: wo['id'] as String),
                icon: const Icon(Icons.alt_route),
                label: Text('Open road: ${wo['road_name']}'),
              ),
            ],
          ),
        ),
      TimelineStep(
        icon: switch (d['outcome']) {
          'fixed_held' => Icons.verified_outlined,
          'fixed_failed' => Icons.report_problem_outlined,
          'in_progress' => Icons.construction,
          _ => Icons.hourglass_empty,
        },
        color: outcomeColor(c, d['outcome'] as String?),
        title: outcomeLabels[d['outcome']] ?? '${d['outcome']}',
        sub: switch (d['outcome']) {
          'fixed_held' => 'Not reported again within 30 days of the repair${d['days_to_fix'] == null ? '' : ' (fixed ${d['days_to_fix']} days after the first report)'}.',
          'fixed_failed' => 'Reported again within 30 days of the repair: needs review.',
          'in_progress' => 'BMC marked a complaint In Progress; no work order is recorded yet.',
          _ => 'No repair is recorded for this issue.',
        },
        last: true,
      ),
    ];
    return PanelList(
      children: [
        Text('${d['category']} · ${place.isEmpty ? 'Ward ${d['ward_code']}' : place}', style: t.titleLarge),
        Text('${d['id']} · Ward ${d['ward_code']} · ${_day(d['first_seen'])} to ${_day(d['last_seen'])}', style: t.bodySmall),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s4,
          runSpacing: AppSpacing.s4,
          children: [
            outcomeTag(context, d['outcome'] as String?),
            if (inferred) inferredTag(context),
            if (d['source'] == 'social_only') Tag('Social posts only: no matching complaint in BMC’s system', bg: c.surfaceAlt, fg: c.textSecondary, icon: Icons.forum_outlined),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          [
            if (complaints.isNotEmpty) '${complaints.length} ${complaints.length == 1 ? 'complaint' : 'complaints'}',
            if ((d['channels'] as List? ?? const []).isNotEmpty) 'via ${(d['channels'] as List).join(', ')}',
            if (posts.isNotEmpty) '${posts.length} social ${posts.length == 1 ? 'post' : 'posts'}',
          ].join(' · '),
          style: t.bodyMedium,
        ),
        const SectionTitle('The trail'),
        ...steps,
        if (inferred)
          Text('An inferred link is our best match by road, repair type and date, not a link recorded by BMC.'
              '${accuracy == null ? '' : ' Tested blind on recorded links, such matches were right ${formatPercent(accuracy)} of the time.'}',
              style: t.bodySmall?.copyWith(color: c.textSecondary)),
      ],
    );
  }

  Widget _complaintStep(BuildContext context, Json x) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final corrected = x['category_corrected'] == true;
    return TimelineStep(
      icon: Icons.inbox_outlined,
      color: c.info,
      title: 'Complaint ${x['id']}${x['channel'] == null ? '' : ' · ${x['channel']}'}',
      sub: '${_day(x['received_at'])} · ${x['status']}${(x['upvotes'] as num? ?? 0) > 0 ? ' · ${x['upvotes']} upvotes' : ''}\n“${x['description']}”',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.s4),
          if (corrected)
            Tag('Reported as ${x['category_reported']} → corrected to ${x['category_clean']}', bg: c.infoTint, fg: c.info, icon: Icons.edit_outlined)
          else
            Text('Category: ${x['category_clean']}', style: t.bodySmall?.copyWith(color: c.textSecondary)),
          if (corrected && x['category_reason'] != null)
            Text('Why: ${x['category_reason']}', style: t.bodySmall?.copyWith(color: c.textSecondary)),
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, AppSpacing.touchTarget)),
            onPressed: () => pushComplaint(context, x['id'] as String),
            child: const Text('Open complaint'),
          ),
        ],
      ),
    );
  }
}
