import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';

class SettingsStorage {
  static const _localeKey = 'settings_locale';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final locale = prefs.getString(_localeKey);
    return AppSettings(localeCode: locale);
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (settings.localeCode == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, settings.localeCode!);
    }
  }
}
