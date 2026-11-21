import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../core/auth/session.dart';
import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/prefs.dart';
import '../../core/widgets/ui.dart';
import '../auth/account_sheet.dart';
import '../citizen/ask_bot.dart';
import '../citizen/citizen_panels.dart';
import '../citizen/report_card.dart';
import '../corporator/corporator_panels.dart';
import '../map/map_data.dart';
import '../map/monsoon.dart';
import '../officer/next_rupee.dart';
import '../officer/officer_data.dart';
import '../officer/officer_panels.dart';
import '../officer/panel.dart';
import '../trail/trail_screen.dart';
import '../ward/ward_comparison_screen.dart';
import '../ward/ward_picker.dart';

const int _mapTab = 1;
const int _actTab = 2;

/// Home tab, role-aware (signed out behaves as citizen): ward pill, language
/// and account in the top bar, "Namaste", then the role's blocks.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionProvider.select((s) => s?.role));
    final ward = ref.watch(chosenWardProvider);
    final shell = StatefulNavigationShell.maybeOf(context);
    void goTab(int i) => shell?.goBranch(i);

    final blocks = switch (role) {
      'officer' => _officer(context, ward, goTab),
      'corporator' => _corporator(context, ward, goTab),
      _ => _citizen(context, ref, ward, goTab),
    };

    return LargeTitleScaffold(
      key: const PageStorageKey('home.scroll'),
      title: context.tr('Namaste'),
      caption: role == null ? 'Nagar Sarthi' : 'Nagar Sarthi · ${context.tr(roleLabels[role] ?? role)}',
      maxWidth: AppSpacing.maxGrid,
      leading: _WardPill(ward: ward),
      actions: [
        const LanguageButton(),
        RoundIconButton(
          icon: role == null ? Icons.person_outline : Icons.person,
          tooltip: role == null ? context.tr('Sign in') : context.tr(roleLabels[role] ?? role),
          onPressed: () => showAccountSheet(context),
        ),
      ],
      onRefresh: () async {
        ref.invalidate(mapDataProvider);
        ref.invalidate(wardDetailProvider(ward));
        ref.invalidate(topFlagsProvider(ward));
        ref.invalidate(nextRupeeProvider(ward));
        ref.invalidate(scorecardsProvider(ward));
      },
      children: [
        // Sections rise in one after another on first paint.
        for (final (i, b) in [...blocks, const _DataLine()].indexed) StaggeredEntrance(index: i, child: b),
      ],
    );
  }

  static List<Widget> _citizen(BuildContext context, WidgetRef ref, String ward, void Function(int) goTab) => [
    Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s16),
      child: Gutter(child: _ReportPill(onTap: () => goTab(_actTab))),
    ),
    const SectionBreak(),
    _Heading(context.tr('Do something')),
    Gutter(
      child: TileGrid(
        tiles: [
          Tile(label: context.tr(kReportProblem), pictogram: PictogramKind.report, size: TileSize.wide, onTap: () => goTab(_actTab)),
          Tile(label: context.tr(kTrackComplaint), pictogram: PictogramKind.track, size: TileSize.wide, onTap: () => appRouter.push('/track')),
          Tile(label: context.tr(kAskBot), pictogram: PictogramKind.chat, onTap: openAskBot),
          Tile(
            label: context.tr(kReportCard),
            pictogram: PictogramKind.reportCard,
            onTap: () => pushPanel(PanelPage(kReportCard, ReportCardPage(ward: ward))),
          ),
          Tile(label: context.tr(kAskWard), pictogram: PictogramKind.ask, onTap: () => pushPanel(PanelPage(kAskWard, AskWardPage(ward: ward)))),
          Tile(
            label: context.tr('Watch the 2025 monsoon'),
            pictogram: PictogramKind.monsoon,
            accent: SaartheeColors.of(context).info,
            onTap: () {
              goTab(_mapTab);
              ref.read(seasonProvider.future).then((s) => ref.read(monsoonProvider.notifier).play(s.last));
            },
          ),
          Tile(label: context.tr('Complaint trail'), pictogram: PictogramKind.trail, onTap: () => openTrail(ward)),
          Tile(label: context.tr('About this data'), pictogram: PictogramKind.about, onTap: () => appRouter.push('/about')),
        ],
      ),
    ),
    const SectionBreak(space: AppSpacing.s32),
    const _CityHero(),
    _Heading(context.tr('Ward {w} this monsoon', {'w': ward}), top: AppSpacing.s40),
    _WardStats(ward: ward),
  ];

  static List<Widget> _officer(BuildContext context, String ward, void Function(int) goTab) => [
    _OfficerHero(ward: ward, onOpenAudit: () => goTab(_actTab)),
    _OfficerStats(ward: ward),
    _Heading(
      'Needs your attention',
      top: AppSpacing.s40,
      trailing: TextButton(onPressed: () => goTab(_actTab), child: const Text('See all')),
    ),
    _TopFlags(ward: ward),
    const SectionBreak(space: AppSpacing.s32),
    _Heading('Tools'),
    _Tools(ward: ward, goTab: goTab, brief: true),
  ];

  static List<Widget> _corporator(BuildContext context, String ward, void Function(int) goTab) => [
    _BudgetHero(ward: ward),
    Gutter(
      child: _WideActionTile(
        title: kWardBrief,
        caption: 'A one-page summary you can share, in English, हिंदी or मराठी',
        pictogram: PictogramKind.brief,
        onTap: () => showWardBrief(context, ward),
      ),
    ),
    const SizedBox(height: AppSpacing.tileGap),
    _WardStats(ward: ward, corporator: true),
    _Heading(
      kContractorsInWard,
      top: AppSpacing.s40,
      trailing: TextButton(
        onPressed: () => pushPanel(PanelPage('$kContractorsInWard · Ward $ward', ScorecardList(ward: ward))),
        child: const Text('See all'),
      ),
    ),
    _Contractors(ward: ward),
    _Heading('Top items to look at', top: AppSpacing.s40),
    _TopFlags(ward: ward),
    const SectionBreak(space: AppSpacing.s32),
    _Heading('Tools'),
    _Tools(ward: ward, goTab: goTab, brief: false),
  ];
}

