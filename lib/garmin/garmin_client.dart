import '../watch/watch_service_client.dart';

typedef GarminFailure = WatchServiceFailure;

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

class GarminClient extends WatchServiceClient {
  GarminClient({super.baseUrl, super.httpClient, super.session});

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
