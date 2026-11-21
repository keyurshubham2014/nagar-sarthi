import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../core/api/api_client.dart';
import '../../core/prefs.dart';
import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/widgets/claude_draft_sheet.dart';
import '../../core/widgets/ui.dart';
import '../officer/officer_data.dart' show Json;
import '../audit/audit_screen.dart' show AuditList;
import '../officer/officer_panels.dart' show openRoad;
import '../officer/panel.dart' show DetailTitle, PanelPage, pushPanel;

// Corporator flow: fair contractor scorecards and the ward brief. Every figure
// comes from the server as the audit engine produced it; nothing is ranked here.

Duration? _noRetry(int _, Object _) => null;

final scorecardsProvider = FutureProvider.family<Json, String?>(
  retry: _noRetry,
  (ref, ward) => ref.watch(apiClientProvider).scorecards(ward: ward),
);

final contractorWardsProvider = FutureProvider.family<Json, String>(
  retry: _noRetry,
  (ref, id) => ref.watch(apiClientProvider).contractorWards(id),
);

typedef MeasureQuery = ({String id, String metric, String? ward});

final measureWorkOrdersProvider = FutureProvider.family<Json, MeasureQuery>(
  retry: _noRetry,
  (ref, q) => ref.watch(apiClientProvider).contractorWorkOrders(q.id, q.metric, ward: q.ward),
);

/// One-page ward brief in English, Hindi or Marathi; the server picks the figures.
void showWardBrief(BuildContext context, String code) => showClaudeDraftSheet(
  context,
  title: '${context.tr(kWardBrief)} · ${context.tr('Ward {w}', {'w': code})}',
  feature: 'brief',
  // The brief starts in the app language; the sheet's switch redrafts it in another.
  body: {'ward_code': code, 'language': briefLanguages.containsKey(context.lang) ? context.lang : 'en'},
  languages: briefLanguages,
  textLabel: context.tr('Ward brief (editable)'),
);

String _plainName(Object? n) => '${n ?? ''}'.replaceAll(' (synthetic)', '');

String _initials(String name) =>
    name.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

void _openScorecard(String id, String? ward) =>
    appRouter.push(Uri(path: '/contractor', queryParameters: {'id': id, 'ward': ?ward}).toString());

void _openMeasure(BuildContext context, String id, String metric, String? ward) {
  final def = scorecardMeasures[metric]!;
  final where = ward == null ? context.tr('Mumbai') : context.tr('Ward {w}', {'w': ward});
  pushPanel(PanelPage('${context.tr(def.listed)} · $where', MeasureWorkOrders(q: (id: id, metric: metric, ward: ward))));
}

/// Contractors A to Z with three like-for-like measures; [ward] scopes to one ward.
/// A scrolling page body (used inside a detail page).
class ScorecardList extends ConsumerWidget {
  const ScorecardList({super.key, this.ward, this.header});
  final String? ward;
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSpacing.maxContent),
      child: ListView(
        primary: true,
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.s32),
        children: [
          const DetailTitle(),
          if (header != null) Gutter(child: header!),
          _ScorecardBody(
            v: ref.watch(scorecardsProvider(ward)),
            ward: ward,
            onRetry: () => ref.invalidate(scorecardsProvider(ward)),
          ),
        ],
      ),
    ),
  );
}

/// Loading, error, empty or the A–Z rows (filtered by [query]); not scrollable itself.
class _ScorecardBody extends StatelessWidget {
  const _ScorecardBody({required this.v, required this.ward, required this.onRetry, this.query = ''});
  final AsyncValue<Json> v;
  final String? ward;
  final VoidCallback onRetry;
  final String query;

