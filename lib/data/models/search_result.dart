import 'package:biblia/data/models/bible_reference.dart';
import 'package:flutter/foundation.dart';

@immutable
class SearchResult {
  const SearchResult({
    required this.reference,
    required this.text,
    required this.snippet,
    required this.matchStart,
    required this.matchLength,
  });

  final BibleReference reference;
  final String text;

  /// Fragmento de [text] con contexto; puede empezar o terminar con «…».
  final String snippet;

  /// Posición del término encontrado dentro de [snippet].
  final int matchStart;
  final int matchLength;
}

@immutable
class SearchResponse {
  const SearchResponse({
    required this.results,
    required this.totalMatches,
    required this.truncated,
  });

  const SearchResponse.empty()
    : results = const <SearchResult>[],
      totalMatches = 0,
      truncated = false;

  final List<SearchResult> results;
  final int totalMatches;
  final bool truncated;
}
