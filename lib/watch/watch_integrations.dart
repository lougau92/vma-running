import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_localizations.dart';
import '../coros/coros_watch_provider.dart';
import '../garmin/garmin_client.dart';
import '../garmin/garmin_watch_provider.dart';
import 'watch_provider.dart';
import 'watch_service_client.dart';

export 'watch_provider.dart';

class WatchIntegrations {
  WatchIntegrations(GarminClient client, {List<WatchProvider>? providers})
    : client = client,
      _adapters = {
        for (final provider in [
          GarminWatchProvider(client),
          CorosWatchProvider(client),
          ...?providers,
        ])
          provider.id: provider,
      };

  final WatchServiceClient client;
  final Map<String, WatchProvider> _adapters;

  Future<List<WatchDestination>> available() async {
    final garmin = WatchDestination(
      _adapters['garmin']!,
      canExport: client.configured,
      canListDevices: client.configured,
    );
    if (!client.configured) return [garmin];

    try {
      final response = await client.request('GET', '/watch/providers');
      return [
        for (final entry in (response['providers'] as List).whereType<Map>())
          if (_adapters[entry['id']] case final provider?)
            WatchDestination(
              provider,
              canExport: entry['saveWorkout'] == true,
              canListDevices: entry['listDevices'] == true,
            ),
      ];
    } catch (_) {
      // Preserve Garmin for clients pointed at a deployment without discovery.
      return [garmin];
    }
  }

  Future<String> get _defaultKey async =>
      'watch_default_${await client.session.userId()}';

  Future<String?> defaultProvider() async {
    if (!client.configured) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(await _defaultKey);
  }

  Future<void> setDefault(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _defaultKey;
    final saved = id == null
        ? await prefs.remove(key)
        : await prefs.setString(key, id);
    if (!saved) throw const WatchServiceFailure('preference_unavailable');
  }
}

Future<void> showWatchIntegrations(
  BuildContext context, {
  String? returningProvider,
  WatchIntegrations? integrations,
}) async {
  final localClient = integrations == null ? GarminClient() : null;
  try {
    await _manageIntegrations(
      context,
      integrations ?? WatchIntegrations(localClient!),
      returningProvider: returningProvider,
    );
  } finally {
    localClient?.close();
  }
}

Future<void> _manageIntegrations(
  BuildContext context,
  WatchIntegrations integrations, {
  String? returningProvider,
}) => showDialog<void>(
  context: context,
  builder: (_) => _IntegrationList(
    integrations: integrations,
    returningProvider: returningProvider,
  ),
);

Future<void> showWatchExport(
  BuildContext context,
  WatchExportRequest workout, {
  WatchIntegrations? integrations,
}) async {
  final localClient = integrations == null ? GarminClient() : null;
  final registry = integrations ?? WatchIntegrations(localClient!);
  try {
    final available = await registry.available();
    final connected = <WatchDestination>[
      for (final entry in available)
        if (entry.canExport && await _connected(entry.provider)) entry,
    ];
    if (!context.mounted) return;
    if (connected.isEmpty) {
      await _manageIntegrations(context, registry);
      return;
    }
    final preferred = connected.length > 1
        ? await registry.defaultProvider().onError((_, _) => null)
        : null;
    var selected = connected.length == 1
        ? connected.single
        : connected
              .where((entry) => entry.provider.id == preferred)
              .firstOrNull;
    while (true) {
      if (!context.mounted) return;
      selected ??= await _pick(context, connected);
      if (selected == null || !context.mounted) return;
      final change = await selected.provider.preview(
        context,
        workout,
        canChange: connected.length > 1,
      );
      if (!change) return;
      selected = null;
    }
  } catch (_) {
    if (context.mounted) await _manageIntegrations(context, registry);
  } finally {
    localClient?.close();
  }
}

Future<bool> _connected(WatchProvider provider) async {
  try {
    return await provider.connected();
  } catch (_) {
    return false;
  }
}

Future<WatchDestination?> _pick(
  BuildContext context,
  List<WatchDestination> connected,
) => showDialog(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(AppLocalizations.of(context)['watch_destination']),
    children: [
      for (final entry in connected)
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, entry),
          child: Text(entry.provider.name),
        ),
    ],
  ),
);

class _IntegrationList extends StatefulWidget {
  const _IntegrationList({
    required this.integrations,
    required this.returningProvider,
  });
  final WatchIntegrations integrations;
  final String? returningProvider;

  @override
  State<_IntegrationList> createState() => _IntegrationListState();
}

class _IntegrationListState extends State<_IntegrationList> {
  Map<String, bool> connected = {};
  Map<String, List<String>> linkedDevices = {};
  List<WatchDestination> entries = [];
  String? preferred;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    final returning = widget.integrations._adapters[widget.returningProvider];
    if (returning == null) {
      _load();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await returning.resumeSignIn(context);
        if (mounted) await _load();
      });
    }
  }

  Future<void> _load() async {
    final available = await widget.integrations.available();
    final preferred = await widget.integrations.defaultProvider().onError(
      (_, _) => null,
    );
    final statuses = <String, bool>{
      for (final entry in available)
        entry.provider.id: await _connected(entry.provider),
    };
    if (!mounted) return;
    setState(() {
      entries = available;
      connected = statuses;
      linkedDevices = {};
      this.preferred = preferred;
      loading = false;
    });
    final names = await Future.wait([
      for (final entry in available)
        if (entry.canListDevices && statuses[entry.provider.id] == true)
          _devicesFor(entry.provider),
    ]);
    if (mounted) setState(() => linkedDevices = Map.fromEntries(names));
  }

  Future<MapEntry<String, List<String>>> _devicesFor(
    WatchProvider provider,
  ) async {
    try {
      return MapEntry(provider.id, await provider.devices());
    } catch (_) {
      return MapEntry(provider.id, const []);
    }
  }

  Future<void> _manage(WatchProvider provider) async {
    await provider.manage(context);
    if (mounted) await _load();
  }

  Future<void> _setDefault(String? id) async {
    try {
      await widget.integrations.setDefault(id);
      if (mounted) setState(() => preferred = id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)['watch_error'])),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final exportable = entries.where(
      (entry) => entry.canExport && connected[entry.provider.id] == true,
    );
    return AlertDialog(
      title: Text(s['watch_integrations']),
      content: SizedBox(
        width: 420,
        child: loading
            ? const LinearProgressIndicator()
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final entry in entries)
                    ListTile(
                      leading: const Icon(Icons.watch_outlined),
                      title: Text(entry.provider.name),
                      subtitle: Text(
                        [
                          connected[entry.provider.id] == true
                              ? s['watch_connected']
                              : s['watch_disconnected'],
                          ...?linkedDevices[entry.provider.id],
                        ].join(' · '),
                      ),
                      onTap: () => _manage(entry.provider),
                    ),
                  if (exportable.isNotEmpty)
                    DropdownButtonFormField<String>(
                      key: ValueKey(preferred),
                      initialValue:
                          exportable.any(
                            (entry) => entry.provider.id == preferred,
                          )
                          ? preferred
                          : '',
                      decoration: InputDecoration(
                        labelText: s['watch_default'],
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(s['watch_no_default']),
                        ),
                        for (final entry in exportable)
                          DropdownMenuItem(
                            value: entry.provider.id,
                            child: Text(entry.provider.name),
                          ),
                      ],
                      onChanged: (value) =>
                          _setDefault(value == '' ? null : value),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s['watch_close']),
        ),
      ],
    );
  }
}
