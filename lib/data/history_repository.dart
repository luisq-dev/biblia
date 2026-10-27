import 'dart:convert';

import 'package:biblia/data/models/bible_reference.dart';
import 'package:biblia/data/models/reading_progress.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryRepository {
  HistoryRepository(this._preferences);

  final SharedPreferences _preferences;

  static const String _key = 'reading.history.v1';
  static const String _progressKey = 'reading.progress.v1';
  static const int maxEntries = 12;

  List<BibleReference> load() {
    final String? raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return <BibleReference>[];

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <BibleReference>[];
      final List<BibleReference> references = <BibleReference>[];
      for (final Object? item in decoded) {
        if (item is! Map) continue;
        try {
          references.add(
            BibleReference.fromJson(Map<String, Object?>.from(item)),
          );
        } on FormatException catch (error) {
          debugPrint('Entrada de historial descartada: ${error.message}');
        }
      }
      return references.take(maxEntries).toList();
    } on FormatException catch (error) {
      debugPrint('No se pudo leer el historial: ${error.message}');
      return <BibleReference>[];
    }
  }

  ReadingProgress loadProgress() {
    final raw = _preferences.getString(_progressKey);
    if (raw == null) return ReadingProgress();
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Progreso no válido');
      }
      return ReadingProgress.fromJson(value);
    } on FormatException catch (error) {
      debugPrint('No se pudo leer el progreso: ${error.message}');
      return ReadingProgress();
    }
  }

  Future<void> saveProgress(ReadingProgress progress) async {
    await _preferences.setString(_progressKey, jsonEncode(progress.toJson()));
  }

  Future<void> save(List<BibleReference> references) async {
    final String encoded = jsonEncode(
      references
          .take(maxEntries)
          .map((BibleReference ref) => ref.toJson())
          .toList(),
    );
    await _preferences.setString(_key, encoded);
  }
}
