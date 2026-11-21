import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../core/api/api_client.dart';
import '../../core/prefs.dart';
import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/widgets/claude_draft_sheet.dart';
import '../../core/widgets/ui.dart';
import '../officer/officer_data.dart' show Json;
import '../officer/officer_panels.dart' show openRoad;
import '../officer/panel.dart' show PanelPage, pushPanel;

// Corporator flow: fair contractor scorecards and the ward brief. Every figure
// comes from the server as the audit engine produced it; nothing is ranked here.

Duration? _noRetry(int _, Object _) => null;

final scorecardsProvider = FutureProvider.family<Json, String?>(
  retry: _noRetry,
  (ref, ward) => ref.watch(apiClientProvider).scorecards(ward: ward),
);

typedef MeasureQuery = ({String id, String metric, String? ward});

final measureWorkOrdersProvider = FutureProvider.family<Json, MeasureQuery>(
  retry: _noRetry,
  (ref, q) => ref.watch(apiClientProvider).contractorWorkOrders(q.id, q.metric, ward: q.ward),
);

/// One-page ward brief in English, Hindi or Marathi; the server picks the figures.
void showWardBrief(BuildContext context, String code) => showClaudeDraftSheet(
  context,
  title: '$kWardBrief · Ward $code',
  feature: 'brief',
  body: {'ward_code': code, 'language': 'en'},
  languages: briefLanguages,
  textLabel: 'Ward brief (editable)',
);

String _plainName(Object? n) => '${n ?? ''}'.replaceAll(' (synthetic)', '');

String _initials(String name) =>
    name.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

void _openScorecard(String id, String? ward) =>
    appRouter.push(Uri(path: '/contractor', queryParameters: {'id': id, 'ward': ?ward}).toString());

