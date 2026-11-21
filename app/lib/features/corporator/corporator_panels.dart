import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/claude_draft_sheet.dart';
import '../../core/widgets/scorecard_stat_tile.dart';
import '../officer/officer_data.dart' show Json;
import '../officer/officer_panels.dart' show RoadPanel;
import '../officer/panel.dart';

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

/// City-wide scorecards as the only panel page (from the map home).
void openScorecards(BuildContext context) => ProviderScope.containerOf(context, listen: false)
    .read(panelProvider.notifier)
    .open(const PanelPage(kScorecardsTitle, ScorecardList()));

/// One-page ward brief in English, Hindi or Marathi; the server picks the figures.
void showWardBrief(BuildContext context, String code) => showClaudeDraftSheet(
  context,
  title: '$kWardBrief · Ward $code',
  feature: 'brief',
  body: {'ward_code': code, 'language': 'en'},
  languages: briefLanguages,
  textLabel: 'Ward brief (editable)',
);

/// Contractors A to Z with three like-for-like measures; [ward] scopes to one ward.
class ScorecardList extends ConsumerWidget {
  const ScorecardList({super.key, this.ward});
  final String? ward;

  @override
  Widget build(BuildContext context, WidgetRef ref) => asyncPage(
    ref.watch(scorecardsProvider(ward)),
    onRetry: () => ref.invalidate(scorecardsProvider(ward)),
    data: (d) {
      final rows = (d['contractors'] as List?) ?? const [];
      if (rows.isEmpty) {
        return PanelMessage.empty(ward == null ? 'No contractors in the audit.' : 'No contractor worked in Ward $ward.');
      }
      return PanelList(
        children: [
          const _FairnessNote(),
          const SizedBox(height: AppSpacing.s12),
          for (final r in rows) _ScorecardCard(row: r as Json, ward: ward),
        ],
      );
    },
  );
}

class _FairnessNote extends StatelessWidget {
  const _FairnessNote();
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(color: c.infoTint, borderRadius: AppRadii.controlRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.balance, size: 18, color: c.info),
              const SizedBox(width: AppSpacing.s8),
              Text(kFairnessTitle, style: t.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          for (final p in kFairnessPoints)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• $p', style: t.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _ScorecardCard extends ConsumerWidget {
  const _ScorecardCard({required this.row, required this.ward});
  final Json row;
  final String? ward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final rated = row['rated'] == true;
    final measures = (row['measures'] as Map?) ?? const {};
    final spend = row['spend'] as num?;
    final where = ward == null ? 'across Mumbai' : 'in Ward $ward';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${row['name']}', style: t.titleMedium),
            // Not rated: show only the reason, no figures at all.
            if (rated)
              Text(
                '${row['jobs']} jobs${spend == null ? '' : ' · ${formatInr(spend)}'} $where',
                style: t.bodySmall?.copyWith(color: c.textSecondary),
              ),
            if (!rated) ...[
              const SizedBox(height: AppSpacing.s12),
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: AppRadii.controlRadius),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: c.textSecondary),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kNotRatedInWard, style: t.titleSmall),
                          Text('${row['reason_if_not_rated'] ?? ''}', style: t.bodyMedium),
                          Text(
                            'Too few jobs to compare fairly, so no figures are shown.',
                            style: t.bodySmall?.copyWith(color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              for (final key in scorecardMeasures.keys)
                if (measures[key] is Map) _Measure(id: row['id'] as String, metric: key, m: measures[key] as Map, jobs: row['jobs'] as num? ?? 0, ward: ward),
              const SizedBox(height: AppSpacing.s12),
              _Note(kDoingWell, '${row['strength']}', ward != null, c.success),
              const SizedBox(height: AppSpacing.s8),
              _Note(kToLookAt, '${row['improve']}', ward != null, c.warning),
            ],
          ],
        ),
      ),
    );
  }
}

