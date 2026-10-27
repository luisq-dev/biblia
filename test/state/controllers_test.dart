import 'package:biblia/data/bible_data_parser.dart';
import 'package:biblia/data/bible_repository.dart';
import 'package:biblia/data/favorites_repository.dart';
import 'package:biblia/data/history_repository.dart';
import 'package:biblia/data/models/bible_book.dart';
import 'package:biblia/data/models/bible_reference.dart';
import 'package:biblia/data/preferences_repository.dart';
import 'package:biblia/state/bible_library.dart';
import 'package:biblia/state/bible_search_controller.dart';
import 'package:biblia/state/favorites_controller.dart';
import 'package:biblia/state/history_controller.dart';
import 'package:biblia/state/reading_controller.dart';
import 'package:biblia/state/settings_controller.dart';
import 'package:biblia/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_support.dart';

Future<SharedPreferences> mockPreferences([
  Map<String, Object> values = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<void> waitForSearch() =>
    Future<void>.delayed(const Duration(milliseconds: 360));

void main() {
  group('BibleLibrary', () {
    test('carga el texto sin construir la búsqueda y reutiliza el índice al pedirlo', () async {
      final BibleLibrary library = BibleLibrary(
        FakeBibleRepository(
          result: BibleLoadResult(
            source: BibleSource.demo,
            dataset: testDataset(),
          ),
        ),
      );

      await library.load();

      expect(library.status, BibleLibraryStatus.ready);
      expect(library.isReady, isTrue);
      expect(library.hasData, isTrue);
      expect(library.isDemo, isTrue);
      expect(library.source, BibleSource.demo);
      expect(library.isSearchPrepared, isFalse);
      final engine = await library.prepareSearch();
      expect(engine!.verseCount, 7);
      expect(library.isSearchPrepared, isTrue);
      expect(identical(engine, await library.prepareSearch()), isTrue);
      await library.reload();
      expect(library.isSearchPrepared, isFalse);
      library.dispose();
    });

    test('distingue el estado vacío', () async {
      final BibleLibrary library = BibleLibrary(
        FakeBibleRepository(result: const BibleLoadResult.empty()),
      );

      await library.load();

      expect(library.status, BibleLibraryStatus.empty);
      expect(library.isEmpty, isTrue);
      expect(library.hasData, isFalse);
      expect(await library.prepareSearch(), isNull);
      library.dispose();
    });

    test('propaga el error de datos con un mensaje útil', () async {
      final FakeBibleRepository repository = FakeBibleRepository(
        result: const BibleLoadResult.empty(),
      )..loadError = const BibleDataException('Archivo dañado');
      final BibleLibrary library = BibleLibrary(repository);

      await library.load();

      expect(library.status, BibleLibraryStatus.error);
      expect(library.errorMessage, contains('Archivo dañado'));
      library.dispose();
    });

    test('importa un texto y recarga el conjunto activo', () async {
      final BibleLibrary library = BibleLibrary(
        FakeBibleRepository(result: const BibleLoadResult.empty()),
      );
      await library.load();

      await library.importJson(testBibleJson(isDemo: false));

      expect(library.status, BibleLibraryStatus.ready);
      expect(library.source, BibleSource.imported);
      expect(library.hasImportedData, isTrue);
      expect(library.dataset?.translation.id, 'test-text');
      library.dispose();
    });

    test('elimina la importación y actualiza el estado', () async {
      final FakeBibleRepository repository = FakeBibleRepository(
        result: const BibleLoadResult.empty(),
      );
      final BibleLibrary library = BibleLibrary(repository);
      await library.load();
      await library.importJson(testBibleJson(isDemo: false));

      await library.removeImportedData();

      expect(library.status, BibleLibraryStatus.empty);
      expect(library.hasImportedData, isFalse);
      library.dispose();
    });
  });

  group('ReadingController', () {
    late BibleLibrary library;
    late HistoryController history;
    late ReadingController reading;

    setUp(() async {
      final SharedPreferences preferences = await mockPreferences();
      library = BibleLibrary(
        FakeBibleRepository(
          result: BibleLoadResult(
            source: BibleSource.demo,
            dataset: testDataset(),
          ),
        ),
      );
      await library.load();
      history = HistoryController(HistoryRepository(preferences));
      reading = ReadingController(library, history);
    });

    tearDown(() {
      reading.dispose();
      library.dispose();
      history.dispose();
    });

    test('abre el primer capítulo disponible al iniciar', () {
      expect(
        reading.reference,
        const BibleReference(bookId: 'GEN', chapter: 1),
      );
      expect(reading.currentChapter?.verses, hasLength(3));
      expect(reading.isReady, isTrue);
    });

    test('navega al capítulo siguiente y anterior', () {
      expect(reading.canGoPrevious, isFalse);
      expect(reading.canGoNext, isTrue);

      expect(reading.goToNextChapter(), isTrue);
      expect(
        reading.reference,
        const BibleReference(bookId: 'GEN', chapter: 2),
      );

      expect(reading.goToNextChapter(), isTrue);
      expect(
        reading.reference,
        const BibleReference(bookId: 'PSA', chapter: 23),
      );

      expect(reading.goToPreviousChapter(), isTrue);
      expect(
        reading.reference,
        const BibleReference(bookId: 'GEN', chapter: 2),
      );
    });

    test('abre una referencia con versículo y conserva el resaltado', () {
      const BibleReference target = BibleReference(
        bookId: 'MAT',
        chapter: 1,
        verse: 2,
      );
      expect(reading.openReference(target), isTrue);
      expect(reading.reference, target.chapterReference());
      expect(reading.highlightedVerse, 2);
      expect(history.lastChapter, target.chapterReference());

      reading.clearHighlight();
      expect(reading.highlightedVerse, isNull);
    });

    test('ignora capítulos y versículos inexistentes', () {
      expect(
        reading.openReference(const BibleReference(bookId: 'REV', chapter: 22)),
        isFalse,
      );
      expect(
        reading.openReference(
          const BibleReference(bookId: 'GEN', chapter: 1, verse: 99),
        ),
        isTrue,
      );
      expect(reading.highlightedVerse, isNull);
    });

    test('restaura el último capítulo del historial', () async {
      final SharedPreferences preferences = await mockPreferences();
      final HistoryController storedHistory = HistoryController(
        HistoryRepository(preferences),
      );
      storedHistory.record(const BibleReference(bookId: 'PSA', chapter: 23));
      final ReadingController restored = ReadingController(
        library,
        storedHistory,
      );

      expect(
        restored.reference,
        const BibleReference(bookId: 'PSA', chapter: 23),
      );

      restored.dispose();
      storedHistory.dispose();
    });
  });

  group('BibleSearchController', () {
    late BibleLibrary library;
    late BibleSearchController search;

    setUp(() async {
      library = BibleLibrary(
        FakeBibleRepository(
          result: BibleLoadResult(
            source: BibleSource.demo,
            dataset: testDataset(),
          ),
        ),
      );
      await library.load();
      search = BibleSearchController(library);
    });

    tearDown(() {
      search.dispose();
      library.dispose();
    });

    test('busca tras el retardo y publica resultados', () async {
      search.updateQuery('corazon');
      expect(search.status, BibleSearchStatus.searching);

      await waitForSearch();

      expect(search.status, BibleSearchStatus.results);
      expect(search.results, hasLength(1));
      expect(search.results.single.reference.label, 'Génesis 1:2');
    });

    test('filtra por testamento', () async {
      search.searchFor('texto');
      await waitForSearch();

      search.setTestament(Testament.newTestament);
      await waitForSearch();

      expect(search.results, hasLength(1));
      expect(search.results.single.reference.bookId, 'MAT');
    });

    test('informa cuando no hay coincidencias', () async {
      search.updateQuery('inexistente');
      await waitForSearch();
      expect(search.status, BibleSearchStatus.noResults);
      expect(search.results, isEmpty);
    });

    test('limpia consulta y filtros', () async {
      search.updateQuery('texto');
      await waitForSearch();
      search.setTestament(Testament.old);
      await waitForSearch();

      search.clear();

      expect(search.query, isEmpty);
      expect(search.testament, isNull);
      expect(search.status, BibleSearchStatus.idle);
      expect(search.results, isEmpty);
    });

    test('sin datos disponibles usa el estado emptyData', () async {
      final BibleLibrary emptyLibrary = BibleLibrary(
        FakeBibleRepository(result: const BibleLoadResult.empty()),
      );
      await emptyLibrary.load();
      final BibleSearchController emptySearch = BibleSearchController(
        emptyLibrary,
      );

      emptySearch.updateQuery('amor');
      expect(emptySearch.status, BibleSearchStatus.emptyData);
      expect(emptySearch.results, isEmpty);
      emptySearch.dispose();
      emptyLibrary.dispose();
    });
  });

  group('SettingsController', () {
    test('usa los valores por defecto y persiste los cambios', () async {
      final SharedPreferences preferences = await mockPreferences();
      final SettingsController settings = SettingsController(
        PreferencesRepository(preferences),
      );

      expect(settings.themeMode, ThemeMode.system);
      expect(settings.readingFontSize, PreferencesRepository.defaultFontSize);

      await settings.setThemeMode(ThemeMode.dark);
      await settings.setReadingFontSize(23);
      await settings.setReadingFont(ReadingFont.classic);
      await settings.setColorPalette(AppColorPalette.terracotta);

      final SettingsController restored = SettingsController(
        PreferencesRepository(preferences),
      );
      expect(restored.themeMode, ThemeMode.dark);
      expect(restored.readingFontSize, 23);
      expect(restored.readingFont, ReadingFont.classic);
      expect(restored.colorPalette, AppColorPalette.terracotta);

      settings.dispose();
      restored.dispose();
    });

    test('las fuentes desconocidas recuperan Literata', () async {
      final preferences = await mockPreferences(<String, Object>{
        'settings.reading_font.v1': 'removed-font',
      });
      final settings = SettingsController(PreferencesRepository(preferences));
      expect(settings.readingFont, ReadingFont.literata);
      settings.dispose();
    });

    test('limita el tamaño de texto al rango permitido', () async {
      final SharedPreferences preferences = await mockPreferences();
      final SettingsController settings = SettingsController(
        PreferencesRepository(preferences),
      );

      await settings.setReadingFontSize(100);
      expect(settings.readingFontSize, PreferencesRepository.maxFontSize);

      await settings.setReadingFontSize(1);
      expect(settings.readingFontSize, PreferencesRepository.minFontSize);

      settings.dispose();
    });
  });

  group('FavoritesController', () {
    test('guarda, recupera y elimina un versículo', () async {
      final SharedPreferences preferences = await mockPreferences();
      final FavoritesController favorites = FavoritesController(
        FavoritesRepository(preferences),
      );
      const BibleReference reference = BibleReference(
        bookId: 'GEN',
        chapter: 1,
        verse: 1,
      );

      expect(
        await favorites.toggle(reference: reference, text: 'Texto de prueba'),
        isTrue,
      );
      expect(favorites.count, 1);
      expect(favorites.isFavorite(reference), isTrue);

      final FavoritesController restored = FavoritesController(
        FavoritesRepository(preferences),
      );
      expect(restored.count, 1);
      expect(restored.isFavorite(reference), isTrue);

      expect(
        await restored.toggle(reference: reference, text: 'Texto de prueba'),
        isFalse,
      );
      expect(restored.isEmpty, isTrue);

      favorites.dispose();
      restored.dispose();
    });

    test('rechaza referencias sin versículo', () async {
      final SharedPreferences preferences = await mockPreferences();
      final FavoritesController favorites = FavoritesController(
        FavoritesRepository(preferences),
      );

      expect(
        () => favorites.toggle(
          reference: const BibleReference(bookId: 'GEN', chapter: 1),
          text: 'Texto',
        ),
        throwsArgumentError,
      );
      favorites.dispose();
    });

    test('vacía todos los favoritos', () async {
      final SharedPreferences preferences = await mockPreferences();
      final FavoritesController favorites = FavoritesController(
        FavoritesRepository(preferences),
      );
      await favorites.toggle(
        reference: const BibleReference(bookId: 'GEN', chapter: 1, verse: 1),
        text: 'Uno',
      );
      await favorites.toggle(
        reference: const BibleReference(bookId: 'GEN', chapter: 1, verse: 2),
        text: 'Dos',
      );

      await favorites.clear();

      expect(favorites.count, 0);
      expect(
        FavoritesController(FavoritesRepository(preferences)).isEmpty,
        isTrue,
      );
      favorites.dispose();
    });
  });

  group('HistoryController', () {
    test('registra sin duplicados y limita el tamaño', () async {
      final SharedPreferences preferences = await mockPreferences();
      final HistoryController history = HistoryController(
        HistoryRepository(preferences),
      );

      history.record(const BibleReference(bookId: 'GEN', chapter: 1));
      history.record(const BibleReference(bookId: 'GEN', chapter: 2));
      history.record(const BibleReference(bookId: 'GEN', chapter: 1));

      expect(history.recentChapters.first.chapter, 1);
      expect(history.recentChapters, hasLength(2));

      for (int chapter = 1; chapter <= 20; chapter++) {
        history.record(BibleReference(bookId: 'PSA', chapter: chapter));
      }
      expect(history.recentChapters, hasLength(HistoryRepository.maxEntries));

      await history.clear();
      expect(history.recentChapters, isEmpty);
      history.dispose();
    });
  });
}
