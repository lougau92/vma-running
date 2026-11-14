import 'package:flutter/material.dart';

import '../app_localizations.dart';
import '../running/running.dart';

class IntensityPaceControl extends StatelessWidget {
  const IntensityPaceControl({
    super.key,
    required this.percent,
    required this.speed,
    required this.onChanged,
  });

  final double percent;
  final RunningSpeed? speed;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.intensity,
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(
                        '${percent.toStringAsFixed(0)}% VMA',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        strings.pacePerKm,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(
                        formatPacePerKm(speed),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 8,
                activeTrackColor: colors.primary,
                inactiveTrackColor: colors.outlineVariant,
                thumbColor: colors.primary,
                activeTickMarkColor: colors.onPrimary,
                inactiveTickMarkColor: colors.onSurfaceVariant,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                tickMarkShape: const RoundSliderTickMarkShape(
                  tickMarkRadius: 1,
                ),
              ),
              child: Slider(
                value: percent,
                min: 60,
                max: 120,
                divisions: 12,
                label: '${percent.toStringAsFixed(0)}%',
                semanticFormatterCallback: (value) =>
                    '${strings.intensity}: ${value.toStringAsFixed(0)}%',
                onChanged: onChanged,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('60%', style: theme.textTheme.labelSmall),
                Text('120%', style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
