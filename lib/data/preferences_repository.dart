import 'package:biblia/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesRepository {
  PreferencesRepository(this._preferences);

  final SharedPreferences _preferences;

  static const String _themeModeKey = 'settings.theme_mode.v1';
  static const String _readingFontSizeKey = 'settings.reading_font_size.v1';
  static const String _readingFontKey = 'settings.reading_font.v1';
  static const String _colorPaletteKey = 'settings.color_palette.v1';
  static const double minFontSize = 15;
  static const double maxFontSize = 30;
  static const double defaultFontSize = 19;

  ThemeMode loadThemeMode() {
    return switch (_preferences.getString(_themeModeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final String value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _preferences.setString(_themeModeKey, value);
  }

  AppColorPalette loadColorPalette() {
    final String? id = _preferences.getString(_colorPaletteKey);
    return AppColorPalette.fromId(id);
  }

  Future<void> saveColorPalette(AppColorPalette palette) async {
    await _preferences.setString(_colorPaletteKey, palette.id);
  }

  ReadingFont loadReadingFont() =>
      ReadingFont.fromId(_preferences.getString(_readingFontKey));

  Future<void> saveReadingFont(ReadingFont font) async {
    await _preferences.setString(_readingFontKey, font.id);
  }

  double loadReadingFontSize() {
    final double? stored = _preferences.getDouble(_readingFontSizeKey);
    if (stored == null) return defaultFontSize;
    return stored.clamp(minFontSize, maxFontSize);
  }

  Future<void> saveReadingFontSize(double size) async {
    await _preferences.setDouble(
      _readingFontSizeKey,
      size.clamp(minFontSize, maxFontSize),
    );
  }
}
