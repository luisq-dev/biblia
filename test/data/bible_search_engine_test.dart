import 'package:biblia/data/models/bible_book.dart';
import 'package:biblia/data/models/search_result.dart';
import 'package:biblia/data/search/bible_search_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_support.dart';

void main() {
  group('normalizeSearchText', () {
    test('convierte a minúsculas y elimina tildes sin cambiar la longitud', () {
      const String source = 'Canción del Corazón: ÁRBOL, fé y niño.';
      final String normalized = normalizeSearchText(source);
      expect(normalized, 'cancion del corazon: arbol, fe y nino.');
      expect(normalized.length, source.length);
    });
  });

  group('BibleSearchEngine', () {
    late BibleSearchEngine engine;

    setUp(() {
      engine = BibleSearchEngine(testDataset());
    });

    test('indexa todos los versículos disponibles', () {
      expect(engine.verseCount, 7);
    });

    test('encuentra palabras sin distinguir mayúsculas ni tildes', () {
      final SearchResponse response = engine.search('CORAZON');
      expect(response.totalMatches, 1);
      expect(response.results.single.reference.label, 'Génesis 1:2');
      expect(response.results.single.snippet, contains('corazón'));
    });

    test('encuentra frases completas', () {
      final SearchResponse response = engine.search('texto de prueba');
      expect(response.totalMatches, 2);
      expect(
        response.results
            .map((SearchResult result) => result.reference.label)
            .toList(),
        <String>['Génesis 1:2', 'Mateo 1:1'],
      );
    });

    test('filtra por testamento', () {
      final SearchResponse old = engine.search(
        'texto',
        testament: Testament.old,
      );
      final SearchResponse current = engine.search(
        'texto',
        testament: Testament.newTestament,
      );

      expect(old.totalMatches, 1);
      expect(old.results.single.reference.bookId, 'GEN');
      expect(current.totalMatches, 1);
      expect(current.results.single.reference.bookId, 'MAT');
    });

    test('limita resultados y marca la respuesta como truncada', () {
      final SearchResponse response = engine.search('texto', limit: 1);
      expect(response.totalMatches, 2);
      expect(response.results, hasLength(1));
      expect(response.truncated, isTrue);
    });

    test('marca el fragmento y la posición de la coincidencia', () {
      final SearchResult result = engine.search('cancion').results.single;
      expect(result.snippet, contains('canción'));
      final String highlighted = result.snippet.substring(
        result.matchStart,
        result.matchStart + result.matchLength,
      );
      expect(highlighted.toLowerCase(), 'canción');
    });

    test('devuelve una respuesta vacía para consultas en blanco', () {
      expect(engine.search('   ').results, isEmpty);
      expect(engine.search('').totalMatches, 0);
    });

    test('no inventa resultados para términos ausentes', () {
      final SearchResponse response = engine.search('inexistente');
      expect(response.results, isEmpty);
      expect(response.totalMatches, 0);
      expect(response.truncated, isFalse);
    });
  });
}
