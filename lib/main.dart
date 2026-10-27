import 'dart:async';

import 'package:biblia/app.dart';
import 'package:biblia/data/favorites_repository.dart';
import 'package:biblia/data/history_repository.dart';
import 'package:biblia/data/local_bible_repository.dart';
import 'package:biblia/data/preferences_repository.dart';
import 'package:biblia/state/bible_library.dart';
import 'package:biblia/state/bible_search_controller.dart';
import 'package:biblia/state/favorites_controller.dart';
import 'package:biblia/state/history_controller.dart';
import 'package:biblia/state/reading_controller.dart';
import 'package:biblia/state/settings_controller.dart';
import 'package:biblia/ui/startup/app_startup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const <String>[
      'Literata',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    yield LicenseEntryWithLineBreaks(const <String>[
      'Liberation Sans',
      'Liberation Serif',
    ], await rootBundle.loadString('assets/fonts/Liberation-LICENSE.txt'));
  });
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));

  runApp(const AppStartup(loadApplication: _prepareApplication));
}

Future<Widget> _prepareApplication() async {
  final Future<SharedPreferences> preferencesReady =
      SharedPreferences.getInstance();
  final BibleLibrary library = BibleLibrary(LocalBibleRepository());
  final Future<void> libraryReady = library.load();
  final SharedPreferences preferences = await preferencesReady;

  final SettingsController settings = SettingsController(
    PreferencesRepository(preferences),
  );
  final FavoritesController favorites = FavoritesController(
    FavoritesRepository(preferences),
  );
  final HistoryController history = HistoryController(
    HistoryRepository(preferences),
  );
  await libraryReady;
  final ReadingController reading = ReadingController(library, history);
  final BibleSearchController search = BibleSearchController(library);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsController>.value(value: settings),
      ChangeNotifierProvider<FavoritesController>.value(value: favorites),
      ChangeNotifierProvider<HistoryController>.value(value: history),
      ChangeNotifierProvider<BibleLibrary>.value(value: library),
      ChangeNotifierProvider<ReadingController>.value(value: reading),
      ChangeNotifierProvider<BibleSearchController>.value(value: search),
    ],
    child: const BibliaApp(),
  );
}
