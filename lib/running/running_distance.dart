/// Distance parsing and numeric display shared by running features.
library;

// Round only for display and absorb floating-point noise in calculated values.
String formatDistanceNumber(double value) {
  if (!value.isFinite) return '-';
  if (value.abs() >= 1e21) return value.toStringAsExponential(2);
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

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
    if (value != null) {
      final meters = value * 1000;
      return meters.isFinite ? meters : null;
    }
  }
  if (input.endsWith('m')) {
    input = input.substring(0, input.length - 1);
  }

  final meters = double.tryParse(input);
  return meters != null && meters.isFinite ? meters : null;
}
