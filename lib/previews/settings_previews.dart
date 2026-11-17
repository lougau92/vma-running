import 'package:flutter/material.dart';

import '../app_localizations.dart';
import '../app_settings.dart';
import '../widgets/number_picker_dialog.dart';
import '../widgets/settings_view.dart';
import 'preview_support.dart';

@ResponsivePreview(group: 'Settings', name: 'Saved VMA')
Widget settingsPreview() => const _SettingsPreview(initialVma: 18);

@ResponsivePreview(group: 'Settings', name: 'VMA not set')
Widget settingsMissingVmaPreview() => const _SettingsPreview(initialVma: null);

class _SettingsPreview extends StatefulWidget {
  const _SettingsPreview({required this.initialVma});
  final double? initialVma;
  @override
  State<_SettingsPreview> createState() => _SettingsPreviewState();
}

class _SettingsPreviewState extends State<_SettingsPreview> {
  late AppSettings _settings = const AppSettings();
  late double? _vma = widget.initialVma;

  Future<void> _editVma() async {
    final strings = AppLocalizations.of(context);
    final initial = _vma ?? 18;
    var selected = initial;
    await showDialog<void>(
      context: context,
      builder: (context) => NumberPickerDialog(
        title: strings.enterVmaTitle,
        initialValue: initial,
        formatValue: strings.yourVma,
        onChanged: (value) => selected = value,
      ),
    );
    if (mounted && selected != _vma) setState(() => _vma = selected);
  }

  @override
  Widget build(BuildContext context) => SettingsContent(
    settings: _settings,
    vma: _vma,
    versionLabel: '1.10.33 (42)',
    onSettingsChanged: (value) => setState(() => _settings = value),
    onVmaPressed: _editVma,
  );
}
