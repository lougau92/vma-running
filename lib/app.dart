// ignore_for_file: avoid_print

import 'dart:async' show unawaited;

import 'package:app_feedback/app_feedback.dart'
    show FeedbackSender, SupabaseFeedbackSender, FeedbackContextScope;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app_localizations.dart';
import 'app_settings.dart';
import 'settings_storage.dart';
import 'widgets/runtime_environment_host.dart' show RuntimeEnvironmentHost;
import 'theme.dart';
import 'widgets/home_page.dart';
import 'feedback_setup.dart';

class RunningApp extends StatefulWidget {
  const RunningApp({super.key, this.feedbackSender, this.feedbackSenderLoader});

  final FeedbackSender? feedbackSender;
  final Future<FeedbackSender> Function()? feedbackSenderLoader;

  @override
  State<RunningApp> createState() => _RunningAppState();
}

class _RunningAppState extends State<RunningApp> {
  final SettingsStorage _storage = SettingsStorage();
  AppSettings _settings = const AppSettings();
  bool _loading = true;
  PackageInfo? _packageInfo;
  FeedbackSender? _feedbackSender;

  @override
  void initState() {
    super.initState();
    _feedbackSender = widget.feedbackSender;
    _loadSettings();
    if (_feedbackSender == null) _loadFeedbackSender();
    _logPackageInfo();
  }

  Future<void> _loadSettings() async {
    final loaded = await _storage.load();
    if (!mounted) return;
    setState(() {
      _settings = loaded;
      _loading = false;
    });
  }

  Future<void> _loadFeedbackSender() async {
    final load = widget.feedbackSenderLoader ?? loadFeedbackSender;
    final feedback = await load();
    if (!mounted) {
      _closeFeedback(feedback);
      return;
    }
    setState(() => _feedbackSender = feedback);
  }

  @override
  void dispose() {
    final feedback = _feedbackSender;
    if (feedback != null) _closeFeedback(feedback);
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
        child: RuntimeEnvironmentHost(child: child ?? const SizedBox.shrink()),
      ),
      home: HomePage(
        feedbackSender: _feedbackSender,
        settings: _settings,
        onSettingsChanged: _updateSettings,
      ),
    );
  }
}
