import 'dart:convert';

import 'package:biblia/data/history_repository.dart';
import 'package:biblia/data/models/bible_reference.dart';
import 'package:biblia/data/models/favorite_verse.dart';
import 'package:biblia/data/models/reading_progress.dart';
import 'package:biblia/data/preferences_repository.dart';
import 'package:biblia/theme/app_theme.dart';
import 'package:flutter/material.dart';

class BackupSettings {
  const BackupSettings({
    required this.themeMode,
    required this.palette,
    required this.font,
    required this.fontSize,
  });
  final ThemeMode themeMode;
  final AppColorPalette palette;
  final ReadingFont font;
  final double fontSize;

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
    'colorPalette': palette.id,
    'readingFont': font.id,
    'readingFontSize': fontSize,
  };

  factory BackupSettings.fromJson(Map<String, dynamic> json) {
    final size = json['readingFontSize'];
    if (!ThemeMode.values.any((value) => value.name == json['themeMode']) ||
        !AppColorPalette.values.any(
          (value) => value.id == json['colorPalette'],
        ) ||
        !ReadingFont.values.any((value) => value.id == json['readingFont']) ||
        size is! num ||
        !size.isFinite ||
        size < PreferencesRepository.minFontSize ||
        size > PreferencesRepository.maxFontSize) {
      throw const FormatException('Los ajustes del respaldo no son válidos.');
    }
    return BackupSettings(
      themeMode: ThemeMode.values.firstWhere(
        (value) => value.name == json['themeMode'],
      ),
      palette: AppColorPalette.fromId(json['colorPalette'] as String),
      font: ReadingFont.fromId(json['readingFont'] as String),
      fontSize: size.toDouble(),
    );
  }
}

class UserBackup {
  UserBackup({
    required this.settings,
    required Iterable<FavoriteVerse> favorites,
    required Iterable<BibleReference> history,
    required this.progress,
    DateTime? exportedAt,
  }) : favorites = List<FavoriteVerse>.unmodifiable(favorites),
       history = List<BibleReference>.unmodifiable(history),
       exportedAt = exportedAt ?? DateTime.now().toUtc();
  static const String format = 'biblia1960.backup';
  static const int schemaVersion = 1;
  static const int maxBytes = 32 * 1024 * 1024;
  final DateTime exportedAt;
  final BackupSettings settings;
  final List<FavoriteVerse> favorites;
  final List<BibleReference> history;
  final ReadingProgress progress;

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'format': format,
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'settings': settings.toJson(),
    'favorites': favorites.map((favorite) => favorite.toJson()).toList(),
    'history': history.map((reference) => reference.toJson()).toList(),
    'reading': progress.toJson(),
  });

  factory UserBackup.decode(String source) {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('El respaldo supera el límite de 32 MB.');
    }
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> ||
        value['format'] != format ||
        value['schemaVersion'] != schemaVersion) {
      throw const FormatException(
        'Selecciona un respaldo JSON de Biblia 1960 compatible (versión 1).',
      );
    }
    final settings = value['settings'];
    final favorites = value['favorites'];
    final history = value['history'];
    final reading = value['reading'];
    final exported = value['exportedAt'];
    if (settings is! Map<String, dynamic> ||
        favorites is! List ||
        history is! List ||
        reading is! Map<String, dynamic> ||
        exported is! String ||
        DateTime.tryParse(exported) == null ||
        favorites.length > 50000 ||
        history.length > HistoryRepository.maxEntries) {
      throw const FormatException(
        'El respaldo está incompleto o contiene datos no válidos.',
      );
    }
    final parsedFavorites = <FavoriteVerse>[];
    final ids = <String>{};
    for (final entry in favorites) {
      final reference = validReference(entry);
      if (!reference.isVerse ||
          entry is! Map<String, dynamic> ||
          !ids.add(reference.key)) {
        throw const FormatException(
          'El respaldo contiene favoritos no válidos o duplicados.',
        );
      }
      final favorite = FavoriteVerse.fromJson(entry);
      if (favorite.text.length > 20000) {
        throw const FormatException(
          'El texto de un favorito es demasiado largo.',
        );
      }
      parsedFavorites.add(favorite);
    }
    final parsedHistory = history
        .map((entry) => validReference(entry, chapterOnly: true))
        .toList();
    if (parsedHistory.toSet().length != parsedHistory.length) {
      throw const FormatException(
        'El historial contiene capítulos duplicados.',
      );
    }
    return UserBackup(
      settings: BackupSettings.fromJson(settings),
      favorites: parsedFavorites,
      history: parsedHistory,
      progress: ReadingProgress.fromJson(reading),
      exportedAt: DateTime.parse(exported),
    );
  }
}
