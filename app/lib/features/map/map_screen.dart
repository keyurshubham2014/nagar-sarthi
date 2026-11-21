import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/map/civic_map.dart';
import '../../core/widgets/ui.dart';
import '../officer/officer_data.dart' show roadDetailProvider, wardDetailProvider;
import '../officer/officer_panels.dart';
import 'map_data.dart';
import 'map_layers.dart';
import 'monsoon.dart';

/// All of Mumbai's wards, for the first view.
final LatLngBounds kMumbaiBounds = LatLngBounds(const LatLng(18.89, 72.77), const LatLng(19.28, 72.99));

/// Map tab: a full-bleed map under the status bar with floating controls only: title pill, Layers button
/// (toggles and legend in a sheet), the monsoon pill, and a preview card for the selected ward or road;
/// full details open as pages.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final MonsoonController _monsoon = ref.read(monsoonProvider.notifier);
  final MapController _map = MapController();
  bool _mapReady = false;

  // Camera ease between fits (500 ms); the listener moves the map along it.
  late final AnimationController _cam = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
    ..addListener(_stepCamera);
  MapCamera? _camFrom, _camTo;

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
    _cam.dispose();
    final monsoon = _monsoon;
    Future.microtask(monsoon.pause);
    _tilesFailedAt.dispose();
    super.dispose();
  }

  void _fitWard(String? code) {
    if (!_mapReady) return;
    final w = ref.read(mapDataProvider).value?.wardByCode[code];
    if (code != null && w == null) return;
    final mq = MediaQuery.of(context);
    // Clear of the title pill on top and the preview card at the bottom; no ward = back to the city.
    final fit = w == null
        ? CameraFit.bounds(
            bounds: kMumbaiBounds,
            padding: _cityPadding(mq, monsoon: ref.read(monsoonProvider) != null),
          )
        : CameraFit.bounds(
            bounds: w.bounds,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s32,
              mq.padding.top + AppSpacing.s56 + AppSpacing.s56, // room for the ward label at its northern tip
              AppSpacing.s32,
              mq.padding.bottom + 340, // preview card + credits
            ),
          );
    _camFrom = _map.camera;
    _camTo = fit.fit(_map.camera);
    if (AppMotion.reduced(context)) {
      _map.move(_camTo!.center, _camTo!.zoom);
    } else {
      _cam.forward(from: 0);
    }
  }

  void _stepCamera() {
    final a = _camFrom, b = _camTo;
    if (a == null || b == null) return;
    final t = Curves.easeInOutCubic.transform(_cam.value);
    _map.move(
      LatLng(
        lerpDouble(a.center.latitude, b.center.latitude, t)!,
        lerpDouble(a.center.longitude, b.center.longitude, t)!,
      ),
      lerpDouble(a.zoom, b.zoom, t)!,
    );
  }

  // The monsoon panel is taller than the pill, so the city sits higher while it is open.
  static EdgeInsets _cityPadding(MediaQueryData mq, {bool monsoon = false}) => EdgeInsets.fromLTRB(
    AppSpacing.s8,
    mq.padding.top + AppSpacing.s56,
    AppSpacing.s8,
    mq.padding.bottom + (monsoon ? 250 : AppSpacing.s56 + AppSpacing.s24),
  );

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final mq = MediaQuery.of(context);
    final async = ref.watch(mapDataProvider);
    final data = async.value;
    final visible = ref.watch(visibleLayersProvider);
    final sel = ref.watch(mapFocusProvider);
    // Only flips on enter/exit; per-day ticks rebuild the monsoon widgets alone.
    final monsoonOn = ref.watch(monsoonProvider.select((s) => s != null));
    ref.listen(mapFocusProvider.select((s) => s.ward), (_, ward) => _fitWard(ward));
    ref.listen(monsoonProvider.select((s) => s != null), (_, _) {
      if (ref.read(mapFocusProvider).ward == null) _fitWard(null);
    });
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
    // Shapes first, then monsoon roads, then pins and clusters, then ward labels (so nothing covers them).
    bool shape(MapLayerDef l) => l.id == 'wards' || l.id == 'roads';

    final road = sel.road == null ? null : data?.roadById[sel.road];
    final ward = sel.ward == null ? null : data?.wardByCode[sel.ward];
    final Widget bottom = data == null
        ? (async.hasError
              ? const SizedBox.shrink(key: ValueKey('none'))
              : Semantics(
                  key: const ValueKey('loading'),
                  label: 'Loading ward and road data',
                  child: const Skeleton(child: SkeletonBox(width: 220, height: AppSpacing.buttonHeight, radius: 28)),
                ))
        : monsoonOn
        ? const MonsoonBar(key: ValueKey('monsoon'))
        : road != null
        ? _RoadPreview(road, key: ValueKey('road ${road.id}'))
        : ward != null
        ? _WardPreview(ward, key: ValueKey('ward ${ward.code}'))
        : const _MonsoonPill(key: ValueKey('pill'));

    return ExtendUnderTabBar(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: NeemFixed.transparent),
        child: Scaffold(
          backgroundColor: c.surfaceAlt,
          body: Stack(
            children: [
              Positioned.fill(
                child: CivicMap(
                  semanticLabel: 'Map of Mumbai wards and repaired roads',
                  mapController: _map,
                  initialCameraFit: CameraFit.bounds(
                    bounds: kMumbaiBounds,
                    padding: _cityPadding(mq, monsoon: monsoonOn),
                  ),
                  onTilesFailed: _onTilesFailed,
                  onTileLoaded: _onTileLoaded,
                  onTap: () => ref.read(mapFocusProvider.notifier).clear(),
                  onMapReady: () {
                    _mapReady = true;
                    _later(() {
                      if (ref.read(mapFocusProvider).ward != null) _fitWard(ref.read(mapFocusProvider).ward);
                    });
                  },
                  layers: [
                    if (layerCtx != null) ...[for (final l in active.where(shape)) l.build(layerCtx)],
                    if (monsoonOn) ...const [MonsoonRainWash(), MonsoonRoadLayer(), MonsoonDotLayer()],
                    if (layerCtx != null) ...[
                      // Next-rupee pins above complaint clusters so their numbers stay readable.
                      for (final l in active.where((l) => !shape(l) && l.id != nextRupeeLayerId)) l.build(layerCtx),
                      for (final l in active.where((l) => l.id == nextRupeeLayerId)) l.build(layerCtx),
                      if (visible.contains('wards'))
                        WardLabelLayer(layerCtx, clearOfPins: visible.contains(nextRupeeLayerId)),
                    ],
                  ],
                ),
              ),
              // Floating top controls under the transparent status bar.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: _TitlePill(
                                  text:
                                      '${context.tr('Map')} · ${ward == null ? context.tr('All Mumbai') : 'Ward ${ward.code}'}',
                                  onTap: ward == null ? null : () => ref.read(mapFocusProvider.notifier).clear(),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            _MapButton(
                              icon: Icons.layers_outlined,
                              tooltip: context.tr('Layers'),
                              onPressed: data == null ? null : () => _showLayers(context),
                            ),
                          ],
                        ),
                        ValueListenableBuilder(
                          valueListenable: _tilesFailedAt,
                          builder: (context, failedAt, _) => failedAt == null
                              ? const SizedBox.shrink()
                              : const Padding(
                                  padding: EdgeInsets.only(top: AppSpacing.s8),
                                  child: _Banner(
                                    text: 'Map tiles could not load. Ward and road shapes are still shown.',
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (async.hasError && !async.isLoading)
                Center(
                  child: _Floating(
                    child: ErrorState(
                      message: context.tr('Could not load the money map'),
                      onRetry: () => ref.invalidate(mapDataProvider),
                    ),
                  ),
                ),
              if (data != null && data.wards.isEmpty)
                const Center(
                  child: _Floating(child: EmptyState(message: 'No ward data to show yet.')),
                ),
              // Floating bottom: monsoon pill, panel or preview card, above the tab bar, then the credits.
              Positioned(
                left: AppSpacing.s12,
                right: AppSpacing.s12,
                bottom: mq.padding.bottom + AppSpacing.s4,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: AppMotion.of(context, AppMotion.sheet),
                          reverseDuration: AppMotion.of(context, AppMotion.quick),
                          switchInCurve: AppMotion.sheetCurve,
                          switchOutCurve: AppMotion.pageOutCurve,
                          layoutBuilder: (current, previous) =>
                              Stack(alignment: Alignment.bottomCenter, children: [...previous, ?current]),
                          transitionBuilder: (child, a) => FadeTransition(
                            opacity: a,
                            child: SlideTransition(
                              position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(a),
                              child: child,
                            ),
                          ),
                          child: bottom,
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        const MapAttribution(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLayers(BuildContext context) =>
      showAppSheet<void>(context, title: context.tr('Layers'), builder: (_) => const _LayersSheet());
}

/// White floating surface for map overlays (error, empty).
class _Floating extends StatelessWidget {
  const _Floating({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Container(
      margin: const EdgeInsets.all(AppSpacing.gutter),
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.mapCard),
        boxShadow: AppElevation.floating(c),
      ),
      child: child,
    );
  }
}

/// "Map · Ward E" pill, top-left. Tapping it with a ward selected returns to the city.
class _TitlePill extends StatelessWidget {
  const _TitlePill({required this.text, this.onTap});
  final String text;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(shape: AppRadii.pill, shadows: AppElevation.soft(c)),
      child: Pressable(
        onTap: onTap,
        scale: onTap != null,
        semanticLabel: onTap == null ? text : '$text. ${context.tr('Show all of Mumbai')}',
        color: c.surface,
        borderRadius: AppRadii.pillRadius,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        child: Text(text, style: context.type.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Round white floating button (48 px) for map controls.
class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(shape: const CircleBorder(), shadows: AppElevation.soft(c)),
        child: Pressable(
          onTap: onPressed,
          semanticLabel: tooltip,
          circle: true,
          color: c.surface,
          child: SizedBox.square(
            dimension: AppSpacing.touchTarget,
            child: Icon(icon, size: AppSpacing.iconSize, color: onPressed == null ? c.textDisabled : c.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _LayersSheet extends ConsumerWidget {
  const _LayersSheet();

  static const Map<String, IconData> _icons = {
    'wards': Icons.grid_view_outlined,
    'roads': Icons.edit_road_outlined,
    'next_rupee': Icons.format_list_numbered,
    'complaints': Icons.report_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final visible = ref.watch(visibleLayersProvider);
    final monsoonOn = ref.watch(monsoonProvider.select((s) => s != null));
    final legend = [
      for (final l in mapLayers)
        if (visible.contains(l.id) && l.legend.isNotEmpty && !(monsoonOn && l.id == 'roads')) l,
      if (monsoonOn) monsoonLegend,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final l in mapLayers)
          Pressable(
            onTap: () => ref.read(visibleLayersProvider.notifier).set(l.id, !visible.contains(l.id)),
            scale: false,
            selected: visible.contains(l.id),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.s12),
            child: Row(
              children: [
                Container(
                  width: AppSpacing.categoryBadge,
                  height: AppSpacing.categoryBadge,
                  decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                  child: Icon(_icons[l.id] ?? Icons.layers_outlined, size: AppSpacing.iconSmall, color: c.textPrimary),
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr(l.label), style: t.bodyStrong),
                      Text(context.tr(_layerHint[l.id] ?? ''), style: t.caption),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                ExcludeSemantics(
                  child: Switch(value: visible.contains(l.id), onChanged: (on) => ref.read(visibleLayersProvider.notifier).set(l.id, on)),
                ),
              ],
            ),
          ),
        const SectionBreak(),
        Gutter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.tr('Legend'), style: t.title),
              if (legend.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s8),
                  child: Text(context.tr('Turn a layer on to see its legend.'), style: t.caption),
                ),
              for (final l in legend) ...[
                const SizedBox(height: AppSpacing.s16),
                Text(context.tr(l.legendTitle ?? l.label), style: t.label),
                const SizedBox(height: AppSpacing.s8),
                if (l.id == 'wards') _ScaleBar(l.legend) else _LegendItems(l.legend),
              ],
              const SizedBox(height: AppSpacing.s24),
              Text(
                'Ward boundaries: OpenCity / Oorvani Foundation via bharatlas (CC0). Map: OpenStreetMap contributors.',
                style: t.caption,
              ),
              const SizedBox(height: AppSpacing.s16),
            ],
          ),
        ),
      ],
    );
  }
}

/// The ward ramp as one bar, low on the left, high on the right.
class _ScaleBar extends StatelessWidget {
  const _ScaleBar(this.ends);
  final List<LegendEntry> ends;
  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 12,
          decoration: ShapeDecoration(
            shape: AppRadii.pill,
            gradient: LinearGradient(colors: [ends.first.color, ends.last.color]),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Row(
          children: [
            Expanded(child: Text('${context.tr('Low')} · ${ends.first.label}', style: t.caption)),
            Text('${context.tr('High')} · ${ends.last.label}', style: t.caption),
          ],
        ),
      ],
    );
  }
}

