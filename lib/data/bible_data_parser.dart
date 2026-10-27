import 'dart:convert';

import 'package:biblia/core/constants/bible_catalog.dart';
import 'package:biblia/data/models/bible_book.dart';
import 'package:biblia/data/models/bible_content.dart';
import 'package:biblia/data/models/bible_dataset.dart';
import 'package:biblia/data/models/translation_info.dart';

class BibleDataException implements Exception {
  const BibleDataException(this.message, {this.details});

  final String message;
  final String? details;

  String get userMessage {
    if (details == null || details!.trim().isEmpty) return message;
    return '$message\n\n$details';
  }

  @override
  String toString() => userMessage;
}

/// Valida el esquema JSON local y construye el contenido bíblico.
abstract final class BibleDataParser {
  static const int supportedSchemaVersion = 1;

  static BibleDataset parse(String source, {String origin = 'archivo'}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw BibleDataException(
        'El archivo de $origin no contiene JSON válido.',
        details: error.message,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw BibleDataException(
        'La raíz del archivo de $origin debe ser un objeto JSON.',
      );
    }

    return parseMap(decoded, origin: origin);
  }

  static BibleDataset parseMap(
    Map<String, dynamic> json, {
    String origin = 'archivo',
  }) {
    final int schemaVersion = _requiredInt(
      json['schemaVersion'],
      'schemaVersion',
      origin,
    );
    if (schemaVersion != supportedSchemaVersion) {
      throw BibleDataException(
        'El archivo de $origin usa el esquema $schemaVersion; '
        'esta versión de la aplicación admite el esquema '
        '$supportedSchemaVersion.',
      );
    }

    final Map<String, dynamic> translationJson = _requiredMap(
      json['translation'],
      'translation',
      origin,
    );

    final String id = _requiredString(
      translationJson['id'],
      'translation.id',
      origin,
    );
    final String name = _requiredString(
      translationJson['name'],
      'translation.name',
      origin,
    );
    final String abbreviation = _requiredString(
      translationJson['abbreviation'],
      'translation.abbreviation',
      origin,
    );
    final String copyright = _requiredString(
      translationJson['copyright'],
      'translation.copyright',
      origin,
    );
    final String license = _requiredString(
      translationJson['license'],
      'translation.license',
      origin,
    );
    final String language =
        _optionalString(
          translationJson['language'],
          'translation.language',
          origin,
        ) ??
        'es';
    final bool isComplete = _requiredBool(
      translationJson['isComplete'],
      'translation.isComplete',
      origin,
    );
    final bool isDemo = translationJson['isDemo'] == null
        ? false
        : _requiredBool(
            translationJson['isDemo'],
            'translation.isDemo',
            origin,
          );

    final Object? booksValue = json['books'];
    if (booksValue is! List) {
      throw BibleDataException(
        'El campo «books» del archivo de $origin debe ser una lista.',
      );
    }
    if (booksValue.isEmpty) {
      throw BibleDataException(
        'El archivo de $origin no contiene ningún libro con texto.',
      );
    }

    final List<BibleBookContent> books = <BibleBookContent>[];
    final Set<String> seenBookIds = <String>{};

    for (int bookIndex = 0; bookIndex < booksValue.length; bookIndex++) {
      final String path = 'books[$bookIndex]';
      final Map<String, dynamic> bookJson = _requiredMap(
        booksValue[bookIndex],
        path,
        origin,
      );
      final String rawBookId = _requiredString(
        bookJson['id'],
        '$path.id',
        origin,
      ).toUpperCase();
      final BibleBook? canonical = BibleCatalog.byId(rawBookId);
      if (canonical == null) {
        throw BibleDataException(
          'El libro «$rawBookId» no pertenece al canon de 66 libros.',
          details: 'Ruta: $path.id',
        );
      }
      if (!seenBookIds.add(rawBookId)) {
        throw BibleDataException(
          'El libro ${canonical.name} aparece más de una vez en el archivo.',
        );
      }

      final Object? chaptersValue = bookJson['chapters'];
      if (chaptersValue is! List || chaptersValue.isEmpty) {
        throw BibleDataException(
          'El libro ${canonical.name} no contiene capítulos.',
        );
      }

      final List<BibleChapter> chapters = <BibleChapter>[];
      final Set<int> seenChapters = <int>{};

      for (
        int chapterIndex = 0;
        chapterIndex < chaptersValue.length;
        chapterIndex++
      ) {
        final String chapterPath = '$path.chapters[$chapterIndex]';
        final Map<String, dynamic> chapterJson = _requiredMap(
          chaptersValue[chapterIndex],
          chapterPath,
          origin,
        );
        final int number = _requiredInt(
          chapterJson['number'],
          '$chapterPath.number',
          origin,
        );
        if (number < 1 || number > canonical.chapterCount) {
          throw BibleDataException(
            'El capítulo $number de ${canonical.name} está fuera del rango '
            'válido (1–${canonical.chapterCount}).',
          );
        }
        if (!seenChapters.add(number)) {
          throw BibleDataException(
            'El capítulo $number de ${canonical.name} aparece más de una vez.',
          );
        }

        final Object? versesValue = chapterJson['verses'];
        if (versesValue is! List || versesValue.isEmpty) {
          throw BibleDataException(
            'El capítulo $number de ${canonical.name} no contiene versículos.',
          );
        }

        final List<Verse> verses = <Verse>[];
        for (
          int verseIndex = 0;
          verseIndex < versesValue.length;
          verseIndex++
        ) {
          final Object? rawText = versesValue[verseIndex];
          if (rawText is! String) {
            throw BibleDataException(
              'El versículo ${verseIndex + 1} del capítulo $number de '
              '${canonical.name} debe ser texto.',
            );
          }
          final String text = rawText.trim();
          if (text.isEmpty) {
            throw BibleDataException(
              'El versículo ${verseIndex + 1} del capítulo $number de '
              '${canonical.name} está vacío.',
            );
          }
          verses.add(Verse(number: verseIndex + 1, text: text));
        }

        chapters.add(
          BibleChapter(bookId: canonical.id, number: number, verses: verses),
        );
      }

      chapters.sort(
        (BibleChapter a, BibleChapter b) => a.number.compareTo(b.number),
      );

      books.add(BibleBookContent(bookId: canonical.id, chapters: chapters));
    }

    if (isComplete) {
      _validateComplete(books, origin);
    }

    books.sort(
      (BibleBookContent a, BibleBookContent b) =>
          BibleCatalog.indexOf(a.bookId) - BibleCatalog.indexOf(b.bookId),
    );

    final int chapterCount = books.fold<int>(
      0,
      (int total, BibleBookContent book) => total + book.chapterCount,
    );
    final int verseCount = books.fold<int>(
      0,
      (int total, BibleBookContent book) => total + book.verseCount,
    );

    return BibleDataset(
      translation: TranslationInfo(
        id: id,
        name: name,
        abbreviation: abbreviation,
        language: language,
        copyright: copyright,
        license: license,
        isComplete: isComplete,
        isDemo: isDemo,
        bookCount: books.length,
        chapterCount: chapterCount,
        verseCount: verseCount,
      ),
      books: books,
    );
  }