// ------------------------------------------------------------------ top bar

/// "Ward E · Byculla ▾" grey pill; opens the ward picker.
class _WardPill extends ConsumerWidget {
  const _WardPill({required this.ward});
  final String ward;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(mapDataProvider).value?.wardByCode[ward]?.name;
    final label = '${context.tr('Ward {w}', {'w': ward})}${name == null ? '' : ' · $name'}';
    // The bar gives the leading slot the full width: leave room for the two round buttons.
    return LayoutBuilder(
      builder: (context, box) => Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: box.maxWidth - 2 * AppSpacing.touchTarget - AppSpacing.s24),
          child: WardPillButton(label: label, onTap: () => pickWard(context, ref)),
        ),
      ),
    );
  }
}

/// Citizen: search-style grey pill that opens Report, black "+" at its end.
class _ReportPill extends StatelessWidget {
  const _ReportPill({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    return Pressable(
      onTap: onTap,
      color: c.surfaceAlt,
      borderRadius: AppRadii.pillRadius,
      semanticLabel: '${context.tr(kReportProblem)}. ${context.tr('Pothole, waterlogging, a repair that failed')}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.buttonHeight),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.s20, AppSpacing.s8, AppSpacing.s8, AppSpacing.s8),
          child: Row(
            children: [
              Expanded(
                child: Text('${context.tr(kReportProblem)}…', style: t.body.copyWith(color: c.textSecondary), maxLines: 2),
              ),
              const SizedBox(width: AppSpacing.s8),
              Container(
                width: AppSpacing.headerButton,
                height: AppSpacing.headerButton,
                decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                child: Icon(Icons.add, color: c.onPrimary, size: AppSpacing.iconSize),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section heading in the gutter; [top] space above, 12 below.
class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.top = 0, this.trailing});
  final String text;
  final double top;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(AppSpacing.gutter, top, AppSpacing.s8, AppSpacing.sectionTitleBottom),
    child: Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text(text, style: context.type.headline)),
        ),
        ?trailing,
        if (trailing == null) const SizedBox(width: AppSpacing.s12),
      ],
    ),
  );
}

