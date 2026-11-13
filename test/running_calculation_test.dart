import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/calculator/running_calculator_draft.dart';

void main() {
  test('all independent pairs and input orders produce the same run', () {
    const inputs = {
      RunningMeasure.distance: '5',
      RunningMeasure.time: '25:00',
      RunningMeasure.speed: '12',
      RunningMeasure.pace: '5:00',
      RunningMeasure.intensity: '66.66666666666667',
    };
    for (final first in inputs.keys) {
      for (final second in inputs.keys) {
        final result = RunningCalculatorDraft(
          first: first,
          second: second,
          firstText: inputs[first]!,
          secondText: inputs[second]!,
        ).calculate(18);
        if (first.quantity == second.quantity) {
          expect(result, isNull);
          continue;
        }
        expect(result, isNotNull, reason: '$first + $second');
        expect(result!.distanceKm, closeTo(5, 1e-9));
        expect(result.seconds, closeTo(1500, 1e-9));
        expect(result.speed.kmh, closeTo(12, 1e-9));
        expect(result.speed.paceSecondsPerKm, closeTo(300, 1e-9));
        expect(result.speed.percentOfVma(18), closeTo(200 / 3, 1e-9));
      }
    }
  });

  test('parses decimal commas and unambiguous duration formats', () {
    expect(parseRunningValue(RunningMeasure.distance, ' 0,4 '), 400);
    expect(parseRunningValue(RunningMeasure.time, '1:02:03.5'), 3723.5);
    expect(parseRunningValue(RunningMeasure.time, '90:00'), 5400);
    expect(parseRunningValue(RunningMeasure.time, '65'), 65);
    expect(
      parseRunningValue(RunningMeasure.pace, '4:30,5'),
      closeTo(3600 / 270.5, 1e-10),
    );
    expect(parseRunningValue(RunningMeasure.intensity, '110', vma: 18), 19.8);
  });

  test(
    'invalid, partial, zero, negative and nonfinite inputs cannot produce results',
    () {
      for (final text in [
        '',
        ' ',
        '0',
        '-5',
        'NaN',
        'Infinity',
        '1e999',
        '1.2.3',
      ]) {
        expect(
          const RunningCalculatorDraft().edit(0, text).calculate(18),
          isNull,
        );
      }
      for (final text in [
        '1:',
        ':30',
        '1:60',
        '1:00:60',
        '1.5:30',
        '1:2:3:4',
      ]) {
        expect(
          const RunningCalculatorDraft().edit(1, text).calculate(18),
          isNull,
        );
      }
      expect(parseRunningValue(RunningMeasure.pace, '1:02:03'), isNull);
      expect(
        const RunningCalculatorDraft(
          firstText: '1e308',
          secondText: '0.001',
        ).calculate(18),
        isNull,
      );
    },
  );

  test(
    'VMA is optional for general calculation and required for intensity input',
    () {
      final draft = const RunningCalculatorDraft();
      expect(draft.calculate(null)!.speed.kmh, 12);
      expect(draft.calculate(null)!.speed.percentOfVma(null), isNull);
      final intensity = draft.select(1, RunningMeasure.intensity);
      for (final vma in [null, 0.0, -1.0, double.nan, double.infinity]) {
        expect(intensity.calculate(vma), isNull);
      }
      expect(intensity.calculate(18)!.seconds, 1000);
      expect(intensity.calculate(20)!.seconds, 900);
    },
  );
}
