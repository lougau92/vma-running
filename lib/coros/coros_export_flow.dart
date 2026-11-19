import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';

import '../app_localizations.dart';
import '../watch/watch_export_dialog.dart';
import '../watch/watch_preview.dart';
import '../watch/watch_provider.dart';
import '../watch/watch_service_client.dart';
import '../watch/watch_workout.dart';
import '../workouts/workout_format.dart';
import 'coros_export.dart';

class CorosExportFlow extends WatchExportFlow {
  CorosExportFlow(this.client);

  final WatchServiceClient client;
  String? _connection;
  bool _outcomeUnknown = false;

  @override
  String get name => corosName;

  @override
  Future<void> initialize() async {
    final status = await client.request('GET', '/coros/status');
    _connection = status['connectionId'] as String?;
    if (_connection == null) {
      throw const WatchServiceFailure('coros_reconnect');
    }
  }

  @override
  String errorMessage(AppLocalizations strings, Object error) {
    final key = switch (error) {
      WatchServiceFailure(code: 'coros_outcome_unknown') =>
        'coros_outcome_unknown',
      WatchServiceFailure(
        code: 'coros_connection_changed' || 'coros_reconnect',
      ) =>
        'watch_oauth_expired',
      _ => 'watch_error',
    };
    return strings.watchLabel(key, name);
  }

  Future<bool> _save(CorosExport export) async {
    final payload = {'connectionId': _connection, 'course': export.course};
    final digest = await Sha256().hash(utf8.encode(jsonEncode(payload)));
    // The same connection and workout get the same key across retries and tabs.
    final key = base64UrlEncode(digest.bytes).replaceAll('=', '');
    try {
      await client.request('POST', '/coros/workouts', body: payload, key: key);
      return true;
    } on WatchServiceFailure catch (failure) {
      switch (failure.code) {
        case 'coros_connection_changed':
        case 'coros_reconnect':
          _connection = null;
        case 'coros_outcome_unknown':
          _outcomeUnknown = true;
      }
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
    final resolved = resolveWatchWorkout(
      request.session,
      request.version,
      request.vma,
      s,
      values: values,
      defaultChoices: true,
      notes: request.notes,
    );
    final export = buildCorosExport(resolved, s);
    final course = export.course;
    final ready =
        _connection != null && !_outcomeUnknown && export.problems.isEmpty;
    return WatchExportPreview(
      title: course['courseName'] as String,
      notes: course['courseDescription'] as String?,
      steps: [
        for (final section in course['sections'] as List<Map<String, dynamic>>)
          _section(section),
      ],
      inputs: resolved.inputs,
      messages: [...export.warnings, ...export.problems],
      save: ready ? () => _save(export) : null,
    );
  }

  Widget _section(Map<String, dynamic> step) {
    if (step['intervalGroup'] == true) {
      return Card(
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text('${step['repeats']} ×'),
          children: [
            for (final child in step['sets'] as List<Map<String, dynamic>>)
              _section(child),
          ],
        ),
      );
    }
    final amount = step['targetValue'] as num?;
    final fast = step['intensityValueStart'] as int?;
    final slow = step['intensityValueEnd'] as int?;
    return WatchStepPreview(
      role: switch (step['sectionType']) {
        1 => 'warmup',
        3 => 'recovery',
        4 => 'cooldown',
        _ => 'interval',
      },
      end: switch ((step['targetType'], amount)) {
        (1, final num distance) => '${workoutNumber(distance.toDouble())} m',
        (2, final num duration) => workoutTime(duration.toDouble()),
        (4, _) => 'LAP',
        _ => '–',
      },
      pace: fast == null || slow == null ? null : watchPreviewPace(fast, slow),
    );
  }

  @override
  List<Widget> savedDetails(
    BuildContext context, {
    required bool busy,
    required ValueChanged<WatchExportAction> run,
    required VoidCallback refresh,
  }) => [
    Text(
      AppLocalizations.of(context).watchLabel('coros_sync_instructions', name),
    ),
  ];
}
