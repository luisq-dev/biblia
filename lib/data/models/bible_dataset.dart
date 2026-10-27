import 'package:biblia/core/constants/bible_catalog.dart';
import 'package:biblia/data/models/bible_book.dart';
import 'package:biblia/data/models/bible_content.dart';
import 'package:biblia/data/models/bible_reference.dart';
import 'package:biblia/data/models/translation_info.dart';
import 'package:flutter/foundation.dart';

/// Contenido bíblico disponible en el dispositivo.
///
/// Puede ser una muestra parcial, un texto autorizado completo o un conjunto
/// de prueba. [TranslationInfo.isComplete] describe el alcance real.
@immutable
class BibleDataset {
  BibleDataset({
    required this.translation,
    required List<BibleBookContent> books,
  }) : _books = <String, BibleBookContent>{
         for (final BibleBookContent book in books) book.bookId: book,
       },
       _booksByCanonicalOrder = List<BibleBookContent>.unmodifiable(
         books.toList()..sort(
           (BibleBookContent a, BibleBookContent b) =>
               BibleCatalog.indexOf(a.bookId) - BibleCatalog.indexOf(b.bookId),
         ),
       );

  final TranslationInfo translation;
  final Map<String, BibleBookContent> _books;
  final List<BibleBookContent> _booksByCanonicalOrder;

  List<BibleBookContent> get books => _booksByCanonicalOrder;

  bool get isEmpty => _books.isEmpty;

  bool get isDemo => translation.isDemo;

  bool hasBook(String bookId) => _books.containsKey(bookId.toUpperCase());

  BibleBookContent? bookContent(String bookId) => _books[bookId.toUpperCase()];

  BibleChapter? chapter(String bookId, int chapter) =>
      _books[bookId.toUpperCase()]?.chapter(chapter);

  Verse? verse(String bookId, int chapter, int verse) =>
      this.chapter(bookId, chapter)?.verse(verse);

  bool contains(BibleReference reference) =>
      chapter(reference.bookId, reference.chapter) != null;

  List<BibleBook> get availableCatalogBooks => books
      .map((BibleBookContent content) => BibleCatalog.byId(content.bookId))
      .whereType<BibleBook>()
      .toList(growable: false);

  int get availableChapterCount => books.fold<int>(
    0,
    (int total, BibleBookContent book) => total + book.chapterCount,
  );

  int get availableVerseCount => books.fold<int>(
    0,
    (int total, BibleBookContent book) => total + book.verseCount,
  );

  /// Primer capítulo disponible en orden canónico.
  BibleReference? get firstChapter {
    if (books.isEmpty) return null;
    final BibleBookContent first = books.first;
    if (first.chapters.isEmpty) return null;
    return BibleReference(
      bookId: first.bookId,
      chapter: first.chapters.first.number,
    );
  }

  /// Capítulo siguiente en orden canónico, saltando libros sin texto.
  BibleReference? nextChapter(BibleReference reference) {
    final BibleBookContent? currentBook = bookContent(reference.bookId);
    if (currentBook == null) return null;

    final int bookIndex = _booksByCanonicalOrder.indexOf(currentBook);
    final int chapterIndex = currentBook.chapters.indexWhere(
      (BibleChapter chapter) => chapter.number == reference.chapter,
    );
    if (chapterIndex < 0) return null;

    if (chapterIndex + 1 < currentBook.chapters.length) {
      return BibleReference(
        bookId: currentBook.bookId,
        chapter: currentBook.chapters[chapterIndex + 1].number,
      );
    }

    for (int i = bookIndex + 1; i < _booksByCanonicalOrder.length; i++) {
      final BibleBookContent next = _booksByCanonicalOrder[i];
      if (next.chapters.isNotEmpty) {
        return BibleReference(
          bookId: next.bookId,
          chapter: next.chapters.first.number,
        );
      }
    }
    return null;
  }

  /// Capítulo anterior en orden canónico, saltando libros sin texto.
  BibleReference? previousChapter(BibleReference reference) {
    final BibleBookContent? currentBook = bookContent(reference.bookId);
    if (currentBook == null) return null;

    final int bookIndex = _booksByCanonicalOrder.indexOf(currentBook);
    final int chapterIndex = currentBook.chapters.indexWhere(
      (BibleChapter chapter) => chapter.number == reference.chapter,
    );
    if (chapterIndex < 0) return null;

    if (chapterIndex > 0) {
      return BibleReference(
        bookId: currentBook.bookId,
        chapter: currentBook.chapters[chapterIndex - 1].number,
      );
    }

    for (int i = bookIndex - 1; i >= 0; i--) {
      final BibleBookContent previous = _booksByCanonicalOrder[i];
      if (previous.chapters.isNotEmpty) {
        return BibleReference(
          bookId: previous.bookId,
          chapter: previous.chapters.last.number,
        );
      }
    }
    return null;
  }
}
