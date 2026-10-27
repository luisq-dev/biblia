import 'dart:async';

import 'package:biblia/core/constants/bible_catalog.dart';
import 'package:biblia/data/history_repository.dart';
import 'package:biblia/data/models/reading_progress.dart';
import 'package:biblia/data/models/bible_reference.dart';
import 'package:flutter/foundation.dart';

class HistoryController extends ChangeNotifier {
  HistoryController(this._repository)
    : _progress = _repository.loadProgress(),
      _recentChapters = _repository
          .load()
          .map((BibleReference reference) => reference.chapterReference())
          .toList();

  final HistoryRepository _repository;
  final List<BibleReference> _recentChapters;
  ReadingProgress _progress;

  ReadingProgress get progress => _progress;
  ReadingPosition? get position => _progress.position;
  bool isCompleted(BibleReference reference) =>
      _progress.completed.contains(reference.chapterReference());

  List<BibleReference> get completedChapters =>
      _progress.completed.toList()..sort((a, b) {
        final book = BibleCatalog.indexOf(a.bookId)
            .compareTo(BibleCatalog.indexOf(b.bookId));
        return book == 0 ? a.chapter.compareTo(b.chapter) : book;
      });

  Future<void> toggleCompleted(BibleReference reference) async {
    final completed = Set<BibleReference>.of(_progress.completed);
    final chapter = reference.chapterReference();
    if (!completed.remove(chapter)) completed.add(chapter);
    _progress = ReadingProgress(completed: completed, position: position);
    notifyListeners();
    await _repository.saveProgress(_progress);
  }

  Future<void> savePosition(ReadingPosition position) async {
    final previous = this.position;
    if (previous?.reference == position.reference &&
        (previous!.offset - position.offset).abs() < 0.5) {
      return;
    }
    _progress = ReadingProgress(
      completed: _progress.completed,
      position: position,
    );
    await _repository.saveProgress(_progress);
  }

  Future<void> restore({
    required List<BibleReference> recent,
    required ReadingProgress progress,
  }) async {
    await _repository.save(recent);
    await _repository.saveProgress(progress);
    _recentChapters
      ..clear()
      ..addAll(recent.take(HistoryRepository.maxEntries));
    _progress = progress;
    notifyListeners();
  }

  List<BibleReference> get recentChapters =>
      List<BibleReference>.unmodifiable(_recentChapters);

  BibleReference? get lastChapter =>
      _recentChapters.isEmpty ? null : _recentChapters.first;

  void record(BibleReference reference) {
    final BibleReference chapter = reference.chapterReference();
    final int previousIndex = _recentChapters.indexWhere(
      (BibleReference item) => item == chapter,
    );
    if (previousIndex == 0) return;
    if (previousIndex > 0) {
      _recentChapters.removeAt(previousIndex);
    }
    _recentChapters.insert(0, chapter);
    if (_recentChapters.length > HistoryRepository.maxEntries) {
      _recentChapters.removeRange(
        HistoryRepository.maxEntries,
        _recentChapters.length,
      );
    }
    notifyListeners();
    unawaited(_repository.save(_recentChapters));
  }

  Future<void> clear() async {
    if (_recentChapters.isEmpty && position == null) return;
    _recentChapters.clear();
    _progress = ReadingProgress(completed: _progress.completed);
    await _repository.saveProgress(_progress);
    notifyListeners();
    await _repository.save(_recentChapters);
  }
}
