import 'package:app_feedback/app_feedback.dart'
    show FeedbackButton, FeedbackSender;
import 'package:flutter/material.dart';

import '../app_localizations.dart';

class VmaHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const VmaHomeAppBar({
    super.key,
    required this.feedbackSender,
    required this.onSettingsPressed,
  });

  final FeedbackSender? feedbackSender;
  final VoidCallback onSettingsPressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AppBar(
      title: Container(
        width: 38,
        height: 38,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
        child: Image.asset(
          'assets/enjambee_img/logo-header-minimized.png',
          fit: BoxFit.contain,
        ),
      ),
      actions: [
        if (feedbackSender != null) FeedbackButton(sender: feedbackSender!),
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: strings.settingsTab,
          onPressed: onSettingsPressed,
        ),
      ],
    );
  }
}
