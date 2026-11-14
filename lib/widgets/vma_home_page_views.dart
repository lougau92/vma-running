import 'package:flutter/material.dart';

import '../running/running.dart' show RunningSpeed;
import '../vma_pace.dart' show VmaPaceEntry;
import '../vma_table.dart' show VmaPaceTable;
import '../vma_times_table.dart' show VmaTimesTable;
import 'intensity_pace_control.dart';

class VmaIntensityPageView extends StatelessWidget {
  const VmaIntensityPageView({
    super.key,
    required this.entries,
    required this.distanceMeters,
    required this.onEditPercentages,
    required this.onEditDistance,
  });

  final List<VmaPaceEntry> entries;
  final double distanceMeters;
  final VoidCallback onEditPercentages;
  final VoidCallback onEditDistance;

  @override
  Widget build(BuildContext context) => CenteredWidth(
    child: VmaPaceTable(
      entries: entries,
      distanceMeters: distanceMeters,
      onEditPercentages: onEditPercentages,
      onEditDistance: onEditDistance,
    ),
  );
}

class VmaTimesPageView extends StatelessWidget {
  const VmaTimesPageView({
    super.key,
    required this.speed,
    required this.percent,
    required this.minDistanceMeters,
    required this.maxDistanceMeters,
    required this.minTimeSeconds,
    required this.maxTimeSeconds,
    required this.customDistances,
    required this.customTimes,
    required this.onPercentChanged,
    required this.onEditDistances,
    required this.onEditTimes,
  });

  final RunningSpeed? speed;
  final double percent;
  final double minDistanceMeters;
  final double maxDistanceMeters;
  final double minTimeSeconds;
  final double maxTimeSeconds;
  final List<double> customDistances;
  final List<double> customTimes;
  final ValueChanged<double> onPercentChanged;
  final VoidCallback onEditDistances;
  final VoidCallback onEditTimes;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      CenteredWidth(
        child: IntensityPaceControl(
          percent: percent,
          speed: speed,
          onChanged: onPercentChanged,
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: CenteredWidth(
          child: VmaTimesTable(
            speed: speed,
            minDistanceMeters: minDistanceMeters,
            maxDistanceMeters: maxDistanceMeters,
            minTimeSeconds: minTimeSeconds,
            maxTimeSeconds: maxTimeSeconds,
            customDistances: customDistances,
            customTimes: customTimes,
            onEditDistances: onEditDistances,
            onEditTimes: onEditTimes,
          ),
        ),
      ),
    ],
  );
}

class CenteredWidth extends StatelessWidget {
  const CenteredWidth({super.key, required this.child, this.maxWidth = 900});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
