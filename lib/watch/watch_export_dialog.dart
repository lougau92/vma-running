import 'package:flutter/material.dart';

import '../app_localizations.dart';
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

Future<void> showWatchExportDialog(
  BuildContext context,
  WatchExportRequest workout,
  WatchExportFlow flow,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => WatchExportDialog(workout: workout, flow: flow),
);

class WatchExportDialog extends StatefulWidget {
  const WatchExportDialog({
    super.key,
    required this.workout,
    required this.flow,
  });

  final WatchExportRequest workout;
  final WatchExportFlow flow;

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
      saved: _saved,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error case final error?) ...[
            WatchExportStatus(
              message: flow.errorMessage(s, error),
              success: false,
            ),
            const SizedBox(height: 16),
          ],
          if (_saved) ...[
            WatchExportStatus(
              message: s.watchLabel('watch_saved', flow.destination),
              detail: preview.title,
            ),
            const SizedBox(height: 16),
            ...flow.savedDetails(
              context,
              busy: _busy,
              run: _run,
              refresh: () => setState(() {}),
            ),
          ] else ...[
            Text(preview.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              s.yourVma(widget.workout.vma),
              style: theme.textTheme.bodyMedium,
            ),
            if (!flow.inputsLocked) ...[
              if (preview.inputs.isNotEmpty) ...[
                const SizedBox(height: 12),
                WatchExportInputs(
                  inputs: preview.inputs,
                  enabled: !_busy,
                  onChanged: (path, value) =>
                      setState(() => _values[path] = value),
                ),
              ],
              for (final message in preview.messages)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(message, style: theme.textTheme.bodySmall),
                ),
            ],
            if (preview.notes case final notes? when notes.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: WatchPreviewNotes(text: notes, title: s.remarks),
              ),
            const SizedBox(height: 20),
            Text(s['watch_steps'], style: theme.textTheme.titleSmall),
            const Divider(),
            ...preview.steps,
          ],
        ],
      ),
      actions: [
        if (!_saved)
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(s['watch_close']),
          ),
        if (_saved)
          FilledButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(s['watch_close']),
          )
        else
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
    required this.saved,
    required this.content,
    required this.actions,
  });

  final String title;
  final bool busy, saved;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scroll = SingleChildScrollView(
      key: ValueKey(saved),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: content,
    );
    final progress = busy
        ? const LinearProgressIndicator()
        : const Divider(height: 1);
    return PopScope(
      canPop: !busy,
      child: MediaQuery.sizeOf(context).width < 600
          ? Dialog.fullscreen(
              backgroundColor: theme.colorScheme.surface,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Text(title, style: theme.textTheme.titleLarge),
                    ),
                    progress,
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: scroll,
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: OverflowBar(
                        alignment: MainAxisAlignment.end,
                        overflowAlignment: OverflowBarAlignment.end,
                        spacing: 8,
                        children: actions,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    progress,
                    Flexible(child: scroll),
                  ],
                ),
              ),
              actions: actions,
            ),
    );
  }
}
