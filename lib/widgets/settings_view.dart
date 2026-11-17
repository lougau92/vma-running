import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_localizations.dart';
import '../app_settings.dart';
import '../vma_storage.dart';

/// Loads platform data, then delegates the visible settings to [SettingsContent].
class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.onVmaChanged,
  });
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final ValueChanged<double>? onVmaChanged;
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final Future<PackageInfo> _packageInfoFuture;
  final _vmaStorage = VmaStorage();
  double? _vma;
  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
    _loadVma();
  }

  Future<void> _loadVma() async {
    final value = await _vmaStorage.load();
    if (mounted) setState(() => _vma = value);
  }

  Future<void> _editVma() async {
    final value = await _vmaStorage.promptForVma(context, initialValue: _vma);
    if (value == null || !mounted) return;
    setState(() => _vma = value);
    widget.onVmaChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: _packageInfoFuture,
    builder: (context, snapshot) => SettingsContent(
      settings: widget.settings,
      vma: _vma,
      versionLabel: snapshot.hasData
          ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
          : null,
      onSettingsChanged: widget.onSettingsChanged,
      onVmaPressed: _editVma,
    ),
  );
}

/// Settings presentation with explicit state, suitable for screens and previews.
class SettingsContent extends StatelessWidget {
  const SettingsContent({
    super.key,
    required this.settings,
    required this.vma,
    required this.versionLabel,
    required this.onSettingsChanged,
    required this.onVmaPressed,
  });
  final AppSettings settings;
  final double? vma;
  final String? versionLabel;
  final ValueChanged<AppSettings> onSettingsChanged;
  final VoidCallback onVmaPressed;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final localeValue = settings.localeCode ?? 'system';
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  key: const ValueKey('vma-edit'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(strings.updateVma),
                  subtitle: vma == null ? null : Text(strings.yourVma(vma!)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onVmaPressed,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                strings.language,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SelectionChip<String>(
                    label: strings.systemDefault,
                    value: 'system',
                    current: localeValue,
                    onSelected: () =>
                        onSettingsChanged(settings.copyWith(localeCode: null)),
                  ),
                  _SelectionChip<String>(
                    label: strings.english,
                    value: 'en',
                    current: localeValue,
                    onSelected: () =>
                        onSettingsChanged(settings.copyWith(localeCode: 'en')),
                  ),
                  _SelectionChip<String>(
                    label: strings.french,
                    value: 'fr',
                    current: localeValue,
                    onSelected: () =>
                        onSettingsChanged(settings.copyWith(localeCode: 'fr')),
                  ),
                  _SelectionChip<String>(
                    label: strings.dutch,
                    value: 'nl',
                    current: localeValue,
                    onSelected: () =>
                        onSettingsChanged(settings.copyWith(localeCode: 'nl')),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                strings.theme,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SelectionChip<ThemeMode>(
                    label: strings.dark,
                    value: ThemeMode.dark,
                    current: settings.themeMode,
                    onSelected: () => onSettingsChanged(
                      settings.copyWith(themeMode: ThemeMode.dark),
                    ),
                  ),
                  _SelectionChip<ThemeMode>(
                    label: strings.light,
                    value: ThemeMode.light,
                    current: settings.themeMode,
                    onSelected: () => onSettingsChanged(
                      settings.copyWith(themeMode: ThemeMode.light),
                    ),
                  ),
                  _SelectionChip<ThemeMode>(
                    label: strings.systemDefault,
                    value: ThemeMode.system,
                    current: settings.themeMode,
                    onSelected: () => onSettingsChanged(
                      settings.copyWith(themeMode: ThemeMode.system),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        if (versionLabel != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.verified_sharp),
                title: Text('${strings.appVersionLabel}: $versionLabel'),
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectionChip<T> extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
  });
  final String label;
  final T value;
  final T current;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: colors.primaryContainer,
      checkmarkColor: colors.onPrimaryContainer,
      labelStyle: TextStyle(color: selected ? colors.onPrimaryContainer : null),
      side: BorderSide(
        color: selected ? colors.primary : colors.outlineVariant,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
