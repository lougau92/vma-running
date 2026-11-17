import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_localizations.dart';
import '../workouts/workout.dart';
import '../workouts/workout_format.dart';
import 'garmin_client.dart';
import 'garmin_connection.dart';
import 'garmin_export.dart';
import 'garmin_journal.dart';

Future<void> showGarminExport(
  BuildContext context, {
  required WorkoutSession session,
  required WorkoutVersion version,
  required double vma,
  List<WorkoutNote> notes = const [],
  GarminClient? client,
}) async {
  final effectiveClient = client ?? GarminClient();
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GarminExportDialog(
        session: session,
        version: version,
        vma: vma,
        notes: notes,
        client: effectiveClient,
      ),
    );
  } finally {
    if (client == null) effectiveClient.close();
  }
}

class GarminExportDialog extends StatefulWidget {
  const GarminExportDialog({
    super.key,
    required this.session,
    required this.version,
    required this.vma,
    required this.client,
    this.notes = const [],
  });
  final WorkoutSession session;
  final WorkoutVersion version;
  final double vma;
  final GarminClient client;
  final List<WorkoutNote> notes;
  @override
  State<GarminExportDialog> createState() => _ExportState();
}

class _ExportState extends State<GarminExportDialog> {
  final values = <String, double>{};
  final fields = <String, ExportInput>{};
  late final journal = GarminJournal(widget.client);
  GarminOperation? operation;
  List<GarminOperation> history = [];
  List<GarminDevice>? devices;
  int? selectedDevice;
  String? error;
  bool busy = false, initialized = false;
  bool journalReady = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      _loadHistory();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
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

