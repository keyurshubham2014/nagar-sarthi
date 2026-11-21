import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';

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
  ApiException(this.message, {this.status, this.fields = const {}});
  final String message;
  final int? status;

  /// Field-level validation messages from a 400 (`{error:{fields:{name: message}}}`).
  final Map<String, dynamic> fields;
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
  ApiClient({Dio? dio, this.token, this.onUnauthorized})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: apiBase,
              connectTimeout: const Duration(seconds: 8),
              // Claude relay waits up to 20 s server-side before falling back.
              receiveTimeout: const Duration(seconds: 30),
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          final t = token?.call();
          if (t != null) o.headers['Authorization'] = 'Bearer $t';
          h.next(o);
        },
      ),
    );
  }

  final Dio _dio;

  /// Current session token, sent as a Bearer header on every call.
  final String? Function()? token;

  /// Called when the server rejects the session (401 on a call that sent a token).
  final void Function()? onUnauthorized;

  Future<T> _get<T>(String path) => _call(() => _dio.get<T>(path));

  Future<T> _call<T>(Future<Response<T>> Function() send) async {
    try {
      return (await send()).data as T;
    } on DioException catch (e) {
      final data = e.response?.data;
      final serverMsg = data is Map && data['error'] is Map
          ? data['error']['message'] as String?
          : null;
      final fields = data is Map && data['error'] is Map ? data['error']['fields'] : null;
      if (e.response?.statusCode == 401 &&
          e.requestOptions.headers.containsKey('Authorization') &&
          e.requestOptions.path != '/api/auth/login') {
        onUnauthorized?.call();
      }
      throw ApiException(
        serverMsg ?? 'Could not reach the Nagar Sarthi server at $apiBase',
        status: e.response?.statusCode,
        fields: fields is Map<String, dynamic> ? fields : const {},
      );
    }
  }

  Future<Map<String, dynamic>> health() => _get('/api/health');

  /// Sign in: {token, role, ward_code, phone}; 401 on a wrong code, 400 with fields.
  Future<Map<String, dynamic>> login(String phone, String code) =>
      _call(() => _dio.post('/api/auth/login', data: {'phone': phone, 'code': code}));

  /// Demo shortcuts: {code, users:{role: phone}} from server config; 404 when turned off.
  Future<Map<String, dynamic>> demoLogin() => _get('/api/auth/demo');
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

  /// Flag rows, biggest rupees first: {total, total_inr, items[]} (items carry road_name).
  /// [type] may be comma-separated; [q] matches work order id or road name; [limit] is at most 100.
  Future<Map<String, dynamic>> flags({
    String? ward,
    String? road,
    String? type,
    String? contractor,
    String? q,
    int offset = 0,
    int limit = 50,
  }) => _call(
    () => _dio.get(
      '/api/flags',
      queryParameters: {
        'ward': ?ward,
        'road': ?road,
        'type': ?type,
        'contractor': ?contractor,
        'q': ?q,
        'offset': offset,
        'limit': limit,
      },
    ),
  );

  /// Complaint trail issues, most reported first: {total, items[]}. [outcome] is fixed_held, fixed_failed,
  /// in_progress, never_fixed or social_only; [q] matches issue, complaint or work order id, place or road.
  Future<Map<String, dynamic>> issues({String? ward, String? outcome, String? q, int offset = 0, int limit = 30}) => _call(
    () => _dio.get(
      '/api/issues',
      queryParameters: {'ward': ?ward, 'outcome': ?outcome, 'q': ?q, 'offset': offset, 'limit': limit},
    ),
  );

  /// One issue's full trail: complaints, social posts, work orders, outcome.
  Future<Map<String, dynamic>> issue(String id) => _get('/api/issues/${Uri.encodeComponent(id)}');

  /// Linker funnel for [ward] (null: all Mumbai), with the method notes and accuracy checks.
  Future<Map<String, dynamic>> linker({String? ward}) =>
      _call(() => _dio.get('/api/linker', queryParameters: {'ward': ?ward}));

  /// "What happened to my complaint?": {text, source, kind, lang, complaint_id, issue_id, work_order_id, road_id...}.
  /// The server finds the id in [text]; [ward] answers ward-level questions when there is no id.
  Future<Map<String, dynamic>> answer(String text, {required String language, String? ward}) =>
      _call(() => _dio.post('/api/claude/answer', data: {'text': text, 'language': language, 'ward_code': ?ward}));

  /// Citizen intake: {source, category, language, locality, ward_code, ward_name, match_count, matches[]}.
  Future<Map<String, dynamic>> intake(String text) =>
      _call(() => _dio.post('/api/claude/intake', data: {'text': text}));

  /// Matches for a corrected category and locality: {match_count, matches[]}.
  Future<Map<String, dynamic>> complaintMatches(String category, String locality) => _call(
    () => _dio.get('/api/complaints/matches', queryParameters: {'category': category, 'locality': locality}),
  );

  /// Gazetteer rows: {locality, ward_code, aliases[]}.
  Future<List<dynamic>> localities() => _get('/api/localities');

  /// Files a complaint; 400 carries [ApiException.fields], 503 when the database is down.
  Future<Map<String, dynamic>> fileComplaint(Map<String, dynamic> body) =>
      _call(() => _dio.post('/api/complaints', data: body));

  /// Full trail for a dataset (BMC25-000123) or app (NS-000001) id.
  Future<Map<String, dynamic>> complaint(String id) => _get('/api/complaints/${Uri.encodeComponent(id)}');

  /// Complaints at one locality, newest first: {locality, ward_code, total, rows[]}.
  Future<Map<String, dynamic>> complaintsAt(String locality) =>
      _call(() => _dio.get('/api/complaints', queryParameters: {'locality': locality}));

  /// Calls a registered server feature (`ping`, later `notice`, `brief`...).
  /// Pass `key` in [body] to pick a saved fallback entry.
  Future<ClaudeReply> claude(String feature, Map<String, dynamic> body) async {
    final data = await _call<Map<String, dynamic>>(
      () => _dio.post('/api/claude/${Uri.encodeComponent(feature)}', data: body),
    );
    return ClaudeReply(data['text'] as String? ?? '', data['source'] as String);
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    token: () => ref.read(sessionProvider)?.token,
    onUnauthorized: () => ref.read(sessionProvider.notifier).expired(),
  ),
);