/// One measure: the contractor's value next to the typical value for the same
/// kind of work. Tapping lists the work orders behind it.
class _Measure extends ConsumerWidget {
  const _Measure({required this.id, required this.metric, required this.m, required this.jobs, required this.ward});
  final String id;
  final String metric;
  final Map m;
  final num jobs;
  final String? ward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final def = scorecardMeasures[metric]!;
    final value = m['value'] as num? ?? 0;
    final typical = m['typical'] as num? ?? 0;
    final count = m['count'] as num? ?? 0;
    final detail = metric == 'pricing'
        ? 'Median job billed at ${m['median_cost_ratio']}× the rate card.'
        : '$kAfterAllowance: ${formatPercent(m['adjusted_value'] as num? ?? 0)} '
              '(typical ${formatPercent(m['adjusted_typical'] as num? ?? 0)}).';

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s12),
      child: Semantics(
        button: true,
        label: '${def.title}: ${def.what}, $kThisContractor ${formatPercent(value)}, '
            '$kTypicalSameWork ${formatPercent(typical)}. Show the $count work orders behind it.',
        child: InkWell(
          borderRadius: AppRadii.controlRadius,
          onTap: () => ref.read(panelProvider.notifier).push(
            PanelPage('${def.listed} · ${ward == null ? 'Mumbai' : 'Ward $ward'}', MeasureWorkOrders(q: (id: id, metric: metric, ward: ward))),
          ),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(def.title, style: t.titleSmall)),
                      Text('$count of $jobs ${def.counted}', style: t.labelMedium?.copyWith(color: c.primary)),
                      Icon(Icons.chevron_right, color: c.primary),
                    ],
                  ),
                  Text('${def.what} · ${def.better}', style: t.bodySmall?.copyWith(color: c.textSecondary)),
                  const SizedBox(height: AppSpacing.s8),
                  Row(
                    children: [
                      Expanded(
                        child: ScorecardStatTile(
                          value: formatPercent(value),
                          label: kThisContractor,
                          barFraction: value.toDouble(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: ScorecardStatTile(
                          value: formatPercent(typical),
                          label: metric == 'pricing' ? 'Typical, all contractors' : kTypicalSameWork,
                          barFraction: typical.toDouble(),
                          barColor: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(detail, style: t.bodySmall?.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.label, this.text, this.cityWide, this.color);
  final String label;
  final String text;
  final bool cityWide;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: AppSpacing.s8),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cityWide ? '$label (across Mumbai)' : label, style: t.labelLarge),
          Text(text, style: t.bodyMedium),
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
  Widget build(BuildContext context, WidgetRef ref) => asyncPage(
    ref.watch(measureWorkOrdersProvider(q)),
    onRetry: () => ref.invalidate(measureWorkOrdersProvider(q)),
    data: (d) {
      final c = SaartheeColors.of(context);
      final t = Theme.of(context).textTheme;
      final rows = (d['rows'] as List?) ?? const [];
      final total = d['total'] as num? ?? 0;
      final def = scorecardMeasures[q.metric]!;
      final where = q.ward == null ? '' : ' in Ward ${q.ward}';
      if (rows.isEmpty) {
        return PanelMessage.empty('None. ${d['contractor']?['name']} has no jobs of this kind$where.');
      }
      return PanelList(
        children: [
          Text('${d['contractor']?['name']}', style: t.titleSmall),
          Text('${def.listed}: $total of ${d['jobs']} jobs$where · $kNeedsReview', style: t.bodyMedium),
          if (total > rows.length)
            Text('Showing the latest ${rows.length}.', style: t.bodySmall?.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpacing.s8),
          for (final r in rows) _WorkOrderRow(r as Json),
        ],
      );
    },
  );
}

class _WorkOrderRow extends ConsumerWidget {
  const _WorkOrderRow(this.w);
  final Json w;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final ratio = w['rate_ratio'];
    final onTime = w['sla_met'] == true;
    final reopened = w['reopened'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: ListTile(
        title: Text('${w['id']} · ${formatInr(w['cost_inr'] as num? ?? 0)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${w['road_name']} · Ward ${w['ward_code']}'),
            Text('${w['method']} · assigned ${'${w['assigned_at']}'.split(' ').first}'),
            const SizedBox(height: AppSpacing.s4),
            Wrap(
              spacing: AppSpacing.s4,
              runSpacing: AppSpacing.s4,
              children: [
                Tag(onTime ? 'On time' : 'Finished late', bg: onTime ? c.successTint : c.warningTint, fg: onTime ? c.success : c.warning),
                Tag(
                  reopened ? 'Re-opened within 30 days' : 'Not re-opened',
                  bg: reopened ? c.warningTint : c.surfaceAlt,
                  fg: reopened ? c.warning : c.textSecondary,
                ),
                if (ratio != null) Tag('$ratio× the standard rate', bg: c.warningTint, fg: c.warning),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => ref.read(panelProvider.notifier).push(PanelPage('${w['road_name']}', RoadPanel('${w['road_id']}'))),
      ),
    );
  }
}
