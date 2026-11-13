import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/running/running.dart';

void main() {
  test(
    'shared formatting handles rounding, long paces and invalid results',
    () {
      expect(formatPacePerKm(RunningSpeed.fromKmh(18)), '03:20');
      expect(
        formatPacePerKm(RunningSpeed.fromKmh(16), includeUnit: true),
        '03:45 /km',
      );
      expect(formatPacePerKm(RunningSpeed.fromKmh(0.5)), '120:00');
      expect(formatPacePerKm(null), '-');
      expect(formatRunningDuration(null), '-');
      expect(formatRunningDuration(double.nan), '-');
      expect(formatRunningDuration(double.infinity), '-');
      expect(formatRunningDuration(-1), '-');
      expect(formatRunningDuration(0), '00:00');
      expect(formatRunningDuration(59.6), '01:00');
      expect(formatRunningDuration(3670), '1:01:10');
      expect(formatRunningDuration(86400), '1d 00:00:00');
      expect(formatRunningDuration(0.5), '0.50 s');
      expect(formatRunningDuration(1e100), '1.00e+100 s');
    },
  );
  test('parses elapsed time, pace and recovery durations', () {
    expect(parseRunningDuration('0'), 0);
    expect(parseRunningDuration('75'), 75);
    expect(parseRunningDuration('1:02:03.5'), 3723.5);
    expect(parseRunningDuration('4:30,5', allowHours: false), 270.5);
    for (final text in ['1:60', '1.5:30', '1:', '-1', 'NaN']) {
      expect(parseRunningDuration(text), isNull);
    }
    expect(parseRunningDuration('1:02:03', allowHours: false), isNull);
    expect(parseRunningDuration('${'9' * 308}:00:00'), isNull);
  });
}
