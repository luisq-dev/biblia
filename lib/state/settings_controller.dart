import 'package:biblia/data/preferences_repository.dart';
import 'package:biblia/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._repository)
    : _themeMode = _repository.loadThemeMode(),
      _colorPalette = _repository.loadColorPalette(),
      _readingFont = _repository.loadReadingFont(),
      _readingFontSize = _repository.loadReadingFontSize();

  final PreferencesRepository _repository;

  ThemeMode _themeMode;
  AppColorPalette _colorPalette;
  double _readingFontSize;
  ReadingFont _readingFont;

  ThemeMode get themeMode => _themeMode;

  AppColorPalette get colorPalette => _colorPalette;

  ReadingFont get readingFont => _readingFont;

  double get readingFontSize => _readingFontSize;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _repository.saveThemeMode(mode);
  }

  Future<void> setColorPalette(AppColorPalette palette) async {
    if (_colorPalette == palette) return;
    _colorPalette = palette;
    notifyListeners();
    await _repository.saveColorPalette(palette);
  }

  Future<void> setReadingFont(ReadingFont font) async {
    if (_readingFont == font) return;
    _readingFont = font;
    notifyListeners();
    await _repository.saveReadingFont(font);
  }

  Future<void> setReadingFontSize(double size) async {
    final double normalized = size.clamp(
      PreferencesRepository.minFontSize,
      PreferencesRepository.maxFontSize,
    );
    if ((_readingFontSize - normalized).abs() >= 0.01) {
      _readingFontSize = normalized;
      notifyListeners();
    }
    await _repository.saveReadingFontSize(normalized);
  }
}
