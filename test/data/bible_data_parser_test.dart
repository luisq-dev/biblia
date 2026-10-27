import 'dart:convert';

import 'package:biblia/data/bible_data_parser.dart';
import 'package:biblia/data/models/bible_dataset.dart';
import 'package:biblia/data/models/bible_content.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_support.dart';

Map<String, dynamic> validMap() =>
    jsonDecode(testBibleJson()) as Map<String, dynamic>;

Map<String, dynamic> translationOf(Map<String, dynamic> map) =>
    map['translation'] as Map<String, dynamic>;

List<dynamic> booksOf(Map<String, dynamic> map) =>
    map['books'] as List<dynamic>;

void main() {
  group('BibleDataParser', () {
    test('convierte un archivo válido en un conjunto consultable', () {
      final BibleDataset dataset = BibleDataParser.parse(
        testBibleJson(),
        origin: 'prueba',
      );

      expect(dataset.translation.id, 'demo-ui');
      expect(dataset.translation.language, 'es');
      expect(dataset.translation.isDemo, isTrue);
      expect(dataset.translation.isComplete, isFalse);
      expect(dataset.translation.bookCount, 3);
      expect(dataset.translation.chapterCount, 4);
      expect(dataset.translation.verseCount, 7);

      final BibleChapter? chapter = dataset.chapter('GEN', 1);
      expect(chapter, isNotNull);
      expect(chapter!.verses, hasLength(3));
      expect(chapter.verses.first.number, 1);
      expect(chapter.verses.last.number, 3);
      expect(chapter.verse(2)?.text, contains('corazón'));
    });

    test('ordena libros y capítulos en orden canónico', () {
      final Map<String, dynamic> map = validMap();
      final List<dynamic> books = booksOf(map);
      final Map<String, dynamic> genesis = books.first as Map<String, dynamic>;
      final List<dynamic> chapters = genesis['chapters'] as List<dynamic>;
      chapters.setAll(0, chapters.reversed.toList());

      final BibleDataset dataset = BibleDataParser.parseMap(map);
      expect(
        dataset.books.map((BibleBookContent book) => book.bookId).toList(),
        <String>['GEN', 'PSA', 'MAT'],
      );
      expect(
        dataset.bookContent('GEN')!.chapters.map((BibleChapter c) => c.number),
        <int>[1, 2],
      );
    });

    test('recorta espacios del texto y de los metadatos', () {
      final Map<String, dynamic> map = validMap();
      translationOf(map)['name'] = '  Texto de prueba  ';
      final List<dynamic> books = booksOf(map);
      final Map<String, dynamic> genesis = books.first as Map<String, dynamic>;
      final List<dynamic> chapters = genesis['chapters'] as List<dynamic>;
      final Map<String, dynamic> chapter =
          chapters.first as Map<String, dynamic>;
      final List<dynamic> verses = chapter['verses'] as List<dynamic>;
      verses[0] = '  Texto con espacios  ';

      final BibleDataset dataset = BibleDataParser.parseMap(map);
      expect(dataset.translation.name, 'Texto de prueba');
      expect(dataset.verse('GEN', 1, 1)?.text, 'Texto con espacios');
    });

    test('usa español cuando translation.language no está presente', () {
      final Map<String, dynamic> map = validMap();
      translationOf(map).remove('language');
      final BibleDataset dataset = BibleDataParser.parseMap(map);
      expect(dataset.translation.language, 'es');
    });

    test('isDemo es falso cuando no se declara', () {
      final Map<String, dynamic> map = validMap();
      translationOf(map).remove('isDemo');
      final BibleDataset dataset = BibleDataParser.parseMap(map);
      expect(dataset.translation.isDemo, isFalse);
    });

    test('rechaza JSON mal formado', () {
      expect(
        () => BibleDataParser.parse('{ nope', origin: 'archivo de prueba'),
        throwsA(
          isA<BibleDataException>().having(
            (BibleDataException error) => error.userMessage,
            'mensaje',
            contains('JSON válido'),
          ),
        ),
      );
    });

    test('rechaza una raíz que no sea objeto', () {
      expect(
        () => BibleDataParser.parse('[]'),
        throwsA(
          isA<BibleDataException>().having(
            (BibleDataException error) => error.message,
            'mensaje',
            contains('objeto JSON'),
          ),
        ),
      );
    });

    test('rechaza versiones de esquema desconocidas', () {
      final Map<String, dynamic> map = validMap();
      map['schemaVersion'] = 2;
      expect(
        () => BibleDataParser.parseMap(map),
        throwsA(
          isA<BibleDataException>().having(
            (BibleDataException error) => error.message,
            'mensaje',
            contains('esquema 2'),
          ),
        ),
      );
    });

    test('rechaza campos obligatorios ausentes', () {
      final Map<String, dynamic> map = validMap();
      translationOf(map).remove('copyright');
      expect(
        () => BibleDataParser.parseMap(map),
        throwsA(
          isA<BibleDataException>().having(
            (BibleDataException error) => error.message,
            'mensaje',
            contains('translation.copyright'),
          ),
        ),
      );
    });

    test('rechaza libros fuera del canon', () {
      final Map<String, dynamic> map = validMap();
      (booksOf(map).first as Map<String, dynamic>)['id'] = 'XYZ';
      expect(
        () => BibleDataParser.parseMap(map),
        throwsA(
          isA<BibleDataException>().having(
            (BibleDataException error) => error.message,
            'mensaje',
            contains('no pertenece al canon'),
          ),
        ),
      );
    });

    test('rechaza libros duplicados', () {
      final Map<String, dynamic> map = validMap();
      final List<dynamic> books = booksOf(map);
      books.add(jsonDecode(jsonEncode(books.last)) as Map<String, dynamic>);
      expect(
        () => BibleDataParser.parseMap(map),
        throwsA(
          isA<BibleDataException>().having(
            (BibleDataException error) => error.message,
            'mensaje',
            contains('más de una vez'),
          ),
        ),
      );
    });

    test('rechaza capítulos duplicados', () {
      final Map<String, dynamic> map = validMap();
      final Map<String, dynamic> genesis =
          booksOf(map).first as Map<String, dynamic>;
      final List<dynamic> chapters = genesis['chapters'] as List<dynamic>;
      chapters.add(
        jsonDecode(jsonEncode(chapters.first)) as Map<String, dynamic>,
      );
      expect(
        () => BibleDataParser.parseMap(map),
        throwsA(
          isA<BibleDataException>().having(
            (BibleDataException error) => error.message,
            'mensaje',
            contains('aparece más de una vez'),
          ),
        ),
      );
    });

    test('rechaza capítulos fuera del rango canónico', () {
      final Map<String, dynamic> map = validMap();
      final Map<String, dynamic> genesis =
          booksOf(map).first as Map<String, dynamic>;
      final Map<String, dynamic> chapter =
          (genesis['chapters'] as List<dynamic>).first as Map<String, dynamic>;
      chapter['number'] = 51;
      expect(
        () => BibleDataParser.parseMap(map),
        throwsA(
          isA<BibleDataException>().having(
            (BibleDataException error) => error.message,
            'mensaje',
            contains('fuera del rango válido'),
          ),
        ),
      );
    });

    test('rechaza capítulos sin versículos', () {
      final Map<String, dynamic> map = validMap();
      final Map<String, dynamic> genesis =
          booksOf(map).first as Map<String, dynamic>;
      final Map<String, dynamic> chapter =
          (genesis['chapters'] as List<dynamic>).first as Map<String, dynamic>;
      chapter['verses'] = <String>[];
      expect(
        () => BibleDataParser.parseMap(map),
        throwsA(
          isA<BibleDataException>().having(
            (BibleDataException error) => error.message,
            'mensaje',
            contains('no contiene versículos'),
          ),
        ),
      );
    });

    test('rechaza versículos vacíos', () {
      final Map<String, dynamic> map = validMap();
      final Map<String, dynamic> genesis =
          booksOf(map).first as Map<String, dynamic>;
      final Map<String, dynamic> chapter =
          (genesis['chapters'] as List<dynamic>).first as Map<String, dynamic>;
      (chapter['verses'] as List<dynamic>)[1] = '   ';
      expect(
        () => BibleDataParser.parseMap(map),
        throwsA(
          isA<BibleDataException>().having(
            (BibleDataException error) => error.message,
            'mensaje',
            contains('está vacío'),
          ),
        ),
      );
    });

    test('rechaza un texto marcado como completo si faltan libros', () {
      final Map<String, dynamic> map = validMap();
      translationOf(map)['isComplete'] = true;
      expect(
        () => BibleDataParser.parseMap(map),
        throwsA(
          isA<BibleDataException>().having(
            (BibleDataException error) => error.message,
            'mensaje',
            contains('3 de 66'),
          ),
        ),
      );
    });

    test('acepta un texto completo con los 66 libros y 1189 capítulos', () {
      final BibleDataset dataset = BibleDataParser.parse(
        completeBibleJson(),
        origin: 'prueba completa',
      );
      expect(dataset.translation.isComplete, isTrue);
      expect(dataset.books, hasLength(66));
      expect(dataset.availableChapterCount, 1189);
      expect(dataset.availableVerseCount, 1189);
    });
  });
}
