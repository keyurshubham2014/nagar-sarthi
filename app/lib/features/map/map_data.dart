import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_client.dart';

/// One ward: polygon from `assets/wards.geojson`, figures from `/api/wards`.
class Ward {
  Ward({required this.code, required this.name, required this.points, required this.data});
  final String code;
  final String name;
  final List<LatLng> points;

  /// The `/api/wards` row (flagged_share, flagged_inr, spend, ...); empty if missing.
  final Map<String, dynamic> data;

  double get flaggedShare => (data['flagged_share'] as num?)?.toDouble() ?? 0;
  num get flaggedInr => data['flagged_inr'] as num? ?? 0;
  num get spend => data['spend'] as num? ?? 0;
}

/// One road segment: line from `assets/roads.geojson`, status from `/api/roads`.
class Road {
  Road({required this.id, required this.name, required this.wardCode, required this.points, required this.data});
  final String id;
  final String name;
  final String wardCode;
  final List<LatLng> points;
  final Map<String, dynamic> data;

  /// dlp_paid | fix_failed | over_rate | double_billing | clean
  String get status => data['status'] as String? ?? 'clean';
  num get spend => data['spend'] as num? ?? 0;
}

/// Everything the map home needs. Later layers can read [meta] or add fields.
class MapData {
  MapData({required this.wards, required this.roads, required this.meta});
  final List<Ward> wards;
  final List<Road> roads;
  final Map<String, dynamic> meta;

  late final Map<String, Ward> wardByCode = {for (final w in wards) w.code: w};
  late final Map<String, Road> roadById = {for (final r in roads) r.id: r};
  String get disclaimer => meta['disclaimer'] as String? ?? kDefaultDisclaimer;
}

const kDefaultDisclaimer = 'Synthetic data. Not BMC data. Contractors are fictional.';

LatLng _ll(dynamic p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble());

Future<List<dynamic>> _features(String asset) async =>
    (jsonDecode(await rootBundle.loadString(asset)) as Map)['features'] as List;

/// Geometry from bundled assets (works offline) joined with API figures.
/// No auto-retry: a failure shows the error card with its Retry button at once.
final mapDataProvider = FutureProvider<MapData>(retry: (_, _) => null, (ref) async {
  final api = ref.watch(apiClientProvider);
  final results = await Future.wait([
    _features('assets/wards.geojson'),
    _features('assets/roads.geojson'),
    api.wards(),
    api.roads(),
    api.meta(),
  ]);
  final wardRows = {for (final w in results[2] as List) w['code'] as String: w as Map<String, dynamic>};
  final roadRows = {for (final r in results[3] as List) r['road_id'] as String: r as Map<String, dynamic>};

  final wards = [
    for (final f in results[0] as List)
      Ward(
        code: f['properties']['ward_code'] as String,
        name: f['properties']['ward_name'] as String,
        // Outer ring only; the ward file has no holes.
        points: [for (final p in f['geometry']['coordinates'][0] as List) _ll(p)],
        data: wardRows[f['properties']['ward_code']] ?? const {},
      ),
  ];
  final roads = [
    for (final f in results[1] as List)
      Road(
        id: f['properties']['road_id'] as String,
        name: f['properties']['road_name'] as String,
        wardCode: f['properties']['ward_code'] as String,
        points: [for (final p in f['geometry']['coordinates'] as List) _ll(p)],
        data: roadRows[f['properties']['road_id']] ?? const {},
      ),
  ];
  return MapData(wards: wards, roads: roads, meta: results[4] as Map<String, dynamic>);
});
