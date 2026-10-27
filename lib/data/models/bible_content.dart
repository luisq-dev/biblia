import 'package:biblia/data/models/bible_reference.dart';
import 'package:flutter/foundation.dart';

@immutable
class Verse {
  const Verse({required this.number, required this.text});

  final int number;
  final String text;
}

@immutable
class BibleChapter {
  BibleChapter({
    required this.bookId,
    required this.number,
    required List<Verse> verses,
  }) : verses = List<Verse>.unmodifiable(verses);

  final String bookId;
  final int number;
  final List<Verse> verses;

  int get verseCount => verses.length;

  Verse? verse(int number) {
    for (final Verse verse in verses) {
      if (verse.number == number) return verse;
    }
    return null;
  }

  BibleReference reference([int? verseNumber]) =>
      BibleReference(bookId: bookId, chapter: number, verse: verseNumber);
}

@immutable
class BibleBookContent {
  BibleBookContent({required this.bookId, required List<BibleChapter> chapters})
    : chapters = List<BibleChapter>.unmodifiable(chapters) {
    _chaptersByNumber = <int, BibleChapter>{
      for (final BibleChapter chapter in this.chapters) chapter.number: chapter,
    };
  }

  final String bookId;
  final List<BibleChapter> chapters;
  late final Map<int, BibleChapter> _chaptersByNumber;

  BibleChapter? chapter(int number) => _chaptersByNumber[number];

  bool hasChapter(int number) => _chaptersByNumber.containsKey(number);

  int get chapterCount => chapters.length;

  int get verseCount => chapters.fold<int>(
    0,
    (int total, BibleChapter c) => total + c.verseCount,
  );

  List<int> get chapterNumbers =>
      chapters.map((BibleChapter chapter) => chapter.number).toList();
}
