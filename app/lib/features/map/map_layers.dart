import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flag_strings.dart';
import '../../core/format.dart';
import '../officer/next_rupee.dart';
import 'map_data.dart';

/// What a layer builder gets: the loaded data and the tap callbacks.
class MapLayerContext {
  const MapLayerContext({required this.data, required this.onWardTap, required this.onRoadTap});
  final MapData data;
  final ValueChanged<Ward> onWardTap;
  final ValueChanged<Road> onRoadTap;
}

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
    return GestureDetector(
      onTap: () {
        final code = _hit.value?.hitValues.firstOrNull;
        if (code != null) widget.ctx.onWardTap(data.wardByCode[code]!);
      },
      child: PolygonLayer<String>(
        hitNotifier: _hit,
        polygons: [
          for (final w in data.wards)
            Polygon<String>(
              points: w.points,
              hitValue: w.code,
              color: wardShade(w.flaggedShare).withValues(alpha: 0.6),
              borderColor: const Color(0xFF5D4037),
              borderStrokeWidth: 1,
              label: w.code,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF3E2723)),
            ),
        ],
      ),
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
    return GestureDetector(
      onTap: () {
        final id = _hit.value?.hitValues.firstOrNull;
        if (id != null) widget.ctx.onRoadTap(data.roadById[id]!);
      },
      child: PolylineLayer<String>(
        hitNotifier: _hit,
        minimumHitbox: 12,
        polylines: [
          for (final r in data.roads)
            Polyline<String>(
              points: r.points,
              hitValue: r.id,
              color: roadStatusColors[r.status] ?? roadStatusColors['clean']!,
              strokeWidth: 4,
              borderColor: Colors.white,
              borderStrokeWidth: 1,
            ),
        ],
      ),
    );
  }
}