  @override
  Widget build(BuildContext context) {
    final t = AppTypeScale.of(context);
    final d = v.value;
    if (d == null) {
      return v.hasError ? ErrorState(message: context.tr('Could not load contractors.'), onRetry: onRetry) : Skeleton.rows(count: 7);
    }
    final all = [...?(d['contractors'] as List?)].cast<Json>();
    if (all.isEmpty) {
      return EmptyState(
        pictogram: PictogramKind.contractors,
        message: ward == null ? context.tr('No contractors in the audit.') : context.tr('No contractor worked in Ward {w}.', {'w': ward}),
      );
    }
    final q = query.trim().toLowerCase();
    final rows = q.isEmpty ? all : all.where((r) => _plainName(r['name']).toLowerCase().contains(q)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gutter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s4),
            child: Text(
              context.tr('A to Z · not a ranking. Bars: finished on time, re-opened within 30 days, billed above rate.'),
              style: t.caption,
            ),
          ),
        ),
        if (rows.isEmpty)
          EmptyState(pictogram: PictogramKind.contractors, message: context.tr('No contractor matches “{q}”.', {'q': query.trim()})),
        for (final (i, r) in rows.indexed)
          StaggeredEntrance(
            index: i,
            child: _ContractorRow(row: r, ward: ward, divider: i < rows.length - 1),
          ),
      ],
    );
  }
}

/// One contractor in the A–Z list: initials, name, jobs and spend (or "not rated"),
/// three small bars; opens the scorecard page.
class _ContractorRow extends StatelessWidget {
  const _ContractorRow({required this.row, required this.ward, required this.divider});
  final Json row;
  final String? ward;
  final bool divider;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final rated = row['rated'] == true;
    final spend = row['spend'] as num?;
    final name = _plainName(row['name']);
    final measures = (row['measures'] as Map?) ?? const {};
    return ListRow(
      initials: _initials(name),
      title: name,
      caption: rated
          ? '${context.tr('{n} jobs', {'n': row['jobs']})}${spend == null ? '' : ' · ${formatInr(spend)}'} · ${context.tr('synthetic')}'
          : '${context.tr(kNotRatedInWard)} · ${context.tr('synthetic')}',
      divider: divider,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rated) _MiniBars(measures),
          const SizedBox(width: AppSpacing.s4),
          Icon(Icons.chevron_right, color: c.textSecondary, size: 22),
        ],
      ),
      onTap: () => _openScorecard('${row['id']}', ward),
    );
  }
}

