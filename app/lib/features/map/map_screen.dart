import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/map/civic_map.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/saarthee.dart';
import '../officer/officer_panels.dart';
import '../officer/panel.dart';
import 'map_data.dart';
import 'map_layers.dart';
import 'monsoon.dart';

/// All of Mumbai's wards, for the first view.
final LatLngBounds kMumbaiBounds = LatLngBounds(const LatLng(18.89, 72.77), const LatLng(19.28, 72.99));

/// Map tab: the map and nothing competing with it. One Layers button (toggles
/// and legend in a sheet), the monsoon pill, and a small preview card for the
/// selected ward or road; full details open as pages.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with WidgetsBindingObserver {
  late final MonsoonController _monsoon = ref.read(monsoonProvider.notifier);
  final MapController _map = MapController();
  bool _mapReady = false;

  // When tiles last failed; cleared by a tile that loads later. A notifier, so only the banner rebuilds.
  final ValueNotifier<DateTime?> _tilesFailedAt = ValueNotifier(null);

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
    // TickerMode turns off when another route or tab covers this one.
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

  void _fitWard(String? code) {
    final w = ref.read(mapDataProvider).value?.wardByCode[code];
    if (w == null || !_mapReady) return;
    _map.fitCamera(CameraFit.bounds(bounds: w.bounds, padding: const EdgeInsets.fromLTRB(32, 32, 32, 180)));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mapDataProvider);
    final data = async.value;
    final visible = ref.watch(visibleLayersProvider);
    final sel = ref.watch(mapFocusProvider);
    // Only flips on enter/exit; per-day ticks rebuild the monsoon widgets alone.
    final monsoonOn = ref.watch(monsoonProvider.select((s) => s != null));
    ref.listen(mapFocusProvider.select((s) => s.ward), (_, ward) => _fitWard(ward));
    // A ward chosen before the data arrived (e.g. from a page) is fitted once it loads.
    ref.listen(mapDataProvider, (prev, next) {
      if (prev?.value == null && next.value != null) _later(() => _fitWard(ref.read(mapFocusProvider).ward));
    });

    final active = [
      for (final l in mapLayers)
        if (visible.contains(l.id) && !(monsoonOn && l.id == 'roads')) l,
    ];
    final layerCtx = data == null
        ? null
        : MapLayerContext(
            data: data,
            selection: sel,
            onWardTap: (w) => ref.read(mapFocusProvider.notifier).focusWard(w.code),
            onRoadTap: (r) => ref.read(mapFocusProvider.notifier).selectRoad(r.id),
          );
    // Ward labels go right above the last of wards/roads, so roads never cover them.
    final labelsAfter = active.lastIndexWhere((l) => l.id == 'wards' || l.id == 'roads');

    return Scaffold(
      appBar: SaartheeAppBar(
        title: context.tr('Map'),
        showBack: false,
        actions: [
          TextButton.icon(
            onPressed: data == null ? null : () => _showLayers(context),
            icon: const Icon(Icons.layers_outlined),
            label: Text(context.tr('Layers')),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CivicMap(
              semanticLabel: 'Map of Mumbai wards and repaired roads',
              mapController: _map,
              // Room at the bottom for the monsoon pill and the credit line.
              initialCameraFit: CameraFit.bounds(bounds: kMumbaiBounds, padding: const EdgeInsets.fromLTRB(8, 8, 8, 72)),
              onTilesFailed: _onTilesFailed,
              onTileLoaded: _onTileLoaded,
              onTap: () => ref.read(mapFocusProvider.notifier).clear(),
              onMapReady: () {
                _mapReady = true;
                _later(() => _fitWard(ref.read(mapFocusProvider).ward));
              },
              layers: [
                if (layerCtx != null)
                  for (final (i, l) in active.indexed) ...[
                    l.build(layerCtx),
                    if (i == labelsAfter && visible.contains('wards')) WardLabelLayer(layerCtx),
                  ],
                if (monsoonOn) ...const [MonsoonRainWash(), MonsoonRoadLayer(), MonsoonDotLayer()],
              ],
            ),
          ),
          if (async.isLoading) ...[
            const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
            const Center(child: _LoadingCard()),
          ],
          if (async.hasError && !async.isLoading)
            Center(
              child: _ErrorCard(message: '${async.error}', onRetry: () => ref.invalidate(mapDataProvider)),
            ),
          Positioned(
            top: AppSpacing.s8,
            left: AppSpacing.s8,
            right: AppSpacing.s8,
            child: ValueListenableBuilder(
              valueListenable: _tilesFailedAt,
              builder: (context, failedAt, _) => failedAt == null
                  ? const SizedBox.shrink()
                  : const _Banner(text: 'Map tiles could not load. Ward and road shapes are still shown.'),
            ),
          ),
          if (data != null)
            Positioned(
              left: AppSpacing.s12,
              right: AppSpacing.s12,
              // Clear of the attribution line.
              bottom: AppSpacing.s40,
              child: Align(
                alignment: Alignment.bottomRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: monsoonOn
                      ? const MonsoonBar()
                      : sel.road != null && data.roadById[sel.road] != null
                      ? _RoadPreview(data.roadById[sel.road]!)
                      : sel.ward != null && data.wardByCode[sel.ward] != null
                      ? _WardPreview(data.wardByCode[sel.ward]!)
                      : const _MonsoonPill(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showLayers(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _LayersSheet(),
  );
}

class _LayersSheet extends ConsumerWidget {
  const _LayersSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final visible = ref.watch(visibleLayersProvider);
    final monsoonOn = ref.watch(monsoonProvider.select((s) => s != null));
    final legend = [
      for (final l in mapLayers)
        if (visible.contains(l.id) && l.legend.isNotEmpty && !(monsoonOn && l.id == 'roads')) l,
      if (monsoonOn) monsoonLegend,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.s24),
        children: [
          Text(context.tr('Layers'), style: t.titleLarge),
          const SizedBox(height: AppSpacing.s8),
          for (final l in mapLayers)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr(l.label)),
              subtitle: Text(context.tr(_layerHint[l.id] ?? '')),
              value: visible.contains(l.id),
              onChanged: (on) => ref.read(visibleLayersProvider.notifier).set(l.id, on),
            ),
          const Divider(height: AppSpacing.s24),
          Text(context.tr('Legend'), style: t.titleLarge),
          if (legend.isEmpty) Text(context.tr('Turn a layer on to see its legend.'), style: t.bodySmall),
          for (final l in legend) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(l.legendTitle ?? l.label, style: t.titleSmall),
            for (final e in l.legend)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s4),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: e.line ? 5 : 14,
                      decoration: BoxDecoration(color: e.color, borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(child: Text(e.label, style: t.bodyMedium)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.s16),
          Text(
            'Ward boundaries: OpenCity / Oorvani Foundation via bharatlas (CC0). Map: OpenStreetMap contributors.',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}

const Map<String, String> _layerHint = {
  'wards': 'Shaded by the share of spend needing review',
  'roads': 'Coloured by flag; shown when zoomed in or a ward is selected',
  'next_rupee': 'Ranked repairs for the selected ward',
  'complaints': 'Open and repeat complaints, clustered',
};

/// Compact "Play the monsoon" pill; it expands into the slider bar while playing.
class _MonsoonPill extends ConsumerWidget {
  const _MonsoonPill();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    return Material(
      color: c.primaryDark,
      shape: const StadiumBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () async {
          final s = await ref.read(seasonProvider.future);
          ref.read(monsoonProvider.notifier).play(s.last);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s12, AppSpacing.s20, AppSpacing.s12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow, color: c.onToast),
              const SizedBox(width: AppSpacing.s8),
              Text(context.tr('Play the monsoon'), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: c.onToast)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends ConsumerWidget {
  const _PreviewCard({required this.title, required this.lines, required this.action, required this.onAction, required this.onClose});
  final String title;
  final List<Widget> lines;
  final String action;
  final VoidCallback onAction;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    return Container(
      decoration: AppElevation.cardDecoration(c).copyWith(
        boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s4, AppSpacing.s4, AppSpacing.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis)),
              IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: onClose),
            ],
          ),
          ...lines,
          const SizedBox(height: AppSpacing.s12),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s12),
            child: FilledButton(onPressed: onAction, child: Text(action)),
          ),
        ],
      ),
    );
  }
}

