import 'package:flutter/material.dart';

import '../workouts/workout.dart';

const garminName = 'Garmin';
const garminConnectName = '$garminName Connect';
const corosName = 'COROS';

class WatchExportRequest {
  const WatchExportRequest(this.session, this.version, this.vma, this.notes);
  final WorkoutSession session;
  final WorkoutVersion version;
  final double vma;
  final List<WorkoutNote> notes;
}

abstract class WatchProvider {
  String get id;
  String get name;
  Future<bool> connected();
  Future<List<String>> devices();
  Future<void> manage(BuildContext context);
  Future<bool> preview(
    BuildContext context,
    WatchExportRequest workout, {
    required bool canChange,
  });
}

class WatchDestination {
  const WatchDestination(
    this.provider, {
    required this.canExport,
    required this.canListDevices,
  });
  final WatchProvider provider;
  final bool canExport, canListDevices;
}
