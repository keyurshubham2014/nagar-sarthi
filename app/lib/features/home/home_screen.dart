import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../core/auth/session.dart';
import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/prefs.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/saarthee.dart';
import '../audit/audit_screen.dart';
import '../auth/account_sheet.dart';
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
import '../ward/ward_picker.dart';

const int _mapTab = 1;
const int _actTab = 2;

/// Home tab, role-aware (signed out behaves as citizen): the green header with
/// the ward line, greeting, language and account buttons, one prominent action
/// card, then the role's cards.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final role = ref.watch(sessionProvider.select((s) => s?.role));
    final ward = ref.watch(chosenWardProvider);
    final data = ref.watch(mapDataProvider);
    final shell = StatefulNavigationShell.maybeOf(context);
    void goTab(int i) => shell?.goBranch(i);

    final body = switch (role) {
      'officer' => _OfficerHome(ward: ward),
      'corporator' => _CorporatorHome(ward: ward),
      _ => _CitizenHome(ward: ward, onWatchMonsoon: () => _watchMonsoon(ref, goTab)),
    };
    final card = switch (role) {
      'officer' => _OfficerHeaderCard(ward: ward, onTap: () => goTab(_actTab)),
      'corporator' => HeaderActionCard(
        icon: Icons.description_outlined,
        title: kWardBrief,
        hint: 'Ward $ward on one page, in English, हिंदी or मराठी',
        onPressed: () => showWardBrief(context, ward),
      ),
      _ => SunriseActionCard(
        title: context.tr(kReportProblem),
        hint: context.tr('Pothole, waterlogging, a repair that failed'),
        onPressed: () => goTab(_actTab),
      ),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(mapDataProvider);
                ref.invalidate(wardDetailProvider(ward));
                ref.invalidate(topFlagsProvider(ward));
                ref.invalidate(nextRupeeProvider(ward));
              },
              child: ListView(
                key: const PageStorageKey('home.scroll'),
                padding: const EdgeInsets.only(bottom: AppSpacing.s40),
                children: [
                  _Header(
                    wardLabel: '${context.tr('Ward {w}', {'w': ward})}${data.value?.wardByCode[ward] == null ? '' : ' · ${data.value!.wardByCode[ward]!.name}'}',
                    role: role,
                    onWardTap: () => pickWard(context, ref),
                    card: card,
                  ),
                  ContentWidth(child: body),
                ],
              ),
            ),
            // Status-bar scrim in the band colour, so scrolled content never runs under the clock.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top,
              child: IgnorePointer(child: ColoredBox(color: c.isDark ? c.primaryDark : c.primary)),
            ),
          ],
        ),
      ),
    );
  }

  static void _watchMonsoon(WidgetRef ref, void Function(int) goTab) {
    goTab(_mapTab);
    ref.read(seasonProvider.future).then((s) => ref.read(monsoonProvider.notifier).play(s.last));
  }
}

/// Green band: ward line (tap to change), greeting, language and account buttons,
/// and the action card hanging half below the band (Saarthee HomeHeader).
class _Header extends StatelessWidget {
  const _Header({required this.wardLabel, required this.role, required this.onWardTap, required this.card});
  final String wardLabel;
  final String? role;
  final VoidCallback onWardTap;
  final Widget card;

  static const double overlap = AppSpacing.reportCardMinHeight / 2;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final band = c.isDark ? c.primaryDark : c.primary;
    final onBand = c.isDark ? c.textPrimary : NeemFixed.white;
    final subtle = c.isDark ? c.onPrimaryContainer : c.onPrimarySubtle;
    return Stack(
      children: [
        Positioned(left: 0, right: 0, top: 0, bottom: overlap, child: ColoredBox(color: band)),
        Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + AppSpacing.s8),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            button: true,
                            label: '$wardLabel. ${context.tr('Change ward')}',
                            excludeSemantics: true,
                            child: InkWell(
                              onTap: onWardTap,
                              borderRadius: AppRadii.controlRadius,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on_outlined, size: AppSpacing.iconSmall, color: subtle),
                                    const SizedBox(width: AppSpacing.s4),
                                    Flexible(
                                      child: Text(wardLabel, style: t.bodyMedium?.copyWith(color: subtle), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ),
                                    Icon(Icons.expand_more, size: AppSpacing.iconSmall, color: subtle),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Semantics(header: true, child: Text(context.tr('Namaste'), style: t.displaySmall?.copyWith(color: onBand))),
                          Text(
                            role == null ? 'Nagar Sarthi' : 'Nagar Sarthi · ${context.tr(roleLabels[role] ?? role!)}',
                            style: t.bodyMedium?.copyWith(color: subtle),
                          ),
                        ],
                      ),
                    ),
                    const LanguageButton(onDark: true),
                    HeaderCircleButton(
                      tooltip: role == null ? context.tr('Sign in') : context.tr(roleLabels[role] ?? role!),
                      onDark: true,
                      onPressed: () => showAccountSheet(context),
                      child: Icon(role == null ? Icons.person_outline : Icons.person, color: onBand, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s20),
                card,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ward stat tiles: spent of budget, rupees to review, repairs failed within 30 days.
class _WardTiles extends ConsumerWidget {
  const _WardTiles({required this.ward});
  final String ward;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final v = ref.watch(wardDetailProvider(ward));
    if (v.hasError) return _Retry(text: 'Could not load ward $ward.', onRetry: () => ref.invalidate(wardDetailProvider(ward)));
    final w = v.value;
    final budget = w?['budget'] as num? ?? 0;
    final spend = w?['spend'] as num? ?? 0;
    final failed = ((w?['by_flag_type'] as Map?)?['fix_failed'] as Map?)?['count'] as num?;
    return StatRow(
      tiles: [
        StatTile(
          value: w == null ? '—' : (budget <= 0 ? formatInr(spend) : formatPercent(spend / budget)),
          label: context.tr('of the budget spent'),
          color: spend > budget ? c.error : null,
        ),
        StatTile(value: w == null ? '—' : formatInr(w['flagged_inr'] as num? ?? 0), label: context.tr('to review')),
        StatTile(value: failed == null ? '—' : '$failed', label: context.tr('repairs failed within 30 days')),
      ],
    );
  }
}

