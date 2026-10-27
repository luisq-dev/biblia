import 'package:biblia/data/models/user_backup.dart';
import 'package:biblia/services/backup_files.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_support.dart';
import '../state/backup_progress_test.dart' show backupService, firstChapter;

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('exporta un JSON completo al selector de documentos', (
    tester,
  ) async {
    final harness = await pumpBibleApp(tester);
    String? exported;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      BackupFiles.channel,
      (call) async {
        expect(call.method, 'exportJson');
        final args = call.arguments as Map<Object?, Object?>;
        expect(args['name'], endsWith('.json'));
        exported = args['contents'] as String;
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        BackupFiles.channel,
        null,
      ),
    );
    await openSettings(tester);
    await tester.scrollUntilVisible(find.text('Exportar respaldo JSON'), 350);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar respaldo JSON'));
    await tester.pumpAndSettle();
    expect(UserBackup.decode(exported!).history, isNotEmpty);
    expect(find.text('Respaldo JSON exportado'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await disposeHarness(harness);
  });

  testWidgets(
    'cancelar la confirmación no cambia nada y restaurar sí recupera los datos',
    (tester) async {
      final harness = await pumpBibleApp(tester);
      await harness.history.toggleCompleted(firstChapter);
      final encoded = backupService(harness).snapshot().encode();
      await harness.history.toggleCompleted(firstChapter);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        BackupFiles.channel,
        (call) async => encoded,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          BackupFiles.channel,
          null,
        ),
      );
      await openSettings(tester);
      await tester.scrollUntilVisible(find.text('Importar respaldo JSON'), 350);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importar respaldo JSON'));
      await tester.pumpAndSettle();
      expect(find.text('¿Restaurar este respaldo?'), findsOneWidget);
      expect(harness.history.completedChapters, isEmpty);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(harness.history.completedChapters, isEmpty);
      await tester.tap(find.text('Importar respaldo JSON'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restaurar'));
      await tester.pumpAndSettle();
      expect(harness.history.isCompleted(firstChapter), isTrue);
      expect(find.text('Respaldo restaurado'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await disposeHarness(harness);
    },
  );

  testWidgets('un archivo ajeno y cancelar el selector no alteran datos', (
    tester,
  ) async {
    final harness = await pumpBibleApp(tester);
    Object? response;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      BackupFiles.channel,
      (call) async => response,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        BackupFiles.channel,
        null,
      ),
    );
    await openSettings(tester);
    await tester.scrollUntilVisible(find.text('Importar respaldo JSON'), 350);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar respaldo JSON'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    response = '{}';
    await tester.tap(find.text('Importar respaldo JSON'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Selecciona un respaldo JSON'), findsOneWidget);
    expect(harness.history.completedChapters, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await disposeHarness(harness);
  });
}
