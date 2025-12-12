import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'app_settings.dart';

class VmaSettingsView extends StatefulWidget {
  const VmaSettingsView({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  @override
  State<VmaSettingsView> createState() => _VmaSettingsViewState();
}

class _VmaSettingsViewState extends State<VmaSettingsView> {
  late TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(
      text: widget.settings.intervalsApiKey ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant VmaSettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.intervalsApiKey != widget.settings.intervalsApiKey) {
      _apiKeyController.text = widget.settings.intervalsApiKey ?? '';
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final localeValue = widget.settings.localeCode ?? 'system';
    final themeValue = widget.settings.themeMode.name;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(strings.language, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _LanguageChip(
              label: strings.systemDefault,
              value: 'system',
              current: localeValue,
              onSelected: () => widget.onSettingsChanged(
                widget.settings.copyWith(localeCode: null),
              ),
            ),
            _LanguageChip(
              label: strings.english,
              value: 'en',
              current: localeValue,
              onSelected: () => widget.onSettingsChanged(
                widget.settings.copyWith(localeCode: 'en'),
              ),
            ),
            _LanguageChip(
              label: strings.french,
              value: 'fr',
              current: localeValue,
              onSelected: () => widget.onSettingsChanged(
                widget.settings.copyWith(localeCode: 'fr'),
              ),
            ),
            _LanguageChip(
              label: strings.dutch,
              value: 'nl',
              current: localeValue,
              onSelected: () => widget.onSettingsChanged(
                widget.settings.copyWith(localeCode: 'nl'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(strings.theme, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ThemeChip(
              label: strings.dark,
              value: ThemeMode.dark,
              current: widget.settings.themeMode,
              onSelected: () => widget.onSettingsChanged(
                widget.settings.copyWith(themeMode: ThemeMode.dark),
              ),
            ),
            _ThemeChip(
              label: strings.light,
              value: ThemeMode.light,
              current: widget.settings.themeMode,
              onSelected: () => widget.onSettingsChanged(
                widget.settings.copyWith(themeMode: ThemeMode.light),
              ),
            ),
            _ThemeChip(
              label: strings.systemDefault,
              value: ThemeMode.system,
              current: widget.settings.themeMode,
              onSelected: () => widget.onSettingsChanged(
                widget.settings.copyWith(themeMode: ThemeMode.system),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              strings.intervalsApiKeyLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),

            IconButton(
              tooltip: strings.intervalsApiKeyInfo,
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showIntervalsApiHelp(context, strings),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKeyController,
          decoration: InputDecoration(
            hintText: strings.intervalsApiKeyHint,
            suffixIcon: IconButton(
              tooltip: strings.intervalsApiKeyClear,
              icon: const Icon(Icons.delete_forever),
              onPressed: () {
                _apiKeyController.clear();
                if (widget.settings.intervalsApiKey != null) {
                  widget.onSettingsChanged(
                    widget.settings.copyWith(intervalsApiKey: null),
                  );
                }
              },
            ),
          ),
          onChanged: (value) {
            final trimmed = value.trim();
            final nextKey = trimmed.isEmpty ? null : trimmed;
            if (nextKey != widget.settings.intervalsApiKey) {
              widget.onSettingsChanged(
                widget.settings.copyWith(intervalsApiKey: nextKey),
              );
            }
          },
        ),
      ],
    );
  }

  void _showIntervalsApiHelp(BuildContext context, AppLocalizations strings) {
    final steps = strings.intervalsApiKeyInstructions.split('\n');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.intervalsApiKeyInstructionsTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: steps
              .map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(line),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.cancel),
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String current;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: current == value,
      onSelected: (_) => onSelected(),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
  });

  final String label;
  final ThemeMode value;
  final ThemeMode current;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: current == value,
      onSelected: (_) => onSelected(),
    );
  }
}
