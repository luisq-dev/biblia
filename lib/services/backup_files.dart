import 'package:flutter/services.dart';

/// Usa el selector de documentos de Android, sin permisos de almacenamiento.
class BackupFiles {
  const BackupFiles();
  static const MethodChannel channel = MethodChannel('biblia1960/backups');

  Future<bool> save(String json) async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    return await channel.invokeMethod<bool>('exportJson', {
          'name': 'biblia-1960-respaldo-$date.json',
          'contents': json,
        }) ??
        false;
  }

  Future<String?> open() => channel.invokeMethod<String>('importJson');
}
