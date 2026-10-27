import 'package:biblia/core/constants/bible_catalog.dart';
import 'package:biblia/data/models/bible_book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BibleCatalog', () {
    test('contiene los 66 libros del canon', () {
      expect(BibleCatalog.books, hasLength(66));
      expect(BibleCatalog.byTestament(Testament.old), hasLength(39));
      expect(BibleCatalog.byTestament(Testament.newTestament), hasLength(27));
    });

    test('la suma de capítulos coincide con los 1189 del canon', () {
      final int chapters = BibleCatalog.books.fold<int>(
        0,
        (int total, BibleBook book) => total + book.chapterCount,
      );
      expect(chapters, BibleCatalog.totalChapters);
      expect(chapters, 1189);
    });

    test(
      'los identificadores son únicos y consultables sin distinguir mayúsculas',
      () {
        final Set<String> ids = BibleCatalog.books
            .map((BibleBook book) => book.id)
            .toSet();
        expect(ids, hasLength(66));
        expect(BibleCatalog.byId('gen')?.name, 'Génesis');
        expect(BibleCatalog.byId('REV')?.name, 'Apocalipsis');
        expect(BibleCatalog.byId('XXX'), isNull);
      },
    );

    test('la búsqueda por libro devuelve nombres y abreviaturas', () {
      expect(BibleCatalog.displayName('JHN'), 'Juan');
      expect(BibleCatalog.displayAbbreviation('JHN'), 'Jn');
      expect(BibleCatalog.indexOf('GEN'), 0);
      expect(BibleCatalog.indexOf('REV'), 65);
      expect(BibleCatalog.indexOf('NOPE'), -1);
    });

    test('los libros tienen nombres y abreviaturas no vacíos', () {
      for (final BibleBook book in BibleCatalog.books) {
        expect(book.name.trim(), isNotEmpty);
        expect(book.abbreviation.trim(), isNotEmpty);
        expect(book.chapterCount, greaterThan(0));
      }
    });
  });
}
