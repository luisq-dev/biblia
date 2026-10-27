import 'dart:convert';

import 'package:biblia/data/history_repository.dart';
import 'package:biblia/data/models/bible_reference.dart';
import 'package:biblia/data/models/reading_progress.dart';
import 'package:biblia/data/models/user_backup.dart';
import 'package:biblia/services/backup_service.dart';
import 'package:biblia/state/history_controller.dart';
import 'package:biblia/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_support.dart';

const firstChapter = BibleReference(bookId: 'GEN', chapter: 1);
const secondChapter = BibleReference(bookId: 'GEN', chapter: 2);
const favoriteReference = BibleReference(bookId: 'GEN', chapter: 1, verse: 2);

BackupService backupService(AppHarness harness) => BackupService(
  settings: harness.settings,
  favorites: harness.favorites,
  history: harness.history,
  reading: harness.reading,
);

void main() {
  test('marcar y desmarcar capítulos persiste sin duplicarlos', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final history = HistoryController(HistoryRepository(prefs));
    await history.toggleCompleted(favoriteReference);
    await history.toggleCompleted(secondChapter);
    expect(history.completedChapters, [firstChapter, secondChapter]);
    final restored = HistoryController(HistoryRepository(prefs));
    expect(restored.isCompleted(firstChapter), isTrue);
    await restored.toggleCompleted(firstChapter);
    expect(restored.isCompleted(firstChapter), isFalse);
    expect(restored.completedChapters, [secondChapter]);
    history.dispose();
    restored.dispose();
  });

  test('borrar historial y posición conserva los capítulos leídos', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final history = HistoryController(HistoryRepository(prefs));
    history.record(firstChapter);
    await history.toggleCompleted(firstChapter);
    await history.savePosition(
      const ReadingPosition(reference: favoriteReference, offset: 24.5),
    );
    await history.clear();
    final restored = HistoryController(HistoryRepository(prefs));
    expect(restored.position, isNull);
    expect(restored.recentChapters, isEmpty);
    expect(restored.isCompleted(firstChapter), isTrue);
    history.dispose();
    restored.dispose();
  });

  testWidgets('respaldo completo restaura datos, ajustes y posición', (
    tester,
  ) async {
    final harness = await pumpBibleApp(tester);
    final service = backupService(harness);
    await harness.settings.setThemeMode(ThemeMode.dark);
    await harness.settings.setColorPalette(AppColorPalette.sageGreen);
    await harness.settings.setReadingFont(ReadingFont.modern);
    await harness.settings.setReadingFontSize(24);
    await harness.favorites.toggle(
      reference: favoriteReference,
      text: 'Favorito de prueba',
    );
    await harness.history.toggleCompleted(firstChapter);
    harness.reading.goToNextChapter();
    await tester.pumpAndSettle();
    await harness.history.savePosition(
      const ReadingPosition(reference: secondChapter, offset: 0),
    );
    final original = service.snapshot();
    final encoded = original.encode();
    final decoded = UserBackup.decode(encoded);
    expect(jsonDecode(decoded.encode()), jsonDecode(encoded));
    await harness.favorites.clear();
    await harness.history.toggleCompleted(firstChapter);
    await harness.history.clear();
    await harness.settings.setReadingFont(ReadingFont.classic);
    await harness.settings.setThemeMode(ThemeMode.light);
    await service.restore(decoded);
    await tester.pumpAndSettle();
    expect(harness.favorites.favorites.single.text, 'Favorito de prueba');
    expect(harness.history.isCompleted(firstChapter), isTrue);
    expect(harness.reading.reference, secondChapter);
    expect(harness.settings.themeMode, ThemeMode.dark);
    expect(harness.settings.readingFont, ReadingFont.modern);
    expect(harness.settings.colorPalette, AppColorPalette.sageGreen);
    expect(harness.settings.readingFontSize, 24);
    final persisted = HistoryRepository(harness.preferences).loadProgress();
    expect(persisted.completed, {firstChapter});
    expect(persisted.position?.reference.chapterReference(), secondChapter);
    await tester.pumpWidget(const SizedBox.shrink());
    await disposeHarness(harness);
  });

  testWidgets(
    'rechaza JSON inválido, versiones desconocidas y referencias incorrectas sin modificar datos',
    (tester) async {
      final harness = await pumpBibleApp(tester);
      final service = backupService(harness);
      final valid =
          jsonDecode(service.snapshot().encode()) as Map<String, dynamic>;
      for (final source in <String>[
        '{',
        '{}',
        testBibleJson(),
        jsonEncode({...valid, 'schemaVersion': 99}),
        jsonEncode({
          ...valid,
          'reading': {
            'completedChapters': [
              {'bookId': 'GEN', 'chapter': 51},
            ],
            'position': null,
          },
        }),
        jsonEncode({
          ...valid,
          'settings': {
            ...valid['settings'] as Map<String, dynamic>,
            'readingFontSize': 999,
          },
        }),
        jsonEncode({
          ...valid,
          'reading': {
            'completedChapters': [],
            'position': {'reference': firstChapter.toJson(), 'offset': 'nan'},
          },
        }),
      ]) {
        expect(() => UserBackup.decode(source), throwsFormatException);
      }
      expect(harness.favorites.count, 0);
      expect(harness.history.completedChapters, isEmpty);
      expect(harness.settings.readingFont, ReadingFont.literata);
      await tester.pumpWidget(const SizedBox.shrink());
      await disposeHarness(harness);
    },
  );
}
