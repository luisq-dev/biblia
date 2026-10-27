import 'package:biblia/data/bible_data_parser.dart';
import 'package:biblia/data/bible_repository.dart';
import 'package:biblia/data/models/bible_reference.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_support.dart';

Finder verse(int number) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.button == true &&
      (widget.properties.label?.startsWith('Génesis 1:$number.') ?? false),
);

bool isSelected(WidgetTester tester, int number) =>
    tester.widget<Semantics>(verse(number)).properties.selected ?? false;

Future<AppHarness> setup(
  WidgetTester tester, {
  bool longChapter = false,
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  BibleLoadResult? result;
  if (longChapter) {
    final Map<String, Object?> data = testBibleMap();
    final books = data['books']! as List<Object?>;
    final book = books.first! as Map<String, Object?>;
    final chapters = book['chapters']! as List<Object?>;
    final chapter = chapters.first! as Map<String, Object?>;
    chapter['verses'] = List<String>.generate(
      40,
      (index) =>
          'Texto de prueba del versículo ${index + 1} para seleccionar al arrastrar.',
    );
    result = BibleLoadResult(
      source: BibleSource.demo,
      dataset: BibleDataParser.parseMap(data),
    );
  }
  final AppHarness harness = await pumpBibleApp(tester, result: result);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await disposeHarness(harness);
  });
  return harness;
}