/// Speed, durability and pricing as three slim bars (the contractor's own share).
class _MiniBars extends StatelessWidget {
  const _MiniBars(this.measures);
  final Map measures;
  @override
  Widget build(BuildContext context) {
    num v(String k) => (measures[k] as Map?)?['value'] as num? ?? 0;
    return Semantics(
      label: context.tr('Finished on time {a}, re-opened {b}, above rate {c}', {
        'a': formatPercent(v('speed')),
        'b': formatPercent(v('durability')),
        'c': formatPercent(v('pricing')),
      }),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, k) in scorecardMeasures.keys.indexed) ...[
              if (i > 0) const SizedBox(height: AppSpacing.s4),
              ScorecardBar(fraction: v(k).toDouble(), height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

/// Contractors tab: the A–Z scorecard list for all Mumbai or the chosen ward.
class ContractorsScreen extends ConsumerStatefulWidget {
  const ContractorsScreen({super.key});
  @override
  ConsumerState<ContractorsScreen> createState() => _ContractorsScreenState();
}

class _ContractorsScreenState extends ConsumerState<ContractorsScreen> {
  bool _inWard = false;
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final ward = ref.watch(chosenWardProvider);
    final scope = _inWard ? ward : null;
    return LargeTitleScaffold(
      title: context.tr('Contractors'),
      caption: context.tr('Fictional names. Compared like for like.'),
      onRefresh: () => ref.refresh(scorecardsProvider(scope).future),
      children: [
        Gutter(
          child: SegmentedControl<bool>(
            segments: [(false, context.tr('All Mumbai')), (true, context.tr('Ward {w}', {'w': ward}))],
            value: _inWard,
            onChanged: (v) => setState(() => _inWard = v),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Gutter(child: SearchField(hint: context.tr('Search contractors'), onChanged: (s) => setState(() => _query = s))),
        const SizedBox(height: AppSpacing.s8),
        AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.standard),
          child: KeyedSubtree(
            key: ValueKey(scope),
            child: _ScorecardBody(
              v: ref.watch(scorecardsProvider(scope)),
              ward: scope,
              query: _query,
              onRetry: () => ref.invalidate(scorecardsProvider(scope)),
            ),
          ),
        ),
      ],
    );
  }
}

/// One contractor's scorecard as a page (from the list, Home or a ward).
class ContractorPage extends ConsumerWidget {
  const ContractorPage({super.key, required this.id, this.ward});
  final String id;
  final String? ward;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(scorecardsProvider(ward));
    final row = [...?(v.value?['contractors'] as List?)].cast<Json>().where((r) => r['id'] == id).firstOrNull;
    final where = ward == null ? context.tr('Across Mumbai') : context.tr('In Ward {w}', {'w': ward});
    final rated = row?['rated'] == true;
    final spend = row?['spend'] as num?;
    return LargeTitleScaffold(
      title: row == null ? context.tr(kScorecardsTitle) : _plainName(row['name']),
      caption: row == null
          ? where
          : rated
          ? '${context.tr('Synthetic contractor')} · ${context.tr('{n} jobs', {'n': row['jobs']})}'
                '${spend == null ? '' : ' · ${formatInr(spend)}'} · $where'
          : '${context.tr('Synthetic contractor')} · $where',
      onRefresh: () => ref.refresh(scorecardsProvider(ward).future),
      children: [
        if (v.value == null && v.hasError)
          ErrorState(message: context.tr('Could not load this scorecard.'), onRetry: () => ref.invalidate(scorecardsProvider(ward)))
        else if (v.value == null)
          Gutter(
            child: Skeleton(
              child: Column(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    const SkeletonBox(height: 180, radius: AppRadii.card),
                    const SizedBox(height: AppSpacing.s12),
                  ],
                ],
              ),
            ),
          )
        else if (row == null)
          EmptyState(pictogram: PictogramKind.contractors, message: context.tr('No scorecard for this contractor here.'))
        else
          ..._scorecard(context, ref, row),
      ],
    );
  }

  List<Widget> _scorecard(BuildContext context, WidgetRef ref, Json row) {
    final c = SaartheeColors.of(context);
    final rated = row['rated'] == true;
    final measures = (row['measures'] as Map?) ?? const {};
    final jobs = row['jobs'] as num? ?? 0;
    final chosen = ref.watch(chosenWardProvider);
    final keys = scorecardMeasures.keys.where((k) => measures[k] is Map).toList();
    return [
      const SizedBox(height: AppSpacing.s8),
      Gutter(
        child: CollapsiblePanel(
          title: context.tr(kFairnessTitle),
          icon: Icons.balance,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in kFairnessPoints)
                Padding(padding: const EdgeInsets.only(top: AppSpacing.s4), child: Text('•  ${context.tr(p)}')),
            ],
          ),
        ),
      ),
      if (!rated) ...[
        const SizedBox(height: AppSpacing.s16),
        // Not rated: show only the reason, no figures at all.
        Gutter(
          child: _TintPanel(
            icon: Icons.info_outline,
            label: context.tr(kNotRatedInWard),
            text: '${notRatedReason(context, row['reason_if_not_rated'])}\n${context.tr('Too few jobs to compare fairly, so no figures are shown.')}',
            fg: c.textSecondary,
            bg: c.surfaceAlt,
          ),
        ),
      ] else ...[
        Gutter(child: SectionHeading(context.tr('How it compares'))),
        for (final (i, k) in keys.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: Gutter(
              child: StaggeredEntrance(
                index: i,
                child: _MetricCard(id: row['id'] as String, metric: k, m: measures[k] as Map, jobs: jobs, ward: ward),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.s4),
        Gutter(
          child: _TintPanel(
            icon: Icons.thumb_up_alt_outlined,
            label: ward != null ? context.tr('Doing well (across Mumbai)') : context.tr(kDoingWell),
            text: scorecardSentence(context, row['strength']),
            fg: c.success,
            bg: c.successTint,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Gutter(
          child: _TintPanel(
            icon: Icons.flag_outlined,
            label: ward != null ? context.tr('To look at (across Mumbai)') : context.tr(kToLookAt),
            text: scorecardSentence(context, row['improve']),
            fg: c.warning,
            bg: c.warningTint,
          ),
        ),
      ],
      const SectionBreak(),
      Gutter(child: SectionHeading(context.tr('By ward'))),
      if (ward != null)
        ListRow(
          icon: Icons.public,
          title: context.tr('Across Mumbai'),
          caption: context.tr('The same measures, all wards together'),
          onTap: () => _openScorecard(row['id'] as String, null),
        ),
      _ByWard(id: row['id'] as String, ward: ward),
      if (rated) ...[
        Gutter(child: SectionHeading(context.tr('Work orders'))),
        ListRow(
          icon: Icons.fact_check_outlined,
          title: context.tr('See this contractor’s flagged work orders'),
          caption: ward == null ? context.tr('In Audit, across Mumbai') : context.tr('In Audit, Ward {w}', {'w': ward}),
          onTap: () => pushPanel(PanelPage(
            '${_plainName(row['name'])} · ${context.tr('flagged')}',
            AuditList(ward: ward ?? chosen, contractor: row['id'] as String, startAllMumbai: ward == null),
          )),
        ),
        for (final (i, k) in keys.indexed)
          ListRow(
            icon: Icons.assignment_outlined,
            title: context.tr(scorecardMeasures[k]!.listed),
            caption: '${context.tr('{n} of {jobs} jobs', {'n': (measures[k] as Map)['count'] ?? 0, 'jobs': jobs})} · ${context.tr(kNeedsReview)}',
            divider: i < keys.length - 1,
            onTap: () => _openMeasure(context, row['id'] as String, k, ward),
          ),
      ],
    ];
  }
}

/// Every ward the contractor worked in: jobs, spend and the three measures; below the
/// minimum jobs a ward is not rated (fairness rule). A row opens that ward's scorecard.
class _ByWard extends ConsumerWidget {
  const _ByWard({required this.id, required this.ward});
  final String id;
  final String? ward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTypeScale.of(context);
    final v = ref.watch(contractorWardsProvider(id));
    final d = v.value;
    if (d == null) {
      return v.hasError
          ? ErrorState(message: context.tr('Could not load the wards.'), onRetry: () => ref.invalidate(contractorWardsProvider(id)))
          : Skeleton.rows(count: 4);
    }
    final rows = [...?(d['wards'] as List?)].cast<Json>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gutter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s4),
            child: Text(
              context.tr('On time · re-opened within 30 days · billed above rate. Rated only with {n} or more jobs in a ward.', {'n': d['min_jobs']}),
              style: t.caption,
            ),
          ),
        ),
        for (final (i, w) in rows.indexed)
          () {
            final m = (w['measures'] as Map?) ?? const {};
            num share(String k) => (m[k] as Map?)?['value'] as num? ?? 0;
            final spend = w['spend'] as num?;
            final here = w['code'] == ward;
            return ListRow(
              initials: '${w['code']}',
              title: '${w['name']}',
              titleMaxLines: 1,
              caption: '${context.tr('{n} jobs', {'n': w['jobs']})}${spend == null ? '' : ' · ${formatInr(spend)}'}',
              chip: w['rated'] == true
                  ? Text(
                      context.tr('{a} on time · {b} re-opened · {c} above rate', {
                        'a': formatPercent(share('speed')),
                        'b': formatPercent(share('durability')),
                        'c': formatPercent(share('pricing')),
                      }),
                      style: t.caption,
                    )
                  : StatusChip(context.tr('Too few jobs to rate ({n})', {'n': w['jobs']})),
              trailing: here
                  ? StatusChip(context.tr('Shown'), tone: StatusTone.info)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (w['rated'] == true) _MiniBars(m),
                        const SizedBox(width: AppSpacing.s4),
                        Icon(Icons.chevron_right, color: SaartheeColors.of(context).textSecondary, size: 22),
                      ],
                    ),
              divider: i < rows.length - 1,
              onTap: here ? null : () => _openScorecard(id, '${w['code']}'),
            );
          }(),
      ],
    );
  }
}

