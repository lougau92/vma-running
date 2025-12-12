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
  late TextEditingController _athleteController;
  String? _apiKeyError;
  String? _athleteError;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(
      text: widget.settings.intervalsApiKey ?? '',
    );
    _athleteController = TextEditingController(
      text: widget.settings.intervalsAthleteId ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant VmaSettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.intervalsApiKey != widget.settings.intervalsApiKey) {
      _apiKeyController.text = widget.settings.intervalsApiKey ?? '';
    }
    if (oldWidget.settings.intervalsAthleteId !=
        widget.settings.intervalsAthleteId) {
      _athleteController.text = widget.settings.intervalsAthleteId ?? '';
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _athleteController.dispose();
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
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.intervalsSectionTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: strings.intervalsApiKeyInfo,
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => _showIntervalsApiHelp(context, strings),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _CredentialField(
                  controller: _athleteController,
                  label: strings.intervalsAthleteIdLabel,
                  hint: strings.intervalsAthleteIdHint,
                  errorText: _athleteError,
                  onChanged: (value) {
                    final trimmed = value.trim();
                    final nextValue = trimmed.isEmpty ? null : trimmed;
                    if (trimmed.isNotEmpty &&
                        !_isValidAthleteId(trimmed)) {
                      setState(() {
                        _athleteError = strings.intervalsAthleteIdInvalid;
                      });
                      return;
                    }
                    setState(() => _athleteError = null);
                    if (nextValue != widget.settings.intervalsAthleteId) {
                      widget.onSettingsChanged(
                        widget.settings.copyWith(intervalsAthleteId: nextValue),
                      );
                    }
                  },
                  onClear: () {
                    _athleteController.clear();
                    setState(() => _athleteError = null);
                    if (widget.settings.intervalsAthleteId != null) {
                      widget.onSettingsChanged(
                        widget.settings.copyWith(intervalsAthleteId: null),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                _CredentialField(
                  controller: _apiKeyController,
                  label: strings.intervalsApiKeyLabel,
                  hint: strings.intervalsApiKeyHint,
                  errorText: _apiKeyError,
                  onChanged: (value) {
                    final trimmed = value.trim();
                    final nextKey = trimmed.isEmpty ? null : trimmed;
                    if (trimmed.isNotEmpty && !_isValidApiKey(trimmed)) {
                      setState(() {
                        _apiKeyError = strings.intervalsApiKeyInvalid;
                      });
                      return;
                    }
                    setState(() => _apiKeyError = null);
                    if (nextKey != widget.settings.intervalsApiKey) {
                      widget.onSettingsChanged(
                        widget.settings.copyWith(intervalsApiKey: nextKey),
                      );
                    }
                  },
                  onClear: () {
                    _apiKeyController.clear();
                    setState(() => _apiKeyError = null);
                    if (widget.settings.intervalsApiKey != null) {
                      widget.onSettingsChanged(
                        widget.settings.copyWith(intervalsApiKey: null),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
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

bool _isValidAthleteId(String value) {
  return RegExp(r'^i[0-9]+$').hasMatch(value.trim());
}

bool _isValidApiKey(String value) {
  return RegExp(r'^[A-Za-z0-9]{20,40}$').hasMatch(value.trim());
}

class _CredentialField extends StatelessWidget {
  const _CredentialField({
    required this.controller,
    required this.label,
    required this.hint,
    this.errorText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        suffixIcon: IconButton(
          tooltip: label,
          icon: const Icon(Icons.delete_forever),
          onPressed: onClear,
        ),
      ),
      onChanged: onChanged,
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
