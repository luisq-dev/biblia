import 'package:biblia/core/constants/bible_catalog.dart';
import 'package:biblia/data/models/bible_book.dart';
import 'package:biblia/data/models/bible_content.dart';
import 'package:biblia/data/models/bible_dataset.dart';
import 'package:biblia/data/models/bible_reference.dart';
import 'package:biblia/state/bible_library.dart';
import 'package:biblia/data/models/reading_progress.dart';
import 'package:biblia/state/history_controller.dart';
import 'package:flutter/foundation.dart';

class ReadingController extends ChangeNotifier {
  ReadingController(this._library, this._history) {
    _library.addListener(_handleLibraryChange);
    _syncFromLibrary();
  }

  final BibleLibrary _library;
  final HistoryController _history;

  BibleReference? _reference;
  int? _highlightedVerse;
  ReadingPosition? _resumePosition;
  int _navigationRevision = 0;

  ReadingPosition? get resumePosition => _resumePosition;
  int get navigationRevision => _navigationRevision;

  BibleReference? get reference => _reference;

  int? get highlightedVerse => _highlightedVerse;

  BibleDataset? get dataset => _library.dataset;

  BibleBook? get currentBook {
    final BibleReference? current = _reference;
    if (current == null) return null;
    return BibleCatalog.byId(current.bookId);
  }

  BibleChapter? get currentChapter {
    final BibleReference? current = _reference;
    final BibleDataset? data = _library.dataset;
    if (current == null || data == null) return null;
    return data.chapter(current.bookId, current.chapter);
  }

  bool get isReady => _library.isReady && _reference != null;

  BibleReference? get nextReference {
    final BibleReference? current = _reference;
    final BibleDataset? data = _library.dataset;
    if (current == null || data == null) return null;
    return data.nextChapter(current);
  }

  BibleReference? get previousReference {
    final BibleReference? current = _reference;
    final BibleDataset? data = _library.dataset;
    if (current == null || data == null) return null;
    return data.previousChapter(current);
  }

  bool get canGoNext => nextReference != null;

  bool get canGoPrevious => previousReference != null;

  bool openReference(BibleReference reference, {int? highlightVerse}) {
    final BibleDataset? data = _library.dataset;
    if (data == null || !data.contains(reference)) return false;

    final BibleReference chapterReference = reference.chapterReference();
    final int? verse = highlightVerse ?? reference.verse;
    final bool verseExists =
        verse != null &&
        data.chapter(reference.bookId, reference.chapter)?.verse(verse) != null;

    _resumePosition = null;
    _navigationRevision++;
    _reference = chapterReference;
    _highlightedVerse = verseExists ? verse : null;
    _history.record(chapterReference);
    notifyListeners();
    return true;
  }

  bool goToNextChapter() {
    final BibleReference? next = nextReference;
    if (next == null) return false;
    return openReference(next);
  }

  bool goToPreviousChapter() {
    final BibleReference? previous = previousReference;
    if (previous == null) return false;
    return openReference(previous);
  }

  void clearHighlight() {
    if (_highlightedVerse == null) return;
    _highlightedVerse = null;
    notifyListeners();
  }

  void _handleLibraryChange() {
    _syncFromLibrary();
  }

  void _syncFromLibrary() {
    final BibleDataset? data = _library.dataset;

    if (data == null) {
      if (_reference != null || _highlightedVerse != null) {
        _reference = null;
        _highlightedVerse = null;
        notifyListeners();
      }
      return;
    }

    final BibleReference? current = _reference;
    if (current != null && data.contains(current)) {
      // Una recarga puede actualizar el texto del mismo capítulo.
      notifyListeners();
      return;
    }

    final savedPosition = _history.position;
    _resumePosition =
        savedPosition != null && data.contains(savedPosition.reference)
        ? savedPosition
        : null;
    final BibleReference? remembered =
        _resumePosition?.reference.chapterReference() ?? _history.lastChapter;
    final BibleReference? initial =
        remembered != null && data.contains(remembered)
        ? remembered
        : data.firstChapter;

    _reference = initial;
    _highlightedVerse = null;
    if (initial != null) {
      _history.record(initial);
    }
    notifyListeners();
  }

  void restoreSavedPosition() {
    _reference = null;
    _resumePosition = null;
    _navigationRevision++;
    _syncFromLibrary();
  }

  @override
  void dispose() {
    _library.removeListener(_handleLibraryChange);
    super.dispose();
  }
}
