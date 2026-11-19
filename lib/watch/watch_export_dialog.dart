import 'package:flutter/material.dart';

import '../app_localizations.dart';
import '../workouts/workout_format.dart';
import 'watch_preview.dart';
import 'watch_provider.dart';
import 'watch_workout.dart';

typedef WatchExportAction = Future<void> Function();

class WatchExportPreview {
  const WatchExportPreview({
    required this.title,
    this.notes,
    required this.steps,
    required this.inputs,
    required this.messages,
    this.save,
  });

  final String title;
  final String? notes;
  final List<Widget> steps;
  final List<ExportInput> inputs;
  final List<String> messages;
  final Future<bool> Function()? save;
}

/// One flow per open dialog. Providers supply the exact preview and save action.
abstract class WatchExportFlow {
  String get name;
  String get destination => name;
  bool get inputsLocked => false;

  Future<void> initialize() async {}
  String errorMessage(AppLocalizations strings, Object error);
  WatchExportPreview preview(
    BuildContext context,
    WatchExportRequest request,
    Map<String, double> values,
  );

  List<Widget> savedDetails(
    BuildContext context, {
    required bool busy,
    required ValueChanged<WatchExportAction> run,
    required VoidCallback refresh,
  }) => const [];
}

Future<bool> showWatchExportDialog(
  BuildContext context,
  WatchExportRequest workout,
  WatchExportFlow flow, {
  required bool canChange,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          WatchExportDialog(workout: workout, flow: flow, canChange: canChange),
    ) ??
    false;

class WatchExportDialog extends StatefulWidget {
  const WatchExportDialog({
    super.key,
    required this.workout,
    required this.flow,
    this.canChange = false,
  });

  final WatchExportRequest workout;
  final WatchExportFlow flow;
  final bool canChange;

  @override
  State<WatchExportDialog> createState() => _WatchExportDialogState();
}

class _WatchExportDialogState extends State<WatchExportDialog> {
  final _values = <String, double>{};
  bool _busy = false, _saved = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _run(widget.flow.initialize);
  }

  Future<void> _run(WatchExportAction action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final flow = widget.flow;
    final preview = flow.preview(context, widget.workout, _values);
    final save =
        flow.inputsLocked || preview.inputs.every((input) => input.resolved)
        ? preview.save
        : null;
    return _ExportDialogFrame(
      title: s.watchLabel('watch_export_to', flow.name),
      busy: _busy,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.workout.version.label} · VMA ${workoutNumber(widget.workout.vma)} km/h',
            style: theme.textTheme.titleSmall,
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(flow.errorMessage(s, error)),
            ),
          if (!_saved && !flow.inputsLocked) ...[
            WatchExportInputs(
              inputs: preview.inputs,
              enabled: !_busy,
              onChanged: (path, value) => setState(() => _values[path] = value),
            ),
            for (final message in preview.messages)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(message),
              ),
          ],
          if (_saved) ...[
            Text(
              s.watchLabel('watch_saved', flow.destination),
              style: theme.textTheme.titleMedium,
            ),
            ...flow.savedDetails(
              context,
              busy: _busy,
              run: _run,
              refresh: () => setState(() {}),
            ),
          ],
          const SizedBox(height: 12),
          Text(preview.title, style: theme.textTheme.titleMedium),
          if (preview.notes case final notes? when notes.trim().isNotEmpty)
            WatchPreviewNotes(text: notes, title: s.remarks),
          ...preview.steps,
        ],
      ),
      actions: [
        if (widget.canChange)
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, true),
            child: Text(s['watch_change_destination']),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(s['watch_close']),
        ),
        if (!_saved)
          FilledButton(
            onPressed: _busy || save == null
                ? null
                : () => _run(() async {
                    _saved = await save();
                  }),
            child: Text(s.watchLabel('watch_save', flow.destination)),
          ),
      ],
    );
  }
}

class _ExportDialogFrame extends StatelessWidget {
  const _ExportDialogFrame({
    required this.title,
    required this.busy,
    required this.content,
    required this.actions,
  });

  final String title;
  final bool busy;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
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
                        title,
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
              title: Text(title),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(child: content),
              ),
              actions: actions,
            ),
    );
  }
}
