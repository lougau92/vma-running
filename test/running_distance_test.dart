import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/running/running.dart';

void main() {
  test('parses meters, kilometers, decimal commas and race aliases', () {
    expect(parseDistanceInput('400'), 400);
    expect(parseDistanceInput(' 400 m '), 400);
    expect(parseDistanceInput('1,25 km'), 1250);
    expect(parseDistanceInput('half marathon'), kHalfMarathonMeters);
    expect(parseDistanceInput('semi-marathon'), kHalfMarathonMeters);
    expect(parseDistanceInput('marathon'), kMarathonMeters);
    for (final text in ['', 'oops', 'NaN', 'Infinity', '1e309 km']) {
      expect(parseDistanceInput(text), isNull);
    }
  });

  test('formats distance numbers without rounding domain values', () {
    expect(formatDistanceNumber(399.999999999), '400');
    expect(formatDistanceNumber(1.25), '1.25');
    expect(formatDistanceNumber(1.5), '1.5');
    expect(formatDistanceNumber(double.nan), '-');
    expect(formatDistanceNumber(1e30), '1.00e+30');
  });
}
