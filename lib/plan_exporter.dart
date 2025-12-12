import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_localizations.dart';
import 'time_utils.dart';
import 'training_plan.dart';


class PlanExportData {
  const PlanExportData({
    required this.plan,
    required this.group,
    required this.userVma,
    required this.strings,
  });

  final TrainingPlan plan;
  final BlockGroup group;
  final double userVma;
  final AppLocalizations strings;
}

abstract class PlanExporter {
  String get id;
  String label(AppLocalizations strings);
  Future<void> export(PlanExportData data, BuildContext context);
}

class ClipboardPlanExporter implements PlanExporter {
  @override
  String get id => 'clipboard';

  @override
  String label(AppLocalizations strings) => strings.export;

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
  Future<void> export(PlanExportData data, BuildContext context) async {
    
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
