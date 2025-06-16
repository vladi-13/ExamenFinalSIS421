import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _accentColorKey = 'accent_color';

  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = const Color(0xFF6366F1);

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  ThemeProvider() {
    _loadThemePreferences();
  }

  Future<void> _loadThemePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cargar modo de tema
      final themeModeIndex = prefs.getInt(_themeModeKey) ?? 0;
      _themeMode = ThemeMode.values[themeModeIndex];

      // Cargar color de acento
      final colorValue = prefs.getInt(_accentColorKey);
      if (colorValue != null) {
        _accentColor = Color(colorValue);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preferences: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeModeKey, mode.index);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  Future<void> setAccentColor(Color color) async {
    if (_accentColor == color) return;

    _accentColor = color;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_accentColorKey, color.value);
    } catch (e) {
      debugPrint('Error saving accent color: $e');
    }
  }

  Future<void> toggleTheme() async {
    final newMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newMode);
  }

  // Colores predefinidos para el selector
  static const List<Color> accentColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Purple
    Color(0xFF06B6D4), // Cyan
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFFEC4899), // Pink
    Color(0xFF84CC16), // Lime
  ];

  // Obtener el tema claro personalizado
  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _accentColor,
      brightness: Brightness.light,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black87),
      titleTextStyle: TextStyle(
        color: Colors.black87,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _accentColor,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
  );

  // Obtener el tema oscuro personalizado
  ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _accentColor,
      brightness: Brightness.dark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _accentColor,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
  );
}
