import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/tokens.dart';

export 'package:latlong2/latlong.dart' show LatLng;

/// Adapted from Saarthee `core/map/civic_map.dart`: full-height, interactive
/// base map with extra [layers] on top of OSM tiles. Shapes in [layers] come
/// from local assets, so they still draw when tiles fail ([onTilesFailed]).
const String kMapTileUrl = String.fromEnvironment(
  'MAP_TILE_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

/// Mumbai, roughly centred on the island city and suburbs.
const LatLng kMumbaiCenter = LatLng(19.07, 72.88);

class CivicMap extends StatelessWidget {
  const CivicMap({
    super.key,
    required this.semanticLabel,
    this.center = kMumbaiCenter,
    this.initialZoom = 11,
    this.layers = const [],
    this.muted = true,
    this.mapController,
    this.onTilesFailed,
  });

  final String semanticLabel;
  final LatLng center;
  final double initialZoom;
  final List<Widget> layers;
  final bool muted;
  final MapController? mapController;

  /// Called on each tile load error; the caller decides how to show it.
  final VoidCallback? onTilesFailed;

  /// Desaturates and lightens raster tiles so data colours stand out.
  static const ColorFilter mutedFilter = ColorFilter.matrix(<double>[
    0.55, 0.35, 0.10, 0, 30, //
    0.25, 0.65, 0.10, 0, 30, //
    0.25, 0.35, 0.40, 0, 30, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Semantics(
      label: semanticLabel,
      container: true,
      child: ColoredBox(
        color: c.surfaceAlt,
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: initialZoom,
            minZoom: 9,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: kMapTileUrl,
              userAgentPackageName: 'in.nagarsarthi.nagar_sarthi',
              errorTileCallback: (_, _, _) => onTilesFailed?.call(),
              tileBuilder: muted
                  ? (context, tile, _) =>
                        ColorFiltered(colorFilter: mutedFilter, child: tile)
                  : null,
            ),
            ...layers,
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
      ),
    );
  }
}