class _WardPreview extends ConsumerWidget {
  const _WardPreview(this.w);
  final Ward w;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = SaartheeColors.of(context);
    return _PreviewCard(
      title: 'Ward ${w.code} · ${w.name}',
      lines: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: formatInr(w.flaggedInr), style: t.titleMedium?.copyWith(color: c.error)),
              TextSpan(text: ' ${context.tr('to review')} · ${formatPercent(w.flaggedShare)} ${context.tr('of spend')}', style: t.bodyMedium),
            ],
          ),
        ),
        Text('${context.tr('Spent')} ${formatInr(w.spend)} · ${context.tr('tap a road for its work orders')}', style: t.bodySmall),
      ],
      action: context.tr('Open ward'),
      onAction: () => openWard(w.code),
      onClose: () => ref.read(mapFocusProvider.notifier).clear(),
    );
  }
}

class _RoadPreview extends ConsumerWidget {
  const _RoadPreview(this.r);
  final Road r;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final color = roadStatusColors[r.status] ?? roadStatusColors['clean']!;
    return _PreviewCard(
      title: r.name,
      lines: [
        Align(
          alignment: Alignment.centerLeft,
          child: Tag(roadStatusLabels[r.status] ?? r.status, bg: color.withValues(alpha: 0.12), fg: color),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text('${formatInr(r.spend)} ${context.tr('spent')} · Ward ${r.wardCode}', style: t.bodyMedium),
      ],
      action: context.tr('Open road'),
      onAction: () => openRoad(r.id),
      onClose: () => ref.read(mapFocusProvider.notifier).selectRoad(null),
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
  const _Banner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Material(
      color: c.warningTint,
      borderRadius: AppRadii.controlRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: AppSpacing.iconSmall, color: c.warning),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.warning))),
          ],
        ),
      ),
    );
  }
}
