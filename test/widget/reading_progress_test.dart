import 'package:biblia/data/bible_data_parser.dart';
import 'package:biblia/data/bible_repository.dart';
import 'package:biblia/data/models/bible_reference.dart';
import 'package:biblia/data/models/reading_progress.dart';
import 'package:biblia/data/models/user_backup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_support.dart';
import '../state/backup_progress_test.dart' show backupService, firstChapter;

BibleLoadResult longChapter() {
  final data = testBibleMap();
  final book = (data['books'] as List).first as Map<String, Object?>;
  final chapter = (book['chapters'] as List).first as Map<String, Object?>;
  chapter['verses'] = List.generate(
    40,
    (index) =>
        'Texto del versículo ${index + 1} con varias palabras para verificar que se restaura la posición exacta al volver a abrir la aplicación.',
  );
  return BibleLoadResult(
    source: BibleSource.demo,
    dataset: BibleDataParser.parseMap(data),
  );
}

double scrollOffset(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

void main() {
  testWidgets(
    'marca capítulos desde lectura y permite desmarcarlos en ajustes',
    (tester) async {
      final harness = await pumpBibleApp(tester);
      await tester.tap(find.byTooltip('Marcar capítulo como leído'));
      await tester.pumpAndSettle();
      expect(harness.history.isCompleted(firstChapter), isTrue);
      expect(find.byTooltip('Marcar como no leído'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Capítulos leídos'), 350);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Capítulos leídos'));
      await tester.pumpAndSettle();
      expect(find.text('Génesis 1'), findsOneWidget);
      await tester.tap(find.byTooltip('Marcar como no leído'));
      await tester.pumpAndSettle();
      expect(harness.history.completedChapters, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await disposeHarness(harness);
    },
  );

  testWidgets('el botón al final del capítulo alterna el estado leído', (
    tester,
  ) async {
    final harness = await pumpBibleApp(tester);
    final button = find.byKey(const ValueKey<String>('toggle-chapter-read'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Capítulo leído'), findsOneWidget);
    expect(harness.history.isCompleted(firstChapter), isTrue);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(harness.history.isCompleted(firstChapter), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await disposeHarness(harness);
  });

  testWidgets(
    'reabrir conserva el versículo y el desplazamiento exacto sin animación',
    (tester) async {
      final result = longChapter();
      var harness = await pumpBibleApp(tester, result: result);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -950),
      );
      await tester.pumpAndSettle();
      final before = scrollOffset(tester);
      expect(before, greaterThan(500));
      final saved = harness.history.position!;
      expect(saved.reference.verse, greaterThan(1));
      final preferences = <String, Object>{
        for (final key in harness.preferences.getKeys())
          key: harness.preferences.get(key)!,
      };
      await tester.pumpWidget(const SizedBox.shrink());
      await disposeHarness(harness);
      harness = await pumpBibleApp(
        tester,
        result: result,
        initialPreferences: preferences,
      );
      expect(scrollOffset(tester), closeTo(before, 0.5));
      expect(harness.history.position!.reference, saved.reference);
      expect(harness.history.position!.offset, closeTo(saved.offset, 0.5));
      expect(harness.reading.highlightedVerse, isNull);
      expect(harness.history.completedChapters, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await disposeHarness(harness);
    },
  );

  testWidgets(
    'importar una posición en el mismo capítulo también la restaura',
    (tester) async {
      final harness = await pumpBibleApp(tester, result: longChapter());
      final service = backupService(harness);
      final snapshot = service.snapshot();
      final backup = UserBackup(
        settings: snapshot.settings,
        favorites: snapshot.favorites,
        history: snapshot.history,
        progress: ReadingProgress(
          position: const ReadingPosition(
            reference: BibleReference(bookId: 'GEN', chapter: 1, verse: 12),
            offset: 13.5,
          ),
        ),
      );
      await service.restore(backup);
      await tester.pumpAndSettle();
      expect(scrollOffset(tester), greaterThan(500));
      expect(harness.history.position!.reference.verse, 12);
      expect(harness.history.position!.offset, closeTo(13.5, 0.5));
      await tester.pumpWidget(const SizedBox.shrink());
      await disposeHarness(harness);
    },
  );
}
