import 'package:biblia/main.dart' as entrypoint;
import 'package:biblia/state/bible_library.dart';
import 'package:biblia/state/bible_search_controller.dart';
import 'package:biblia/state/favorites_controller.dart';
import 'package:biblia/state/history_controller.dart';
import 'package:biblia/state/reading_controller.dart';
import 'package:biblia/state/settings_controller.dart';
import 'package:biblia/ui/home/home_shell.dart';
import 'package:biblia/ui/search/search_screen.dart';
import 'package:biblia/ui/favorites/favorites_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'el inicio muestra la lectura sin animación ni cargar otras pestañas',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      // runApp dibuja un warm-up frame: establece primero el reloj de esta prueba.
      await tester.pumpWidget(const SizedBox.shrink());
      entrypoint.main();
      await tester.pump();
      expect(find.textContaining('Cargando'), findsNothing);
      for (
        var attempt = 0;
        attempt < 100 && find.byType(HomeShell).evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(find.byType(HomeShell), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Omitir'), findsNothing);
      final context = tester.element(find.byType(HomeShell));
      final library = context.read<BibleLibrary>();
      expect(library.isReady, isTrue);
      expect(library.dataset!.availableVerseCount, greaterThan(30000));
      expect(library.isSearchPrepared, isFalse);
      expect(find.text('Génesis 1'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Preparando'), findsNothing);
      expect(find.byType(SearchScreen, skipOffstage: false), findsNothing);
      expect(find.byType(FavoritesScreen, skipOffstage: false), findsNothing);

      await tester.runAsync(() async {
        final engine = await library.prepareSearch();
        expect(engine!.verseCount, library.dataset!.availableVerseCount);
        expect(engine.search('principio').results, isNotEmpty);
      });
      expect(library.isSearchPrepared, isTrue);

      final controllers = <ChangeNotifier>[
        context.read<ReadingController>(),
        context.read<BibleSearchController>(),
        context.read<SettingsController>(),
        context.read<FavoritesController>(),
        context.read<HistoryController>(),
        library,
      ];
      await tester.pumpWidget(const SizedBox.shrink());
      for (final controller in controllers) {
        controller.dispose();
      }
    },
  );
}
