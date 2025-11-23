import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'app_settings.dart';
import 'vma_settings_view.dart';

class VmaSettingsPage extends StatelessWidget {
  const VmaSettingsPage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.settingsTab),
      ),
      body: VmaSettingsView(
        settings: settings,
        onSettingsChanged: onSettingsChanged,
      ),
    );
  }
}
