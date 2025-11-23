const double kHalfMarathonMeters = 21097.5;
const double kMarathonMeters = 42195;
final halfMarathon = kHalfMarathonMeters.toDouble();
final marathon = kMarathonMeters.toDouble();

extension DistanceLabel on num {
  /// Renders common race distances with names; otherwise returns meters.
  String toRaceLabel() {
    final meters = round();

    if ((meters - marathon).abs() <= 1) {
      return 'Marathon';
    }
    if ((meters - halfMarathon).abs() <= 2) {
      return 'Half marathon';
    }

    return '$meters m';
  }
}

double? parseDistanceInput(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  if (normalized.contains('marathon') &&
      !normalized.contains('half') &&
      !normalized.contains('semi')) {
    return kMarathonMeters;
  }
  if (normalized.contains('half') || normalized.contains('semi')) {
    return kHalfMarathonMeters;
  }

  var input = normalized.replaceAll(',', '.').replaceAll(' ', '');
  if (input.endsWith('km')) {
    final value = double.tryParse(input.substring(0, input.length - 2));
    if (value != null) return value * 1000;
  }
  if (input.endsWith('m')) {
    input = input.substring(0, input.length - 1);
  }

  return double.tryParse(input);
}
