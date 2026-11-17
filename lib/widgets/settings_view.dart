import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_localizations.dart';
import '../app_settings.dart';
import '../garmin/garmin_client.dart';
import '../garmin/garmin_connection.dart';
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
class SettingsContent extends StatefulWidget {
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
  State<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<SettingsContent> {
  static const _dismissDistance = 96.0;
  double _pullDownDistance = 0;
  bool _dismissRequested = false;

  bool _handleSettingsScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _pullDownDistance = 0;
      _dismissRequested = false;
    } else if (notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent) {
      if (notification.overscroll < 0) {
        _pullDownDistance += -notification.overscroll;
      } else {
        _pullDownDistance = (_pullDownDistance - notification.overscroll)
            .clamp(0.0, double.infinity)
            .toDouble();
      }
      if (_pullDownDistance >= _dismissDistance) _dismissSettings();
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      final pulled =
          notification.metrics.minScrollExtent - notification.metrics.pixels;
      if (pulled > 0) {
        _pullDownDistance = pulled;
        if (_pullDownDistance >= _dismissDistance) _dismissSettings();
      } else if (notification.metrics.pixels >
          notification.metrics.minScrollExtent) {
        _pullDownDistance = 0;
      }
    } else if (notification is ScrollEndNotification) {
      _pullDownDistance = 0;
      _dismissRequested = false;
    }
    return false;
  }

  void _dismissSettings() {
    if (_dismissRequested) return;
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    _dismissRequested = true;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final settings = widget.settings;
    final localeValue = settings.localeCode ?? 'system';
    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleSettingsScroll,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                _VmaSettingCard(
                  vma: widget.vma,
                  onPressed: widget.onVmaPressed,
                ),
                const SizedBox(height: 16),
                Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    leading: const Icon(Icons.watch_outlined),
                    title: const Text('Garmin Connect'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final client = GarminClient();
                      try {
                        await showGarminConnection(context, client);
                      } finally {
                        client.close();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 28),
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
                      onSelected: () => widget.onSettingsChanged(
                        settings.copyWith(localeCode: null),
                      ),
                    ),
                    _SelectionChip<String>(
                      label: strings.english,
                      value: 'en',
                      current: localeValue,
                      onSelected: () => widget.onSettingsChanged(
                        settings.copyWith(localeCode: 'en'),
                      ),
                    ),
                    _SelectionChip<String>(
                      label: strings.french,
                      value: 'fr',
                      current: localeValue,
                      onSelected: () => widget.onSettingsChanged(
                        settings.copyWith(localeCode: 'fr'),
                      ),
                    ),
                    _SelectionChip<String>(
                      label: strings.dutch,
                      value: 'nl',
                      current: localeValue,
                      onSelected: () => widget.onSettingsChanged(
                        settings.copyWith(localeCode: 'nl'),
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
                    _SelectionChip<ThemeMode>(
                      label: strings.dark,
                      value: ThemeMode.dark,
                      current: settings.themeMode,
                      onSelected: () => widget.onSettingsChanged(
                        settings.copyWith(themeMode: ThemeMode.dark),
                      ),
                    ),
                    _SelectionChip<ThemeMode>(
                      label: strings.light,
                      value: ThemeMode.light,
                      current: settings.themeMode,
                      onSelected: () => widget.onSettingsChanged(
                        settings.copyWith(themeMode: ThemeMode.light),
                      ),
                    ),
                    _SelectionChip<ThemeMode>(
                      label: strings.systemDefault,
                      value: ThemeMode.system,
                      current: settings.themeMode,
                      onSelected: () => widget.onSettingsChanged(
                        settings.copyWith(themeMode: ThemeMode.system),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        if (widget.versionLabel != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.verified_sharp),
                title: Text(
                  '${strings.appVersionLabel}: ${widget.versionLabel}',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _VmaSettingCard extends StatelessWidget {
  const _VmaSettingCard({required this.vma, required this.onPressed});

  final double? vma;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final onContainer = colors.onPrimaryContainer;
    final detail = vma == null ? strings.setVma : strings.yourVma(vma!);

    return Card(
      key: const ValueKey('vma-setting-card'),
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: colors.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.primary.withValues(alpha: 0.24)),
      ),
      child: InkWell(
        key: const ValueKey('vma-edit'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colors.surface,
                child: Icon(Icons.speed_rounded, color: colors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.updateVma,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: onContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.edit_outlined, color: onContainer),
            ],
          ),
        ),
      ),
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
