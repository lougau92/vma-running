import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_localizations.dart';

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
    final controller = TextEditingController(
      text: initialValue != null ? initialValue.toStringAsFixed(2) : '',
    );
    String? validationError;

    final selected = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(strings.enterVmaTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: strings.vmaLabel,
              errorText: validationError,
            ),
            onChanged: (_) {
              if (validationError != null) {
                setStateDialog(() => validationError = null);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                final parsed = double.tryParse(
                  controller.text.replaceAll(',', '.'),
                );
                if (parsed == null) {
                  setStateDialog(() => validationError = strings.enterNumber);
                  return;
                }
                Navigator.of(dialogContext).pop(parsed);
              },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      await save(selected, prefs: prefs);
    }

    return selected;
  }
}