/// Loading skeleton, error with retry, or the data block.
Widget _block<T>(AsyncValue<T> v, {required Widget skeleton, required VoidCallback onRetry, required String error, required Widget Function(T) data}) {
  final value = v.value;
  if (value != null) return data(value);
  if (v.hasError) return ErrorState(message: error, onRetry: onRetry);
  return skeleton;
}

Widget _heroSkeleton() => const Gutter(
  child: Skeleton(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(height: 14, widthFactor: 0.4),
        SizedBox(height: AppSpacing.s8),
        SkeletonBox(height: 44, widthFactor: 0.55),
        SizedBox(height: AppSpacing.s8),
        SkeletonBox(height: 14, widthFactor: 0.8),
      ],
    ),
  ),
);

// ------------------------------------------------------------------ citizen

/// "Mumbai this monsoon": the city's warranty figure; opens the ward comparison.
class _CityHero extends ConsumerWidget {
  const _CityHero();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _block(
    ref.watch(mapDataProvider),
    skeleton: _heroSkeleton(),
    error: context.tr('Could not load the city figures.'),
    onRetry: () => ref.invalidate(mapDataProvider),
    data: (data) {
      final dlp = (((data.meta['totals'] as Map?)?['flags'] as Map?)?['dlp_paid'] as Map?) ?? const {};
      return Gutter(
        child: HeroFigure(
          caption: context.tr('Mumbai this monsoon'),
          value: dlp['inr'] as num? ?? 0,
          format: formatInr,
          explanation: context.tr('billed on roads under warranty — to be claimed and verified'),
          onTap: openWardComparison,
          action: Text(
            context.tr('{n} jobs across Mumbai · see wards', {'n': dlp['count'] ?? '—'}),
            style: context.type.caption,
          ),
        ),
      );
    },
  );
}

