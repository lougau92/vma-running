import 'dart:convert';
import 'workout_fixture.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/workouts/workout.dart';
import 'package:vma_running/workouts/workout_format.dart';
import 'package:vma_running/workouts/workout_schema.g.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:flutter/material.dart';

void main() {
  final cases =
      jsonDecode(
            File(
              'test/fixtures/workouts/contract_cases.json',
            ).readAsStringSync(),
          )
          as List;
  for (final scenario in cases) {
    test(scenario['name'] as String, () {
      WorkoutConversion parse() => WorkoutConversion.parse(
        jsonEncode(workoutCase(scenario as Map<String, dynamic>)),
      );
      if (scenario['valid'] == true) {
        expect(parse, returnsNormally);
      } else {
        expect(parse, throwsFormatException);
      }
    });
  }
  test('generated schema matches the source contract', () {
    expect(
      workoutSchema,
      jsonDecode(File('docs/workouts/workout.schema.json').readAsStringSync()),
    );
  });
  test('all schema variants deserialize to immutable structures', () {
    final plan = WorkoutConversion.parse(
      File('test/fixtures/workouts/all_features.json').readAsStringSync(),
    );
    final sequence =
        plan.workouts.first.versions.first.main.plan! as WorkoutSequence;
    expect(sequence.children, hasLength(11));
    expect(() => sequence.children.clear(), throwsUnsupportedError);
    expect(() => plan.workouts.clear(), throwsUnsupportedError);
    expect(sequence.children.last, isA<WorkoutChoice>());
  });
  for (final locale in ['en', 'fr', 'nl']) {
    test('all endpoint and target variants format in $locale', () {
      final plan = WorkoutConversion.parse(
        File('test/fixtures/workouts/all_features.json').readAsStringSync(),
      );
      final s = AppLocalizations(Locale(locale));
      void walk(WorkoutNode node) {
        switch (node) {
          case WorkoutStep step:
            expect(formatWorkoutEnd(step.end, s), isNotEmpty);
            for (final target in step.targets) {
              expect(formatWorkoutTarget(target, s, 18), isNotEmpty);
            }
            expect(formatWorkoutMovement(step.movement, s), isNotEmpty);
          case WorkoutSequence sequence:
            sequence.children.forEach(walk);
          case WorkoutRepeat repeat:
            walk(repeat.body);
            if (repeat.between != null) walk(repeat.between!);
          case WorkoutChoice choice:
            for (final option in choice.options) {
              walk(option.plan);
            }
        }
      }

      walk(plan.workouts.first.versions.first.main.plan!);
    });
  }
  test(
    'VMA pace ranges preserve both bounds and invalid VMA preserves prescription',
    () {
      final target = WorkoutTarget({
        'kind': 'numeric',
        'metric': 'vma_percent',
        'value': {'min': 80, 'max': 100},
      });
      final s = AppLocalizations(const Locale('en'));
      expect(
        formatWorkoutTarget(target, s, 20),
        '80–100 % VMA · 03:00–03:45 /km',
      );
      expect(formatWorkoutTarget(target, s, 0), '80–100 % VMA');
      expect(formatWorkoutTarget(target, s, double.nan), '80–100 % VMA');
    },
  );
  test('fractional prescriptions remain visible without rounding to zero', () {
    expect(workoutNumber(0.001), '0.001');
    expect(workoutTime(0.001), '0.001 s');
  });
}