  Future<void> _loadHistory() => _run(() async {
    if (!widget.client.configured) return;
    history = await journal.load();
    journalReady = true;
  });
  Future<void> _upload(GarminExport export, {bool anotherCopy = false}) =>
      _run(() async {
        if (!await widget.client.status()) {
          if (!mounted) return;
          if (!await showGarminConnection(context, widget.client)) return;
        }
        if (!mounted) return;
        operation ??= await journal.prepare(
          export.payload,
          anotherCopy: anotherCopy,
        );
        await journal.upload(operation!);
        history = await journal.load();
      });
  Future<void> _loadDevices() => _run(() async {
    devices = (await widget.client.devices()).where((d) => d.eligible).toList();
    selectedDevice = devices!.length == 1 ? devices!.single.id : null;
  });
  Future<void> _send() => _run(() async {
    await journal.send(operation!, selectedDevice!);
  });
  Future<void> _another() async {
    final s = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s['garmin_another']),
        content: Text(s['garmin_duplicate_note']),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s['garmin_another']),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final snapshot = operation!.payload;
      await _run(() async {
        operation = await journal.prepare(snapshot, anotherCopy: true);
        devices = null;
        selectedDevice = null;
        await journal.upload(operation!);
        history = await journal.load();
      });
    }
  }

  Widget _input(ExportInput input, AppLocalizations s) {
    if (input.options != null) {
      return DropdownButtonFormField<double>(
        key: ValueKey(input.path),
        initialValue:
            values[input.path] ?? (input.path.endsWith('/optional') ? 0 : null),
        isExpanded: true,
        decoration: InputDecoration(labelText: input.label),
        items: [
          for (var i = 0; i < input.options!.length; i++)
            DropdownMenuItem(
              value: i.toDouble(),
              child: Text(input.options![i], overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: busy
            ? null
            : (v) => setState(() {
                if (v != null) values[input.path] = v;
              }),
      );
    }
    final b = input.bounds!;
    return TextFormField(
      key: ValueKey(input.path),
      enabled: !busy,
      initialValue: values[input.path]?.isFinite == true
          ? workoutNumber(values[input.path]!)
          : null,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: input.label,
        helperText: '${workoutNumber(b.min)}–${workoutNumber(b.max)}',
        errorText:
            values.containsKey(input.path) &&
                (!values[input.path]!.isFinite ||
                    values[input.path]! < b.min ||
                    values[input.path]! > b.max ||
                    (input.integer && values[input.path]! % 1 != 0))
            ? s['garmin_range_error']
            : null,
      ),
      onChanged: (text) => setState(() {
        values[input.path] =
            double.tryParse(text.replaceAll(',', '.')) ?? double.nan;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final export = buildGarminExport(
      widget.session,
      widget.version,
      widget.vma,
      s,
      values: values,
      notes: widget.notes,
    );
    fields.clear();
    for (final input in export.inputs) {
      fields[input.path] = input;
    }
    final payload = operation?.payload ?? export.payload;
    final steps =
        ((payload['workoutSegments'] as List).single as Map)['workoutSteps']
            as List;
    final id = operation?.workoutId;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (operation == null)
          Text('${widget.version.label} · VMA ${widget.vma} km/h'),
        if (!widget.client.configured) Text(s['garmin_unavailable']),
        if (operation == null) ...[
          ...fields.values.map(
            (input) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _input(input, s),
            ),
          ),
          ...export.warnings.map(
            (w) =>
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(w)),
          ),
          ...export.problems.map(
            (p) =>
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(p)),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          payload['workoutName'] as String,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (payload['description'] != null)
          Text(payload['description'] as String),
        for (final raw in steps)
          _StepPreview(step: raw as Map<String, dynamic>),
        if (id != null) ...[
          Text(
            s['garmin_saved'],
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SelectableText('https://connect.garmin.com/modern/workout/$id'),
          TextButton.icon(
            onPressed: () => Clipboard.setData(
              ClipboardData(
                text: 'https://connect.garmin.com/modern/workout/$id',
              ),
            ),
            icon: const Icon(Icons.copy),
            label: Text(s['garmin_copy_link']),
          ),
          if (devices == null)
            OutlinedButton(
              onPressed: busy ? null : _loadDevices,
              child: Text(s['garmin_send']),
            ),
          if (devices != null && devices!.isEmpty) Text(s['garmin_no_watch']),
          if (devices != null && devices!.isNotEmpty) ...[
            DropdownButtonFormField<int>(
              key: ValueKey(devices),
              initialValue: selectedDevice,
              isExpanded: true,
              decoration: InputDecoration(labelText: s['garmin_watch']),
              items: devices!
                  .map(
                    (d) => DropdownMenuItem(value: d.id, child: Text(d.name)),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      selectedDevice = v;
                    }),
            ),
            if (operation!.delivered.contains(selectedDevice))
              Text(s['garmin_delivery_requested'])
            else
              FilledButton(
                onPressed: busy || selectedDevice == null ? null : _send,
                child: Text(s['garmin_send']),
              ),
          ],
        ],
        if (operation == null && history.isNotEmpty)
          ExpansionTile(
            title: Text(s['garmin_recent']),
            children: [
              for (final previous in history.reversed.take(20))
                ListTile(
                  title: Text(previous.payload['workoutName'] as String),
                  subtitle: Text(
                    previous.workoutId == null
                        ? s['garmin_pending']
                        : '#${previous.workoutId}',
                  ),
                  onTap: busy
                      ? null
                      : () => setState(() {
                          operation = previous;
                          devices = null;
                          selectedDevice = null;
                        }),
                ),
            ],
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(error!),
          ),
        if (busy) const LinearProgressIndicator(),
      ],
    );
    final actions = <Widget>[
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: Text(s['garmin_close']),
      ),
      if (!journalReady && widget.client.configured)
        TextButton(
          onPressed: busy ? null : _loadHistory,
          child: Text(s['workout_retry']),
        ),
      if (operation != null)
        TextButton(
          onPressed: busy ? null : _another,
          child: Text(s['garmin_another']),
        ),
      if (id == null)
        FilledButton(
          onPressed:
              busy || !journalReady || (operation == null && !export.ready)
              ? null
              : () => _upload(export),
          child: Text(s['garmin_save']),
        ),
      if (error != null && widget.client.configured)
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  await showGarminConnection(context, widget.client);
                },
          child: Text(s['garmin_connect']),
        ),
    ];
    return PopScope(
      canPop: !busy,
      child: MediaQuery.sizeOf(context).width < 600
          ? Dialog.fullscreen(
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        s['garmin_export'],
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: content,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Wrap(spacing: 8, children: actions),
                    ),
                  ],
                ),
              ),
            )
          : AlertDialog(
              title: Text(s['garmin_export']),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(child: content),
              ),
              actions: actions,
            ),
    );
  }
}

class _StepPreview extends StatelessWidget {
  const _StepPreview({required this.step});
  final Map<String, dynamic> step;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final end = (step['endCondition'] as Map)['conditionTypeKey'];
    final value = step['endConditionValue'] as num?;
    final type = (step['stepType'] as Map)['stepTypeKey'];
    final label = switch (type) {
      'warmup' => s.warmup,
      'cooldown' => s.cooldown,
      'recovery' || 'rest' => s.recovery,
      _ => s.sessionContent,
    };
    String pace(num speed) => workoutTime((1000 / speed).roundToDouble());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${step['stepOrder']}. $label · ${end == 'lap.button'
                ? 'LAP'
                : end == 'time'
                ? workoutTime(value!.toDouble())
                : '${workoutNumber(value!.toDouble())} m'}',
          ),
          if (step['targetValueOne'] != null)
            Text(
              '${pace(step['targetValueOne'] as num)}–${pace(step['targetValueTwo'] as num)} /km',
            ),
          if (step['description'] != null) Text(step['description'] as String),
        ],
      ),
    );
  }
}