void _openMeasure(String id, String metric, String? ward) {
  final def = scorecardMeasures[metric]!;
  pushPanel(PanelPage('${def.listed} · ${ward == null ? 'Mumbai' : 'Ward $ward'}', MeasureWorkOrders(q: (id: id, metric: metric, ward: ward))));
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
        padding: EdgeInsets.only(top: AppSpacing.s8, bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.s32),
        children: [
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
      return v.hasError ? ErrorState(message: 'Could not load contractors.', onRetry: onRetry) : Skeleton.rows(count: 7);
    }
    final all = [...?(d['contractors'] as List?)].cast<Json>();
    if (all.isEmpty) {
      return EmptyState(
        pictogram: PictogramKind.contractors,
        message: ward == null ? 'No contractors in the audit.' : 'No contractor worked in Ward $ward.',
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
            child: Text('A to Z · not a ranking. Bars: finished on time, re-opened within 30 days, billed above rate.', style: t.caption),
          ),
        ),
        if (rows.isEmpty) EmptyState(pictogram: PictogramKind.contractors, message: 'No contractor matches “${query.trim()}”.'),
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
      caption: rated ? '${row['jobs']} jobs${spend == null ? '' : ' · ${formatInr(spend)}'} · synthetic' : '$kNotRatedInWard · synthetic',
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
      label: 'Finished on time ${formatPercent(v('speed'))}, re-opened ${formatPercent(v('durability'))}, '
          'above rate ${formatPercent(v('pricing'))}',
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
      title: 'Contractors',
      caption: 'Fictional names. Compared like for like.',
      onRefresh: () => ref.refresh(scorecardsProvider(scope).future),
      children: [
        Gutter(
          child: SegmentedControl<bool>(
            segments: [(false, 'All Mumbai'), (true, 'Ward $ward')],
            value: _inWard,
            onChanged: (v) => setState(() => _inWard = v),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Gutter(child: SearchField(hint: 'Search contractors', onChanged: (s) => setState(() => _query = s))),
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
    final where = ward == null ? 'Across Mumbai' : 'In Ward $ward';
    final rated = row?['rated'] == true;
    final spend = row?['spend'] as num?;
    return LargeTitleScaffold(
      title: row == null ? kScorecardsTitle : _plainName(row['name']),
      caption: row == null
          ? where
          : rated
          ? 'Synthetic contractor · ${row['jobs']} jobs${spend == null ? '' : ' · ${formatInr(spend)}'} · ${ward == null ? 'across Mumbai' : 'in Ward $ward'}'
          : 'Synthetic contractor · $where',
      onRefresh: () => ref.refresh(scorecardsProvider(ward).future),
      children: [
        if (v.value == null && v.hasError)
          ErrorState(message: 'Could not load this scorecard.', onRetry: () => ref.invalidate(scorecardsProvider(ward)))
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
          const EmptyState(pictogram: PictogramKind.contractors, message: 'No scorecard for this contractor here.')
        else
          ..._scorecard(context, ref, row),
      ],
    );
  }

  List<Widget> _scorecard(BuildContext context, WidgetRef ref, Json row) {
    final c = SaartheeColors.of(context);
    final t = AppTypeScale.of(context);
    final rated = row['rated'] == true;
    final measures = (row['measures'] as Map?) ?? const {};
    final jobs = row['jobs'] as num? ?? 0;
    final chosen = ref.watch(chosenWardProvider);
    final keys = scorecardMeasures.keys.where((k) => measures[k] is Map).toList();
    return [
      const SizedBox(height: AppSpacing.s8),
      Gutter(
        child: CollapsiblePanel(
          title: kFairnessTitle,
          icon: Icons.balance,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in kFairnessPoints)
                Padding(padding: const EdgeInsets.only(top: AppSpacing.s4), child: Text('•  $p')),
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
            label: kNotRatedInWard,
            text: '${row['reason_if_not_rated'] ?? ''}\nToo few jobs to compare fairly, so no figures are shown.',
            fg: c.textSecondary,
            bg: c.surfaceAlt,
          ),
        ),
      ] else ...[
        const Gutter(child: SectionHeading('How it compares')),
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
            label: ward != null ? '$kDoingWell (across Mumbai)' : kDoingWell,
            text: '${row['strength']}',
            fg: c.success,
            bg: c.successTint,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Gutter(
          child: _TintPanel(
            icon: Icons.flag_outlined,
            label: ward != null ? '$kToLookAt (across Mumbai)' : kToLookAt,
            text: '${row['improve']}',
            fg: c.warning,
            bg: c.warningTint,
          ),
        ),
      ],
      const SectionBreak(),
      const Gutter(child: SectionHeading('By ward')),
      if (ward == null)
        ListRow(
          icon: Icons.location_city_outlined,
          title: 'In Ward $chosen',
          caption: 'The same measures, for this ward only',
          divider: false,
          onTap: () => _openScorecard(row['id'] as String, chosen),
        )
      else
        ListRow(
          icon: Icons.public,
          title: 'Across Mumbai',
          caption: 'The same measures, all wards together',
          divider: false,
          onTap: () => _openScorecard(row['id'] as String, null),
        ),
      if (rated) ...[
        const Gutter(child: SectionHeading('Work orders')),
        Gutter(child: Text('See this contractor’s flagged work orders', style: t.caption)),
        const SizedBox(height: AppSpacing.s4),
        for (final (i, k) in keys.indexed)
          ListRow(
            icon: Icons.assignment_outlined,
            title: scorecardMeasures[k]!.listed,
            caption: '${(measures[k] as Map)['count'] ?? 0} of $jobs jobs · $kNeedsReview',
            divider: i < keys.length - 1,
            onTap: () => _openMeasure(row['id'] as String, k, ward),
          ),
      ],
    ];
  }
}

