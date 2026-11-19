import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_localizations.dart';
import '../runtime/runtime_platform.dart' show openBrowserPage;
import '../watch/watch_export_dialog.dart';
import '../watch/watch_provider.dart';
import '../watch/watch_service_client.dart';
import 'coros_export_flow.dart';

enum _Authorization { none, pending, connected }

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

  Future<void> _start() async {
    final pending = await client.request('POST', '/coros/login/start');
    final url = Uri.parse(pending['url'] as String);
    if (url.origin != 'https://mcpeu.coros.com' ||
        url.path != '/oauth2/authorize') {
      throw const WatchServiceFailure('coros_unavailable');
    }
    final prefs = await SharedPreferences.getInstance();
    final key = await _pendingKey;
    if (!await prefs.setString(
      key,
      jsonEncode({'attempt': pending['attempt'], 'proof': pending['proof']}),
    )) {
      throw const WatchServiceFailure('coros_unavailable');
    }
    try {
      if (!await openBrowserPage(url)) {
        throw const WatchServiceFailure('coros_unavailable');
      }
    } catch (_) {
      await prefs.remove(key);
      rethrow;
    }
  }

  Future<_Authorization> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _pendingKey;
    final pending = prefs.getString(key);
    if (pending == null) return _Authorization.none;
    try {
      final result = await client.request(
        'POST',
        '/coros/login/complete',
        body: jsonDecode(pending) as Map<String, dynamic>,
      );
      switch (result['status']) {
        case 'pending':
          return _Authorization.pending;
        case 'connected':
          await prefs.remove(key);
          return _Authorization.connected;
        default:
          throw const WatchServiceFailure('coros_unavailable');
      }
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
  Future<void> manage(BuildContext context) => _showConnection(context);

  @override
  Future<void> resumeSignIn(BuildContext context) =>
      _showConnection(context, returning: true);

  Future<void> _showConnection(
    BuildContext context, {
    bool returning = false,
  }) => showDialog<void>(
    context: context,
    builder: (_) => _CorosConnection(provider: this, returning: returning),
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
  const _CorosConnection({required this.provider, required this.returning});
  final CorosWatchProvider provider;
  final bool returning;

  @override
  State<_CorosConnection> createState() => _CorosConnectionState();
}

class _CorosConnectionState extends State<_CorosConnection> {
  late final AppLifecycleListener _lifecycle;
  bool busy = false, connected = false, pending = false, canRetry = false;
  bool missingAttempt = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (pending) _check();
      },
    );
    _check();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() => _run(() async {
    canRetry = true;
    final authorization = await widget.provider._complete();
    pending = authorization == _Authorization.pending;
    connected = switch (authorization) {
      _Authorization.none => await widget.provider.connected(),
      _Authorization.pending => false,
      _Authorization.connected => true,
    };
    missingAttempt =
        widget.returning && authorization == _Authorization.none && !connected;
    canRetry = false;
  });

  Future<void> _start() => _run(() async {
    await widget.provider._start();
    pending = true;
    canRetry = false;
    missingAttempt = false;
  });

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
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
      if (error != 'watch_error') {
        pending = false;
        canRetry = false;
      }
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
      scrollable: true,
      title: Text(widget.provider.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy) const LinearProgressIndicator(),
          if (connected)
            Text(s['watch_connected'])
          else if (pending)
            Text(s.watchLabel('watch_oauth_pending', widget.provider.name))
          else if (missingAttempt)
            Text(s.watchLabel('watch_oauth_original_app', widget.provider.name))
          else if (!busy)
            Text(s['watch_disconnected']),
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
        else if (!missingAttempt) ...[
          if (pending || canRetry)
            TextButton(
              onPressed: busy ? null : _start,
              child: Text(s['watch_oauth_restart']),
            ),
          FilledButton(
            onPressed: busy ? null : (pending || canRetry ? _check : _start),
            child: Text(
              pending
                  ? s['watch_oauth_finish']
                  : canRetry
                  ? s['workout_retry']
                  : s['watch_connect'],
            ),
          ),
        ],
      ],
    );
  }
}
