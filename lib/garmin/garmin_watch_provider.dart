import 'package:flutter/material.dart';

import '../watch/watch_export_dialog.dart';
import '../watch/watch_provider.dart';
import 'garmin_client.dart';
import 'garmin_connection.dart';
import 'garmin_export_flow.dart';

class GarminWatchProvider extends WatchProvider {
  GarminWatchProvider(this.client);
  final GarminClient client;

  @override
  String get id => 'garmin';
  @override
  String get name => garminConnectName;
  @override
  Future<bool> connected() => client.status();
  @override
  Future<List<String>> devices() async =>
      (await client.devices()).map((device) => device.name).toList();
  @override
  Future<void> manage(BuildContext context) async {
    await showGarminConnection(context, client);
  }

  @override
  Future<bool> preview(
    BuildContext context,
    WatchExportRequest workout, {
    required bool canChange,
  }) => showWatchExportDialog(
    context,
    workout,
    GarminExportFlow(client),
    canChange: canChange,
  );
}
