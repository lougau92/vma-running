import 'package:flutter/material.dart';

import 'app_localizations.dart';

int _decimalsFor(double value) {
  if (value % 1 == 0) return 0;
  final times10 = (value * 10).roundToDouble();
  if (times10 % 1 == 0) return 1;
  return 2;
}

String formatDistanceShort(double meters, AppLocalizations strings) {
  if ((meters - kMarathonMeters).abs() <= 1) return strings.marathon;
  if ((meters - kHalfMarathonMeters).abs() <= 2) return strings.halfMarathon;

  if (meters >= 1000) {
    final km = meters / 1000;
    final decimals = _decimalsFor(km);
    return '${km.toStringAsFixed(decimals)} ${strings.kilometersAbbr}';
  }

  final decimals = _decimalsFor(meters);
  return '${meters.toStringAsFixed(decimals)} ${strings.metersAbbr}';
}

String formatDistanceLong(double meters, AppLocalizations strings) {
  if ((meters - kMarathonMeters).abs() <= 1) return strings.marathon;
  if ((meters - kHalfMarathonMeters).abs() <= 2) return strings.halfMarathon;

  if (meters >= 1000) {
    final km = meters / 1000;
    final decimals = _decimalsFor(km);
    return '${km.toStringAsFixed(decimals)} ${strings.kilometersFull}';
  }

  final decimals = _decimalsFor(meters);
  return '${meters.toStringAsFixed(decimals)} ${strings.metersFull}';
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
    if (value != null) return value * 1000;
  }
  if (input.endsWith('m')) {
    input = input.substring(0, input.length - 1);
  }

  return double.tryParse(input);
}

extension DistanceLabel on num {
  /// Renders common race distances with names; otherwise returns meters.
  String toRaceLabel(BuildContext context) {
    final meters = this;

    final strings = AppLocalizations.of(context);

    if ((meters - kMarathonMeters).abs() <= 1) {
      return strings.marathon;
    }
    if ((meters - kHalfMarathonMeters).abs() <= 2) {
      return strings.halfMarathon;
    }

    return strings.timeForDistanceLabel(meters.toDouble());
  }
}
