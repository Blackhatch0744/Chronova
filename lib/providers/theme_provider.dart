import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;

  ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E3A8A),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF4F7FF),
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0F1419),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A2332),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFF5F5F5)),
        titleTextStyle: TextStyle(
          color: Color(0xFFF5F5F5),
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.dark,
        surface: const Color(0xFF1A2332),
        background: const Color(0xFF0F1419),
      ),
      cardColor: const Color(0xFF1A2332),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFF5F5F5)),
        bodyMedium: TextStyle(color: Color(0xFFD0D0D0)),
        labelLarge: TextStyle(color: Color(0xFFF5F5F5)),
        titleLarge: TextStyle(color: Color(0xFFF5F5F5)),
        titleMedium: TextStyle(color: Color(0xFFF5F5F5)),
        headlineSmall: TextStyle(color: Color(0xFFF5F5F5)),
      ),
      iconTheme: const IconThemeData(color: Color(0xFFF5F5F5)),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: const Color(0xFF1A2332),
        filled: true,
        labelStyle: const TextStyle(color: Color(0xFFD0D0D0)),
        hintStyle: const TextStyle(color: Color(0xFF808080)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
      ),
    );
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs.getBool('isDarkMode') ?? false;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  Future<void> setDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    await _prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }
}
