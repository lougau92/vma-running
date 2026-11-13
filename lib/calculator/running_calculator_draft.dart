import '../running/running.dart'
    show
        RunningSpeed,
        RunningSplit,
        formatPacePerKm,
        formatRunningDuration,
        isPositiveFinite,
        parseRunningDuration;

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
    this.third = RunningMeasure.speed,
    this.fourth = RunningMeasure.pace,
    this.firstText = '5',
    this.secondText = '25:00',
    this.thirdText = '',
    this.fourthText = '',
    this.inputIndices = const [0, 1],
  });

  final RunningMeasure first;
  final RunningMeasure second;
  final RunningMeasure third;
  final RunningMeasure fourth;
  final String firstText;
  final String secondText;
  final String thirdText;
  final String fourthText;
  final List<int> inputIndices;

  RunningMeasure measureAt(int index) => switch (index) {
    0 => first,
    1 => second,
    2 => third,
    3 => fourth,
    _ => throw RangeError.index(index, [first, second, third, fourth]),
  };

  String textAt(int index) => switch (index) {
    0 => firstText,
    1 => secondText,
    2 => thirdText,
    3 => fourthText,
    _ => throw RangeError.index(index, [
      firstText,
      secondText,
      thirdText,
      fourthText,
    ]),
  };

  bool isInput(int index) => inputIndices.contains(index);

  /// The selected input values determine the other cards' displayed values.
  String displayValueAt(int index, double? vma) {
    if (isInput(index)) return textAt(index);
    final split = calculate(vma);
    if (split == null) return '';
    final intensity = split.speed.percentOfVma(vma);
    return switch (measureAt(index)) {
      RunningMeasure.distance => _formatNumber(split.distanceKm),
      RunningMeasure.time => formatRunningDuration(split.seconds),
      RunningMeasure.speed => _formatNumber(split.speed.kmh),
      RunningMeasure.pace => formatPacePerKm(split.speed),
      RunningMeasure.intensity =>
        intensity == null ? '—' : _formatNumber(intensity),
    };
  }

  RunningCalculatorDraft edit(int index, String text) => RunningCalculatorDraft(
    first: first,
    second: second,
    third: third,
    fourth: fourth,
    firstText: index == 0 ? text : firstText,
    secondText: index == 1 ? text : secondText,
    thirdText: index == 2 ? text : thirdText,
    fourthText: index == 3 ? text : fourthText,
    inputIndices: _withInput(index),
  );

  /// Makes a calculated card editable, keeping the newest independent pair.
  RunningCalculatorDraft activate(int index, String currentValue) =>
      RunningCalculatorDraft(
        first: first,
        second: second,
        third: third,
        fourth: fourth,
        firstText: index == 0 ? currentValue : firstText,
        secondText: index == 1 ? currentValue : secondText,
        thirdText: index == 2 ? currentValue : thirdText,
        fourthText: index == 3 ? currentValue : fourthText,
        inputIndices: _withInput(index),
      );

  List<int> _withInput(int index) {
    if (index < 0 || index > 3) {
      throw RangeError.index(index, [first, second, third, fourth]);
    }
    if (inputIndices.contains(index)) return inputIndices;

    final inputs = [...inputIndices];
    final quantityMatch = inputs.indexWhere(
      (input) => measureAt(input).quantity == measureAt(index).quantity,
    );
    if (quantityMatch >= 0) {
      inputs.removeAt(quantityMatch);
    } else if (inputs.length >= 2) {
      inputs.removeAt(0);
    }
    inputs.add(index);
    return inputs;
  }

  RunningCalculatorDraft select(int index, RunningMeasure measure) =>
      _select(index, measure);

  RunningCalculatorDraft _select(int index, RunningMeasure measure) {
    if (index < 0 || index > 3) {
      throw RangeError.index(index, [first, second, third, fourth]);
    }
    final otherIndex = [0, 1, 2, 3].firstWhere(
      (other) => other != index && measureAt(other) == measure,
      orElse: () => -1,
    );
    final oldMeasure = measureAt(index);
    final measures = [first, second, third, fourth];
    final texts = [firstText, secondText, thirdText, fourthText];
    measures[index] = measure;
    if (otherIndex >= 0) measures[otherIndex] = oldMeasure;
    if (isInput(index)) texts[index] = measure.example;

    var inputs = [...inputIndices];
    if (inputs.contains(index)) {
      final collision = inputs.firstWhere(
        (input) =>
            input != index && measures[input].quantity == measure.quantity,
        orElse: () => -1,
      );
      if (collision >= 0) inputs.remove(collision);
    }
    return RunningCalculatorDraft(
      first: measures[0],
      second: measures[1],
      third: measures[2],
      fourth: measures[3],
      firstText: texts[0],
      secondText: texts[1],
      thirdText: texts[2],
      fourthText: texts[3],
      inputIndices: inputs,
    );
  }

  RunningSplit? calculate(double? vma) {
    if (inputIndices.length != 2) return null;
    final firstIndex = inputIndices[0];
    final secondIndex = inputIndices[1];
    final firstMeasure = measureAt(firstIndex);
    final secondMeasure = measureAt(secondIndex);
    if (firstMeasure.quantity == secondMeasure.quantity) return null;
    final a = parseRunningValue(firstMeasure, textAt(firstIndex), vma: vma);
    final b = parseRunningValue(secondMeasure, textAt(secondIndex), vma: vma);
    if (a == null || b == null) return null;
    final values = {firstMeasure.quantity: a, secondMeasure.quantity: b};
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

String _formatNumber(double value) => value < 0.01 || value >= 1e9
    ? value.toStringAsExponential(2)
    : value.toStringAsFixed(2);

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
