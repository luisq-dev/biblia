import 'package:biblia/data/models/user_backup.dart';
import 'package:biblia/state/favorites_controller.dart';
import 'package:biblia/state/history_controller.dart';
import 'package:biblia/state/reading_controller.dart';
import 'package:biblia/state/settings_controller.dart';

class BackupService {
  const BackupService({
    required this.settings,
    required this.favorites,
    required this.history,
    required this.reading,
  });
  final SettingsController settings;
  final FavoritesController favorites;
  final HistoryController history;
  final ReadingController reading;

  UserBackup snapshot() => UserBackup(
    settings: BackupSettings(
      themeMode: settings.themeMode,
      palette: settings.colorPalette,
      font: settings.readingFont,
      fontSize: settings.readingFontSize,
    ),
    favorites: favorites.favorites,
    history: history.recentChapters,
    progress: history.progress,
  );

  Future<void> restore(UserBackup backup) async {
    final previous = snapshot();
    try {
      await _apply(backup);
    } on Object {
      await _apply(previous);
      rethrow;
    }
    reading.restoreSavedPosition();
  }

  Future<void> _apply(UserBackup backup) async {
    await favorites.restore(backup.favorites);
    await settings.setThemeMode(backup.settings.themeMode);
    await settings.setColorPalette(backup.settings.palette);
    await settings.setReadingFont(backup.settings.font);
    await settings.setReadingFontSize(backup.settings.fontSize);
    await history.restore(recent: backup.history, progress: backup.progress);
  }
}
