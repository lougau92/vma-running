const double kHalfMarathonMeters = 21097.5;
const double kMarathonMeters = 42195;

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