/// Ward stat tiles. Citizen: spent of budget, to review, failed repairs.
/// Corporator: to review, share of repairs failed, complaints never fixed.
class _WardStats extends ConsumerWidget {
  const _WardStats({required this.ward, this.corporator = false});
  final String ward;
  final bool corporator;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    return Gutter(
      child: _block(
        ref.watch(wardDetailProvider(ward)),
        skeleton: Skeleton.tiles(),
        error: context.tr('Could not load ward {w}.', {'w': ward}),
        onRetry: () => ref.invalidate(wardDetailProvider(ward)),
        data: (w) {
          final budget = w['budget'] as num? ?? 0;
          final spend = w['spend'] as num? ?? 0;
          final failed = ((w['by_flag_type'] as Map?)?['fix_failed'] as Map?)?['count'] as num? ?? 0;
          final review = StatTile.count(count: w['flagged_inr'] as num? ?? 0, format: formatInr, label: context.tr('to review'));
          if (corporator) {
            final jobs = ((w['by_method'] as List?) ?? const []).fold<num>(0, (s, m) => s + (m['jobs'] as num? ?? 0));
            return StatRow(
              tiles: [
                review,
                StatTile.count(count: jobs == 0 ? 0 : failed / jobs, format: formatPercent, label: 'repairs failed within 30 days', color: c.error, dot: c.error),
                StatTile.count(count: (w['never_fixed'] as List?)?.length ?? 0, label: 'complaints never fixed'),
              ],
            );
          }
          return StatRow(
            tiles: [
              budget <= 0
                  ? StatTile.count(count: spend, format: formatInr, label: context.tr('of the budget spent'))
                  : StatTile.count(
                      count: spend / budget,
                      format: formatPercent,
                      label: context.tr('of the budget spent'),
                      color: spend > budget ? c.error : null,
                      dot: spend > budget ? c.error : null,
                    ),
              review,
              StatTile.count(count: failed, label: context.tr('repairs failed within 30 days')),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ officer

class _OfficerHero extends ConsumerWidget {
  const _OfficerHero({required this.ward, required this.onOpenAudit});
  final String ward;
  final VoidCallback onOpenAudit;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.s16, bottom: AppSpacing.s24),
    child: _block(
      ref.watch(wardDetailProvider(ward)),
      skeleton: _heroSkeleton(),
      error: 'Could not load ward $ward.',
      onRetry: () => ref.invalidate(wardDetailProvider(ward)),
      data: (w) => Gutter(
        child: HeroFigure(
          caption: 'To review in Ward $ward',
          value: w['flagged_inr'] as num? ?? 0,
          format: formatInr,
          explanation: "${formatPercent(w['flagged_share'] as num? ?? 0)} of this monsoon's road spend",
          action: PrimaryButton(label: 'Open audit', icon: Icons.fact_check_outlined, onPressed: onOpenAudit, expand: false),
        ),
      ),
    ),
  );
}

class _OfficerStats extends ConsumerWidget {
  const _OfficerStats({required this.ward});
  final String ward;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final nr = ref.watch(nextRupeeProvider(ward));
    return Gutter(
      child: _block(
        ref.watch(wardDetailProvider(ward)),
        skeleton: Skeleton.tiles(),
        error: 'Could not load ward $ward.',
        onRetry: () => ref.invalidate(wardDetailProvider(ward)),
        data: (w) {
          final bft = (w['by_flag_type'] as Map?) ?? const {};
          final dlp = (bft['dlp_paid'] as Map?) ?? const {};
          final items = (nr.value?['items'] as List?)?.length;
          return StatRow(
            tiles: [
              StatTile.count(count: dlp['inr'] as num? ?? 0, format: formatInr, label: '${dlp['count'] ?? 0} warranty claims to make'),
              StatTile.count(
                count: (bft['fix_failed'] as Map?)?['count'] as num? ?? 0,
                label: 'repairs failed within 30 days',
                color: c.error,
                dot: c.error,
              ),
              items == null
                  ? StatTile(
                      value: '—',
                      label: nr.hasError ? 'Next rupee: tap to retry' : 'items ranked for the next rupee',
                      onTap: nr.hasError ? () => ref.invalidate(nextRupeeProvider(ward)) : null,
                    )
                  : StatTile.count(count: items, label: 'items ranked for the next rupee', onTap: () => showNextRupee(ref, ward)),
            ],
          );
        },
      ),
    );
  }
}

/// Biggest money flags in the ward as list rows; each opens its road page on that work order.
class _TopFlags extends ConsumerWidget {
  const _TopFlags({required this.ward});
  final String ward;
  @override
  Widget build(BuildContext context, WidgetRef ref) => _block(
    ref.watch(topFlagsProvider(ward)),
    skeleton: Skeleton.rows(count: 5),
    error: 'Could not load flags.',
    onRetry: () => ref.invalidate(topFlagsProvider(ward)),
    data: (flags) => flags.isEmpty
        ? const EmptyState(message: 'No flags in this ward.', pictogram: PictogramKind.warranty)
        : Column(
            children: [
              for (final (i, f) in flags.cast<Map<String, dynamic>>().indexed)
                StaggeredEntrance(
                  index: i,
                  child: ListRow(
                    title: '${f['road_name'] ?? f['road_id']}',
                    caption: '${f['work_order_id']} · ${'${f['contractor_name']}'.replaceAll(' (synthetic)', '')}',
                    leading: _FlagWell(flagTone('${f['type']}')),
                    chip: StatusChip(flagShortLabels[f['type']] ?? flagLabel('${f['type']}'), tone: flagTone('${f['type']}')),
                    amount: formatInr(f['cost_inr'] as num? ?? 0),
                    divider: i < flags.length - 1,
                    onTap: () => openRoad(f['road_id'] as String, wo: f['work_order_id'] as String),
                  ),
                ),
            ],
          ),
  );
}

/// 40 px grey well with the flag's status-colour dot (as on the ward page).
class _FlagWell extends StatelessWidget {
  const _FlagWell(this.tone);
  final StatusTone tone;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
      child: Container(
        width: AppSpacing.timelineDot,
        height: AppSpacing.timelineDot,
        decoration: BoxDecoration(color: StatusChip.colors(c, tone).$1, shape: BoxShape.circle),
      ),
    );
  }
}

/// Staff tools as tiles.
class _Tools extends ConsumerWidget {
  const _Tools({required this.ward, required this.goTab, required this.brief});
  final String ward;
  final void Function(int) goTab;

