import 'dart:convert';

import 'package:biblia/data/models/favorite_verse.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesRepository {
  FavoritesRepository(this._preferences);

  final SharedPreferences _preferences;

  static const String _key = 'favorites.verses.v1';

  List<FavoriteVerse> load() {
    final String? raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return <FavoriteVerse>[];

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <FavoriteVerse>[];
      final List<FavoriteVerse> favorites = <FavoriteVerse>[];
      for (final Object? item in decoded) {
        if (item is! Map) continue;
        try {
          favorites.add(
            FavoriteVerse.fromJson(Map<String, Object?>.from(item)),
          );
        } on FormatException catch (error) {
          debugPrint('Favorito descartado: ${error.message}');
        }
      }
      favorites.sort(
        (FavoriteVerse a, FavoriteVerse b) =>
            b.createdAt.compareTo(a.createdAt),
      );
      return favorites;
    } on FormatException catch (error) {
      debugPrint('No se pudieron leer los favoritos: ${error.message}');
      return <FavoriteVerse>[];
    }
  }

  Future<void> save(List<FavoriteVerse> favorites) async {
    final String encoded = jsonEncode(
      favorites.map((FavoriteVerse favorite) => favorite.toJson()).toList(),
    );
    await _preferences.setString(_key, encoded);
  }
}
