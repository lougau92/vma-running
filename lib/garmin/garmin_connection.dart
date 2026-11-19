import 'package:flutter/material.dart';
import '../app_localizations.dart';
import '../watch/watch_provider.dart' show garminConnectName;
import 'garmin_client.dart';

String garminError(AppLocalizations s, Object error) {
  final code = error is GarminFailure ? error.code : '';
  if (code == 'outcome_unknown_check_garmin_before_retry') {
    return s['garmin_unknown_outcome'];
  }
  if (['garmin_reconnect_required', 'garmin_not_connected'].contains(code)) {
    return s['garmin_reconnect'];
  }
  if (['invalid_mfa_challenge', 'mfa_challenge_expired'].contains(code)) {
    return s['garmin_mfa_restart'];
  }
  if (['rate_limited', 'garmin_rate_limited'].contains(code)) {
    return s['garmin_rate_limit'];
  }
  if (code == 'operation_in_progress') return s['garmin_busy'];
  if (code == 'journal_unavailable') return s['garmin_journal_error'];
  return s['garmin_error'];
}

Future<bool> showGarminConnection(
  BuildContext context,
  GarminClient client,
) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GarminConnectionDialog(client: client),
    ) ??
    false;

class GarminConnectionDialog extends StatefulWidget {
  const GarminConnectionDialog({super.key, required this.client});
  final GarminClient client;
  @override
  State<GarminConnectionDialog> createState() => _ConnectionState();
}

class _ConnectionState extends State<GarminConnectionDialog> {
  final email = TextEditingController();
  final password = TextEditingController();
  final code = TextEditingController();
  String? challenge, error;
  bool busy = false;
  bool? connected;
  @override
  void initState() {
    super.initState();
    if (widget.client.configured) {
      _check();
    }
  }

  Future<void> _check() => _run(() async {
    connected = await widget.client.status();
  });
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) error = garminError(AppLocalizations.of(context), e);
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> _login() => _run(() async {
    if (challenge != null) {
      final pending = challenge!;
      final value = code.text;
      code.clear();
      challenge = null;
      await widget.client.mfa(pending, value);
      connected = true;
    } else {
      final value = password.text;
      password.clear();
      final result = await widget.client.login(email.text.trim(), value);
      challenge = result.challenge;
      connected = challenge == null;
    }
  });
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: const Text(garminConnectName),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s['garmin_identity_note']),
                const SizedBox(height: 16),
                if (!widget.client.configured)
                  Text(s['garmin_unavailable'])
                else if (connected == true)
                  Text(s['garmin_connected'])
                else if (connected == false || challenge != null) ...[
                  if (challenge == null) ...[
                    TextField(
                      controller: email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: s['garmin_email']),
                    ),
                    TextField(
                      controller: password,
                      enabled: !busy,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: s['garmin_password'],
                      ),
                    ),
                  ] else ...[
                    Text(s['garmin_mfa_note']),
                    TextField(
                      controller: code,
                      enabled: !busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(labelText: s['garmin_mfa']),
                    ),
                  ],
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!),
                  ),
                if (busy) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () => Navigator.pop(context, connected == true),
            child: Text(s['watch_close']),
          ),
          if (widget.client.configured && connected == null && !busy)
            TextButton(onPressed: _check, child: Text(s['workout_retry'])),
          if (connected == true)
            TextButton(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                      await widget.client.disconnect();
                      connected = false;
                    }),
              child: Text(s['watch_disconnect']),
            ),
          if (connected == false || challenge != null)
            FilledButton(
              onPressed: busy ? null : _login,
              child: Text(s['watch_connect']),
            ),
        ],
      ),
    );
  }
}
