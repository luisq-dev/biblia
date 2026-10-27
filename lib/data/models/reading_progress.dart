import 'package:biblia/core/constants/bible_catalog.dart';
import 'package:biblia/data/models/bible_reference.dart';
import 'package:flutter/foundation.dart';

BibleReference validReference(Object? value, {bool chapterOnly = false}) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Referencia bíblica no válida.');
  }
  final reference = BibleReference.fromJson(value);
  final book = BibleCatalog.byId(reference.bookId);
  if (book == null ||
      reference.chapter > book.chapterCount ||
      (reference.verse != null && reference.verse! > 1000) ||
      (chapterOnly && reference.verse != null)) {
    throw const FormatException('La referencia está fuera de la Biblia.');
  }
  return reference;
}

/// El desplazamiento del borde superior de la lectura respecto al versículo.
/// Puede ser negativo si todavía se ve el encabezado del capítulo.
@immutable
class ReadingPosition {
  const ReadingPosition({required this.reference, required this.offset});
  final BibleReference reference;
  final double offset;

  Map<String, Object?> toJson() => {
    'reference': reference.toJson(),
    'offset': offset,
  };

  factory ReadingPosition.fromJson(Map<String, dynamic> json) {
    final offset = json['offset'];
    if (offset is! num || !offset.isFinite || offset.abs() > 10000000) {
      throw const FormatException('La posición de lectura no es válida.');
    }
    return ReadingPosition(
      reference: validReference(json['reference']),
      offset: offset.toDouble(),
    );
  }
}

@immutable
class ReadingProgress {
  ReadingProgress({
    Iterable<BibleReference> completed = const [],
    this.position,
  }) : completed = Set<BibleReference>.unmodifiable(completed);
  final Set<BibleReference> completed;
  final ReadingPosition? position;

  Map<String, Object?> toJson() => {
    'completedChapters': completed
        .map((reference) => reference.toJson())
        .toList(),
    'position': position?.toJson(),
  };

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    final completed = json['completedChapters'];
    final position = json['position'];
    if (completed is! List ||
        completed.length > BibleCatalog.totalChapters ||
        (position != null && position is! Map<String, dynamic>)) {
      throw const FormatException('El progreso de lectura no es válido.');
    }
    return ReadingProgress(
      completed: completed.map(
        (value) => validReference(value, chapterOnly: true),
      ),
      position: position == null
          ? null
          : ReadingPosition.fromJson(position as Map<String, dynamic>),
    );
  }
}
