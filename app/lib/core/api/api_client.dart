import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `--dart-define=API_BASE=http://host:8787` overrides the default.
const String _apiBaseDefine = String.fromEnvironment('API_BASE');

/// Android emulator reaches the laptop at 10.0.2.2; web and desktop use localhost.
String get apiBase {
  if (_apiBaseDefine.isNotEmpty) return _apiBaseDefine;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8787';
  }
  return 'http://localhost:8787';
}

/// Thrown for any failed API call; [message] is safe to show.
class ApiException implements Exception {
  ApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Reply from the Claude relay: [source] is `live` or `fallback`.
class ClaudeReply {
  const ClaudeReply(this.text, this.source);
  final String text;
  final String source;
  bool get isFallback => source == 'fallback';
}

/// Thin client over the Nagar Sarthi API. Responses stay as decoded JSON
/// maps and lists; screens read the fields they need.
class ApiClient {
  ApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: apiBase,
              connectTimeout: const Duration(seconds: 8),
              // Claude relay waits up to 20 s server-side before falling back.
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio _dio;

  Future<T> _get<T>(String path) => _call(() => _dio.get<T>(path));

  Future<T> _call<T>(Future<Response<T>> Function() send) async {
    try {
      return (await send()).data as T;
    } on DioException catch (e) {
      final data = e.response?.data;
      final serverMsg = data is Map && data['error'] is Map
          ? data['error']['message'] as String?
          : null;
      throw ApiException(
        serverMsg ?? 'Could not reach the Nagar Sarthi server at $apiBase',
        status: e.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> health() => _get('/api/health');
  Future<Map<String, dynamic>> meta() => _get('/api/meta');

  /// Shading values per ward: code, name, spend, flagged_inr, flagged_share...
  Future<List<dynamic>> wards() => _get('/api/wards');

  /// Full ward record. [code] may contain a slash (`H/E`); it is encoded.
  Future<Map<String, dynamic>> ward(String code) =>
      _get('/api/wards/${Uri.encodeComponent(code)}');

  /// Status per segment: road_id, road_name, ward_code, status, spend...
  Future<List<dynamic>> roads() => _get('/api/roads');
  Future<Map<String, dynamic>> road(String id) =>
      _get('/api/roads/${Uri.encodeComponent(id)}');
  Future<List<dynamic>> contractors() => _get('/api/contractors');
  Future<Map<String, dynamic>> nextRupee(String ward) =>
      _get('/api/next-rupee/${Uri.encodeComponent(ward)}');
  /// Compact per day: {d, rain, alert, tide, n, c:[[lat,lon]], r:[road_id], x:[road_id]}.
  Future<List<dynamic>> timeline() => _get('/api/timeline');

  /// Open and repeat complaints clustered: [{lat, lon, count, open, sample[]}]; [ward] scopes it.
  Future<List<dynamic>> complaintsHeat({String? ward}) =>
      _call(() => _dio.get<List<dynamic>>('/api/complaints/heat', queryParameters: {'ward': ?ward}));

  /// Fair scorecards, alphabetical; [ward] scopes them to one ward.
  Future<Map<String, dynamic>> scorecards({String? ward}) =>
      _call(() => _dio.get('/api/scorecards', queryParameters: {'ward': ?ward}));

  /// Work orders behind one measure (`speed`, `durability`, `pricing`): up to 100 rows and `total`.
  Future<Map<String, dynamic>> contractorWorkOrders(String id, String metric, {String? ward}) => _call(
    () => _dio.get(
      '/api/contractors/${Uri.encodeComponent(id)}/work-orders',
      queryParameters: {'metric': metric, 'ward': ?ward},
    ),
  );

  /// Flag rows from audit.json, filtered by any of ward, road and type.
  Future<List<dynamic>> flags({String? ward, String? road, String? type}) => _call(
    () => _dio.get<List<dynamic>>(
      '/api/flags',
      queryParameters: {'ward': ?ward, 'road': ?road, 'type': ?type},
    ),
  );

  /// Calls a registered server feature (`ping`, later `notice`, `brief`...).
  /// Pass `key` in [body] to pick a saved fallback entry.
  Future<ClaudeReply> claude(String feature, Map<String, dynamic> body) async {
    final data = await _call<Map<String, dynamic>>(
      () => _dio.post('/api/claude/${Uri.encodeComponent(feature)}', data: body),
    );
    return ClaudeReply(data['text'] as String? ?? '', data['source'] as String);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