/// "Only 2 jobs in this ward; minimum is 15." from the engine, in the app language.
String notRatedReason(BuildContext context, Object? reason) {
  final m = RegExp(r'^Only (\d+) jobs? in this ward; minimum is (\d+)\.$').firstMatch('${reason ?? ''}');
  return m == null ? context.tr('${reason ?? ''}') : context.tr('Only {n} jobs in this ward; minimum is {min}.', {'n': m[1], 'min': m[2]});
}

/// Plain sentence comparing the contractor with the typical value; neutral wording.
String _sentence(BuildContext context, String metric, num v, num typ) {
  final args = {'p': formatPercent(v), 'q': formatPercent(typ)};
  if ((v - typ).abs() < 0.01) return context.tr('About typical: {p} against a typical {q}.', args);
  final higher = v > typ;
  return context.tr(switch (metric) {
    'speed' => higher
        ? 'Finishes on time more often than most: {p} on time against a typical {q}.'
        : 'Finishes on time less often than most: {p} on time against a typical {q}.',
    'durability' => higher
        ? 'Repairs are re-opened more often than most: {p} within 30 days against a typical {q}.'
        : 'Repairs hold up better than most: {p} re-opened within 30 days against a typical {q}.',
    _ => higher
        ? 'Billed above the rate card more often than most: {p} of jobs against a typical {q}.'
        : 'Billed above the rate card less often than most: {p} of jobs against a typical {q}.',
  }, args);
}

