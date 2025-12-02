import 'dart:convert';
import 'package:flutter/services.dart';

enum RecoveryType { active, walk, jog, rest }

class IntervalSet {
  const IntervalSet({
    required this.repetitions,
    this.distanceMeters,
    this.durationSeconds,
    required this.vmaPercent,
    required this.recoverySeconds,
    required this.recoveryType,
  });

  final int repetitions;
  final double? distanceMeters;
  final double? durationSeconds;
  final double vmaPercent;
  final double recoverySeconds;
  final RecoveryType recoveryType;

  factory IntervalSet.fromJson(Map<String, dynamic> json) {
    return IntervalSet(
      repetitions: json['repetitions'] as int,
      distanceMeters: json['distanceMeters']?.toDouble(),
      durationSeconds: json['durationSeconds']?.toDouble(),
      vmaPercent: json['vmaPercent'].toDouble(),
      recoverySeconds: json['recoverySeconds'].toDouble(),
      recoveryType: RecoveryType.values.firstWhere(
        (e) => e.toString().split('.').last == json['recoveryType'],
      ),
    );
  }
}

class TrainingBlock {
  const TrainingBlock({
    required this.title,
    required this.sets,
    this.afterRecoverySeconds,
    this.afterRecoveryType = RecoveryType.rest,
  });

  final String title;
  final List<IntervalSet> sets;
  final double? afterRecoverySeconds;
  final RecoveryType afterRecoveryType;

  factory TrainingBlock.fromJson(Map<String, dynamic> json) {
    return TrainingBlock(
      title: json['title'] as String,
      sets: (json['sets'] as List)
          .map((setJson) => IntervalSet.fromJson(setJson))
          .toList(),
      afterRecoverySeconds: json['afterRecoverySeconds']?.toDouble(),
      afterRecoveryType: json['afterRecoveryType'] != null
          ? RecoveryType.values.firstWhere(
              (e) => e.toString().split('.').last == json['afterRecoveryType'],
            )
          : RecoveryType.rest,
    );
  }
}

class BlockGroup {
  const BlockGroup({required this.title, required this.blocks});

  final String title;
  final List<TrainingBlock> blocks;

  factory BlockGroup.fromJson(Map<String, dynamic> json) {
    return BlockGroup(
      title: json['title'] as String,
      blocks: (json['blocks'] as List)
          .map((blockJson) => TrainingBlock.fromJson(blockJson))
          .toList(),
    );
  }
}

class TrainingPlan {
  const TrainingPlan({
    required this.title,
    required this.warmup,
    required this.cooldown,
    required this.remarks,
    required this.groups,
  });

  final String title;
  final String warmup;
  final String cooldown;
  final String remarks;
  final List<BlockGroup> groups;

  factory TrainingPlan.fromJson(Map<String, dynamic> json) {
    return TrainingPlan(
      title: json['title'] as String,
      warmup: json['warmup'] as String,
      cooldown: json['cooldown'] as String,
      remarks: json['remarks'] as String,
      groups: (json['groups'] as List)
          .map((groupJson) => BlockGroup.fromJson(groupJson))
          .toList(),
    );
  }

  factory TrainingPlan.fromJsonString(String jsonString) {
    try {
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      return TrainingPlan.fromJson(jsonData);
    } catch (e) {
      throw Exception('Failed to load training plan: $e');
    }
  }
}

Future<TrainingPlan> loadTrainingPlanFromAssets(String filePath) async {
  try {
    final String jsonString = await rootBundle.loadString(filePath);
    return TrainingPlan.fromJsonString(jsonString);
  } catch (e) {
    throw Exception('Failed to load training plan: $e');
  }
}
