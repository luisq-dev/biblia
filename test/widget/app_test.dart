import 'package:biblia/data/bible_repository.dart';
import 'package:biblia/data/models/bible_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_support.dart';

void main() {
  group('Navegación y lectura', () {
    testWidgets('muestra las tres secciones y conserva su estado', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await pumpBibleApp(tester);

      expect(navigationTab('Lectura'), findsOneWidget);
      expect(navigationTab('Buscar'), findsOneWidget);
      expect(navigationTab('Favoritos'), findsOneWidget);
      expect(find.text('Génesis 1'), findsOneWidget);
      expect(find.text('Modo demostración'), findsOneWidget);
      expect(
        find.text('Versículo de prueba con amor y esperanza para la interfaz.'),
        findsOneWidget,
      );

      await openTab(tester, 'Buscar');
      expect(selectedNavigationIndex(tester), 1);
      expect(find.byType(SearchBar), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(SearchBar),
          matching: find.byType(TextField),
        ),
        'corazon',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Génesis 1:2'), findsOneWidget);

      await openTab(tester, 'Favoritos');
      expect(selectedNavigationIndex(tester), 2);
      expect(find.text('Aún no tienes favoritos'), findsOneWidget);

      await openTab(tester, 'Buscar');
      expect(selectedNavigationIndex(tester), 1);
      expect(find.text('Génesis 1:2'), findsOneWidget);
      expect(find.byType(SearchBar), findsOneWidget);

      await disposeHarness(harness);
    });

    testWidgets('abre un resultado de búsqueda en el pasaje exacto', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await pumpBibleApp(tester);

      await openTab(tester, 'Buscar');
      await tester.enterText(
        find.descendant(
          of: find.byType(SearchBar),
          matching: find.byType(TextField),
        ),
        'corazon',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Génesis 1:2'));
      await tester.pumpAndSettle();

      expect(
        harness.reading.reference,
        const BibleReference(bookId: 'GEN', chapter: 1),
      );
      expect(harness.reading.highlightedVerse, 2);
      expect(find.text('Génesis 1'), findsOneWidget);

      await disposeHarness(harness);
    });

    testWidgets('navega entre capítulos desde el pie de lectura', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await pumpBibleApp(tester);

      final Finder nextChapter = find.text('Capítulo 2').last;
      await tester.ensureVisible(nextChapter);
      await tester.pumpAndSettle();
      await tester.tap(nextChapter);
      await tester.pumpAndSettle();

      expect(
        harness.reading.reference,
        const BibleReference(bookId: 'GEN', chapter: 2),
      );
      expect(find.text('Génesis 2'), findsOneWidget);

      await disposeHarness(harness);
    });
  });

  group('Favoritos', () {
    testWidgets('guarda un versículo y lo muestra en la pestaña de favoritos', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await pumpBibleApp(tester);

      const String verseText =
          'Versículo de prueba con amor y esperanza para la interfaz.';
      await tester.tap(find.text(verseText));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();

      expect(find.text('Génesis 1:1'), findsOneWidget);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(harness.favorites.count, 1);
      expect(find.text('Versículo guardado en favoritos'), findsOneWidget);
      expect(
        harness.preferences.getString('favorites.verses.v1'),
        contains('GEN'),
      );

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      await openTab(tester, 'Favoritos');
      expect(selectedNavigationIndex(tester), 2);

      expect(find.text('1 versículo guardado'), findsOneWidget);
      expect(find.text('Génesis 1:1'), findsOneWidget);
      expect(find.text(verseText), findsOneWidget);

      await disposeHarness(harness);
    });
  });

  group('Ajustes', () {
    testWidgets('cambia el tema y lo persiste', (WidgetTester tester) async {
      final AppHarness harness = await pumpBibleApp(tester);

      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Tema de la aplicación'), findsOneWidget);
      expect(find.text('Tamaño del texto bíblico'), findsOneWidget);

      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();

      expect(harness.settings.themeMode, ThemeMode.light);
      expect(harness.preferences.getString('settings.theme_mode.v1'), 'light');
      expect(
        harness.preferences.getDouble('settings.reading_font_size.v1'),
        isNull,
      );

      await disposeHarness(harness);
    });
  });

  group('Estados vacíos', () {
    testWidgets('explica la ausencia de texto y permite abrir Ajustes', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await pumpBibleApp(
        tester,
        result: const BibleLoadResult.empty(),
      );

      expect(
        find.text('El texto bíblico aún no está instalado'),
        findsOneWidget,
      );
      expect(find.text('Abrir Ajustes'), findsOneWidget);
      expect(find.text('Modo demostración'), findsNothing);

      await tester.tap(find.text('Abrir Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Ajustes'), findsOneWidget);

      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();
      await openTab(tester, 'Buscar');
      expect(find.text('No hay texto para buscar'), findsOneWidget);

      await openTab(tester, 'Favoritos');
      expect(find.text('Aún no tienes favoritos'), findsOneWidget);

      await disposeHarness(harness);
    });

    testWidgets('muestra el estado sin resultados de búsqueda', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await pumpBibleApp(tester);

      await openTab(tester, 'Buscar');
      await tester.enterText(
        find.descendant(
          of: find.byType(SearchBar),
          matching: find.byType(TextField),
        ),
        'zzzz',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Sin resultados'), findsOneWidget);
      expect(find.text('Limpiar búsqueda'), findsOneWidget);

      await disposeHarness(harness);
    });
  });

  group('Texto parcial', () {
    testWidgets('etiqueta un texto incompleto y no afirma que sea la RVR1960', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await pumpBibleApp(
        tester,
        result: BibleLoadResult(
          source: BibleSource.bundled,
          dataset: testDataset(isDemo: false),
        ),
      );

      expect(find.text('Modo demostración'), findsNothing);
      expect(
        find.text('Texto parcial: 3 libros y 4 capítulos disponibles.'),
        findsOneWidget,
      );
      expect(find.text('Génesis 1'), findsOneWidget);
      expect(find.textContaining('Texto de prueba controlado'), findsOneWidget);

      await disposeHarness(harness);
    });
  });

  group('Persistencia de ajustes', () {
    testWidgets('restaura el tema y el tamaño de texto guardados', (
      WidgetTester tester,
    ) async {
      final AppHarness harness = await pumpBibleApp(
        tester,
        initialPreferences: <String, Object>{
          'settings.theme_mode.v1': 'dark',
          'settings.reading_font_size.v1': 24.0,
        },
      );

      expect(harness.settings.themeMode, ThemeMode.dark);
      expect(harness.settings.readingFontSize, 24);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );

      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pumpAndSettle();
      final Slider slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 24);

      await disposeHarness(harness);
    });
  });
}
