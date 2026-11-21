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
    this.onTileLoaded,
    this.initialCameraFit,
    this.onTap,
    this.onMapReady,
  });

  /// The camera exists (fitCamera may be called from now on).
  final VoidCallback? onMapReady;

  /// Overrides [center] / [initialZoom] when set (e.g. fit all of Mumbai).
  final CameraFit? initialCameraFit;

  /// Tap on the map where no layer handled it.
  final VoidCallback? onTap;

  final String semanticLabel;
  final LatLng center;
  final double initialZoom;
  final List<Widget> layers;
  final bool muted;
  final MapController? mapController;

  /// Called on each tile load error; the caller decides how to show it.
  final VoidCallback? onTilesFailed;

  /// Called with the load time whenever a tile has loaded without error.
  final ValueChanged<DateTime>? onTileLoaded;

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
            initialCameraFit: initialCameraFit,
            onTap: onTap == null ? null : (_, _) => onTap!(),
            onMapReady: onMapReady,
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
              tileBuilder: (context, tile, image) {
                final at = image.loadFinishedAt;
                if (at != null && !image.loadError) onTileLoaded?.call(at);
                return muted ? ColorFiltered(colorFilter: mutedFilter, child: tile) : tile;
              },
            ),
            ...layers,
            // Wraps on narrow phones instead of cutting the credit off.
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.only(left: 64),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: c.surface.withValues(alpha: 0.85),
                child: Text(
                  '© OpenStreetMap contributors · Ward boundaries: OpenCity / Oorvani Foundation via bharatlas (CC0)',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, height: 1.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
