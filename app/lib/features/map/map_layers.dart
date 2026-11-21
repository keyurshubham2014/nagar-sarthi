import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/map/civic_map.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/blocks.dart' show StatusTone;
import '../officer/next_rupee.dart';
import 'complaints_heat.dart';
import 'map_data.dart';

/// What a layer builder gets: the loaded data, the current selection and the tap callbacks.
class MapLayerContext {
  const MapLayerContext({
    required this.data,
    required this.selection,
    required this.onWardTap,
    required this.onRoadTap,
  });
  final MapData data;
  final MapSelection selection;
  final ValueChanged<Ward> onWardTap;
  final ValueChanged<Road> onRoadTap;
}

/// Below this zoom the map shows ward shading and labels only; roads appear when zoomed in or a ward is selected.
const double kRoadsMinZoom = 12.5;

typedef MapSelection = ({String? ward, String? road});

/// What is selected on the map. A selected ward is zoomed to and highlighted; a road shows its preview card.
class MapFocus extends Notifier<MapSelection> {
  @override
  MapSelection build() => (ward: null, road: null);
  void focusWard(String? code) => state = (ward: code, road: null);
  void selectRoad(String? id) => state = (ward: state.ward, road: id);
  void clear() => state = (ward: null, road: null);
}

final mapFocusProvider = NotifierProvider<MapFocus, MapSelection>(MapFocus.new);

/// One toggleable map layer. Add a layer by appending a [MapLayerDef] to
/// [mapLayers]: it gets a toggle chip, and its [legend] shows while it is on.
/// List order is paint order (later entries draw on top).
class MapLayerDef {
  const MapLayerDef({
    required this.id,
    required this.label,
    required this.build,
    this.legend = const [],
    this.legendTitle,
    this.defaultOn = true,
  });
  final String id;
  final String label;
  final String? legendTitle;
  final Widget Function(MapLayerContext ctx) build;
  final List<LegendEntry> legend;
  final bool defaultOn;
}

class LegendEntry {
  const LegendEntry(this.label, this.color, {this.line = false, this.ring = false});
  final String label;
  final Color color;
  final bool line;

  /// Drawn as an outlined circle (e.g. an unfunded pin).
  final bool ring;
}

// Ward shade: share of ward spend flagged for review on one red ramp, clamped to this range.
const double wardShareLow = 0.25;
const double wardShareHigh = 0.70;

Color wardShade(double share, {double opacity = MapColors.wardFillOpacity}) =>
    MapColors.wardFill((share - wardShareLow) / (wardShareHigh - wardShareLow), opacity: opacity);

// Road status, most serious first (matches the engine's tie-break).
const Map<String, Color> roadStatusColors = {
  'dlp_paid': MapColors.warranty,
  'fix_failed': MapColors.failed,
  'over_rate': MapColors.aboveRate,
  'double_billing': MapColors.repeatJob,
  'clean': MapColors.road,
};

/// Status chip tone for a road status (matches [roadStatusColors]).
const Map<String, StatusTone> roadStatusTones = {
  'dlp_paid': StatusTone.info,
  'fix_failed': StatusTone.error,
  'over_rate': StatusTone.review,
  'double_billing': StatusTone.warning,
};
// Wording comes from the shared strings file (REQ-N-006).
final Map<String, String> roadStatusLabels = {...flagLabels, 'clean': kNoFlags};

final List<MapLayerDef> mapLayers = [
  MapLayerDef(
    id: 'wards',
    label: 'Wards',
    build: (ctx) => _WardLayer(ctx),
    legendTitle: 'Share of spend to review',
    // Drawn as a scale bar from the first entry to the last.
    legend: [
      LegendEntry('${formatPercent(wardShareLow)} or less', wardShade(wardShareLow)),
      LegendEntry('${formatPercent(wardShareHigh)}+', wardShade(wardShareHigh)),
    ],
  ),
  MapLayerDef(
    id: 'roads',
    label: 'Roads',
    build: (ctx) => _RoadLayer(ctx),
    legend: [for (final e in roadStatusColors.entries) LegendEntry(roadStatusLabels[e.key]!, e.value, line: true)],
  ),
  MapLayerDef(
    id: nextRupeeLayerId,
    label: 'Next rupee',
    legendTitle: 'Next rupee pins',
    defaultOn: false,
    legend: nextRupeeLegend,
    build: (_) => const NextRupeeLayer(),
  ),
  MapLayerDef(
    id: 'complaints',
    label: 'Complaints',
    legendTitle: kHeatRepeat,
    defaultOn: false,
    legend: [
      LegendEntry('Under ${heatSteps[0]}', heatColors[0]),
      LegendEntry('${heatSteps[0]}–${heatSteps[1] - 1}', heatColors[1]),
      LegendEntry('${heatSteps[1]}+', heatColors[2]),
    ],
    build: (_) => const ComplaintsHeatLayer(),
  ),
];

const String nextRupeeLayerId = 'next_rupee';

/// Which layers are on. A provider so panels can turn a layer on (next rupee).
class VisibleLayers extends Notifier<Set<String>> {
  @override
  Set<String> build() => {
    for (final l in mapLayers)
      if (l.defaultOn) l.id,
  };
  void set(String id, bool on) => state = on ? {...state, id} : ({...state}..remove(id));
}

final visibleLayersProvider = NotifierProvider<VisibleLayers, Set<String>>(VisibleLayers.new);

class _WardLayer extends StatefulWidget {
  const _WardLayer(this.ctx);
  final MapLayerContext ctx;
  @override
  State<_WardLayer> createState() => _WardLayerState();
}

class _WardLayerState extends State<_WardLayer> {
  final LayerHitNotifier<String> _hit = ValueNotifier(null);