class _CitizenHome extends ConsumerWidget {
  const _CitizenHome({required this.ward, required this.onWatchMonsoon});
  final String ward;
  final VoidCallback onWatchMonsoon;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: AppSpacing.s24),
      const _CityCard(),
      SectionHeading(context.tr('Ward {w} this monsoon', {'w': ward})),
      _WardTiles(ward: ward),
      SectionHeading(context.tr('For citizens')),
      NavCard(
        icon: Icons.timeline,
        title: context.tr(kTrackComplaint),
        subtitle: context.tr('By complaint id or by locality.'),
        onTap: () => appRouter.push('/track'),
      ),
      NavCard(
        icon: Icons.ios_share,
        title: context.tr(kReportCard),
        subtitle: context.tr('A shareable card of your ward’s road repairs.'),
        onTap: () => pushPanel(PanelPage(kReportCard, ReportCardPage(ward: ward))),
      ),
      NavCard(
        icon: Icons.question_answer_outlined,
        title: context.tr(kAskWard),
        subtitle: context.tr('A polite question to the ward office, with the figures.'),
        onTap: () => pushPanel(PanelPage(kAskWard, AskWardPage(ward: ward))),
      ),
      NavCard(
        icon: Icons.water_drop_outlined,
        title: context.tr('Watch the 2025 monsoon'),
        subtitle: context.tr('June to October on the map: complaints, repairs and repairs that failed.'),
        onTap: onWatchMonsoon,
      ),
      const _DataLine(),
    ],
  );
}

class _OfficerHeaderCard extends ConsumerWidget {
  const _OfficerHeaderCard({required this.ward, required this.onTap});
  final String ward;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inr = ref.watch(wardDetailProvider(ward)).value?['flagged_inr'] as num?;
    return HeaderActionCard(
      icon: Icons.fact_check_outlined,
      title: inr == null ? 'Rupees to review in Ward $ward' : '${formatInr(inr)} to review in Ward $ward',
      hint: 'Open the audit list',
      onPressed: onTap,
    );
  }
}

class _OfficerHome extends ConsumerWidget {
  const _OfficerHome({required this.ward});
  final String ward;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(wardDetailProvider(ward)).value;
    final bft = (w?['by_flag_type'] as Map?) ?? const {};
    final dlp = bft['dlp_paid'] as Map?;
    final nr = ref.watch(nextRupeeProvider(ward)).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading('Ward this monsoon'),
        StatRow(
          tiles: [
            StatTile(value: dlp == null ? '—' : formatInr(dlp['inr'] as num? ?? 0), label: '${dlp?['count'] ?? '—'} warranty claims to make'),
            StatTile(value: w == null ? '—' : '${(bft['fix_failed'] as Map?)?['count'] ?? 0}', label: 'repairs failed within 30 days'),
            StatTile(value: nr == null ? '—' : '${(nr['items'] as List? ?? const []).length}', label: 'items ranked for the next rupee'),
          ],
        ),
        SectionHeading('Needs your attention', trailing: TextButton(onPressed: () => StatefulNavigationShell.maybeOf(context)?.goBranch(_actTab), child: const Text('See all'))),
        _TopFlags(ward: ward),
        const SizedBox(height: AppSpacing.s8),
        NavCard(
          icon: Icons.place_outlined,
          title: kNextRupeeAction,
          subtitle: nr == null ? 'Open issues ranked by need' : 'Budget left ${formatInr(nr['remaining_budget'] as num? ?? 0)} · ranked by need',
          onTap: () => showNextRupee(ref, ward),
        ),
        NavCard(icon: Icons.account_balance_outlined, title: 'Ward $ward money trail', subtitle: 'Budget, flags by type, contractors, repair methods', onTap: () => openWard(ward)),
        _trailCard(ward),
        const _DataLine(),
      ],
    );
  }
}

