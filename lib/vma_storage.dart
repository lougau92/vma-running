import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_localizations.dart';
import 'widgets/number_picker_dialog.dart';

/// Handles loading, saving, and prompting for the user's VMA value.
class VmaStorage {
  static const _storageKey = 'user_vma';

  Future<double?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_storageKey);
  }

  Future<void> save(double vma, {SharedPreferences? prefs}) async {
    final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
    await sharedPrefs.setDouble(_storageKey, vma);
  }

  Future<double?> promptForVma(
    BuildContext context, {
    double? initialValue,
    SharedPreferences? prefs,
  }) async {
    final strings = AppLocalizations.of(context);
    final value = initialValue != null && initialValue.isFinite
        ? initialValue.clamp(1.0, 99.99)
        : 18.0;
    final selected = await showDialog<double>(
      context: context,
      builder: (_) => NumberPickerDialog(
        title: strings.enterVmaTitle,
        initialValue: value,
        formatValue: strings.yourVma,
      ),
    );

    if (selected != null) {
      await save(selected, prefs: prefs);
    }

    return selected;
  }
}
