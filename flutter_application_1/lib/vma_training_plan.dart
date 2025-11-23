import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'time_utils.dart';

class VmaTrainingPlan extends StatelessWidget {
  const VmaTrainingPlan({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = _wednesdayWorkout();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            child: const Text('W'),
          ),
          title: Text(session.title),
          subtitle: Text(session.description),
          trailing: session.targetTimeSeconds != null
              ? Text(formatElapsed(session.targetTimeSeconds!))
              : null,
        ),
      ),
    );
  }

  _Session _wednesdayWorkout() {
    return const _Session(
      title: 'Wednesday workout',
      description: 'Intervals: 6 x 400m @ 100% VMA with 1 min recovery',
      targetTimeSeconds: 0,
    );
  }
}

class _Session {
  const _Session({
    required this.title,
    required this.description,
    this.targetTimeSeconds,
  });

  final String title;
  final String description;
  final int? targetTimeSeconds;
}
