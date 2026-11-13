import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/running/running.dart';

void main() {
  test('speed, pace, VMA and distance/time describe the same effort', () {
    final speeds = [
      RunningSpeed.fromKmh(18),
      RunningSpeed.fromPaceSeconds(200),
      RunningSpeed.fromVma(20, 90),
      RunningSpeed.fromDistanceAndTime(distanceMeters: 400, seconds: 80),
    ];
    for (final speed in speeds) {
      expect(speed!.kmh, 18);
      expect(speed.metersPerSecond, 5);
      expect(speed.paceSecondsPerKm, 200);
      expect(speed.percentOfVma(20), 90);
      expect(speed.forDistance(400)!.seconds, 80);
      expect(speed.forDuration(80)!.distanceMeters, 400);
    }
  });

  test(
    'distance and time conversions retain precision across running ranges',
    () {
      for (final kmh in [8.5, 12.0, 16.0, 18.0, 23.0]) {
        final speed = RunningSpeed.fromKmh(kmh)!;
        for (final meters in [100.0, 400.0, 1500.0, 5000.0, 42195.0]) {
          final split = speed.forDistance(meters)!;
          expect(split.distanceMeters, meters);
          expect(
            speed.forDuration(split.seconds)!.distanceMeters,
            closeTo(meters, 1e-8),
          );
          expect(
            RunningSpeed.fromDistanceAndTime(
              distanceMeters: meters,
              seconds: split.seconds,
            )!.kmh,
            closeTo(kmh, 1e-10),
          );
        }
      }
      final fractional = RunningSpeed.fromKmh(17)!.forDistance(400)!;
      expect(fractional.seconds, closeTo(84.7058823529, 1e-9));
      expect(formatRunningDuration(fractional.seconds), '01:25');
    },
  );

  test('invalid and unrepresentable values are rejected consistently', () {
    final speed = RunningSpeed.fromKmh(18)!;
    for (final invalid in [
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(RunningSpeed.fromKmh(invalid), isNull);
      expect(RunningSpeed.fromPaceSeconds(invalid), isNull);
      expect(RunningSpeed.fromVma(invalid, 100), isNull);
      expect(RunningSpeed.fromVma(18, invalid), isNull);
      expect(
        RunningSpeed.fromDistanceAndTime(distanceMeters: invalid, seconds: 80),
        isNull,
      );
      expect(
        RunningSpeed.fromDistanceAndTime(distanceMeters: 400, seconds: invalid),
        isNull,
      );
      expect(speed.forDistance(invalid), isNull);
      expect(speed.forDuration(invalid), isNull);
      expect(speed.percentOfVma(invalid), isNull);
    }
    expect(RunningSpeed.fromKmh(null), isNull);
    expect(RunningSpeed.fromPaceSeconds(null), isNull);
    expect(RunningSpeed.fromVma(null, 100), isNull);
    expect(speed.percentOfVma(null), isNull);
    expect(RunningSpeed.fromKmh(1e-320), isNull);
    expect(RunningSpeed.fromKmh(1e308)!.forDuration(100), isNull);
    expect(RunningSpeed.fromKmh(1e-300)!.forDistance(1e308), isNull);
  });
}
