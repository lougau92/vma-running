import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_localizations.dart';
import '../watch/watch_export_dialog.dart';
import '../watch/watch_preview.dart';
import '../watch/watch_provider.dart';
import '../workouts/workout_format.dart';
import 'garmin_client.dart';
import 'garmin_connection.dart';
import 'garmin_export.dart';
import 'garmin_journal.dart';

class GarminExportFlow extends WatchExportFlow {
  GarminExportFlow(this.client) : _journal = GarminJournal(client);

  final GarminClient client;
  final GarminJournal _journal;
  GarminOperation? _operation;
  List<GarminDevice>? _devices;
  int? _selectedDevice;
  bool _needsReconnect = false;

  @override
  String get name => garminName;

  @override
  String get destination => garminConnectName;

  @override
  bool get inputsLocked => _operation != null;

  @override
  String errorMessage(AppLocalizations strings, Object error) =>
      garminError(strings, error);

  Future<bool> _withConnection(
    BuildContext context,
    WatchExportAction action,
  ) async {
    try {
      if (_needsReconnect || !await client.status()) {
        if (!context.mounted || !await showGarminConnection(context, client)) {
          return false;
        }
      }
      if (!context.mounted) return false;
      _needsReconnect = false;
      await action();
      return true;
    } on GarminFailure catch (error) {
      _needsReconnect =
          error.code == 'garmin_not_connected' ||
          error.code == 'garmin_reconnect_required';
      rethrow;
    }
  }

  @override
  WatchExportPreview preview(
    BuildContext context,
    WatchExportRequest request,
    Map<String, double> values,
  ) {
    final s = AppLocalizations.of(context);
    final export = buildGarminExport(
      request.session,
      request.version,
      request.vma,
      s,
      values: values,
      defaultChoices: true,
      notes: request.notes,
    );
    final payload = _operation?.payload ?? export.payload;
    final segment = (payload['workoutSegments'] as List).single as Map;
    return WatchExportPreview(
      title: payload['workoutName'] as String,
      notes: payload['description'] as String?,
      steps: [
        for (final step in segment['workoutSteps'] as List)
          _step(step as Map<String, dynamic>),
      ],
      inputs: export.inputs,
      messages: [
        if (!client.configured) s['garmin_unavailable'],
        ...export.warnings,
        ...export.problems,
      ],
      save: client.configured && (inputsLocked || export.problems.isEmpty)
          ? () => _withConnection(context, () async {
              final operation = _operation ??= await _journal.prepare(
                export.payload,
              );
              await _journal.upload(operation);
            })
          : null,
    );
  }

  Widget _step(Map<String, dynamic> step) {
    final end = (step['endCondition'] as Map)['conditionTypeKey'];
    final value = step['endConditionValue'] as num?;
    final limit = switch (end) {
      'lap.button' => 'LAP',
      'time' => workoutTime(value!.toDouble()),
      _ => '${workoutNumber(value!.toDouble())} m',
    };
    final fast = step['targetValueOne'] as num?;
    final slow = step['targetValueTwo'] as num?;
    return WatchStepPreview(
      role: (step['stepType'] as Map)['stepTypeKey'] as String,
      end: limit,
      pace: fast == null || slow == null
          ? null
          : watchPreviewPace((1000 / fast).round(), (1000 / slow).round()),
      notes: step['description'] as String?,
      number: step['stepOrder'] as int,
    );
  }

  @override
  List<Widget> savedDetails(
    BuildContext context, {
    required bool busy,
    required ValueChanged<WatchExportAction> run,
    required VoidCallback refresh,
  }) {
    final s = AppLocalizations.of(context);
    final operation = _operation!;
    final url =
        'https://connect.garmin.com/modern/workout/${operation.workoutId}';
    final devices = _devices;
    final selected = _selectedDevice;
    return [
      SelectableText(url),
      TextButton.icon(
        onPressed: () => Clipboard.setData(ClipboardData(text: url)),
        icon: const Icon(Icons.copy),
        label: Text(s['garmin_copy_link']),
      ),
      if (devices == null)
        OutlinedButton(
          onPressed: busy
              ? null
              : () => run(() async {
                  await _withConnection(context, () async {
                    final eligible = (await client.devices())
                        .where((device) => device.eligible)
                        .toList();
                    _devices = eligible;
                    _selectedDevice = eligible.length == 1
                        ? eligible.single.id
                        : null;
                  });
                }),
          child: Text(s['garmin_send']),
        )
      else if (devices.isEmpty)
        Text(s['garmin_no_watch'])
      else ...[
        DropdownButtonFormField<int>(
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(labelText: s['garmin_watch']),
          items: [
            for (final device in devices)
              DropdownMenuItem(value: device.id, child: Text(device.name)),
          ],
          onChanged: busy
              ? null
              : (id) {
                  _selectedDevice = id;
                  refresh();
                },
        ),
        if (operation.delivered.contains(selected))
          Text(s['garmin_delivery_requested'])
        else
          FilledButton(
            onPressed: busy || selected == null
                ? null
                : () => run(() async {
                    await _withConnection(
                      context,
                      () => _journal.send(operation, selected),
                    );
                  }),
            child: Text(s['garmin_send']),
          ),
      ],
    ];
  }
}
