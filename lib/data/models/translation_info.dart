import 'package:flutter/foundation.dart';

@immutable
class TranslationInfo {
  const TranslationInfo({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.language,
    required this.copyright,
    required this.license,
    required this.isComplete,
    required this.isDemo,
    required this.bookCount,
    required this.chapterCount,
    required this.verseCount,
  });

  final String id;
  final String name;
  final String abbreviation;
  final String language;
  final String copyright;
  final String license;
  final bool isComplete;
  final bool isDemo;
  final int bookCount;
  final int chapterCount;
  final int verseCount;

  String get displayName => name;
}
