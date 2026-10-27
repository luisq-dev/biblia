import 'dart:async';

import 'package:biblia/data/models/bible_book.dart';
import 'package:biblia/data/models/search_result.dart';
import 'package:biblia/data/search/bible_search_engine.dart';
import 'package:biblia/state/bible_library.dart';
import 'package:flutter/foundation.dart';

enum BibleSearchStatus { idle, emptyData, searching, results, noResults, error }

class BibleSearchController extends ChangeNotifier {
  BibleSearchController(this._library) {
    _library.addListener(_handleLibraryChange);
  }

  final BibleLibrary _library;

  String _query = '';
  Testament? _testament;
  String? _bookId;
  SearchResponse _response = const SearchResponse.empty();
  BibleSearchStatus _status = BibleSearchStatus.idle;
  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  String get query => _query;

  Testament? get testament => _testament;

  String? get bookId => _bookId;

  SearchResponse get response => _response;

  List<SearchResult> get results => _response.results;

  BibleSearchStatus get status => _status;

  bool get hasData => _library.hasData;

  void updateQuery(String value) {
    if (_query == value) return;
    _query = value;
    _scheduleSearch();
  }

  void setTestament(Testament? testament) {
    if (_testament == testament) return;
    _testament = testament;
    _scheduleSearch(immediate: true);
  }

  void setBookId(String? bookId) {
    if (_bookId == bookId) return;
    _bookId = bookId;
    _scheduleSearch(immediate: true);
  }

  void searchFor(String term) {
    _query = term;
    _scheduleSearch(immediate: true);
  }

  void clear() {
    _requestId++;
    _debounce?.cancel();
    _query = '';
    _testament = null;
    _bookId = null;
    _response = const SearchResponse.empty();
    _status = BibleSearchStatus.idle;
    notifyListeners();
  }

  void _scheduleSearch({bool immediate = false}) {
    _requestId++;
    _debounce?.cancel();

    if (_query.trim().isEmpty) {
      _response = const SearchResponse.empty();
      _status = _library.hasData
          ? BibleSearchStatus.idle
          : BibleSearchStatus.emptyData;
      notifyListeners();
      return;
    }

    if (!_library.hasData) {
      _response = const SearchResponse.empty();
      _status = BibleSearchStatus.emptyData;
      notifyListeners();
      return;
    }

    _status = BibleSearchStatus.searching;
    notifyListeners();

    _debounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 280),
      _runSearch,
    );
  }

  Future<void> _runSearch() async {
    if (!_library.hasData) {
      _response = const SearchResponse.empty();
      _status = BibleSearchStatus.emptyData;
      notifyListeners();
      return;
    }

    final String query = _query.trim();
    if (query.isEmpty) {
      _response = const SearchResponse.empty();
      _status = BibleSearchStatus.idle;
      notifyListeners();
      return;
    }

    final int request = _requestId;
    final Testament? testament = _testament;
    final String? bookId = _bookId;
    final BibleSearchEngine? engine;
    try {
      engine = await _library.prepareSearch();
    } on Object catch (error) {
      if (_disposed || request != _requestId) return;
      debugPrint('No se pudo preparar la búsqueda: $error');
      _status = BibleSearchStatus.error;
      notifyListeners();
      return;
    }
    if (_disposed || request != _requestId || engine == null) return;
    final SearchResponse response = engine.search(
      query,
      testament: testament,
      bookId: bookId,
    );
    _response = response;
    _status = response.results.isEmpty
        ? BibleSearchStatus.noResults
        : BibleSearchStatus.results;
    notifyListeners();
  }

  void _handleLibraryChange() {
    if (!_library.hasData) {
      _requestId++;
      _debounce?.cancel();
      _response = const SearchResponse.empty();
      _status = BibleSearchStatus.emptyData;
      notifyListeners();
      return;
    }

    if (_library.status == BibleLibraryStatus.ready &&
        _query.trim().isNotEmpty) {
      _scheduleSearch(immediate: true);
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestId++;
    _debounce?.cancel();
    _library.removeListener(_handleLibraryChange);
    super.dispose();
  }
}
