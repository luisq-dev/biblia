import 'dart:convert';
import 'dart:io';

import 'package:biblia/data/bible_data_parser.dart';
import 'package:biblia/data/bible_repository.dart';
import 'package:biblia/data/models/bible_dataset.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Repositorio local basado en JSON.
///
/// Prioridad de carga:
/// 1. Texto autorizado importado por el usuario.
/// 2. Texto autorizado incluido por el desarrollador (`assets/bible/rvr1960.json`).
/// 3. Muestra de desarrollo (solo en debug o con `--dart-define=BIBLE_DEMO=true`).
/// 4. Estado vacío.
class LocalBibleRepository implements BibleRepository {
  LocalBibleRepository({
    AssetBundle? bundle,
    Future<Directory> Function()? supportDirectory,
    bool? allowDemo,
    this.bundledAsset = 'assets/bible/rvr1960.json',
    this.demoAsset = 'assets/bible/demo_bible.json',
  }) : _bundle = bundle ?? rootBundle,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       allowDemo = allowDemo ?? _demoEnabledByDefault;

  static const bool _demoEnabledByDefault =
      kDebugMode || bool.fromEnvironment('BIBLE_DEMO');

  static const String importedFileName = 'imported_bible.json';
  static const int maxImportBytes = 32 * 1024 * 1024;

  final AssetBundle _bundle;
  final Future<Directory> Function() _supportDirectory;
  late final Future<Directory> _directory = _supportDirectory();
  final String bundledAsset;
  final String demoAsset;
  final bool allowDemo;

  @override
  Future<BibleLoadResult> load() async {
    if (await hasImportedData()) {
      final File file = await _importedFile();
      final String text;
      try {
        text = await file.readAsString();
      } on FileSystemException catch (error) {
        throw BibleDataException(
          'No se pudo leer el texto bíblico importado.',
          details: error.message,
        );
      }
      final BibleDataset dataset;
      try {
        dataset = await _parse(text, origin: 'texto importado');
      } on BibleDataException catch (error) {
        throw BibleDataException(
          'El texto bíblico importado no es válido. Elimina la importación '
          'desde Ajustes o vuelve a importar un archivo correcto.',
          details: error.userMessage,
        );
      }
      return BibleLoadResult(source: BibleSource.imported, dataset: dataset);
    }

    final BibleDataset? bundled = await _tryLoadAsset(
      bundledAsset,
      origin: 'texto incluido en la aplicación',
    );
    if (bundled != null) {
      return BibleLoadResult(source: BibleSource.bundled, dataset: bundled);
    }

    if (allowDemo) {
      final BibleDataset? demo = await _tryLoadAsset(
        demoAsset,
        origin: 'muestra de demostración',
      );
      if (demo != null) {
        return BibleLoadResult(source: BibleSource.demo, dataset: demo);
      }
    }

    return const BibleLoadResult.empty();
  }

  @override
  Future<bool> hasImportedData() async {
    try {
      return await (await _importedFile()).exists();
    } on Exception {
      return false;
    }
  }

  @override
  Future<BibleDataset> importJson(String json, {String? sourceName}) async {
    final int size = utf8.encode(json).length;
    if (size > maxImportBytes) {
      throw BibleDataException(
        'El archivo supera el límite de 32 MB permitido para importar.',
      );
    }

    final BibleDataset dataset = await _parse(
      json,
      origin: sourceName ?? 'archivo seleccionado',
    );

    if (dataset.translation.isDemo) {
      throw const BibleDataException(
        'No se puede importar una muestra de demostración como texto bíblico. '
        'Selecciona un archivo autorizado.',
      );
    }

    final Directory directory = await _directory;
    await directory.create(recursive: true);
    final File file = await _importedFile();
    final File temporary = File('${file.path}.tmp');
    await temporary.writeAsString(json, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await temporary.rename(file.path);
    return dataset;
  }

  @override
  Future<void> removeImported() async {
    final File file = await _importedFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _importedFile() async {
    final Directory directory = await _directory;
    return File('${directory.path}/$importedFileName');
  }

  Future<BibleDataset> _parse(String source, {required String origin}) {
    if (source.length < 64 * 1024) {
      return Future.value(BibleDataParser.parse(source, origin: origin));
    }
    return compute(_parseInBackground, (
      source,
      origin,
    ), debugLabel: 'bible-json');
  }

  static BibleDataset _parseInBackground((String, String) input) =>
      BibleDataParser.parse(input.$1, origin: input.$2);

  static BibleDataset _decodeAndParse((Uint8List, String) input) =>
      BibleDataParser.parse(utf8.decode(input.$1), origin: input.$2);

  Future<BibleDataset?> _tryLoadAsset(
    String asset, {
    required String origin,
  }) async {
    final ByteData bytes;
    try {
      bytes = await _bundle.load(asset);
    } on FlutterError {
      return null;
    }
    final Uint8List data = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    if (data.length < 64 * 1024) {
      return _parse(utf8.decode(data), origin: origin);
    }
    return compute(_decodeAndParse, (data, origin), debugLabel: 'bible-asset');
  }
}
