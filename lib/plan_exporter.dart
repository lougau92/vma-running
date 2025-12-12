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
  String label(AppLocalizations strings) => strings.exportToClipboard;

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
    final existingKey = _normalize(data.settings.intervalsApiKey);
    final existingAthlete = _normalize(data.settings.intervalsAthleteId);
    String? apiKey = existingKey;
    String? athleteId = existingAthlete;

    if (apiKey == null || athleteId == null) {
      final result = await _promptForCredentials(
        context,
        strings,
        existingApiKey: apiKey,
        existingAthleteId: athleteId,
      );
      if (result == null || !context.mounted) return;
      apiKey = result.apiKey;
      athleteId = result.athleteId;
      data.onSettingsChanged(
        data.settings.copyWith(
          intervalsApiKey: apiKey,
          intervalsAthleteId: athleteId,
        ),
      );
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

  String? _normalize(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<_IntervalsCredentials?> _promptForCredentials(
    BuildContext context,
    AppLocalizations strings,
    {String? existingApiKey, String? existingAthleteId}) async {
    final apiKeyController = TextEditingController(text: existingApiKey ?? '');
    final athleteController =
        TextEditingController(text: existingAthleteId ?? '');
    String? keyError;
    String? athleteError;
    final steps = strings.intervalsApiKeyInstructions.split('\n');

    return showDialog<_IntervalsCredentials>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogCtx, setStateDialog) => AlertDialog(
          title: Text(strings.intervalsApiKeyPromptTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.intervalsApiKeyInstructionsTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...steps.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(line),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: athleteController,
                decoration: InputDecoration(
                  labelText: strings.intervalsAthleteIdLabel,
                  hintText: strings.intervalsAthleteIdHint,
                  errorText: athleteError,
                ),
                onChanged: (_) {
                  if (athleteError != null) {
                    setStateDialog(() => athleteError = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apiKeyController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: strings.intervalsApiKeyLabel,
                  hintText: strings.intervalsApiKeyHint,
                  errorText: keyError,
                ),
                onChanged: (_) {
                  if (keyError != null) {
                    setStateDialog(() => keyError = null);
                  }
                },
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
                final keyValue = apiKeyController.text.trim();
                final athleteValue = athleteController.text.trim();
                String? nextKeyError;
                String? nextAthleteError;

                if (athleteValue.isEmpty ||
                    !_isValidAthleteId(athleteValue)) {
                  nextAthleteError = strings.intervalsAthleteIdInvalid;
                }
                if (keyValue.isEmpty || !_isValidApiKey(keyValue)) {
                  nextKeyError = keyValue.isEmpty
                      ? strings.enterIntervalsApiKey
                      : strings.intervalsApiKeyInvalid;
                }
                if (nextAthleteError != null || nextKeyError != null) {
                  setStateDialog(() {
                    keyError = nextKeyError;
                    athleteError = nextAthleteError;
                  });
                  return;
                }
                Navigator.of(dialogContext).pop(
                  _IntervalsCredentials(
                    apiKey: keyValue,
                    athleteId: athleteValue,
                  ),
                );
              },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntervalsCredentials {
  const _IntervalsCredentials({required this.apiKey, required this.athleteId});

  final String apiKey;
  final String athleteId;
}

bool _isValidAthleteId(String value) {
  return RegExp(r'^i[0-9]+$').hasMatch(value.trim());
}

bool _isValidApiKey(String value) {
  return RegExp(r'^[A-Za-z0-9]{20,40}$').hasMatch(value.trim());
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
