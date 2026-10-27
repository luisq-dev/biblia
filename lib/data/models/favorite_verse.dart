import 'package:biblia/data/models/bible_reference.dart';
import 'package:flutter/foundation.dart';

@immutable
class FavoriteVerse {
  const FavoriteVerse({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.createdAt,
  });

  final String bookId;
  final int chapter;
  final int verse;
  final String text;
  final DateTime createdAt;

  BibleReference get reference =>
      BibleReference(bookId: bookId, chapter: chapter, verse: verse);

  String get label => reference.label;

  String get id => reference.key;

  Map<String, Object?> toJson() => <String, Object?>{
    'bookId': bookId,
    'chapter': chapter,
    'verse': verse,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory FavoriteVerse.fromJson(Map<String, Object?> json) {
    final Object? bookId = json['bookId'];
    final Object? chapter = json['chapter'];
    final Object? verse = json['verse'];
    final Object? text = json['text'];
    final Object? createdAt = json['createdAt'];

    if (bookId is! String ||
        bookId.trim().isEmpty ||
        chapter is! int ||
        chapter < 1 ||
        verse is! int ||
        verse < 1 ||
        text is! String ||
        createdAt is! String) {
      throw const FormatException('Favorito no válido');
    }

    final DateTime? parsedDate = DateTime.tryParse(createdAt);
    if (parsedDate == null) {
      throw const FormatException('Fecha de favorito no válida');
    }

    return FavoriteVerse(
      bookId: bookId.toUpperCase(),
      chapter: chapter,
      verse: verse,
      text: text,
      createdAt: parsedDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteVerse &&
          other.bookId == bookId &&
          other.chapter == chapter &&
          other.verse == verse;

  @override
  int get hashCode => Object.hash(bookId, chapter, verse);
}