void main() {
  testWidgets('tocar alterna cada versículo sin bloquear la lectura', (
    tester,
  ) async {
    await setup(tester);
    await tester.tap(verse(1));
    await tester.pumpAndSettle();
    expect(isSelected(tester, 1), isTrue);
    expect(find.text('1 versículo seleccionado'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(verse(3));
    await tester.pumpAndSettle();
    expect(isSelected(tester, 1), isTrue);
    expect(isSelected(tester, 2), isFalse);
    expect(isSelected(tester, 3), isTrue);

    await tester.tap(verse(1));
    await tester.pumpAndSettle();
    expect(isSelected(tester, 1), isFalse);
    expect(isSelected(tester, 3), isTrue);
    await tester.tap(verse(3));
    await tester.pumpAndSettle();
    expect(find.text('Acciones'), findsNothing);
  });

  testWidgets(
    'seleccionar una fila conserva el texto de las filas sin cambios',
    (tester) async {
      await setup(tester);
      final Finder secondText = find
          .descendant(of: verse(2), matching: find.byType(Text))
          .last;
      final Text before = tester.widget<Text>(secondText);
      await tester.tap(verse(1));
      await tester.pumpAndSettle();
      expect(identical(before, tester.widget<Text>(secondText)), isTrue);
    },
  );

  for (final bool reverse in <bool>[false, true]) {
    testWidgets(
      'mantener y arrastrar selecciona un rango ${reverse ? 'hacia arriba' : 'hacia abajo'}',
      (tester) async {
        await setup(tester);
        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(verse(reverse ? 3 : 1)),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await gesture.moveTo(tester.getCenter(verse(reverse ? 1 : 3)));
        await tester.pump();
        for (int number = 1; number <= 3; number++) {
          expect(isSelected(tester, number), isTrue);
        }
        await gesture.moveTo(tester.getCenter(verse(2)));
        await tester.pump();
        expect(isSelected(tester, 2), isTrue);
        expect(isSelected(tester, reverse ? 1 : 3), isFalse);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.text('2 versículos seleccionados'), findsOneWidget);
        await tester.tap(verse(2));
        await tester.pumpAndSettle();
        expect(isSelected(tester, 2), isFalse);
      },
    );
  }

  testWidgets('arrastrar conserva selecciones previas y permite limpiar todo', (
    tester,
  ) async {
    await setup(tester);
    await tester.tap(verse(3));
    await tester.pumpAndSettle();
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(verse(1)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(verse(2)));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('3 versículos seleccionados'), findsOneWidget);
    await tester.tap(find.byTooltip('Deseleccionar todo'));
    await tester.pumpAndSettle();
    for (int number = 1; number <= 3; number++) {
      expect(isSelected(tester, number), isFalse);
    }
    expect(find.text('Acciones'), findsNothing);
  });

  testWidgets('copia varios versículos en orden y mantiene la selección', (
    tester,
  ) async {
    await setup(tester);
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(verse(3));
    await tester.pumpAndSettle();
    await tester.tap(verse(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copiar'));
    await tester.pumpAndSettle();
    expect(
      copiedText,
      '1 Versículo de prueba con amor y esperanza para la interfaz.\n'
      '3 La navegación entre capítulos funciona sin conexión.\n\n— Génesis 1:1, 3 (DEMO)',
    );
    expect(isSelected(tester, 1), isTrue);
    expect(isSelected(tester, 3), isTrue);
  });

  testWidgets('guarda una selección mixta sin quitar favoritos existentes', (
    tester,
  ) async {
    final AppHarness harness = await setup(tester);
    const BibleReference first = BibleReference(
      bookId: 'GEN',
      chapter: 1,
      verse: 1,
    );
    await harness.favorites.toggle(
      reference: first,
      text: harness.reading.currentChapter!.verse(1)!.text,
    );
    await tester.pumpAndSettle();
    await tester.tap(verse(1));
    await tester.pumpAndSettle();
    await tester.tap(verse(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(harness.favorites.count, 2);
    expect(harness.favorites.isFavorite(first), isTrue);
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    expect(harness.favorites.count, 0);
  });

  testWidgets('deslizar sin mantener pulsado desplaza sin seleccionar', (
    tester,
  ) async {
    await setup(tester, longChapter: true);
    await tester.ensureVisible(verse(1));
    await tester.pumpAndSettle();
    final double before = tester.getTopLeft(verse(1)).dy;
    await tester.drag(verse(1), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(verse(1)).dy, lessThan(before));
    expect(find.text('Acciones'), findsNothing);
  });

  testWidgets('arrastrar al borde desplaza y amplía la selección', (
    tester,
  ) async {
    await setup(tester, longChapter: true);
    await tester.ensureVisible(verse(1));
    await tester.pumpAndSettle();
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(verse(1)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    final Rect viewport = tester.getRect(
      find.byType(SingleChildScrollView).first,
    );
    await gesture.moveTo(Offset(viewport.center.dx, viewport.bottom - 10));
    await tester.pump();
    final double before = tester.getTopLeft(verse(1)).dy;
    for (int tick = 0; tick < 25; tick++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(tester.getTopLeft(verse(1)).dy, lessThan(before));
    expect(isSelected(tester, 10), isTrue);
    await gesture.up();
    await tester.pumpAndSettle();
    final double after = tester.getTopLeft(verse(1)).dy;
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(verse(1)).dy, after);
  });

  testWidgets('cambiar de capítulo limpia la selección', (tester) async {
    final AppHarness harness = await setup(tester);
    await tester.tap(verse(1));
    await tester.pumpAndSettle();
    harness.reading.goToNextChapter();
    await tester.pumpAndSettle();
    expect(find.text('Acciones'), findsNothing);
    harness.reading.goToPreviousChapter();
    await tester.pumpAndSettle();
    expect(isSelected(tester, 1), isFalse);
  });

  testWidgets('tocar un versículo resaltado por búsqueda quita el resaltado', (
    tester,
  ) async {
    final AppHarness harness = await setup(tester);
    harness.reading.openReference(
      const BibleReference(bookId: 'GEN', chapter: 1, verse: 2),
    );
    await tester.pumpAndSettle();
    await tester.tap(verse(2));
    await tester.pumpAndSettle();
    expect(harness.reading.highlightedVerse, isNull);
    expect(isSelected(tester, 2), isFalse);
    expect(find.text('Acciones'), findsNothing);
  });
}