/// One measure as a grey card: figure, bar against the typical marker, a plain
/// sentence. Tapping lists the work orders behind it.
class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.id, required this.metric, required this.m, required this.jobs, required this.ward});
  final String id;
  final String metric;
  final Map m;
  final num jobs;
  final String? ward;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final def = scorecardMeasures[metric]!;
    final value = m['value'] as num? ?? 0;
    final typical = m['typical'] as num? ?? 0;
    final count = m['count'] as num? ?? 0;
    final typicalLabel = context.tr(metric == 'pricing' ? 'Typical, all contractors' : kTypicalSameWork);
    final detail = metric == 'pricing'
        ? context.tr('Median job billed at {r}× the rate card.', {'r': m['median_cost_ratio']})
        : context.tr('After allowing for heavy rain and low-lying wards: {p} (typical {q}).', {
            'p': formatPercent(m['adjusted_value'] as num? ?? 0),
            'q': formatPercent(m['adjusted_typical'] as num? ?? 0),
          });
    final sentence = _sentence(context, metric, value, typical);
    return Pressable(
      onTap: () => _openMeasure(context, id, metric, ward),
      color: c.surfaceAlt,
      borderRadius: AppRadii.cardRadius,
      padding: const EdgeInsets.all(AppSpacing.s16),
      semanticLabel: '${context.tr(def.title)}: ${context.tr(def.what)}, ${context.tr(kThisContractor)} ${formatPercent(value)}, '
          '$typicalLabel ${formatPercent(typical)}. $sentence ${context.tr('Show the {n} work orders behind it.', {'n': count})}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(context.tr(def.title), style: t.title)),
              Icon(Icons.chevron_right, color: c.textSecondary),
            ],
          ),
          Text('${context.tr(def.what)} · ${context.tr(def.better)}', style: t.caption),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.s8,
            children: [
              Text(formatPercent(value), style: t.figure),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('$typicalLabel: ${formatPercent(typical)}', style: t.caption),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          ScorecardBar(fraction: value.toDouble(), marker: typical.toDouble(), trackColor: c.background),
          const SizedBox(height: AppSpacing.s12),
          Text(sentence, style: t.body),
          const SizedBox(height: AppSpacing.s4),
          Text(detail, style: t.caption),
          const SizedBox(height: AppSpacing.s8),
          Text(context.tr('{n} of {jobs} {what} · see the work orders', {'n': count, 'jobs': jobs, 'what': context.tr(def.counted)}), style: t.label),
        ],
      ),
    );
  }
}