class _CorporatorHome extends ConsumerWidget {
  const _CorporatorHome({required this.ward});
  final String ward;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(scorecardsProvider(ward));
    final rows = [...?(sc.value?['contractors'] as List?)].cast<Map<String, dynamic>>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading('Ward this monsoon'),
        _WardTiles(ward: ward),
        SectionHeading(
          kContractorsInWard,
          trailing: TextButton(
            onPressed: () => pushPanel(PanelPage('$kContractorsInWard · Ward $ward', ScorecardList(ward: ward))),
            child: const Text('See all'),
          ),
        ),
        if (sc.hasError)
          _Retry(text: 'Could not load contractors.', onRetry: () => ref.invalidate(scorecardsProvider(ward)))
        else if (sc.value == null)
          const LinearProgressIndicator()
        else
          for (final r in rows.where((r) => r['rated'] == true).take(3))
            NavCard(
              icon: Icons.engineering_outlined,
              title: '${r['name']}',
              subtitle: '${r['jobs']} jobs · ${formatInr(r['spend'] as num? ?? 0)}',
              onTap: () => appRouter.push(Uri(path: '/contractor', queryParameters: {'id': '${r['id']}', 'ward': ward}).toString()),
            ),
        const SectionHeading('Top items to look at'),
        _TopFlags(ward: ward),
        const SizedBox(height: AppSpacing.s8),
        _trailCard(ward),
        const _DataLine(),
      ],
    );
  }
}

Widget _trailCard(String ward) => NavCard(
  icon: Icons.account_tree_outlined,
  title: 'Complaint trail',
  subtitle: 'Ward $ward: complaints → issues → work orders → what happened',
  onTap: () => openTrail(ward),
);

/// Biggest money flags in the ward; each opens its road page on that work order.
class _TopFlags extends ConsumerWidget {
  const _TopFlags({required this.ward});
  final String ward;
  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(topFlagsProvider(ward))) {
    AsyncData(:final value) when value.isEmpty => const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Text('No flags in this ward.'),
    ),
    AsyncData(:final value) => Column(children: [for (final f in value) FlagRow(f as Map<String, dynamic>)]),
    AsyncError() => _Retry(text: 'Could not load flags.', onRetry: () => ref.invalidate(topFlagsProvider(ward))),
    _ => const LinearProgressIndicator(),
  };
}

/// "Mumbai this monsoon": the city figure from /api/meta; opens the list of wards.
class _CityCard extends ConsumerWidget {
  const _CityCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final t = Theme.of(context).textTheme;
    final async = ref.watch(mapDataProvider);
    final data = async.value;
    if (async.hasError && data == null) return _Retry(text: 'Could not load the city figures.', onRetry: () => ref.invalidate(mapDataProvider));
    final dlp = (((data?.meta['totals'] as Map?)?['flags'] as Map?)?['dlp_paid'] as Map?) ?? const {};
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius, side: BorderSide(color: c.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data == null ? null : () => pushPanel(PanelPage('Billed under warranty, by ward', DlpWardRanking(data))),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Mumbai this monsoon'), style: t.labelMedium?.copyWith(color: c.primary)),
              const SizedBox(height: AppSpacing.s4),
              Text(data == null ? '—' : formatInr(dlp['inr'] as num? ?? 0), style: t.displaySmall?.copyWith(color: flagColor('dlp_paid'))),
              Text(context.tr('billed on roads under warranty — to be claimed and verified'), style: t.bodyLarge),
              const SizedBox(height: AppSpacing.s8),
              Row(
                children: [
                  Expanded(child: Text(context.tr('{n} jobs across Mumbai · tap to see wards', {'n': dlp['count'] ?? '—'}), style: t.bodySmall)),
                  Icon(Icons.chevron_right, color: c.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one synthetic-data line, on Home only; taps through to About.
class _DataLine extends ConsumerWidget {
  const _DataLine();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final disclaimer = ref.watch(mapDataProvider).value?.disclaimer ?? kDefaultDisclaimer;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s24),
      child: InkWell(
        borderRadius: AppRadii.controlRadius,
        onTap: () => appRouter.push('/about'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s8),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: AppSpacing.iconSmall, color: c.textSecondary),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  '${context.tr(disclaimer)} ${context.tr('Not a BMC app.')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(text)),
      TextButton(onPressed: onRetry, child: Text(context.tr('Retry'))),
    ],
  );
}
