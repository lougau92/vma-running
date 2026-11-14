import 'package:app_feedback/app_feedback.dart'
    show
        FeedbackButton,
        FeedbackSender,
        UnavailableFeedbackSender,
        FeedbackContextScope;
import 'package:flutter/material.dart';
import '../app_localizations.dart';
import '../app_settings.dart';
import 'decorated_scaffold.dart';
import 'settings_view.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.onVmaChanged,
    this.feedbackSender = const UnavailableFeedbackSender(),
  });

  final FeedbackSender? feedbackSender;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final ValueChanged<double>? onVmaChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return FeedbackContextScope(
      id: 'settings',
      isScreen: true,
      data: {
        'localePreference': settings.localeCode ?? 'system',
        'themeMode': settings.themeMode.name,
        'themeId': settings.themeId,
      },
      child: DecoratedScaffold(
        appBar: AppBar(
          title: Text(strings.settingsTab),
          actions: [
            if (feedbackSender != null) FeedbackButton(sender: feedbackSender!),
          ],
        ),
        body: SettingsView(
          settings: settings,
          onSettingsChanged: onSettingsChanged,
          onVmaChanged: onVmaChanged,
        ),
      ),
    );
  }
}