class _LegendItems extends StatelessWidget {
  const _LegendItems(this.entries);
  final List<LegendEntry> entries;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Center(
                    child: Container(
                      width: e.line ? 24 : 14,
                      height: e.line ? 4 : 14,
                      decoration: e.line
                          ? ShapeDecoration(color: e.color, shape: AppRadii.pill)
                          : BoxDecoration(
                              color: e.ring ? c.surface : e.color,
                              shape: BoxShape.circle,
                              border: e.ring ? Border.all(color: e.color, width: 2) : null,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(child: Text(e.label, style: context.type.body)),
              ],
            ),
          ),
      ],
    );
  }
}

const Map<String, String> _layerHint = {
  'wards': 'Shaded by the share of spend needing review',
  'roads': 'Coloured by flag; shown when zoomed in or a ward is selected',
  'next_rupee': 'Ranked repairs for the selected ward',
  'complaints': 'Open and repeat complaints, clustered',
};

/// Black "Play the monsoon" pill; it expands into the monsoon panel.
class _MonsoonPill extends ConsumerWidget {
  const _MonsoonPill({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(shape: AppRadii.pill, shadows: AppElevation.floating(c)),
      child: Pressable(
        haptic: true,
        color: c.primaryDark,
        pressedColor: c.primary,
        borderRadius: AppRadii.pillRadius,
        semanticLabel: context.tr('Play the monsoon'),
        onTap: () async {
          final s = await ref.read(seasonProvider.future);
          ref.read(monsoonProvider.notifier).play(s.last);
        },
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s20, AppSpacing.s12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, color: c.onToast),
            const SizedBox(width: AppSpacing.s8),
            Flexible(
              child: Text(
                context.tr('Play the monsoon'),
                style: context.type.bodyStrong.copyWith(color: c.onToast, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating preview card: grabber, title block with close, [body], one black button. Swipe down closes it.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.action,
    required this.onAction,
    required this.onClose,
  });
  final String title;
  final String subtitle;
  final List<Widget> body;
  final String action;
  final VoidCallback onAction;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    var dragged = 0.0; // Lives for one drag: nothing rebuilds the card mid-gesture.
    return GestureDetector(
      onVerticalDragStart: (_) => dragged = 0,
      onVerticalDragUpdate: (d) => dragged += d.delta.dy,
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 200 || dragged > 48) onClose();
      },
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.mapCard),
          boxShadow: AppElevation.floating(c),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s8, AppSpacing.s8, AppSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.s12),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: ShapeDecoration(color: c.borderStrong, shape: AppRadii.pill),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: t.headline, maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (subtitle.isNotEmpty)
                          Text(subtitle, style: t.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
                RoundIconButton(icon: Icons.close, tooltip: context.tr('Close'), onPressed: onClose),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...body,
                  const SizedBox(height: AppSpacing.s16),
                  PrimaryButton(label: action, onPressed: onAction),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WardPreview extends ConsumerWidget {
  const _WardPreview(this.w, {super.key});
  final Ward w;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final t = context.type;
    final budget = w.data['budget'] as num?;
    final ofBudget = budget == null || budget == 0 ? null : w.spend / budget;
    final failed = ((ref.watch(wardDetailProvider(w.code)).value?['by_flag_type'] as Map?)?['fix_failed'] as Map?)?['count'] as num?;
    return _PreviewCard(
      title: 'Ward ${w.code}',
      subtitle: w.name == w.code ? '' : w.name,
      body: [
        const SizedBox(height: AppSpacing.s12),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: AppSpacing.s8,
          children: [
            AnimatedCount(
              value: w.flaggedInr,
              format: formatInr,
              style: t.figure.copyWith(color: c.error),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${context.tr('to review')} · ${formatPercent(w.flaggedShare)} ${context.tr('of spend')}',
                style: t.caption,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        StatRow(
          tiles: [
            StatTile(
              value: ofBudget == null ? '—' : formatPercent(ofBudget),
              label: context.tr('of budget spent'),
              color: (ofBudget ?? 0) > 1 ? c.error : null,
            ),
            StatTile(value: failed == null ? '…' : '$failed', label: context.tr('failed repairs'), color: (failed ?? 0) > 0 ? c.error : null),
          ],
        ),
      ],
      action: context.tr('Open ward'),
      onAction: () => openWard(w.code),
      onClose: () => ref.read(mapFocusProvider.notifier).clear(),
    );
  }
}

class _RoadPreview extends ConsumerWidget {
  const _RoadPreview(this.r, {super.key});
  final Road r;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final type = r.data['road_type'] as String?;
    final jobs = (ref.watch(roadDetailProvider(r.id)).value?['work_orders'] as List?)?.length;
    return _PreviewCard(
      title: r.name,
      subtitle: ['Ward ${r.wardCode}', ?type].join(' · '),
      body: [
        const SizedBox(height: AppSpacing.s12),
        Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(
            flagShortLabels[r.status] ?? kNoFlags,
            tone: roadStatusTones[r.status] ?? StatusTone.neutral,
            dot: true,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: AppSpacing.s8,
          children: [
            Text(formatInr(r.spend), style: t.figure),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                jobs == null
                    ? context.tr('spent on this road')
                    : '${context.tr('spent on this road')} · ${context.tr(jobs == 1 ? '1 work order' : '{n} work orders', {'n': '$jobs'})}',
                style: t.caption,
              ),
            ),
          ],
        ),
      ],
      action: context.tr('Open road'),
      onAction: () => openRoad(r.id),
      onClose: () => ref.read(mapFocusProvider.notifier).selectRoad(null),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
      decoration: BoxDecoration(
        color: c.warningTint,
        borderRadius: AppRadii.tileRadius,
        boxShadow: AppElevation.soft(c),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: AppSpacing.iconSmall, color: c.warning),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(text, style: context.type.caption.copyWith(color: c.warning)),
          ),
        ],
      ),
    );
  }
}
