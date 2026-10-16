import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;

/// Where the solver lives. Nothing about the schedule is decided without it, so an
/// unreachable backend is a hard stop, not a fallback screen.
///
/// Android emulators reach the host machine as `10.0.2.2`, not `localhost`, so the
/// default depends on the platform the app was built for. Override any of it with:
///
///   flutter run --dart-define=SYNCHRO_API=http://192.168.1.20:8000
abstract final class ApiConfig {
  static const String _override = String.fromEnvironment('SYNCHRO_API');

  static String get defaultBaseUrl =>
      defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:8000' : 'http://localhost:8000';

  static String get baseUrl => _override.isNotEmpty ? _override : defaultBaseUrl;

  static const Duration generateTimeout = Duration(minutes: 3);
  static const Duration requestTimeout = Duration(seconds: 20);
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode = 0});

  /// 0 means the request never got an answer: nothing listening, DNS failure, or a timeout.
  final int statusCode;
  final String message;

  bool get isTransport => statusCode == 0;

  @override
  String toString() => message;
}

class SynchroApi {
  SynchroApi({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const String demoCampusId = 'demo-slrtce';

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> health() => _get('/health');

  Future<({Map<String, dynamic> campus, String name, Map<String, dynamic> summary})> sampleCampus() async {
    final body = await _get('/sample-campus');
    return (
      campus: body['campus'] as Map<String, dynamic>,
      name: body['name'] as String? ?? 'Demo campus',
      summary: (body['summary'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<Map<String, dynamic>> saveCampus(String id, String name, Map<String, dynamic> campus) =>
      _send('PUT', '/campuses/$id', {'name': name, 'campus': campus});

  Future<Map<String, dynamic>> preview(String id) => _post('/campuses/$id/preview', {});

  Future<Map<String, dynamic>> generate(
    String id, {
    required double timeLimitSeconds,
    required int randomSeed,
    List<Map<String, dynamic>> fixed = const [],
  }) =>
      _send(
        'POST',
        '/campuses/$id/generate',
        {'time_limit_seconds': timeLimitSeconds, 'random_seed': randomSeed, 'fixed': fixed},
        timeout: ApiConfig.generateTimeout,
      );

  Future<Map<String, dynamic>> validate(String id, List<Map<String, dynamic>> assignments) =>
      _post('/campuses/$id/validate', {'assignments': assignments});

  Future<List<Map<String, dynamic>>> runs(String id) async {
    final body = await _get('/campuses/$id/runs');
    return (body['runs'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _get(String path) => _send('GET', path, null);

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) => _send('POST', path, body);

  Future<Map<String, dynamic>> _send(String method, String path, Map<String, dynamic>? body,
      {Duration? timeout}) async {
    final uri = _uri(path);
    final request = http.Request(method, uri)..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    try {
      final streamed = await _client.send(request).timeout(timeout ?? ApiConfig.requestTimeout);
      final response = await http.Response.fromStream(streamed);
      return _decode(uri, response);
    } on TimeoutException {
      throw ApiException(
        'The backend did not answer $path within ${(timeout ?? ApiConfig.requestTimeout).inSeconds}s.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      // dart:io raises SocketException, the browser raises a ClientException; both mean
      // the same thing here and neither is worth branching the import graph over.
      throw ApiException(
        'No reachable backend at ${uri.origin} ($e). '
        '${kIsWeb ? 'Check the URL and that CORS allows this origin' : 'Start it with: '
            'uvicorn app.main:app --host 0.0.0.0 --port 8000'}',
      );
    }
  }

  Map<String, dynamic> _decode(Uri uri, http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 400) {
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      throw ApiException(
        detail is String ? detail : 'HTTP ${response.statusCode} from ${uri.path}',
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Expected a JSON object from ${uri.path}, got ${response.body.runtimeType}.');
    }
    return decoded;
  }

  void close() => _client.close();
}
