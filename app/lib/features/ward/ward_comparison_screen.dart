import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/widgets/ui.dart';
import '../map/map_data.dart';
import '../officer/officer_panels.dart' show openWard;

/// Opens the ward comparison (from Home's "Mumbai this monsoon").
void openWardComparison() => appRouter.push('/wards');

enum _Measure { warranty, review, budget, failed }

/// "Wards this monsoon": the 24 wards ranked by billed-under-warranty, to
/// review, spend against budget, or share of repairs failed within 30 days. A row opens the ward page.
class WardComparisonScreen extends ConsumerStatefulWidget {
  const WardComparisonScreen({super.key});
  @override
  ConsumerState<WardComparisonScreen> createState() => _WardComparisonScreenState();
}

class _WardComparisonScreenState extends ConsumerState<WardComparisonScreen> {
  _Measure _m = _Measure.warranty;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mapDataProvider);
    final data = async.value;
    return LargeTitleScaffold(
      title: context.tr('Wards this monsoon'),
      caption: context.tr('Tap a ward to open its page.'),
      onRefresh: () async => ref.invalidate(mapDataProvider),
      children: [
        // Pills, not a segmented control: four labels do not fit a 360 dp phone in Hindi or Marathi.
        FilterChipRow(
          children: [
            for (final (m, label) in [
              (_Measure.warranty, 'Under warranty'),
              (_Measure.review, 'To review'),
              (_Measure.budget, 'Over budget'),
              (_Measure.failed, 'Failed repairs'),
            ])
              FilterPill(label: context.tr(label), selected: _m == m, onTap: () => setState(() => _m = m)),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        if (data != null)
          AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.standard),
            switchInCurve: AppMotion.standardCurve,
            child: KeyedSubtree(key: ValueKey(_m), child: _rows(context, data.wards)),
          )
        else if (async.hasError)
          ErrorState(message: context.tr('Could not load wards.'), onRetry: () => ref.invalidate(mapDataProvider))
        else
          Skeleton.rows(count: 8),
      ],
    );
  }

  Widget _rows(BuildContext context, List<Ward> all) {
    final c = SaartheeColors.of(context);
    num n(Ward w, String k) => w.data[k] as num? ?? 0;
    double ratio(Ward w) => n(w, 'budget') <= 0 ? 0 : n(w, 'spend') / n(w, 'budget');
    double failed(Ward w) => n(w, 'jobs') <= 0 ? 0 : n(w, 'fix_failed_count') / n(w, 'jobs');
    final rows = switch (_m) {
      _Measure.warranty => [...all.where((w) => n(w, 'dlp_paid_inr') > 0)]..sort((a, b) => n(b, 'dlp_paid_inr').compareTo(n(a, 'dlp_paid_inr'))),
      _Measure.review => [...all]..sort((a, b) => b.flaggedInr.compareTo(a.flaggedInr)),
      _Measure.budget => [...all]..sort((a, b) => ratio(b).compareTo(ratio(a))),
      _Measure.failed => [...all]..sort((a, b) => failed(b).compareTo(failed(a))),
    };
    if (rows.isEmpty) return EmptyState(message: context.tr('No ward has work billed under warranty.'), pictogram: PictogramKind.warranty);
    final max = switch (_m) {
      _Measure.warranty => n(rows.first, 'dlp_paid_inr'),
      _Measure.review => rows.first.flaggedInr,
      _Measure.budget => 1,
      _Measure.failed => failed(rows.first),
    };
    return Column(
      children: [
        for (final (i, w) in rows.indexed)
          StaggeredEntrance(
            index: i,
            child: ListRow(
              title: w.name,
              titleMaxLines: 1,
              caption: switch (_m) {
                _Measure.warranty => context.tr('{n} jobs', {'n': n(w, 'dlp_paid_count')}),
                _Measure.review => context.tr('{p} of spend', {'p': formatPercent(w.flaggedShare)}),
                _Measure.budget => context.tr('Spent {spend} of {budget} budget', {'spend': formatInr(w.spend), 'budget': formatInr(n(w, 'budget'))}),
                _Measure.failed => context.tr('{n} of {jobs} repairs failed within 30 days', {'n': n(w, 'fix_failed_count'), 'jobs': n(w, 'jobs')}),
              },
              initials: w.code,
              chip: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s4),
                child: ProgressBar(
                  value: switch (_m) {
                    _Measure.warranty => max <= 0 ? 0 : n(w, 'dlp_paid_inr') / max,
                    _Measure.review => max <= 0 ? 0 : w.flaggedInr / max,
                    _Measure.budget => ratio(w),
                    _Measure.failed => max <= 0 ? 0 : failed(w) / max,
                  },
                  height: 4,
                  color: switch (_m) {
                    _Measure.warranty => c.info,
                    _Measure.failed => c.error,
                    _ => null,
                  },
                ),
              ),
              amount: switch (_m) {
                _Measure.warranty => formatInr(n(w, 'dlp_paid_inr')),
                _Measure.review => formatInr(w.flaggedInr),
                _Measure.budget => formatPercent(ratio(w)),
                _Measure.failed => formatPercent(failed(w)),
              },
              amountColor: _m == _Measure.budget && ratio(w) > 1 ? c.error : null,
              divider: i < rows.length - 1,
              onTap: () => openWard(w.code),
            ),
          ),
      ],
    );
  }
}
