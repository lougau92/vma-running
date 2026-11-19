import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'garmin_client.dart';

String _key() => List.generate(
  24,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

/// Contains workout snapshots and operation IDs, never authentication secrets.
class GarminOperation {
  GarminOperation(this.payload) : key = _key();
  GarminOperation.fromJson(Map<String, dynamic> json)
    : payload = json['payload'] as Map<String, dynamic>,
      key = json['key'] as String,
      workoutId = json['workoutId'] as int?,
      sendKeys = Map<String, String>.from(json['sendKeys'] as Map? ?? {}),
      delivered = List<int>.from(json['delivered'] as List? ?? []);
  final Map<String, dynamic> payload;
  final String key;
  int? workoutId;
  Map<String, String> sendKeys = {};
  List<int> delivered = [];
  Map<String, dynamic> toJson() => {
    'payload': payload,
    'key': key,
    'workoutId': workoutId,
    'sendKeys': sendKeys,
    'delivered': delivered,
  };
}

class GarminJournal {
  GarminJournal(this.client);
  final GarminClient client;
  Future<String> _storageKey() async =>
      'garmin_operations_v1_${await client.session.userId()}';
  Future<List<GarminOperation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(await _storageKey());
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((j) => GarminOperation.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Never silently reset an unreadable journal and risk duplicate uploads.
      throw const GarminFailure('journal_unavailable');
    }
  }

  Future<void> save(List<GarminOperation> operations) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      await _storageKey(),
      jsonEncode(operations.map((o) => o.toJson()).toList()),
    );
    if (!saved) throw const GarminFailure('journal_unavailable');
  }

  Future<GarminOperation> prepare(Map<String, dynamic> payload) async {
    final operations = await load();
    final encoded = jsonEncode(payload);
    for (final operation in operations.reversed) {
      if (jsonEncode(operation.payload) == encoded) return operation;
    }
    final operation = GarminOperation(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
    operations.add(operation);
    await save(operations);
    return operation;
  }

  Future<void> _update(GarminOperation operation) async {
    final operations = await load();
    final index = operations.indexWhere((o) => o.key == operation.key);
    if (index < 0) throw const GarminFailure('journal_unavailable');
    operations[index] = operation;
    await save(operations);
  }

  Future<void> upload(GarminOperation operation) async {
    if (operation.workoutId != null) return;
    final result = await client.upload(operation.payload, operation.key);
    operation.workoutId = result.id;
    await _update(operation);
  }

  Future<void> send(GarminOperation operation, int deviceId) async {
    if (operation.delivered.contains(deviceId)) return;
    final id = operation.workoutId;
    if (id == null) throw const GarminFailure('invalid_request');
    final key = operation.sendKeys.putIfAbsent('$deviceId', _key);
    await _update(operation);
    await client.send(id, deviceId, key);
    operation.delivered.add(deviceId);
    await _update(operation);
  }
}