/// Tinted note panel (strength, to improve, not rated).
class _TintPanel extends StatelessWidget {
  const _TintPanel({required this.icon, required this.label, required this.text, required this.fg, required this.bg});
  final IconData icon;
  final String label;
  final String text;
  final Color fg;
  final Color bg;
  @override
  Widget build(BuildContext context) {
    final t = AppTypeScale.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.tileRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: AppSpacing.iconSmall, color: fg),
              const SizedBox(width: AppSpacing.s8),
              Expanded(child: Text(label, style: t.bodyStrong.copyWith(color: fg))),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(text, style: t.body),
        ],
      ),
    );
  }
}

/// The work orders behind one measure (late, re-opened or above-rate jobs).
class MeasureWorkOrders extends ConsumerWidget {
  const MeasureWorkOrders({super.key, required this.q});
  final MeasureQuery q;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTypeScale.of(context);
    final v = ref.watch(measureWorkOrdersProvider(q));
    final d = v.value;
    final def = scorecardMeasures[q.metric]!;
    final where = q.ward == null ? '' : ' ${context.tr('in Ward {w}', {'w': q.ward})}';
    final rows = [...?(d?['rows'] as List?)].cast<Json>();
    final total = d?['total'] as num? ?? 0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContent),
        child: ListView(
          primary: true,
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.s32),
          children: [
            const DetailTitle(),
            if (d == null)
              v.hasError
                  ? ErrorState(message: context.tr('Could not load these work orders.'), onRetry: () => ref.invalidate(measureWorkOrdersProvider(q)))
                  : Skeleton.rows(count: 6)
            else if (rows.isEmpty)
              EmptyState(
                pictogram: PictogramKind.audit,
                message: context.tr('None. {name} has no jobs of this kind{where}.', {'name': _plainName(d['contractor']?['name']), 'where': where}),
              )
            else ...[
              Gutter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_plainName(d['contractor']?['name']), style: t.title),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      '${context.tr(def.listed)}: ${context.tr('{n} of {jobs} jobs', {'n': total, 'jobs': d['jobs']})}$where · ${context.tr(kNeedsReview)}',
                      style: t.body,
                    ),
                    if (total > rows.length) Text(context.tr('Showing the latest {n}.', {'n': rows.length}), style: t.caption),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              for (final (i, r) in rows.indexed)
                StaggeredEntrance(index: i, child: _WorkOrderRow(r, metric: q.metric, divider: i < rows.length - 1)),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkOrderRow extends StatelessWidget {
  const _WorkOrderRow(this.w, {required this.metric, required this.divider});
  final Json w;
  final String metric;
  final bool divider;
  @override
  Widget build(BuildContext context) {
    final t = AppTypeScale.of(context);
    final ratio = w['rate_ratio'];
    final onTime = w['sla_met'] == true;
    final reopened = w['reopened'] == true;
    final late = (context.tr(onTime ? 'On time' : 'Finished late'), onTime ? StatusTone.success : StatusTone.warning);
    final reo = (context.tr(reopened ? 'Re-opened within 30 days' : 'Not re-opened'), reopened ? StatusTone.warning : StatusTone.neutral);
    final rate = ratio == null ? null : (context.tr('{r}× the standard rate', {'r': ratio}), StatusTone.review);
    // The chip shows the fact this list is about; the other facts follow in words.
    final main = switch (metric) {
      'speed' => late,
      'durability' => reo,
      _ => rate ?? late,
    };
    final others = [
      context.tr('Assigned {d}', {'d': '${w['assigned_at']}'.split(' ').first}),
      ...[late, reo, ?rate].where((f) => f != main).map((f) => f.$1),
    ].join(' · ');
    return ListRow(
      icon: Icons.assignment_outlined,
      title: '${w['id']} · ${w['road_name']}',
      caption: '${context.tr('Ward {w}', {'w': w['ward_code']})} · ${context.tr('${w['method']}')}',
      chip: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusChip(main.$1, tone: main.$2),
          const SizedBox(height: AppSpacing.s4),
          Text(others, style: t.caption),
        ],
      ),
      amount: formatInr(w['cost_inr'] as num? ?? 0),
      divider: divider,
      onTap: () => openRoad('${w['road_id']}', wo: '${w['id']}'),
    );
  }
}
