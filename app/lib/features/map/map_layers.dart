import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../officer/next_rupee.dart';
import 'complaints_heat.dart';
import 'map_data.dart';

/// What a layer builder gets: the loaded data, the current selection and the tap callbacks.
class MapLayerContext {
  const MapLayerContext({required this.data, required this.selection, required this.onWardTap, required this.onRoadTap});
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
  const LegendEntry(this.label, this.color, {this.line = false});
  final String label;
  final Color color;
  final bool line;
}

// Ward shade: share of ward spend flagged for review, five fixed steps.
const List<double> wardShareSteps = [0.30, 0.40, 0.50, 0.60];
const List<Color> wardShadeColors = [
  Color(0xFFFFF3C4),
  Color(0xFFFFD27F),
  Color(0xFFF9A350),
  Color(0xFFE5662E),
  Color(0xFFB8321E),
];

Color wardShade(double share) {
  var i = 0;
  while (i < wardShareSteps.length && share >= wardShareSteps[i]) {
    i++;
  }
  return wardShadeColors[i];
}

// Road status, most serious first (matches the engine's tie-break).
const Map<String, Color> roadStatusColors = {
  'dlp_paid': Color(0xFFC2185B),
  'fix_failed': Color(0xFFE65100),
  'over_rate': Color(0xFF6A1B9A),
  'double_billing': Color(0xFF1565C0),
  'clean': Color(0xFF2E7D32),
};
// Wording comes from the shared strings file (REQ-N-006).
final Map<String, String> roadStatusLabels = {...flagLabels, 'clean': kNoFlags};

final List<MapLayerDef> mapLayers = [
  MapLayerDef(
    id: 'wards',
    label: 'Wards',
    build: (ctx) => _WardLayer(ctx),
    legendTitle: 'Wards: share of spend needing review',
    legend: [
      LegendEntry('Under ${formatPercent(wardShareSteps[0])} flagged', wardShadeColors[0]),
      for (var i = 1; i < wardShareSteps.length; i++)
        LegendEntry(
          '${formatPercent(wardShareSteps[i - 1])}–${formatPercent(wardShareSteps[i])}',
          wardShadeColors[i],
        ),
      LegendEntry('${formatPercent(wardShareSteps.last)}+ flagged', wardShadeColors.last),
    ],
  ),
  MapLayerDef(
    id: 'roads',
    label: 'Roads',
    build: (ctx) => _RoadLayer(ctx),
    legend: [
      for (final e in roadStatusColors.entries)
        LegendEntry(roadStatusLabels[e.key]!, e.value, line: true),
    ],
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
  Set<String> build() => {for (final l in mapLayers) if (l.defaultOn) l.id};
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
    final primary = SaartheeColors.of(context).primary;
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
              for (final part in w.parts) _polygon(w, part, fill: sel == null ? 0.5 : 0.3, border: const Color(0xCC4E342E), width: 1.2),
          // Selected ward last, so its outline sits on top of its neighbours'.
          if (data.wardByCode[sel] case final w?)
            for (final part in w.parts) _polygon(w, part, fill: 0.55, border: primary, width: 3.5),
        ],
      ),
    );
  }

  Polygon<String> _polygon(Ward w, List<List<LatLng>> part, {required double fill, required Color border, required double width}) =>
      Polygon<String>(
        points: part.first,
        holePointsList: part.length > 1 ? part.sublist(1) : null,
        hitValue: w.code,
        color: wardShade(w.flaggedShare).withValues(alpha: fill),
        borderColor: border,
        borderStrokeWidth: width,
      );
}

/// Ward code labels as small pills, drawn above roads so they stay readable. Tapping one selects the ward.
class WardLabelLayer extends StatelessWidget {
  const WardLabelLayer(this.ctx, {super.key});
  final MapLayerContext ctx;

  static final Map<String, LatLng> _at = {};

  static LatLng labelPoint(Ward w) => _at[w.code] ??=
      Polygon(points: w.mainRing, labelPlacementCalculator: const PolygonLabelPlacementCalculator.polylabel()).labelPosition;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final zoom = MapCamera.of(context).zoom;
    final small = zoom < 11.3;
    return MarkerLayer(
      markers: [
        for (final w in ctx.data.wards)
          Marker(
            point: labelPoint(w),
            width: small ? 34 : 44,
            height: small ? 18 : 22,
            child: GestureDetector(
              onTap: () => ctx.onWardTap(w),
              child: Semantics(
                button: true,
                label: 'Ward ${w.code}, ${w.name}',
                excludeSemantics: true,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: w.code == ctx.selection.ward ? c.primary : c.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: w.code == ctx.selection.ward ? c.primary : const Color(0x994E342E), width: 0.8),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1))],
                  ),
                  child: Text(
                    w.code,
                    style: TextStyle(
                      fontSize: small ? 10 : 12,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: w.code == ctx.selection.ward ? c.onPrimary : const Color(0xFF3E2723),
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
    final roads = zoomedIn ? data.roads : [for (final r in data.roads) if (r.wardCode == sel.ward) r];
    if (roads.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
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
              color: roadStatusColors[r.status] ?? roadStatusColors['clean']!,
              strokeWidth: r.id == sel.road ? 8 : 5,
              borderColor: r.id == sel.road ? const Color(0xFF17251E) : Colors.white,
              borderStrokeWidth: r.id == sel.road ? 2 : 1.2,
            ),
        ],
      ),
    );
  }
}
