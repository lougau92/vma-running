import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../firebase_content_session.dart';

class GarminFailure implements Exception {
  const GarminFailure(this.code);
  final String code;
  @override
  String toString() => 'GarminFailure';
}

class GarminDevice {
  GarminDevice(Map<String, dynamic> json)
    : id = json['deviceId'] as int,
      name = json['name'] as String,
      eligible = json['runningWorkoutCapable'] == true;
  final int id;
  final String name;
  final bool eligible;
}

class GarminLogin {
  GarminLogin(Map<String, dynamic> json)
    : challenge = json['status'] == 'mfa_required'
          ? json['challengeId'] as String
          : null;
  final String? challenge;
}

class GarminUpload {
  GarminUpload(Map<String, dynamic> json) : id = json['workoutId'] as int;
  final int id;
  String get url => 'https://connect.garmin.com/modern/workout/$id';
}

/// Only Firebase ID tokens go to this trusted, build-time configured endpoint.
class GarminClient {
  GarminClient({
    String? baseUrl,
    http.Client? httpClient,
    FirebaseContentSession? session,
  }) : baseUrl = baseUrl ?? const String.fromEnvironment('GARMIN_PROXY_URL'),
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
    if (!configured) throw const GarminFailure('unavailable');
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
          throw GarminFailure(
            json['error'] is String ? json['error'] as String : 'unavailable',
          );
        }
        return json;
      }
    } on GarminFailure {
      rethrow;
    } catch (_) {
      throw const GarminFailure('unavailable');
    }
    throw const GarminFailure('unavailable');
  }

  Future<bool> status() async =>
      (await request('GET', '/garmin/status'))['connected'] == true;
  Future<GarminLogin> login(String email, String password) async => GarminLogin(
    await request(
      'POST',
      '/garmin/login',
      body: {'email': email, 'password': password},
    ),
  );
  Future<void> mfa(String challenge, String code) async {
    await request(
      'POST',
      '/garmin/login/mfa',
      body: {'challengeId': challenge, 'code': code},
    );
  }

  Future<void> disconnect() async {
    await request('DELETE', '/garmin/session');
  }

  Future<List<GarminDevice>> devices() async =>
      ((await request('GET', '/garmin/devices'))['devices'] as List)
          .map((d) => GarminDevice(d as Map<String, dynamic>))
          .toList();
  Future<GarminUpload> upload(Map<String, dynamic> payload, String key) async =>
      GarminUpload(
        await request('POST', '/garmin/workouts', body: payload, key: key),
      );
  Future<void> send(int workoutId, int deviceId, String key) async {
    await request(
      'POST',
      '/garmin/workouts/$workoutId/send',
      body: {'deviceId': deviceId},
      key: key,
    );
  }
}