  @override
  void dispose() {
    _hit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data;
    final sel = widget.ctx.selection.ward;
    final dim = sel == null ? 1.0 : MapColors.dimmed;
    return GestureDetector(
      onTap: () {
        final code = _hit.value?.hitValues.firstOrNull;
        if (code != null) widget.ctx.onWardTap(data.wardByCode[code]!);
      },
      child: PolygonLayer<String>(
        hitNotifier: _hit,
        polygons: [
          for (final w in data.wards)
            if (w.code != sel)
              for (final part in w.parts)
                _polygon(
                  w,
                  part,
                  fill: MapColors.wardFillOpacity * dim,
                  border: MapColors.wardOutline,
                  width: MapColors.wardOutlineWidth,
                ),
          // Selected ward last, so its outline sits on top of its neighbours'.
          if (data.wardByCode[sel] case final w?)
            for (final part in w.parts)
              _polygon(
                w,
                part,
                fill: MapColors.wardFillOpacity,
                border: MapColors.selectedOutline,
                width: MapColors.selectedOutlineWidth,
              ),
        ],
      ),
    );
  }

  Polygon<String> _polygon(
    Ward w,
    List<List<LatLng>> part, {
    required double fill,
    required Color border,
    required double width,
  }) => Polygon<String>(
    points: part.first,
    holePointsList: part.length > 1 ? part.sublist(1) : null,
    hitValue: w.code,
    color: wardShade(w.flaggedShare, opacity: fill),
    borderColor: border,
    borderStrokeWidth: width,
  );
}

/// Ward code labels as small pills, drawn above roads so they stay readable. Tapping one selects the ward.
class WardLabelLayer extends StatelessWidget {
  const WardLabelLayer(this.ctx, {super.key, this.clearOfPins = false});
  final MapLayerContext ctx;

  /// Next-rupee pins are showing: the selected ward's label moves to the ward's northern tip, clear of them.
  final bool clearOfPins;

  static final Map<String, LatLng> _at = {};

  static LatLng labelPoint(Ward w) => _at[w.code] ??= Polygon(
    points: w.mainRing,
    labelPlacementCalculator: const PolygonLabelPlacementCalculator.polylabel(),
  ).labelPosition;

  @override
  Widget build(BuildContext context) {
    // Smaller pills when the whole city fits on a phone, so neighbours do not collide.
    final small = MapCamera.of(context).zoom < 11.3;
    final style = (small ? Theme.of(context).textTheme.labelSmall! : context.type.label).copyWith(
      fontWeight: FontWeight.w700,
      height: 1,
    );
    return MarkerLayer(
      markers: [
        for (final w in ctx.data.wards)
          Marker(
            point: clearOfPins && w.code == ctx.selection.ward
                ? w.mainRing.reduce((a, b) => a.latitude >= b.latitude ? a : b)
                : labelPoint(w),
            alignment: clearOfPins && w.code == ctx.selection.ward ? Alignment.topCenter : Alignment.center,
            width: 48,
            height: 26,
            child: GestureDetector(
              onTap: () => ctx.onWardTap(w),
              child: Semantics(
                button: true,
                label: 'Ward ${w.code}, ${w.name}',
                excludeSemantics: true,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: small ? AppSpacing.s4 + 2 : AppSpacing.s8,
                      vertical: small ? 3 : AppSpacing.s4,
                    ),
                    decoration: ShapeDecoration(
                      color: w.code == ctx.selection.ward ? MapColors.pin : MapColors.label,
                      shape: AppRadii.pill,
                      shadows: AppElevation.soft(SaartheeColors.light),
                    ),
                    child: Text(
                      w.code,
                      maxLines: 1,
                      style: style.copyWith(
                        color: w.code == ctx.selection.ward ? MapColors.onPin : MapColors.labelText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoadLayer extends StatefulWidget {
  const _RoadLayer(this.ctx);
  final MapLayerContext ctx;
  @override
  State<_RoadLayer> createState() => _RoadLayerState();
}

class _RoadLayerState extends State<_RoadLayer> {
  final LayerHitNotifier<String> _hit = ValueNotifier(null);

  @override
  void dispose() {
    _hit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data;
    final sel = widget.ctx.selection;
    final zoomedIn = MapCamera.of(context).zoom >= kRoadsMinZoom;
    // City zoom: no roads unless a ward is selected, then only that ward's.
    final roads = zoomedIn
        ? data.roads
        : [
            for (final r in data.roads)
              if (r.wardCode == sel.ward) r,
          ];
    if (roads.isEmpty) return const SizedBox.shrink();
    // Fades in when roads first appear (zoom in, or a ward is picked).
    return TweenAnimationBuilder<double>(
      key: ValueKey((zoomedIn, sel.ward)),
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.of(context, AppMotion.standard),
      builder: (context, o, child) => Opacity(opacity: o, child: child),
      child: GestureDetector(
        onTap: () {
          final id = _hit.value?.hitValues.firstOrNull;
          if (id != null) widget.ctx.onRoadTap(data.roadById[id]!);
        },
        child: PolylineLayer<String>(
          hitNotifier: _hit,
          minimumHitbox: 14,
          polylines: [
            for (final r in roads)
              Polyline<String>(
                points: r.points,
                hitValue: r.id,
                color: roadStatusColors[r.status] ?? MapColors.road,
                strokeWidth: r.id == sel.road ? 7 : (r.status == 'clean' ? 3 : 4),
                borderColor: r.id == sel.road ? MapColors.selectedOutline : MapColors.roadCasing,
                borderStrokeWidth: r.id == sel.road ? 2 : 1,
              ),
          ],
        ),
      ),
    );
  }
}
