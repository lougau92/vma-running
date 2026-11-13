import '../running/running.dart'
    show RunningSpeed, RunningSplit, isPositiveFinite, parseRunningDuration;

enum RunningQuantity { distance, time, speed }

/// Speed, pace and intensity are different representations of one quantity.
enum RunningMeasure {
  distance,
  time,
  speed,
  pace,
  intensity;

  RunningQuantity get quantity => switch (this) {
    distance => RunningQuantity.distance,
    time => RunningQuantity.time,
    speed || pace || intensity => RunningQuantity.speed,
  };

  String get example => switch (this) {
    distance => '5',
    time => '25:00',
    speed => '12',
    pace => '5:00',
    intensity => '100',
  };
}

class RunningCalculatorDraft {
  const RunningCalculatorDraft({
    this.first = RunningMeasure.distance,
    this.second = RunningMeasure.time,
    this.firstText = '5',
    this.secondText = '25:00',
  });

  final RunningMeasure first;
  final RunningMeasure second;
  final String firstText;
  final String secondText;

  RunningCalculatorDraft edit(int index, String text) => RunningCalculatorDraft(
    first: first,
    second: second,
    firstText: index == 0 ? text : firstText,
    secondText: index == 1 ? text : secondText,
  );

  RunningCalculatorDraft select(int index, RunningMeasure measure) =>
      RunningCalculatorDraft(
        first: index == 0 ? measure : first,
        second: index == 1 ? measure : second,
        firstText: index == 0 ? measure.example : firstText,
        secondText: index == 1 ? measure.example : secondText,
      );

  RunningSplit? calculate(double? vma) {
    if (first.quantity == second.quantity) return null;
    final a = parseRunningValue(first, firstText, vma: vma);
    final b = parseRunningValue(second, secondText, vma: vma);
    if (a == null || b == null) return null;
    final values = {first.quantity: a, second.quantity: b};
    final meters = values[RunningQuantity.distance];
    final seconds = values[RunningQuantity.time];
    final kmh = values[RunningQuantity.speed];
    final speed = kmh != null
        ? RunningSpeed.fromKmh(kmh)
        : RunningSpeed.fromDistanceAndTime(
            distanceMeters: meters!,
            seconds: seconds!,
          );
    return meters != null
        ? speed?.forDistance(meters)
        : speed?.forDuration(seconds!);
  }
}

/// Normalizes distance to meters, time to seconds and the speed family to km/h.
double? parseRunningValue(RunningMeasure measure, String text, {double? vma}) {
  final value = switch (measure) {
    RunningMeasure.time => parseRunningDuration(text),
    RunningMeasure.pace => parseRunningDuration(text, allowHours: false),
    _ => double.tryParse(text.trim().replaceAll(',', '.')),
  };
  if (!isPositiveFinite(value)) return null;
  final normalized = switch (measure) {
    RunningMeasure.distance => value! * 1000,
    RunningMeasure.speed => RunningSpeed.fromKmh(value)?.kmh,
    RunningMeasure.pace => RunningSpeed.fromPaceSeconds(value)?.kmh,
    RunningMeasure.intensity => RunningSpeed.fromVma(vma, value!)?.kmh,
    _ => value,
  };
  return isPositiveFinite(normalized) ? normalized : null;
}
