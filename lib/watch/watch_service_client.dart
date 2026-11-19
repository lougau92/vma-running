import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../firebase_content_session.dart';

class WatchServiceFailure implements Exception {
  const WatchServiceFailure(this.code);
  final String code;
  @override
  String toString() => 'WatchServiceFailure';
}

/// Only Firebase ID tokens go to this trusted, build-time configured endpoint.
class WatchServiceClient {
  WatchServiceClient({
    String? baseUrl,
    http.Client? httpClient,
    FirebaseContentSession? session,
  }) : baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'WATCH_SERVICE_URL',
             defaultValue: String.fromEnvironment('GARMIN_PROXY_URL'),
           ),
       _http = httpClient ?? http.Client(),
       session = session ?? FirebaseContentSession();
  final String baseUrl;
  final http.Client _http;
  final FirebaseContentSession session;
  void close() => _http.close();
  bool get configured {
    final uri = Uri.tryParse(baseUrl);
    return uri != null &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty &&
        (uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                ['localhost', '127.0.0.1', '[::1]'].contains(uri.host)));
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
  }) async {
    if (!configured) throw const WatchServiceFailure('unavailable');
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final token = await session.idToken(forceRefresh: attempt == 1);
        final request = http.Request(
          method,
          Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path'),
        );
        request.headers.addAll({
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          if (key != null) 'Idempotency-Key': key,
        });
        if (body != null) request.body = jsonEncode(body);
        final response = await _http
            .send(request)
            .then(http.Response.fromStream)
            .timeout(const Duration(seconds: 90));
        if (response.statusCode == 401 && attempt == 0) continue;
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw WatchServiceFailure(
            json['error'] is String ? json['error'] as String : 'unavailable',
          );
        }
        return json;
      }
    } on WatchServiceFailure {
      rethrow;
    } catch (_) {
      throw const WatchServiceFailure('unavailable');
    }
    throw const WatchServiceFailure('unavailable');
  }
}
