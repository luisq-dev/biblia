import 'dart:math' as math;

import 'package:biblia/core/constants/bible_catalog.dart';
import 'package:biblia/data/models/bible_book.dart';
import 'package:biblia/data/models/bible_content.dart';
import 'package:biblia/data/models/bible_dataset.dart';
import 'package:biblia/data/models/bible_reference.dart';
import 'package:biblia/data/models/search_result.dart';

/// Normaliza texto para búsquedas insensibles a mayúsculas y tildes.
///
/// La sustitución es uno a uno para conservar la correspondencia entre
/// posiciones del texto original y del texto normalizado.
String normalizeSearchText(String input) {
  final StringBuffer buffer = StringBuffer();
  for (final int codeUnit in input.toLowerCase().codeUnits) {
    buffer.write(_replacements[codeUnit] ?? String.fromCharCode(codeUnit));
  }
  return buffer.toString();
}

const Map<int, String> _replacements = <int, String>{
  0x00E1: 'a', // á
  0x00E0: 'a', // à
  0x00E4: 'a', // ä
  0x00E2: 'a', // â
  0x00E3: 'a', // ã
  0x00E9: 'e', // é
  0x00E8: 'e', // è
  0x00EB: 'e', // ë
  0x00EA: 'e', // ê
  0x00ED: 'i', // í
  0x00EC: 'i', // ì
  0x00EF: 'i', // ï
  0x00EE: 'i', // î
  0x00F3: 'o', // ó
  0x00F2: 'o', // ò
  0x00F6: 'o', // ö
  0x00F4: 'o', // ô
  0x00F5: 'o', // õ
  0x00FA: 'u', // ú
  0x00F9: 'u', // ù
  0x00FC: 'u', // ü
  0x00FB: 'u', // û
  0x00F1: 'n', // ñ
  0x00E7: 'c', // ç
};

class _IndexedVerse {
  const _IndexedVerse({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.normalized,
  });

  final String bookId;
  final int chapter;
  final int verse;
  final String text;
  final String normalized;
}

/// Índice en memoria para búsquedas rápidas sobre el texto cargado.
///
/// Se construye una sola vez cuando se solicita la búsqueda. Para la RVR1960
/// completa (~31.000 versículos) el coste de memoria y de construcción es
/// asumible; si en el futuro el corpus crece mucho, esta clase puede sustituirse
/// por SQLite FTS5 sin cambiar la interfaz de la aplicación.
class BibleSearchEngine {
  BibleSearchEngine(BibleDataset dataset) {
    final List<_IndexedVerse> index = <_IndexedVerse>[];
    final Map<String, List<_IndexedVerse>> byBook =
        <String, List<_IndexedVerse>>{};
    final List<_IndexedVerse> oldTestament = <_IndexedVerse>[];
    final List<_IndexedVerse> newTestament = <_IndexedVerse>[];

    for (final BibleBookContent book in dataset.books) {
      final Testament? testament = BibleCatalog.byId(book.bookId)?.testament;
      final List<_IndexedVerse> bookList = <_IndexedVerse>[];

      for (final BibleChapter chapter in book.chapters) {
        for (final Verse verse in chapter.verses) {
          final _IndexedVerse entry = _IndexedVerse(
            bookId: book.bookId,
            chapter: chapter.number,
            verse: verse.number,
            text: verse.text,
            normalized: normalizeSearchText(verse.text),
          );
          index.add(entry);
          bookList.add(entry);
          if (testament == Testament.old) {
            oldTestament.add(entry);
          } else if (testament == Testament.newTestament) {
            newTestament.add(entry);
          }
        }
      }
      byBook[book.bookId] = List<_IndexedVerse>.unmodifiable(bookList);
    }
    _index = List<_IndexedVerse>.unmodifiable(index);
    _byBook = byBook;
    _oldTestament = List<_IndexedVerse>.unmodifiable(oldTestament);
    _newTestament = List<_IndexedVerse>.unmodifiable(newTestament);
  }

  late final List<_IndexedVerse> _index;
  late final Map<String, List<_IndexedVerse>> _byBook;
  late final List<_IndexedVerse> _oldTestament;
  late final List<_IndexedVerse> _newTestament;

  int get verseCount => _index.length;

  SearchResponse search(
    String query, {
    Testament? testament,
    String? bookId,
    int limit = 200,
  }) {
    final String normalizedQuery = normalizeSearchText(query.trim());
    if (normalizedQuery.isEmpty) return const SearchResponse.empty();

    final Iterable<_IndexedVerse> targetList;
    if (bookId != null) {
      targetList = _byBook[bookId] ?? const <_IndexedVerse>[];
    } else if (testament == Testament.old) {
      targetList = _oldTestament;
    } else if (testament == Testament.newTestament) {
      targetList = _newTestament;
    } else {
      targetList = _index;
    }

    final List<SearchResult> results = <SearchResult>[];
    int total = 0;

    for (final _IndexedVerse entry in targetList) {
      final int matchIndex = entry.normalized.indexOf(normalizedQuery);
      if (matchIndex < 0) continue;

      total++;
      if (results.length >= limit) continue;

      final _Snippet snippet = _buildSnippet(
        text: entry.text,
        matchStart: matchIndex,
        matchLength: normalizedQuery.length,
      );

      results.add(
        SearchResult(
          reference: BibleReference(
            bookId: entry.bookId,
            chapter: entry.chapter,
            verse: entry.verse,
          ),
          text: entry.text,
          snippet: snippet.text,
          matchStart: snippet.matchStart,
          matchLength: normalizedQuery.length,
        ),
      );
    }

    return SearchResponse(
      results: List<SearchResult>.unmodifiable(results),
      totalMatches: total,
      truncated: total > results.length,
    );
  }
}

class _Snippet {
  const _Snippet({required this.text, required this.matchStart});

  final String text;
  final int matchStart;
}

_Snippet _buildSnippet({
  required String text,
  required int matchStart,
  required int matchLength,
}) {
  const int context = 70;
  final int start = math.max(0, matchStart - context);
  final int end = math.min(text.length, matchStart + matchLength + context);

  String snippet = text.substring(start, end).replaceAll(RegExp(r'\s+'), ' ');
  final String prefix = text
      .substring(start, matchStart)
      .replaceAll(RegExp(r'\s+'), ' ');

  // Al recortar los espacios iniciales, el resaltado se desplaza.
  final int leadingSpaces = snippet.length - snippet.trimLeft().length;
  int localMatch = prefix.length - leadingSpaces;
  snippet = snippet.trim();

  if (start > 0) {
    snippet = '…$snippet';
    localMatch += 1;
  }
  if (end < text.length) {
    snippet = '$snippet…';
  }

  return _Snippet(
    text: snippet,
    matchStart: localMatch.clamp(0, snippet.length),
  );
}
