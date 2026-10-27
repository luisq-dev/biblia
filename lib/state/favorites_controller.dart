import 'dart:collection';

import 'package:biblia/data/favorites_repository.dart';
import 'package:biblia/data/models/bible_reference.dart';
import 'package:biblia/data/models/favorite_verse.dart';
import 'package:flutter/foundation.dart';

class FavoritesController extends ChangeNotifier {
  FavoritesController(this._repository)
    : _favorites = _repository.load().toList();

  final FavoritesRepository _repository;
  final List<FavoriteVerse> _favorites;

  late final List<FavoriteVerse> _view = UnmodifiableListView<FavoriteVerse>(
    _favorites,
  );

  List<FavoriteVerse> get favorites => _view;

  bool get isEmpty => _favorites.isEmpty;

  int get count => _favorites.length;

  bool isFavorite(BibleReference reference) {
    if (reference.verse == null) return false;
    return _favorites.any(
      (FavoriteVerse favorite) => favorite.reference == reference,
    );
  }

  FavoriteVerse? favoriteFor(BibleReference reference) {
    if (reference.verse == null) return null;
    for (final FavoriteVerse favorite in _favorites) {
      if (favorite.reference == reference) return favorite;
    }
    return null;
  }

  /// Devuelve `true` si el versículo quedó guardado.
  Future<bool> toggle({
    required BibleReference reference,
    required String text,
  }) async {
    final int? verseNumber = reference.verse;
    if (verseNumber == null) {
      throw ArgumentError('Solo se pueden guardar versículos completos.');
    }

    final int existingIndex = _favorites.indexWhere(
      (FavoriteVerse favorite) => favorite.reference == reference,
    );
    if (existingIndex >= 0) {
      _favorites.removeAt(existingIndex);
      notifyListeners();
      await _persist();
      return false;
    }

    _favorites.insert(
      0,
      FavoriteVerse(
        bookId: reference.bookId,
        chapter: reference.chapter,
        verse: verseNumber,
        text: text,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> add(FavoriteVerse favorite) async {
    final int existingIndex = _favorites.indexWhere(
      (FavoriteVerse item) => item.reference == favorite.reference,
    );
    if (existingIndex >= 0) {
      _favorites[existingIndex] = favorite;
    } else {
      _favorites.insert(0, favorite);
    }
    _sort();
    notifyListeners();
    await _persist();
  }

  Future<void> remove(BibleReference reference) async {
    final int removed = _favorites.length;
    _favorites.removeWhere(
      (FavoriteVerse favorite) => favorite.reference == reference,
    );
    if (_favorites.length == removed) return;
    notifyListeners();
    await _persist();
  }

  Future<void> restore(List<FavoriteVerse> favorites) async {
    await _repository.save(favorites);
    _favorites
      ..clear()
      ..addAll(favorites);
    _sort();
    notifyListeners();
  }

  Future<void> clear() async {
    if (_favorites.isEmpty) return;
    _favorites.clear();
    notifyListeners();
    await _persist();
  }

  void _sort() {
    _favorites.sort(
      (FavoriteVerse a, FavoriteVerse b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  Future<void> _persist() => _repository.save(_favorites);
}
