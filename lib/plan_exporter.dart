import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_localizations.dart';
import 'app_settings.dart';
import 'time_utils.dart';
import 'training_plan.dart';

class PlanExportData {
  const PlanExportData({
    required this.plan,
    required this.group,
    required this.userVma,
    required this.strings,
    required this.settings,
    required this.onSettingsChanged,
  });

  final TrainingPlan plan;
  final BlockGroup group;
  final double userVma;
  final AppLocalizations strings;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
}

abstract class PlanExporter {
  String get id;
  String label(AppLocalizations strings);
  IconData get icon;
  Future<void> export(PlanExportData data, BuildContext context);
}

class ClipboardPlanExporter implements PlanExporter {
  @override
  String get id => 'clipboard';

  @override
  String label(AppLocalizations strings) => strings.export;

  @override
  IconData get icon => Icons.content_copy;

  @override
  Future<void> export(PlanExportData data, BuildContext context) async {
    final formatted = PlanExportFormatter(data).asPlainText();
    await Clipboard.setData(ClipboardData(text: formatted));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(data.strings.exportSuccess)));
  }
}

class GarminPlanExporter implements PlanExporter {
  @override
  String get id => 'garmin';

  @override
  String label(AppLocalizations strings) => strings.exportToGarmin;

  @override
  IconData get icon => Icons.watch;

  @override
  Future<void> export(PlanExportData data, BuildContext context) async {
    final strings = data.strings;
    final existingKey = _normalizeKey(data.settings.intervalsApiKey);
    var apiKey = existingKey;

    if (apiKey == null) {
      apiKey = await _promptForApiKey(context, strings);
      if (apiKey == null || !context.mounted) return;
      data.onSettingsChanged(data.settings.copyWith(intervalsApiKey: apiKey));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.intervalsApiKeySaved)));
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.exportToGarminComingSoon)));
  }

  String? _normalizeKey(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<String?> _promptForApiKey(
    BuildContext context,
    AppLocalizations strings,
  ) async {
    final controller = TextEditingController();
    String? validationError;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogCtx, setStateDialog) => AlertDialog(
          title: Text(strings.intervalsApiKeyPromptTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.intervalsApiKeyInstructions),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: strings.intervalsApiKeyLabel,
                  errorText: validationError,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  setStateDialog(
                    () => validationError = strings.enterIntervalsApiKey,
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );
  }
}

class PlanExportFormatter {
  const PlanExportFormatter(this.data);

  final PlanExportData data;

  String asPlainText() {
    final strings = data.strings;
    final plan = data.plan;
    final group = data.group;

    final buffer = StringBuffer()
      ..writeln('${strings.trainingPlanTab}: ${plan.title}')
      ..writeln('${strings.preSession}: ${plan.warmup}')
      ..writeln('${strings.sessionContent} (${group.title})');

    for (final block in group.blocks) {
      buffer.writeln('- ${block.title}');
      for (final set in block.sets) {
        buffer.writeln('  - ${formatSetLine(set, data.userVma, strings)}');
      }
      if (block.afterRecoverySeconds != null) {
        buffer.writeln(
          '  ${strings.recovery}: ${formatElapsed(block.afterRecoverySeconds!.toInt())} (${recoveryLabel(block.afterRecoveryType, strings)})',
        );
      }
    }

    buffer
      ..writeln('${strings.cooldown}: ${plan.cooldown}')
      ..writeln('${strings.remarks}: ${plan.remarks}');

    return buffer.toString();
  }
}

String formatSetLine(IntervalSet set, double vma, AppLocalizations strings) {
  final reps = '${set.repetitions}x';
  final load = set.distanceMeters != null
      ? strings.distanceShort(set.distanceMeters!)
      : set.durationSeconds != null
      ? formatElapsed(set.durationSeconds!.toInt())
      : '';
  final adjustedSpeed = vma * set.vmaPercent / 100;
  final pace = formatPacePerKm(adjustedSpeed, includeUnit: true);
  final recov =
      '${formatElapsed(set.recoverySeconds.toInt())} ${recoveryLabel(set.recoveryType, strings)}';
  return '$reps $load @ $pace | $recov';
}

String recoveryLabel(RecoveryType type, AppLocalizations strings) {
  switch (type) {
    case RecoveryType.active:
      return strings.activeRecovery;
    case RecoveryType.walk:
      return strings.walkRecovery;
    case RecoveryType.jog:
      return strings.jogRecovery;
    case RecoveryType.rest:
      return strings.restRecovery;
  }
}
