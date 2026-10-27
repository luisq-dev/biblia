import 'package:biblia/core/constants/bible_catalog.dart';
import 'package:flutter/foundation.dart';

/// Referencia inequívoca a un capítulo o a un versículo.
@immutable
class BibleReference {
  const BibleReference({
    required this.bookId,
    required this.chapter,
    this.verse,
  });

  final String bookId;
  final int chapter;
  final int? verse;

  bool get isVerse => verse != null;

  String get bookName => BibleCatalog.displayName(bookId);

  String get chapterLabel => '$bookName $chapter';

  String get label => isVerse ? '$chapterLabel:$verse' : chapterLabel;

  String get key => '$bookId:$chapter:${verse ?? '*'}';

  BibleReference chapterReference() =>
      BibleReference(bookId: bookId, chapter: chapter);

  BibleReference withVerse(int? verse) =>
      BibleReference(bookId: bookId, chapter: chapter, verse: verse);

  Map<String, Object?> toJson() => <String, Object?>{
    'bookId': bookId,
    'chapter': chapter,
    if (verse != null) 'verse': verse,
  };

  factory BibleReference.fromJson(Map<String, Object?> json) {
    final Object? bookId = json['bookId'];
    final Object? chapter = json['chapter'];
    final Object? verse = json['verse'];
    if (bookId is! String ||
        bookId.trim().isEmpty ||
        chapter is! int ||
        chapter < 1 ||
        (verse != null && (verse is! int || verse < 1))) {
      throw const FormatException('Referencia bíblica no válida');
    }
    return BibleReference(
      bookId: bookId.toUpperCase(),
      chapter: chapter,
      verse: verse as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleReference &&
          other.bookId == bookId &&
          other.chapter == chapter &&
          other.verse == verse;

  @override
  int get hashCode => Object.hash(bookId, chapter, verse);

  @override
  String toString() => label;
}
