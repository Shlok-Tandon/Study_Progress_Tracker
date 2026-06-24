import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_themeKey);
      if (value == 'light') _themeMode = ThemeMode.light;
      if (value == 'dark') _themeMode = ThemeMode.dark;
      notifyListeners();
    } catch (_) {
      // Gracefully handle SharedPreferences initialization exceptions
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;

    // FIX: Notify listeners synchronously and immediately.
    // This allows Flutter to instantly trigger the rebuild/interpolation
    // without waiting for disk writes to finish.
    notifyListeners();

    try {
      // Execute disk-write operations in the background without awaiting them
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.name);
    } catch (_) {
      // Handle storage failure gracefully without crashing the UI
    }
  }
}