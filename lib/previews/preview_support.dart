import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app_localizations.dart';
import '../remote_asset_loader.dart';
import '../theme.dart';

/// Generates paired phone and desktop entries for one useful UI state.
final class ResponsivePreview extends MultiPreview {
  const ResponsivePreview({
    required this.name,
    this.group = 'Core running',
    this.wrapper = appPreviewWrapper,
  });

  final String name;
  final String group;
  final WidgetWrapper wrapper;

  @override
  List<Preview> get previews => [
    Preview(
      group: group,
      name: '$name · phone',
      size: const Size(390, 844),
      wrapper: wrapper,
    ),
    Preview(
      group: group,
      name: '$name · desktop',
      size: const Size(1100, 900),
      wrapper: wrapper,
    ),
  ];
}

/// Reuses the app's theme and French localization while staying service-free.
Widget appPreviewWrapper(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('fr'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppThemes.resolve('enjambee').light,
  darkTheme: AppThemes.resolve('enjambee').dark,
  home: Scaffold(body: child),
);

/// A deterministic loader for page previews; it never reads assets or Firebase.
class PreviewContentLoader extends RemoteAssetLoader {
  PreviewContentLoader({
    this.results = const [],
    this.terminalError,
    this.waitForever = false,
  });

  final List<RemoteLoadResult> results;
  final Object? terminalError;
  final bool waitForever;

  @override
  Stream<RemoteLoadResult> watchText({
    required String documentPath,
    String? assetPath,
    String fieldName = 'content',
    void Function(String)? validate,
  }) async* {
    if (waitForever) {
      await Completer<void>().future;
    }
    for (final result in results) {
      validate?.call(result.data);
      yield result;
    }
    if (terminalError != null) throw terminalError!;
  }
}

/// Opens an application's real dialog from a labelled preview surface.
class DialogPreviewLauncher extends StatelessWidget {
  const DialogPreviewLauncher({super.key, required this.onOpen});
  final Future<void> Function(BuildContext context) onOpen;

  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: () => onOpen(context),
      icon: const Icon(Icons.tune_rounded),
      label: const Text('Ouvrir le réglage'),
    ),
  );
}
