import 'dart:convert';

import 'package:biblia/core/constants/bible_catalog.dart';
import 'package:biblia/data/bible_data_parser.dart';
import 'package:biblia/data/bible_repository.dart';
import 'package:biblia/data/favorites_repository.dart';
import 'package:biblia/data/history_repository.dart';
import 'package:biblia/data/models/bible_book.dart';
import 'package:biblia/data/models/bible_dataset.dart';
import 'package:biblia/data/preferences_repository.dart';
import 'package:biblia/state/bible_library.dart';
import 'package:biblia/state/bible_search_controller.dart';
import 'package:biblia/state/favorites_controller.dart';
import 'package:biblia/state/history_controller.dart';
import 'package:biblia/state/reading_controller.dart';
import 'package:biblia/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:biblia/app.dart';

/// Contenido de interfaz para pruebas. No reproduce ninguna traducción bíblica.
const Map<String, Map<int, List<String>>> _testBooks =
    <String, Map<int, List<String>>>{
      'GEN': <int, List<String>>{
        1: <String>[
          'Versículo de prueba con amor y esperanza para la interfaz.',
          'El corazón y la canción aparecen con tildes en este texto de prueba.',
          'La navegación entre capítulos funciona sin conexión.',
        ],
        2: <String>['Segundo capítulo de prueba para comprobar la navegación.'],
      },
      'PSA': <int, List<String>>{
        23: <String>['Capítulo de prueba en el libro de los Salmos.'],
      },
      'MAT': <int, List<String>>{
        1: <String>[
          'Texto de prueba del Nuevo Testamento.',
          'La búsqueda distingue Testamentos en la interfaz.',
        ],
      },
    };

Map<String, Object?> testBibleMap({bool isDemo = true}) {
  return <String, Object?>{
    'schemaVersion': 1,
    'translation': <String, Object?>{
      'id': isDemo ? 'demo-ui' : 'test-text',
      'name': isDemo
          ? 'Demostración sin texto bíblico'
          : 'Texto de prueba controlado',
      'abbreviation': isDemo ? 'DEMO' : 'TEST',
      'language': 'es',
      'copyright': 'Contenido de interfaz creado para pruebas automatizadas.',
      'license': 'Uso exclusivo en pruebas. No es una traducción bíblica.',
      'isComplete': false,
      'isDemo': isDemo,
    },
    'books': <Object?>[
      for (final MapEntry<String, Map<int, List<String>>> entry
          in _testBooks.entries)
        <String, Object?>{
          'id': entry.key,
          'chapters': <Object?>[
            for (final MapEntry<int, List<String>> chapter
                in entry.value.entries)
              <String, Object?>{
                'number': chapter.key,
                'verses': chapter.value,
              },
          ],
        },
    ],
  };
}

String testBibleJson({bool isDemo = true}) =>
    const JsonEncoder.withIndent('  ').convert(testBibleMap(isDemo: isDemo));

BibleDataset testDataset({bool isDemo = true}) =>
    BibleDataParser.parseMap(testBibleMap(isDemo: isDemo));

/// Genera un archivo marcado como completo con todos los capítulos del canon.
String completeBibleJson() {
  final List<Object?> books = <Object?>[];
  for (final BibleBook book in BibleCatalog.books) {
    books.add(<String, Object?>{
      'id': book.id,
      'chapters': <Object?>[
        for (int chapter = 1; chapter <= book.chapterCount; chapter++)
          <String, Object?>{
            'number': chapter,
            'verses': <String>['Contenido sintético de prueba.'],
          },
      ],
    });
  }
  return jsonEncode(<String, Object?>{
    'schemaVersion': 1,
    'translation': <String, Object?>{
      'id': 'complete-test',
      'name': 'Texto completo sintético',
      'abbreviation': 'TEST',
      'language': 'es',
      'copyright': 'Datos sintéticos para pruebas.',
      'license': 'Solo pruebas.',
      'isComplete': true,
      'isDemo': false,
    },
    'books': books,
  });
}

class FakeBibleRepository implements BibleRepository {
  FakeBibleRepository({required BibleLoadResult result})
    : _result = result,
      _fallback = result;

  BibleLoadResult _result;
  final BibleLoadResult _fallback;

  Object? loadError;
  int loadCalls = 0;

  @override
  Future<BibleLoadResult> load() async {
    loadCalls++;
    final Object? error = loadError;
    if (error != null) throw error;
    return _result;
  }

  @override
  Future<bool> hasImportedData() async =>
      _result.source == BibleSource.imported;

  @override
  Future<BibleDataset> importJson(String json, {String? sourceName}) async {
    final BibleDataset dataset = BibleDataParser.parse(json);
    _result = BibleLoadResult(source: BibleSource.imported, dataset: dataset);
    return dataset;
  }

  @override
  Future<void> removeImported() async {
    _result = _fallback;
  }
}

class MemoryAssetBundle extends CachingAssetBundle {
  MemoryAssetBundle(this.contents);

  final Map<String, String> contents;

  @override
  Future<ByteData> load(String key) async {
    final String? content = contents[key];
    if (content == null) {
      throw FlutterError('No se encontró el recurso $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}

class AppHarness {
  AppHarness({
    required this.preferences,
    required this.settings,
    required this.favorites,
    required this.history,
    required this.library,
    required this.reading,
    required this.search,
  });

  final SharedPreferences preferences;
  final SettingsController settings;
  final FavoritesController favorites;
  final HistoryController history;
  final BibleLibrary library;
  final ReadingController reading;
  final BibleSearchController search;
}

/// Monta la aplicación completa con repositorios controlados por la prueba.
Future<AppHarness> pumpBibleApp(
  WidgetTester tester, {
  BibleLoadResult? result,
  FakeBibleRepository? repository,
  Map<String, Object> initialPreferences = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(initialPreferences);
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  final FakeBibleRepository bibleRepository =
      repository ??
      FakeBibleRepository(
        result:
            result ??
            BibleLoadResult(source: BibleSource.demo, dataset: testDataset()),
      );

  final SettingsController settings = SettingsController(
    PreferencesRepository(preferences),
  );
  final FavoritesController favorites = FavoritesController(
    FavoritesRepository(preferences),
  );
  final HistoryController history = HistoryController(
    HistoryRepository(preferences),
  );
  final BibleLibrary library = BibleLibrary(bibleRepository);
  final ReadingController reading = ReadingController(library, history);
  final BibleSearchController search = BibleSearchController(library);

  await library.load();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<FavoritesController>.value(value: favorites),
        ChangeNotifierProvider<HistoryController>.value(value: history),
        ChangeNotifierProvider<BibleLibrary>.value(value: library),
        ChangeNotifierProvider<ReadingController>.value(value: reading),
        ChangeNotifierProvider<BibleSearchController>.value(value: search),
      ],
      child: const BibliaApp(),
    ),
  );
  await tester.pumpAndSettle();

  return AppHarness(
    preferences: preferences,
    settings: settings,
    favorites: favorites,
    history: history,
    library: library,
    reading: reading,
    search: search,
  );
}

/// Etiqueta de una pestaña inferior, sin confundirla con títulos ocultos.
Finder navigationTab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

int selectedNavigationIndex(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(navigationTab(label));
  await tester.pumpAndSettle();
}

Future<void> disposeHarness(AppHarness harness) async {
  harness.reading.dispose();
  harness.search.dispose();
  harness.library.dispose();
  harness.settings.dispose();
  harness.favorites.dispose();
  harness.history.dispose();
}
