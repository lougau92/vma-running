import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app_localizations.dart';
import 'app_settings.dart';
import 'vma_storage.dart';

class VmaSettingsView extends StatefulWidget {
  const VmaSettingsView({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.onVmaChanged,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final ValueChanged<double>? onVmaChanged;

  @override
  State<VmaSettingsView> createState() => _VmaSettingsViewState();
}

class _VmaSettingsViewState extends State<VmaSettingsView> {
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
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final localeValue = widget.settings.localeCode ?? 'system';

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
                  subtitle: _vma == null ? null : Text(strings.yourVma(_vma!)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _editVma,
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
              Text(
                strings.theme,
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: FutureBuilder<PackageInfo>(
              future: _packageInfoFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final info = snapshot.data!;
                final version = info.version;
                final buildNumber = info.buildNumber;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.verified_sharp),
                  title: Text(
                    '${strings.appVersionLabel}: $version ($buildNumber)',
                  ),
                );
              },
            ),
          ),
        ),
      ],
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
