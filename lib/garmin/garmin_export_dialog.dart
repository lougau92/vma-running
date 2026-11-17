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
    final unresolvedInputs = export.inputs
        .where((input) => !input.resolved)
        .toList();
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
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.watch_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.version.label,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text('VMA ${workoutNumber(widget.vma)} km/h'),
                      ],
                    ),
                  ),
                  if (widget.client.configured)
                    const Icon(Icons.cloud_done_outlined, size: 20),
                ],
              ),
            ),
          ),
        if (!widget.client.configured)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_outlined),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s['garmin_unavailable'])),
                ],
              ),
            ),
          ),
        if (operation == null && widget.client.configured && !journalReady)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(s['garmin_checking_history'])),
              ],
            ),
          ),
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
          if (unresolvedInputs.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['garmin_complete_inputs'],
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    for (final input in unresolvedInputs.take(5))
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text('• ${input.label}'),
                      ),
                    if (unresolvedInputs.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text('+${unresolvedInputs.length - 5}'),
                      ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 12),
        Card(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.directions_run,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        payload['workoutName'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${steps.length}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.list_alt,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (payload['description'] != null) ...[
                  const SizedBox(height: 10),
                  _CoachNotes(
                    text: payload['description'] as String,
                    title: s.remarks,
                  ),
                ],
              ],
            ),
          ),
        ),
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
    final icon = switch (type) {
      'warmup' => Icons.wb_twilight,
      'cooldown' => Icons.nights_stay_outlined,
      'recovery' || 'rest' => Icons.pause_circle_outline,
      _ => Icons.bolt,
    };
    final distanceLabel = end == 'lap.button'
        ? 'LAP'
        : end == 'time'
        ? workoutTime(value!.toDouble())
        : '${workoutNumber(value!.toDouble())} m';
    String pace(num speed) => workoutTime((1000 / speed).roundToDouble());
    final paceLabel = step['targetValueOne'] == null
        ? null
        : '${pace(step['targetValueTwo'] as num)}–${pace(step['targetValueOne'] as num)} /km';
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${step['stepOrder']}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 19, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        distanceLabel,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  if (paceLabel != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      paceLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (step['description'] != null) ...[
                    const SizedBox(height: 3),
                    _CoachNotes(
                      text: step['description'] as String,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachNotes extends StatelessWidget {
  const _CoachNotes({required this.text, this.title, this.compact = false});

  final String text;
  final String? title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || compact)
            Padding(
              padding: EdgeInsets.only(bottom: lines.length > 1 ? 4 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: compact ? 15 : 17,
                    color: colors.onSecondaryContainer,
                  ),
                  if (title != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      title!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          for (final line in lines)
            Padding(
              padding: EdgeInsets.only(top: compact ? 2 : 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lines.length > 1) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 7),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.onSecondaryContainer,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      line,
                      style: compact
                          ? theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSecondaryContainer,
                            )
                          : theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSecondaryContainer,
                            ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