  /// Ward brief tile (the corporator has it as a wide tile further up).
  final bool brief;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Gutter(
    child: TileGrid(
      tiles: [
        Tile(label: 'Next rupee', pictogram: PictogramKind.nextRupee, size: TileSize.wide, onTap: () => showNextRupee(ref, ward), semanticLabel: kNextRupeeAction),
        Tile(label: 'Complaint trail', pictogram: PictogramKind.trail, size: TileSize.wide, onTap: () => openTrail(ward)),
        Tile(label: 'Money trail', pictogram: PictogramKind.ward, onTap: () => openWard(ward), semanticLabel: 'Ward $ward money trail'),
        Tile(
          label: 'Contractors',
          pictogram: PictogramKind.contractors,
          onTap: () => pushPanel(PanelPage('$kContractorsInWard · Ward $ward', ScorecardList(ward: ward))),
        ),
        brief
            ? Tile(label: kWardBrief, pictogram: PictogramKind.brief, onTap: () => showWardBrief(context, ward))
            : Tile(label: kAskWard, pictogram: PictogramKind.ask, onTap: () => pushPanel(PanelPage(kAskWard, AskWardPage(ward: ward)))),
        Tile(label: 'Report card', pictogram: PictogramKind.reportCard, onTap: () => pushPanel(PanelPage(kReportCard, ReportCardPage(ward: ward)))),
        Tile(label: 'Map', pictogram: PictogramKind.map, onTap: () => goTab(_mapTab)),
        Tile(label: 'About', pictogram: PictogramKind.about, onTap: () => appRouter.push('/about')),
      ],
    ),
  );
}

// ------------------------------------------------------------------ corporator

/// Ward road budget: spend as the hero figure with a slim bar (red past 100%).
class _BudgetHero extends ConsumerWidget {
  const _BudgetHero({required this.ward});
  final String ward;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.s16, bottom: AppSpacing.s24),
    child: _block(
      ref.watch(wardDetailProvider(ward)),
      skeleton: _heroSkeleton(),
      error: 'Could not load ward $ward.',
      onRetry: () => ref.invalidate(wardDetailProvider(ward)),
      data: (w) {
        final budget = w['budget'] as num? ?? 0;
        final spend = w['spend'] as num? ?? 0;
        final over = spend - budget;
        return Gutter(
          child: HeroFigure(
            caption: 'Ward $ward road budget',
            value: spend,
            format: formatInr,
            explanation: 'spent of ${formatInr(budget)} · ${over > 0 ? '${formatInr(over)} over budget' : '${formatInr(-over)} left'}',
            onTap: () => openWard(ward),
            action: ProgressBar(
              value: budget <= 0 ? 1 : spend / budget,
              semanticLabel: 'Spent ${formatInr(spend)} of ${formatInr(budget)}',
            ),
          ),
        );
      },
    ),
  );
}

