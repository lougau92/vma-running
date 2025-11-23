import 'package:flutter/material.dart';
import 'distance_extensions.dart';
import 'l10n/translations_en.dart';
import 'l10n/translations_fr.dart';
import 'l10n/translations_nl.dart';

class AppLocalizations {
  AppLocalizations(this.locale) {
    _assertKeys();
  }

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('fr'), Locale('nl')];

  void _assertKeys() {
    final allKeys = _localizedValues.values.expand((m) => m.keys).toSet();
    for (final entry in _localizedValues.entries) {
      final missing = allKeys.difference(entry.value.keys.toSet());
      assert(
        missing.isEmpty,
        'Missing localization keys for "${entry.key}": $missing',
      );
    }
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': TranslationsEn.values,
    'fr': TranslationsFr.values,
    'nl': TranslationsNl.values,
  };

  /// Direct translation access.
  String translate(String key) => _t(key);

  /// Shorthand for translate(key).
  String operator [](String key) => _t(key);

  String _t(String key) =>
      _localizedValues[locale.languageCode]?[key] ??
      _localizedValues['en']![key]!;

  String get appTitle => _t('appTitle');
  String get noVma => _t('noVma');
  String get enterVmaPlaceholder => _t('enterVmaPlaceholder');
  String get setVma => _t('setVma');
  String get updateVma => _t('updateVma');
  String get intensity => _t('intensity');
  String get pacePerKm => _t('pacePerKm');
  String get speedKmh => _t('speedKmh');
  String get distance => _t('distance');
  String get time => _t('time');
  String get avgPace => _t('avgPace');
  String get timesTab => _t('timesTab');
  String get intensityTab => _t('intensityTab');
  String get settingsTab => _t('settingsTab');
  String get language => _t('language');
  String get systemDefault => _t('systemDefault');
  String get english => _t('english');
  String get french => _t('french');
  String get dutch => _t('dutch');
  String get theme => _t('theme');
  String get dark => _t('dark');
  String get light => _t('light');
  String get timeRange => _t('timeRange');
  String get settingsComingSoon => _t('settingsComingSoon');
  String get adjustIntensity => _t('adjustIntensity');
  String get minPercent => _t('minPercent');
  String get maxPercent => _t('maxPercent');
  String get stepPercent => _t('stepPercent');
  String get useNumbersOnly => _t('useNumbersOnly');
  String get valuesGreaterThanZero => _t('valuesGreaterThanZero');
  String get minLessThanMax => _t('minLessThanMax');
  String get stepTooLarge => _t('stepTooLarge');
  String get distanceRange => _t('distanceRange');
  String get minMeters => _t('minMeters');
  String get maxMeters => _t('maxMeters');
  String get enterVmaTitle => _t('enterVmaTitle');
  String get vmaLabel => _t('vmaLabel');
  String get enterNumber => _t('enterNumber');
  String get save => _t('save');
  String get cancel => _t('cancel');
  String get setTargetDistance => _t('setTargetDistance');
  String get distanceMetersLabel => _t('distanceMetersLabel');
  String get distanceGreaterThanZero => _t('distanceGreaterThanZero');
  String get halfMarathon => _t('halfMarathon');
  String get marathon => _t('marathon');
  String get metersAbbr => _t('metersAbbr');
  String get metersFull => _t('metersFull');
  String get kilometersAbbr => _t('kilometersAbbr');
  String get kilometersFull => _t('kilometersFull');
}

extension DynamicStrings on AppLocalizations {
  String yourVma(double vma) =>
      this['yourVma'].replaceFirst('{value}', vma.toStringAsFixed(2));

  String timeForDistanceLabel(double distanceMeters) =>
      '${this['time']} (${formatDistanceShort(distanceMeters, this)})';

  String distanceShort(double meters) => formatDistanceShort(meters, this);

  String distanceLong(double meters) => formatDistanceLong(meters, this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .map((l) => l.languageCode)
      .contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
