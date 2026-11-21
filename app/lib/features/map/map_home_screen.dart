import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/map/civic_map.dart';
import '../../core/flag_strings.dart';
import '../../core/theme/tokens.dart';
import '../citizen/citizen_panels.dart';
import '../corporator/corporator_panels.dart';
import '../officer/officer_data.dart';
import '../officer/officer_panels.dart';
import '../officer/panel.dart';
import 'map_data.dart';
import 'map_layers.dart';
import 'map_sheets.dart';
import 'monsoon.dart';

/// Money map home (REQ-F-016). Tap handling is injectable: later tasks pass
/// [onWardTap] / [onRoadTap] (or replace the default sheets in map_sheets.dart).
class MapHomeScreen extends ConsumerStatefulWidget {
  const MapHomeScreen({super.key, this.onWardTap, this.onRoadTap});

  final void Function(BuildContext context, Ward ward)? onWardTap;
  final void Function(BuildContext context, Road road)? onRoadTap;

  @override
  ConsumerState<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends ConsumerState<MapHomeScreen> with WidgetsBindingObserver {
  late final MonsoonController _monsoon = ref.read(monsoonProvider.notifier);

  // When tiles last failed; cleared by a tile that loads later. A notifier, so only the banner rebuilds.
  final ValueNotifier<DateTime?> _tilesFailedAt = ValueNotifier(null);
  bool? _legendOpen; // null: open on wide screens, collapsed on phones

  // Tile events arrive mid-frame; defer the change.
  void _later(VoidCallback f) => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) f();
  });

  void _onTilesFailed() {
    if (_tilesFailedAt.value == null) _later(() => _tilesFailedAt.value = DateTime.now());
  }

  void _onTileLoaded(DateTime at) {
    final failed = _tilesFailedAt.value;
    if (failed != null && at.isAfter(failed)) _later(() => _tilesFailedAt.value = null);
  }

  // The monsoon timer must stop when the map is covered, left or the app goes to the background.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _monsoon.pause();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode turns off when another route covers this one.
    if (!TickerMode.valuesOf(context).enabled) _later(_monsoon.pause);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final monsoon = _monsoon;
    Future.microtask(monsoon.pause);
    _tilesFailedAt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final async = ref.watch(mapDataProvider);
    final data = async.value;
    final disclaimer = data?.disclaimer ?? kDefaultDisclaimer;
    final visible = ref.watch(visibleLayersProvider);
    final legendOpen = _legendOpen ?? MediaQuery.sizeOf(context).width >= 600;
    final wide = MediaQuery.sizeOf(context).width >= kSidePanelBreakpoint;
    // Only flips on enter/exit; per-day ticks rebuild the monsoon widgets alone.
    final monsoonOn = ref.watch(monsoonProvider.select((s) => s != null));
    final active = [
      for (final l in mapLayers)
        if (visible.contains(l.id) && !(monsoonOn && l.id == 'roads')) l,
    ];
    final legendLayers = [...active, if (monsoonOn) monsoonLegend];

    final layerCtx = data == null
        ? null
        : MapLayerContext(
            data: data,
            onWardTap: (w) => (widget.onWardTap ?? showWardSheet)(context, w),
            onRoadTap: (r) => (widget.onRoadTap ?? showRoadSheet)(context, r),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nagar Sarthi'),
        actions: [
          IconButton(
            tooltip: kScorecardsTitle,
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => openScorecards(context),
          ),
          IconButton(
            tooltip: 'Departments',
            icon: const Icon(Icons.apartment_outlined),
            onPressed: () => showDepartmentsSheet(context),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'notice') showDataNotice(context, disclaimer);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'notice', child: Text('About this data')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CivicMap(
              semanticLabel: 'Map of Mumbai wards and repaired roads',
              onTilesFailed: _onTilesFailed,
              onTileLoaded: _onTileLoaded,
              layers: [
                if (layerCtx != null) for (final l in active) l.build(layerCtx),
                if (monsoonOn) ...const [MonsoonRainWash(), MonsoonRoadLayer(), MonsoonDotLayer()],
              ],
            ),
          ),
          // Layer toggle chips: one per entry in mapLayers.
          Positioned(
            top: AppSpacing.s8,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
              child: Row(
                children: [
                  for (final l in mapLayers)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.s8),
                      child: FilterChip(
                        label: Text(l.label),
                        selected: visible.contains(l.id),
                        onSelected: (on) {
                          ref.read(visibleLayersProvider.notifier).set(l.id, on);
                          if (on && l.id == nextRupeeLayerId && ref.read(nextRupeeWardProvider) == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tap a ward, then "$kNextRupeeAction"')),
                            );
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (data != null)
            Positioned(
              top: 56,
              left: AppSpacing.s8,
              right: wide ? null : AppSpacing.s8,
              width: wide ? 400 : null,
              child: WarrantyHeroCard(data: data),
            ),
          if (async.isLoading) ...[
            const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
            const Center(child: _LoadingCard()),
          ],
          if (async.hasError && !async.isLoading)
            Center(
              child: _ErrorCard(
                message: '${async.error}',
                onRetry: () => ref.invalidate(mapDataProvider),
              ),
            ),
          Positioned(
            left: AppSpacing.s8,
            right: AppSpacing.s8,
            bottom: AppSpacing.s24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Citizen entry on the left, legend on the right; the legend wraps below if both don't fit.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  runSpacing: AppSpacing.s8,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: 'citizen',
                      onPressed: () => openCitizenHub(context),
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text(kCitizenAction),
                    ),
                    if (data != null && legendLayers.any((l) => l.legend.isNotEmpty))
                      _Legend(
                        layers: legendLayers,
                        open: legendOpen,
                        onToggle: () => setState(() => _legendOpen = !legendOpen),
                      ),
                  ],
                ),
                if (data != null) ...[
                  const SizedBox(height: AppSpacing.s8),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: MonsoonBar(wide: wide),
                    ),
                  ),
                ],
                ValueListenableBuilder(
                  valueListenable: _tilesFailedAt,
                  builder: (context, failedAt, _) => failedAt == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s8),
                          child: _Banner(
                            icon: Icons.cloud_off_outlined,
                            text: 'Map tiles could not load. Ward and road shapes are still shown.',
                            bg: c.warningTint,
                            fg: c.warning,
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.s8),
                _Banner(
                  icon: Icons.info_outline,
                  text: disclaimer,
                  bg: c.infoTint,
                  fg: c.info,
                  onTap: () => showDataNotice(context, disclaimer),
                ),
              ],
            ),
          ),
          const Positioned.fill(child: PanelHost()),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.s16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: AppSpacing.s12),
          Text('Loading ward and road data…'),
        ],
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Card(
        margin: const EdgeInsets.all(AppSpacing.s16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: c.error, size: 32),
              const SizedBox(height: AppSpacing.s8),
              Text('Could not load the money map', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.s4),
              Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.s12),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.bg, required this.fg, this.onTap});
  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: bg,
    borderRadius: AppRadii.controlRadius,
    child: InkWell(
      borderRadius: AppRadii.controlRadius,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
        child: Row(
          children: [
            Icon(icon, size: AppSpacing.iconSmall, color: fg),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.layers, required this.open, required this.onToggle});
  final List<MapLayerDef> layers;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Legend', style: t.labelLarge),
                  Icon(open ? Icons.expand_more : Icons.expand_less, size: AppSpacing.iconSmall),
                ],
              ),
            ),
            if (open)
              for (final l in layers)
                if (l.legend.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(l.legendTitle ?? l.label, style: t.labelMedium),
                  for (final e in l.legend)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: e.line ? 4 : 12,
                            decoration: BoxDecoration(color: e.color, borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Text(e.label, style: t.bodySmall),
                        ],
                      ),
                    ),
                ],
          ],
        ),
      ),
    );
  }
}