/// Full-width grey tile with a title, a caption and a pictogram top-right.
class _WideActionTile extends StatelessWidget {
  const _WideActionTile({required this.title, required this.caption, required this.pictogram, required this.onTap});
  final String title;
  final String caption;
  final PictogramKind pictogram;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    return Pressable(
      onTap: onTap,
      color: c.surfaceAlt,
      borderRadius: AppRadii.tileRadius,
      semanticLabel: '$title. $caption',
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(alignment: AlignmentDirectional.topEnd, child: Pictogram(pictogram, size: 32)),
          Text(title, style: t.title),
          const SizedBox(height: AppSpacing.s4),
          Text(caption, style: t.caption),
        ],
      ),
    );
  }
}

/// Rated contractors in the ward as a horizontal row of compact grey cards.
class _Contractors extends ConsumerWidget {
  const _Contractors({required this.ward});
  final String ward;
  @override
  Widget build(BuildContext context, WidgetRef ref) => _block(
    ref.watch(scorecardsProvider(ward)),
    skeleton: Gutter(child: Skeleton.tiles(count: 2, height: 132)),
    error: 'Could not load contractors.',
    onRetry: () => ref.invalidate(scorecardsProvider(ward)),
    data: (sc) {
      final rows = [...?(sc['contractors'] as List?)].cast<Map<String, dynamic>>().where((r) => r['rated'] == true).toList();
      if (rows.isEmpty) {
        return const EmptyState(message: 'No contractor has enough jobs here to be rated yet.', pictogram: PictogramKind.contractors);
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, r) in rows.indexed) ...[
                if (i > 0) const SizedBox(width: AppSpacing.tileGap),
                StaggeredEntrance(index: i, child: _ContractorCard(row: r, ward: ward)),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _ContractorCard extends StatelessWidget {
  const _ContractorCard({required this.row, required this.ward});
  final Map<String, dynamic> row;
  final String ward;

  static const double width = 216;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final m = (row['measures'] as Map?) ?? const {};
    double v(String k) => ((m[k] as Map?)?['value'] as num?)?.toDouble() ?? 0;
    // Each bar is "how good": share on time, share that held, share at or under the rate card.
    final bars = [('Speed', v('speed'), 'on time'), ('Durability', 1 - v('durability'), 'held 30 days'), ('Pricing', 1 - v('pricing'), 'within rate')];
    return SizedBox(
      width: width,
      child: Pressable(
        onTap: () => appRouter.push(Uri(path: '/contractor', queryParameters: {'id': '${row['id']}', 'ward': ward}).toString()),
        color: c.surfaceAlt,
        borderRadius: AppRadii.tileRadius,
        padding: const EdgeInsets.all(AppSpacing.s14),
        semanticLabel:
            '${row['name']}, ${formatInr(row['spend'] as num? ?? 0)}. ${[for (final b in bars) '${b.$1} ${formatPercent(b.$2)} ${b.$3}'].join(', ')}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${row['name']}'.replaceAll(' (synthetic)', ''), style: t.bodyStrong, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.s4),
            Text('${formatInr(row['spend'] as num? ?? 0)} · ${row['jobs']} jobs', style: t.caption),
            const Spacer(),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                for (final (i, b) in bars.indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.$1, style: t.caption.copyWith(fontSize: 12, height: 16 / 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: AppSpacing.s4),
                        ProgressBar(value: b.$2.clamp(0.0, 1.0), height: 4, trackColor: c.surface),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ footer

/// The one synthetic-data line, on Home only; taps through to About.
class _DataLine extends ConsumerWidget {
  const _DataLine();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final disclaimer = ref.watch(mapDataProvider).value?.disclaimer ?? kDefaultDisclaimer;
    final text = '${context.tr(disclaimer)} ${context.tr('Not a BMC app.')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s8, AppSpacing.s40, AppSpacing.s8, 0),
      child: Pressable(
        onTap: () => appRouter.push('/about'),
        borderRadius: AppRadii.tileRadius,
        scale: false,
        semanticLabel: '$text ${context.tr('About this data')}',
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: AppSpacing.iconSmall, color: c.textSecondary),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: Text(text, style: context.type.caption)),
          ],
        ),
      ),
    );
  }
}
