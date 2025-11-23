import 'distance_input.dart';

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
