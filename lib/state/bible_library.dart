import 'package:biblia/data/bible_data_parser.dart';
import 'package:biblia/data/bible_repository.dart';
import 'package:biblia/data/models/bible_dataset.dart';
import 'package:biblia/data/search/bible_search_engine.dart';
import 'package:flutter/foundation.dart';

enum BibleLibraryStatus { initial, loading, ready, empty, error }

class BibleLibrary extends ChangeNotifier {
  BibleLibrary(this._repository);

  final BibleRepository _repository;

  BibleLibraryStatus _status = BibleLibraryStatus.initial;
  BibleDataset? _dataset;
  BibleSearchEngine? _searchEngine;
  Future<BibleSearchEngine?>? _preparingSearch;
  BibleSource _source = BibleSource.none;
  String? _errorMessage;
  bool _hasImportedData = false;
  Future<void>? _loading;

  BibleLibraryStatus get status => _status;

  BibleDataset? get dataset => _dataset;

  bool get isSearchPrepared => _searchEngine != null;

  Future<BibleSearchEngine?> prepareSearch() {
    final BibleDataset? data = _dataset;
    if (data == null) return Future<BibleSearchEngine?>.value();
    if (_searchEngine != null) return Future.value(_searchEngine);
    return _preparingSearch ??= _buildSearch(data)
        .catchError((Object error, StackTrace stack) {
          if (identical(data, _dataset)) _preparingSearch = null;
          Error.throwWithStackTrace(error, stack);
        });
  }

  Future<BibleSearchEngine?> _buildSearch(BibleDataset data) async {
    // Los textos pequeños no justifican el coste de crear un isolate.
    final BibleSearchEngine engine = data.availableVerseCount < 500
        ? BibleSearchEngine(data)
        : await compute(
            BibleSearchEngine.new,
            data,
            debugLabel: 'bible-search-index',
          );
    if (!identical(data, _dataset)) return null;
    _searchEngine = engine;
    return engine;
  }

  BibleSource get source => _source;

  String? get errorMessage => _errorMessage;

  bool get hasImportedData => _hasImportedData;

  bool get isReady => _status == BibleLibraryStatus.ready;

  bool get isEmpty => _status == BibleLibraryStatus.empty;

  bool get hasData => _dataset != null;

  bool get isDemo => _dataset?.translation.isDemo ?? false;

  Future<void> load() {
    final Future<void>? inFlight = _loading;
    if (inFlight != null) return inFlight;

    final Future<void> future = _load();
    _loading = future;
    return future.whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    _status = BibleLibraryStatus.loading;
    _errorMessage = null;
    _preparingSearch = null;
    notifyListeners();

    try {
      final BibleLoadResult result = await _repository.load();
      _source = result.source;
      _dataset = result.dataset;
      _searchEngine = null;
      _preparingSearch = null;
      _status = result.dataset == null
          ? BibleLibraryStatus.empty
          : BibleLibraryStatus.ready;
    } on BibleDataException catch (error) {
      _source = BibleSource.none;
      _dataset = null;
      _searchEngine = null;
      _status = BibleLibraryStatus.error;
      _errorMessage = error.userMessage;
    } on Object catch (error) {
      _source = BibleSource.none;
      _dataset = null;
      _searchEngine = null;
      _status = BibleLibraryStatus.error;
      _errorMessage = 'No se pudo cargar el texto bíblico local.\n\n$error';
      debugPrint('Error al cargar la Biblia: $error');
    } finally {
      if (_status == BibleLibraryStatus.error) {
        await _refreshImportedFlag();
      } else {
        _hasImportedData = _source == BibleSource.imported;
      }
      notifyListeners();
    }
  }

  Future<void> _refreshImportedFlag() async {
    try {
      _hasImportedData = await _repository.hasImportedData();
    } on Object catch (error) {
      debugPrint('No se pudo comprobar la importación: $error');
      _hasImportedData = false;
    }
  }

  Future<BibleDataset> importJson(String json, {String? sourceName}) async {
    final BibleDataset dataset = await _repository.importJson(
      json,
      sourceName: sourceName,
    );
    await load();
    if (_status != BibleLibraryStatus.ready) {
      throw BibleDataException(
        _errorMessage ?? 'No se pudo activar el texto importado.',
      );
    }
    return dataset;
  }

  Future<void> removeImportedData() async {
    await _repository.removeImported();
    await load();
  }

  Future<void> reload() => load();
}
