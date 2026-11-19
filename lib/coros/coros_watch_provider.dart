import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_localizations.dart';
import '../runtime/runtime_platform.dart' show openBrowserPage;
import '../watch/watch_export_dialog.dart';
import '../watch/watch_provider.dart';
import '../watch/watch_service_client.dart';
import 'coros_export_flow.dart';

class CorosWatchProvider extends WatchProvider {
  CorosWatchProvider(this.client);
  final WatchServiceClient client;

  @override
  String get id => 'coros';
  @override
  String get name => corosName;
  @override
  Future<bool> connected() async =>
      (await client.request('GET', '/coros/status'))['connected'] == true;
  @override
  Future<List<String>> devices() async =>
      ((await client.request('GET', '/coros/devices'))['devices'] as List)
          .map((item) => (item as Map)['name'] as String)
          .toList();

  Future<String> get _pendingKey async =>
      'watch_oauth_coros_attempt_${await client.session.userId()}';

  Future<void> start() async {
    final pending = await client.request('POST', '/coros/login/start');
    final url = Uri.parse(pending['url'] as String);
    if (url.origin != 'https://mcpeu.coros.com' ||
        url.path != '/oauth2/authorize') {
      throw const WatchServiceFailure('coros_unavailable');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      await _pendingKey,
      jsonEncode({'attempt': pending['attempt'], 'proof': pending['proof']}),
    )) {
      throw const WatchServiceFailure('coros_unavailable');
    }
    openBrowserPage(url.toString());
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _pendingKey;
    final pending = prefs.getString(key);
    if (pending == null) return;
    try {
      final result = await client.request(
        'POST',
        '/coros/login/complete',
        body: jsonDecode(pending) as Map<String, dynamic>,
      );
      if (result['status'] == 'connected') await prefs.remove(key);
    } on WatchServiceFailure catch (error) {
      if ([
        'coros_sign_in_expired',
        'coros_sign_in_denied',
        'coros_reconnect',
      ].contains(error.code)) {
        await prefs.remove(key);
      }
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await client.request('DELETE', '/coros/session');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await _pendingKey);
  }

  @override
  Future<void> manage(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => _CorosConnection(provider: this),
  );

  @override
  Future<bool> preview(
    BuildContext context,
    WatchExportRequest workout, {
    required bool canChange,
  }) => showWatchExportDialog(
    context,
    workout,
    CorosExportFlow(client),
    canChange: canChange,
  );
}

class _CorosConnection extends StatefulWidget {
  const _CorosConnection({required this.provider});
  final CorosWatchProvider provider;

  @override
  State<_CorosConnection> createState() => _CorosConnectionState();
}

class _CorosConnectionState extends State<_CorosConnection> {
  bool busy = false, connected = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _run(() async {
      await widget.provider.complete();
      connected = await widget.provider.connected();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on WatchServiceFailure catch (failure) {
      error = switch (failure.code) {
        'coros_sign_in_denied' => 'watch_oauth_denied',
        'coros_sign_in_expired' || 'coros_reconnect' => 'watch_oauth_expired',
        _ => 'watch_error',
      };
    } catch (_) {
      error = 'watch_error';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.provider.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy) const LinearProgressIndicator(),
          if (!busy)
            Text(connected ? s['watch_connected'] : s['watch_disconnected']),
          if (error case final key?)
            Text(s.watchLabel(key, widget.provider.name)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(s['watch_close']),
        ),
        if (connected)
          TextButton(
            onPressed: busy
                ? null
                : () => _run(() async {
                    await widget.provider.disconnect();
                    connected = false;
                  }),
            child: Text(s['watch_disconnect']),
          )
        else
          FilledButton(
            onPressed: busy ? null : () => _run(widget.provider.start),
            child: Text(s['watch_connect']),
          ),
      ],
    );
  }
}