  static void _validateComplete(List<BibleBookContent> books, String origin) {
    if (books.length != BibleCatalog.books.length) {
      throw BibleDataException(
        'El archivo de $origin se marca como completo, pero contiene '
        '${books.length} de ${BibleCatalog.books.length} libros.',
      );
    }

    final Map<String, BibleBookContent> byId = <String, BibleBookContent>{
      for (final BibleBookContent book in books) book.bookId: book,
    };

    for (final BibleBook canonical in BibleCatalog.books) {
      final BibleBookContent? content = byId[canonical.id];
      if (content == null) {
        throw BibleDataException(
          'Falta el libro ${canonical.name} en un archivo marcado como completo.',
        );
      }
      if (content.chapterCount != canonical.chapterCount) {
        throw BibleDataException(
          '${canonical.name} debe tener ${canonical.chapterCount} capítulos '
          'y el archivo contiene ${content.chapterCount}.',
        );
      }
      for (int number = 1; number <= canonical.chapterCount; number++) {
        if (!content.hasChapter(number)) {
          throw BibleDataException(
            'Falta el capítulo $number de ${canonical.name} en un archivo '
            'marcado como completo.',
          );
        }
      }
    }
  }

  static String _requiredString(Object? value, String path, String origin) {
    if (value is! String || value.trim().isEmpty) {
      throw BibleDataException(
        'El campo «$path» es obligatorio en el archivo de $origin.',
      );
    }
    return value.trim();
  }

  static String? _optionalString(Object? value, String path, String origin) {
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw BibleDataException(
        'El campo «$path» debe ser texto no vacío en el archivo de $origin.',
      );
    }
    return value.trim();
  }

  static int _requiredInt(Object? value, String path, String origin) {
    if (value is! int) {
      throw BibleDataException(
        'El campo «$path» debe ser un número entero en el archivo de $origin.',
      );
    }
    return value;
  }

  static bool _requiredBool(Object? value, String path, String origin) {
    if (value is! bool) {
      throw BibleDataException(
        'El campo «$path» debe ser verdadero o falso en el archivo de $origin.',
      );
    }
    return value;
  }

  static Map<String, dynamic> _requiredMap(
    Object? value,
    String path,
    String origin,
  ) {
    if (value is! Map) {
      throw BibleDataException(
        'El campo «$path» debe ser un objeto en el archivo de $origin.',
      );
    }
    return Map<String, dynamic>.from(value);
  }
}
