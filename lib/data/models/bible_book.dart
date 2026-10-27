enum Testament { old, newTestament }

extension TestamentLabel on Testament {
  String get label => switch (this) {
    Testament.old => 'Antiguo Testamento',
    Testament.newTestament => 'Nuevo Testamento',
  };

  String get shortLabel => switch (this) {
    Testament.old => 'Antiguo Testamento',
    Testament.newTestament => 'Nuevo Testamento',
  };
}

/// Metadatos de un libro del canon bíblico.
///
/// No contiene texto bíblico. El contenido se consulta en [BibleDataset].
class BibleBook {
  const BibleBook({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.testament,
    required this.chapterCount,
  });

  /// Identificador USFM estable, por ejemplo `GEN` o `JHN`.
  final String id;
  final String name;
  final String abbreviation;
  final Testament testament;
  final int chapterCount;
}
