import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global Theme Controller for managing Light and Dark theme modes dynamically
class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  static const String _prefKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.dark; // Default to Incline dark luxury
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isDark => isDarkMode;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.dark; // Default
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[ThemeController] Init notice: $e');
    }
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _themeMode == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }
}
