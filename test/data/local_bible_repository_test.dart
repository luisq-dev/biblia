import 'dart:io';

import 'package:biblia/data/bible_data_parser.dart';
import 'package:biblia/data/bible_repository.dart';
import 'package:biblia/data/local_bible_repository.dart';
import 'package:biblia/data/models/bible_dataset.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_support.dart';

void main() {
  late Directory directory;

  LocalBibleRepository repositoryWith({
    Map<String, String> assets = const <String, String>{},
    bool allowDemo = false,
  }) {
    return LocalBibleRepository(
      bundle: MemoryAssetBundle(assets),
      supportDirectory: () async => directory,
      allowDemo: allowDemo,
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('biblia_repository_');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  group('LocalBibleRepository', () {
    test('devuelve el estado vacío cuando no hay ninguna fuente', () async {
      final LocalBibleRepository repository = repositoryWith();
      final BibleLoadResult result = await repository.load();

      expect(result.source, BibleSource.none);
      expect(result.dataset, isNull);
      expect(await repository.hasImportedData(), isFalse);
    });

    test(
      'carga el texto incluido en la aplicación antes que la demo',
      () async {
        final LocalBibleRepository repository = repositoryWith(
          allowDemo: true,
          assets: <String, String>{
            'assets/bible/rvr1960.json': testBibleJson(isDemo: false),
            'assets/bible/demo_bible.json': testBibleJson(),
          },
        );

        final BibleLoadResult result = await repository.load();
        expect(result.source, BibleSource.bundled);
        expect(result.dataset?.translation.isDemo, isFalse);
      },
    );

    test('usa la demo solo cuando está permitida', () async {
      final Map<String, String> assets = <String, String>{
        'assets/bible/demo_bible.json': testBibleJson(),
      };

      final BibleLoadResult disabled = await repositoryWith(assets: assets)
          .load();
      final BibleLoadResult enabled = await repositoryWith(
        assets: assets,
        allowDemo: true,
      ).load();

      expect(disabled.source, BibleSource.none);
      expect(enabled.source, BibleSource.demo);
      expect(enabled.dataset?.translation.isDemo, isTrue);
    });

    test('importa, persiste y da prioridad al texto del usuario', () async {
      final LocalBibleRepository repository = repositoryWith(
        assets: <String, String>{
          'assets/bible/rvr1960.json': testBibleJson(isDemo: false),
        },
      );

      final BibleDataset imported = await repository.importJson(
        testBibleJson(isDemo: false),
        sourceName: 'prueba.json',
      );

      expect(imported.translation.bookCount, 3);
      expect(await repository.hasImportedData(), isTrue);
      expect(
        File('${directory.path}/imported_bible.json').existsSync(),
        isTrue,
      );
      expect(
        File('${directory.path}/imported_bible.json.tmp').existsSync(),
        isFalse,
      );

      final BibleLoadResult result = await repository.load();
      expect(result.source, BibleSource.imported);
      expect(result.dataset?.translation.id, 'test-text');
    });

    test('elimina la importación y vuelve a la fuente incluida', () async {
      final LocalBibleRepository repository = repositoryWith(
        assets: <String, String>{
          'assets/bible/rvr1960.json': testBibleJson(isDemo: false),
        },
      );

      await repository.importJson(testBibleJson(isDemo: false));
      await repository.removeImported();

      expect(await repository.hasImportedData(), isFalse);
      final BibleLoadResult result = await repository.load();
      expect(result.source, BibleSource.bundled);
    });

    test('rechaza importar una demostración', () async {
      final LocalBibleRepository repository = repositoryWith();

      expect(
        () => repository.importJson(testBibleJson()),
        throwsA(
          isA<BibleDataException>().having(
            (BibleDataException error) => error.message,
            'mensaje',
            contains('No se puede importar una muestra'),
          ),
        ),
      );
      expect(await repository.hasImportedData(), isFalse);
    });

    test('rechaza una importación con JSON inválido', () async {
      final LocalBibleRepository repository = repositoryWith();
      expect(
        () => repository.importJson('{'),
        throwsA(isA<BibleDataException>()),
      );
    });

    test('informa de un archivo importado corrupto sin ocultarlo', () async {
      final LocalBibleRepository repository = repositoryWith();
      await File('${directory.path}/imported_bible.json')
          .writeAsString('{"schemaVersion": 1}');

      expect(
        () => repository.load(),
        throwsA(
          isA<BibleDataException>().having(
            (BibleDataException error) => error.message,
            'mensaje',
            contains('texto bíblico importado no es válido'),
          ),
        ),
      );
    });
  });
}
