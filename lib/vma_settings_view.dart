import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'app_settings.dart';

class VmaSettingsView extends StatelessWidget {
  const VmaSettingsView({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final localeValue = settings.localeCode ?? 'system';
    final themeValue = settings.themeMode.name;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(strings.language, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: localeValue,
          onChanged: (value) {
            final nextLocale = value == 'system' ? null : value;
            onSettingsChanged(settings.copyWith(localeCode: nextLocale));
          },
          items: [
            DropdownMenuItem(
              value: 'system',
              child: Text(strings.systemDefault),
            ),
            DropdownMenuItem(value: 'en', child: Text(strings.english)),
            DropdownMenuItem(value: 'fr', child: Text(strings.french)),
            DropdownMenuItem(value: 'nl', child: Text(strings.dutch)),
          ],
        ),
        const SizedBox(height: 24),
        Text(strings.theme, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: themeValue,
          onChanged: (value) {
            final nextTheme = switch (value) {
              'light' => ThemeMode.light,
              'system' => ThemeMode.system,
              _ => ThemeMode.dark,
            };
            onSettingsChanged(settings.copyWith(themeMode: nextTheme));
          },
          items: [
            DropdownMenuItem(value: 'dark', child: Text(strings.dark)),
            DropdownMenuItem(value: 'light', child: Text(strings.light)),
            DropdownMenuItem(
              value: 'system',
              child: Text(strings.systemDefault),
            ),
          ],
        ),
      ],
    );
  }
}
