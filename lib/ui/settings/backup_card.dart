import 'package:biblia/data/models/user_backup.dart';
import 'package:biblia/services/backup_files.dart';
import 'package:biblia/services/backup_service.dart';
import 'package:biblia/state/favorites_controller.dart';
import 'package:biblia/state/history_controller.dart';
import 'package:biblia/state/reading_controller.dart';
import 'package:biblia/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class BackupCard extends StatefulWidget {
  const BackupCard({super.key});
  @override
  State<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<BackupCard> {
  bool _busy = false;
  bool _confirming = false;
  BackupService get _service => BackupService(
    settings: context.read<SettingsController>(),
    favorites: context.read<FavoritesController>(),
    history: context.read<HistoryController>(),
    reading: context.read<ReadingController>(),
  );

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } on FormatException catch (error) {
      _message(error.message);
    } on PlatformException catch (error) {
      _message(error.message ?? 'No se pudo acceder al archivo.');
    } on Object {
      _message('No se pudo completar el respaldo. Vuelve a intentarlo.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _export() => _run(() async {
    final saved = await const BackupFiles().save(_service.snapshot().encode());
    if (saved) _message('Respaldo JSON exportado');
  });

  Future<void> _import() => _run(() async {
    final source = await const BackupFiles().open();
    if (source == null || !mounted) return;
    // Validar todo antes de mostrar la confirmación o cambiar datos locales.
    final backup = UserBackup.decode(source);
    final service = _service;
    setState(() => _confirming = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Restaurar este respaldo?'),
        content: Text(
          '${backup.favorites.length} favoritos · ${backup.progress.completed.length} capítulos leídos.\n\n'
          'Se reemplazarán tus favoritos, capítulos leídos, historial, posición de lectura y ajustes actuales por los del respaldo.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed != true) return;
    await service.restore(backup);
    _message('Respaldo restaurado');
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Guarda o recupera favoritos, capítulos leídos, historial, posición de lectura y ajustes en un archivo JSON.',
            ),
          ),
          if (_busy && !_confirming) const LinearProgressIndicator(),
          ListTile(
            leading: Icon(Icons.file_download_outlined, color: scheme.primary),
            title: const Text('Exportar respaldo JSON'),
            subtitle: const Text('Elige dónde guardar tus datos'),
            enabled: !_busy,
            onTap: _export,
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          ListTile(
            leading: Icon(Icons.file_upload_outlined, color: scheme.primary),
            title: const Text('Importar respaldo JSON'),
            subtitle: const Text('Recupera un respaldo de Biblia 1960'),
            enabled: !_busy,
            onTap: _import,
          ),
        ],
      ),
    );
  }
}
