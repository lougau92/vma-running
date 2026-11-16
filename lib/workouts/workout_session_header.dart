import 'package:flutter/material.dart';
import 'workout.dart';

/// Session identity stays separate from the selected group's prescription.
class WorkoutSessionHeader extends StatelessWidget {
  const WorkoutSessionHeader({super.key, required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final date = DateTime.tryParse(session.scheduledDate ?? '');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            session.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (session.scheduledDate != null || session.location != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                if (session.scheduledDate != null)
                  _Detail(
                    icon: Icons.calendar_today_outlined,
                    text: date == null
                        ? session.scheduledDate!
                        : MaterialLocalizations.of(
                            context,
                          ).formatFullDate(date),
                  ),
                if (session.location != null)
                  _Detail(icon: Icons.place_outlined, text: session.location!),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onPrimaryContainer;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: ink),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: ink),
          ),
        ),
      ],
    );
  }
}
