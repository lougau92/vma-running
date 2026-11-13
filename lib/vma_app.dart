// ignore_for_file: avoid_print

import 'dart:async' show unawaited;

import 'package:app_feedback/app_feedback.dart'
    show
        FeedbackSender,
        SupabaseFeedbackSender,
        UnavailableFeedbackSender,
        FeedbackContextScope;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app_localizations.dart';
import 'app_settings.dart';
import 'settings_storage.dart';
import 'theme.dart';
import 'vma_home.dart';
import 'feedback_setup.dart';

class VmaApp extends StatefulWidget {
  const VmaApp({super.key, this.feedbackSender});

  final FeedbackSender? feedbackSender;

  @override
  State<VmaApp> createState() => _VmaAppState();
}

class _VmaAppState extends State<VmaApp> {
  final SettingsStorage _storage = SettingsStorage();
  AppSettings _settings = const AppSettings();
  bool _loading = true;
  PackageInfo? _packageInfo;
  FeedbackSender _feedbackSender = const UnavailableFeedbackSender();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _logPackageInfo();
  }

  Future<void> _loadSettings() async {
    final loaded = await _storage.load();
    final feedback = widget.feedbackSender ?? await loadFeedbackSender();
    if (!mounted) {
      _closeFeedback(feedback);
      return;
    }
    setState(() {
      _settings = loaded;
      _feedbackSender = feedback;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _closeFeedback(_feedbackSender);
    super.dispose();
  }

  void _closeFeedback(FeedbackSender sender) {
    if (sender is SupabaseFeedbackSender) unawaited(sender.dispose());
  }

  Future<void> _logPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      print('VMA Running app started');
      print('Version: ${info.version}');
      print('Build: ${info.buildNumber}');
      if (mounted) setState(() => _packageInfo = info);
    } catch (e) {
      print('App launch: failed to read package info: $e');
    }
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
      builder: (context, child) => FeedbackContextScope(
        id: 'application',
        data: {
          'version': _packageInfo?.version,
          'build': _packageInfo?.buildNumber,
        },
        child: child ?? const SizedBox.shrink(),
      ),
      home: VmaHomePage(
        feedbackSender: _feedbackSender,
        settings: _settings,
        onSettingsChanged: _updateSettings,
      ),
    );
  }
}
