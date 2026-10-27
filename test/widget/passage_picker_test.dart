import 'package:biblia/data/models/bible_reference.dart';
import 'package:biblia/ui/reading/passage_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_support.dart';

void main() {
  testWidgets('PassagePickerSheet muestra tres pestañas y permite seleccionar libro, capítulo y versículo', (
    WidgetTester tester,
  ) async {
    final AppHarness harness = await pumpBibleApp(tester);

    // Abrir el selector de pasaje desde la AppBar
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();

    final Finder sheet = find.byType(PassagePickerSheet);

    // Comprobar que existen las 3 pestañas
    expect(find.descendant(of: sheet, matching: find.text('Todo')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Antiguo')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Nuevo')), findsOneWidget);

    // Cambiar a la pestaña Nuevo Testamento
    await tester.tap(find.descendant(of: sheet, matching: find.text('Nuevo')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: sheet, matching: find.text('Mateo')), findsOneWidget);

    // Cambiar a la pestaña Antiguo Testamento
    await tester.tap(find.descendant(of: sheet, matching: find.text('Antiguo')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: sheet, matching: find.text('Génesis')), findsOneWidget);

    // Tocar Génesis (Nivel 1: Libro)
    await tester.tap(find.descendant(of: sheet, matching: find.text('Génesis')));
    await tester.pumpAndSettle();

    // Ahora estamos en selección de capítulo (Nivel 2)
    expect(find.descendant(of: sheet, matching: find.text('Capítulos de Génesis')), findsOneWidget);

    // Tocar capítulo 1
    await tester.tap(find.descendant(of: sheet, matching: find.text('1')).first);
    await tester.pumpAndSettle();

    // Ahora estamos en selección de versículo (Nivel 3)
    expect(find.descendant(of: sheet, matching: find.text('O elige un versículo para ir a él:')), findsOneWidget);

    // Tocar versículo 2
    final Finder verse2 = find.descendant(of: sheet, matching: find.text('2')).first;
    await tester.tap(verse2);
    await tester.pumpAndSettle();

    // El bottom sheet se cerró y navegó a Génesis 1 versículo 2
    expect(
      harness.reading.reference,
      const BibleReference(bookId: 'GEN', chapter: 1),
    );
    expect(harness.reading.highlightedVerse, 2);

    await disposeHarness(harness);
  });
}
