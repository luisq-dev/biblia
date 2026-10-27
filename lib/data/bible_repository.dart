import 'package:biblia/data/models/bible_dataset.dart';

enum BibleSource { none, demo, bundled, imported }

extension BibleSourceInfo on BibleSource {
  String get label => switch (this) {
    BibleSource.none => 'Sin texto bíblico',
    BibleSource.demo => 'Demostración',
    BibleSource.bundled => 'Incluido en la aplicación',
    BibleSource.imported => 'Importado por el usuario',
  };

  bool get hasText => this != BibleSource.none;

  bool get isUserControlled => this == BibleSource.imported;
}

class BibleLoadResult {
  const BibleLoadResult({required this.source, this.dataset});

  const BibleLoadResult.empty() : source = BibleSource.none, dataset = null;

  final BibleSource source;
  final BibleDataset? dataset;
}

/// Contrato de acceso al texto bíblico local.
abstract interface class BibleRepository {
  Future<BibleLoadResult> load();

  Future<bool> hasImportedData();

  /// Valida y guarda un texto importado. Lanza [BibleDataException] si el
  /// archivo no cumple el esquema o no es un texto apto para el usuario.
  Future<BibleDataset> importJson(String json, {String? sourceName});

  Future<void> removeImported();
}