/// Plain sentence comparing the contractor with the typical value; neutral wording.
String _sentence(String metric, num v, num typ) {
  final p = formatPercent(v);
  final q = formatPercent(typ);
  if ((v - typ).abs() < 0.01) return 'About typical: $p against a typical $q.';
  final higher = v > typ;
  return switch (metric) {
    'speed' => 'Finishes on time ${higher ? 'more' : 'less'} often than most: $p on time against a typical $q.',
    'durability' => higher
        ? 'Repairs are re-opened more often than most: $p within 30 days against a typical $q.'
        : 'Repairs hold up better than most: $p re-opened within 30 days against a typical $q.',
    _ => 'Billed above the rate card ${higher ? 'more' : 'less'} often than most: $p of jobs against a typical $q.',
  };
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
    final typicalLabel = metric == 'pricing' ? 'Typical, all contractors' : kTypicalSameWork;
    final detail = metric == 'pricing'
        ? 'Median job billed at ${m['median_cost_ratio']}× the rate card.'
        : '$kAfterAllowance: ${formatPercent(m['adjusted_value'] as num? ?? 0)} '
              '(typical ${formatPercent(m['adjusted_typical'] as num? ?? 0)}).';
    return Pressable(
      onTap: () => _openMeasure(id, metric, ward),
      color: c.surfaceAlt,
      borderRadius: AppRadii.cardRadius,
      padding: const EdgeInsets.all(AppSpacing.s16),
      semanticLabel: '${def.title}: ${def.what}, $kThisContractor ${formatPercent(value)}, '
          '$typicalLabel ${formatPercent(typical)}. ${_sentence(metric, value, typical)} Show the $count work orders behind it.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(def.title, style: t.title)),
              Icon(Icons.chevron_right, color: c.textSecondary),
            ],
          ),
          Text('${def.what} · ${def.better}', style: t.caption),
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
          Text(_sentence(metric, value, typical), style: t.body),
          const SizedBox(height: AppSpacing.s4),
          Text(detail, style: t.caption),
          const SizedBox(height: AppSpacing.s8),
          Text('$count of $jobs ${def.counted} · see the work orders', style: t.label),
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
    final where = q.ward == null ? '' : ' in Ward ${q.ward}';
    final rows = [...?(d?['rows'] as List?)].cast<Json>();
    final total = d?['total'] as num? ?? 0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContent),
        child: ListView(
          padding: EdgeInsets.only(top: AppSpacing.s8, bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.s32),
          children: [
            if (d == null)
              v.hasError
                  ? ErrorState(message: 'Could not load these work orders.', onRetry: () => ref.invalidate(measureWorkOrdersProvider(q)))
                  : Skeleton.rows(count: 6)
            else if (rows.isEmpty)
              EmptyState(pictogram: PictogramKind.audit, message: 'None. ${_plainName(d['contractor']?['name'])} has no jobs of this kind$where.')
            else ...[
              Gutter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_plainName(d['contractor']?['name']), style: t.title),
                    const SizedBox(height: AppSpacing.s4),
                    Text('${def.listed}: $total of ${d['jobs']} jobs$where · $kNeedsReview', style: t.body),
                    if (total > rows.length) Text('Showing the latest ${rows.length}.', style: t.caption),
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
    final late = (onTime ? 'On time' : 'Finished late', onTime ? StatusTone.success : StatusTone.warning);
    final reo = (reopened ? 'Re-opened within 30 days' : 'Not re-opened', reopened ? StatusTone.warning : StatusTone.neutral);
    final rate = ratio == null ? null : ('$ratio× the standard rate', StatusTone.review);
    // The chip shows the fact this list is about; the other facts follow in words.
    final main = switch (metric) {
      'speed' => late,
      'durability' => reo,
      _ => rate ?? late,
    };
    final others = [
      'Assigned ${'${w['assigned_at']}'.split(' ').first}',
      ...[late, reo, ?rate].where((f) => f != main).map((f) => f.$1),
    ].join(' · ');
    return ListRow(
      icon: Icons.assignment_outlined,
      title: '${w['id']} · ${w['road_name']}',
      caption: 'Ward ${w['ward_code']} · ${w['method']}',
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
