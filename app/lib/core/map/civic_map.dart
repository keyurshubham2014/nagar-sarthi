import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

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
    this.interactive = true,
  });

  /// False: a still picture (no pan, zoom or taps), e.g. a mini map on a page.
  final bool interactive;

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

  /// Turns raster tiles into a light grey basemap so only the data carries colour.
  static const ColorFilter mutedFilter = ColorFilter.matrix(<double>[
    0.117, 0.393, 0.040, 0, 112, //
    0.117, 0.393, 0.040, 0, 112, //
    0.117, 0.393, 0.040, 0, 112, //
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
            interactionOptions: InteractionOptions(flags: interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none),
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
          ],
        ),
      ),
    );
  }
}

/// Required map credits, small; the screen places it above its floating controls.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});
  @override
  Widget build(BuildContext context) => Text(
    '© OpenStreetMap contributors · Ward boundaries: OpenCity / Oorvani Foundation via bharatlas (CC0)',
    textAlign: TextAlign.center,
    style: context.type.caption.copyWith(fontSize: 10, height: 1.3, color: MapColors.labelText),
  );
}

/// Map colour tokens (design overhaul §1 "Map"). The basemap is always light grey, so these do not
/// change with the theme.
class MapColors {
  const MapColors._();

  /// Ward fill ramp by share of spend to review, low → high, drawn at [wardFillOpacity].
  static const Color wardLow = Color(0xFFFDE9E7);
  static const Color wardHigh = Color(0xFFC8102E);
  static const double wardFillOpacity = 0.55;

  /// Other wards while one is selected, as a fraction of their normal opacity.
  static const double dimmed = 0.3;
  static const Color wardOutline = Color(0xFFFFFFFF);
  static const double wardOutlineWidth = 1.5;
  static const Color selectedOutline = Color(0xFF0A0A0A);
  static const double selectedOutlineWidth = 2.5;

  static Color wardFill(double t, {double opacity = wardFillOpacity}) =>
      Color.lerp(wardLow, wardHigh, t.clamp(0, 1))!.withValues(alpha: opacity);

  /// Roads: grey normally, the status colour when flagged.
  static const Color road = Color(0xFF8A8A8A);
  static const Color roadCasing = Color(0xFFFFFFFF);
  static const Color warranty = Color(0xFF1F5FD0); // info
  static const Color failed = Color(0xFFC8102E); // error
  static const Color aboveRate = Color(0xFF6B3FD4); // review
  static const Color repeatJob = Color(0xFFA85800); // warning

  /// Ward labels and pins: white pill, black text.
  static const Color label = Color(0xFFFFFFFF);
  static const Color labelText = Color(0xFF0A0A0A);
  static const Color pin = Color(0xFF0A0A0A);
  static const Color onPin = Color(0xFFFFFFFF);

  /// Next-rupee context markers: hospitals, schools, flood hotspots.
  static const Color hospital = Color(0xFFC8102E);
  static const Color school = Color(0xFF1F5FD0);
  static const Color hotspot = Color(0xFF00838F);

  /// Complaint clusters by size, and monsoon complaint dots.
  static const List<Color> heat = [Color(0xFF9DB8EA), Color(0xFF4F7FDB), Color(0xFF1F4BA8)];
  static const Color complaintDot = Color(0xFF1F5FD0);

  /// Monsoon replay: roads not yet repaired, repaired this week, failed; rain wash on alert days.
  static const Color monsoonIdle = Color(0xFFA6A6A6);
  static const Color monsoonRecent = Color(0xFFE59A00);
  static const Color monsoonFailed = Color(0xFFC8102E);
  static const Color rainWash = Color(0xFF1F5FD0);

  /// IMD rain alert levels.
  static const Map<String, Color> alert = {
    'Green': Color(0xFF0C7A40),
    'Yellow': Color(0xFFF2B705),
    'Orange': Color(0xFFE07000),
    'Red': Color(0xFFC8102E),
  };
}
