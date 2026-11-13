/// Flutter localization adapter for the Dart-only running backbone.
library;

import 'package:flutter/widgets.dart' show BuildContext;

import '../app_localizations.dart' show AppLocalizations, DynamicStrings;
import 'running_distance.dart';

String formatDistanceShort(double meters, AppLocalizations strings) =>
    _formatDistance(meters, strings, longUnits: false);

String formatDistanceLong(double meters, AppLocalizations strings) =>
    _formatDistance(meters, strings, longUnits: true);

String _formatDistance(
  double meters,
  AppLocalizations strings, {
  required bool longUnits,
}) {
  if (!meters.isFinite) return '-';
  final race = _raceLabel(meters, strings);
  if (race != null) return race;
  final kilometers = meters >= 1000;
  final value = formatDistanceNumber(kilometers ? meters / 1000 : meters);
  final unit = kilometers
      ? (longUnits ? strings.kilometersFull : strings.kilometersAbbr)
      : (longUnits ? strings.metersFull : strings.metersAbbr);
  return '$value $unit';
}

String? _raceLabel(double meters, AppLocalizations strings) {
  if ((meters - kMarathonMeters).abs() <= 1) return strings.marathon;
  if ((meters - kHalfMarathonMeters).abs() <= 2) return strings.halfMarathon;
  return null;
}

extension DistanceLabel on num {
  /// Renders common race distances with names; otherwise a time/distance label.
  String toRaceLabel(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return _raceLabel(toDouble(), strings) ??
        strings.timeForDistanceLabel(toDouble());
  }
}
