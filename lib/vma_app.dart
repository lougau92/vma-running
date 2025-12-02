import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_localizations.dart';
import 'app_settings.dart';
import 'settings_storage.dart';
import 'theme.dart';
import 'vma_home.dart';

class VmaApp extends StatefulWidget {
  const VmaApp({super.key});

  @override
  State<VmaApp> createState() => _VmaAppState();
}

class _VmaAppState extends State<VmaApp> {
  final SettingsStorage _storage = SettingsStorage();
  AppSettings _settings = const AppSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loaded = await _storage.load();
    setState(() {
      _settings = loaded;
      _loading = false;
    });
  }

  Future<void> _updateSettings(AppSettings next) async {
    setState(() => _settings = next);
    await _storage.save(next);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(home: SizedBox.shrink());
    }

    final appTheme = AppThemes.resolve(_settings.themeId);

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: appTheme.light,
      darkTheme: appTheme.dark,
      themeMode: _settings.themeMode,
      locale: _settings.localeCode != null
          ? Locale(_settings.localeCode!)
          : null,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: VmaHomePage(
        settings: _settings,
        onSettingsChanged: _updateSettings,
      ),
    );
  }
}
