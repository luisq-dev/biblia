import 'package:biblia/core/constants/bible_catalog.dart';
import 'package:biblia/data/models/bible_book.dart';
import 'package:biblia/data/models/bible_content.dart';
import 'package:biblia/data/models/bible_dataset.dart';
import 'package:biblia/data/models/bible_reference.dart';
import 'package:biblia/data/search/bible_search_engine.dart';
import 'package:biblia/state/bible_library.dart';
import 'package:biblia/state/history_controller.dart';
import 'package:biblia/state/reading_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<BibleReference?> showPassagePicker(
  BuildContext context, {
  required ReadingController reading,
}) {
  return showModalBottomSheet<BibleReference>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) =>
        PassagePickerSheet(current: reading.reference),
  );
}

class PassagePickerSheet extends StatefulWidget {
  const PassagePickerSheet({super.key, this.current});

  final BibleReference? current;

  @override
  State<PassagePickerSheet> createState() => _PassagePickerSheetState();
}

class _PassagePickerSheetState extends State<PassagePickerSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _bookSearch = TextEditingController();
  late final TabController _tabController;

  String? _selectedBookId;
  int? _selectedChapter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _bookSearch.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (_selectedChapter != null) {
      setState(() => _selectedChapter = null);
    } else if (_selectedBookId != null) {
      setState(() => _selectedBookId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final BibleLibrary library = context.watch<BibleLibrary>();
    final HistoryController history = context.watch<HistoryController>();
    final BibleDataset? dataset = library.dataset;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SheetHeader(
              bookId: _selectedBookId,
              chapter: _selectedChapter,
              dataset: dataset,
              onBack: (_selectedBookId != null || _selectedChapter != null)
                  ? _handleBack
                  : null,
            ),
            const Divider(height: 1),
            Expanded(
              child: dataset == null
                  ? const _NoTextMessage()
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position:
                                    Tween<Offset>(
                                      begin: const Offset(0.04, 0),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    ),
                                child: child,
                              ),
                            );
                          },
                      child: _buildCurrentView(context, dataset, history),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView(
    BuildContext context,
    BibleDataset dataset,
    HistoryController history,
  ) {
    if (_selectedBookId == null) {
      return _BooksView(
        key: const ValueKey<String>('books'),
        dataset: dataset,
        searchController: _bookSearch,
        tabController: _tabController,
        recent: history.recentChapters,
        onBookSelected: (String bookId) {
          FocusScope.of(context).unfocus();
          setState(() {
            _selectedBookId = bookId;
            _selectedChapter = null;
          });
        },
        onRecentSelected: (BibleReference reference) {
          Navigator.of(context).pop(reference);
        },
      );
    }

    if (_selectedChapter == null) {
      return _ChaptersView(
        key: ValueKey<String>('chapters-$_selectedBookId'),
        bookId: _selectedBookId!,
        dataset: dataset,
        selectedChapter: widget.current?.bookId == _selectedBookId
            ? widget.current?.chapter
            : null,
        onChapterSelected: (int chapter) {
          setState(() {
            _selectedChapter = chapter;
          });
        },
      );
    }

    return _VersesView(
      key: ValueKey<String>('verses-$_selectedBookId-$_selectedChapter'),
      bookId: _selectedBookId!,
      chapterNumber: _selectedChapter!,
      dataset: dataset,
      selectedVerse:
          (widget.current?.bookId == _selectedBookId &&
              widget.current?.chapter == _selectedChapter)
          ? widget.current?.verse
          : null,
      onVerseSelected: (int verse) {
        Navigator.of(context).pop(
          BibleReference(
            bookId: _selectedBookId!,
            chapter: _selectedChapter!,
            verse: verse,
          ),
        );
      },
      onFullChapterSelected: () {
        Navigator.of(context).pop(
          BibleReference(bookId: _selectedBookId!, chapter: _selectedChapter!),
        );
      },
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.bookId,
    required this.chapter,
    required this.dataset,
    required this.onBack,
  });

  final String? bookId;
  final int? chapter;
  final BibleDataset? dataset;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final BibleBook? book = bookId == null ? null : BibleCatalog.byId(bookId!);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    String title;
    String subtitle;

    if (book != null && chapter != null) {
      final BibleChapter? ch = dataset?.chapter(book.id, chapter!);
      final int vCount = ch?.verseCount ?? 0;
      title = '${book.name} $chapter';
      subtitle = vCount > 0
          ? '$vCount versículos · Selecciona un versículo'
          : 'Capítulo $chapter';
    } else if (book != null) {
      title = book.name;
      subtitle = '${book.testament.label} · ${book.chapterCount} capítulos';
    } else {
      title = 'Seleccionar pasaje';
      subtitle = '${BibleCatalog.books.length} libros · Reina-Valera 1960';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
      child: Row(
        children: <Widget>[
          if (onBack != null)
            IconButton(
              tooltip: 'Atrás',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            )
          else
            const SizedBox(width: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _BooksView extends StatefulWidget {
  const _BooksView({
    super.key,
    required this.dataset,
    required this.searchController,
    required this.tabController,
    required this.recent,
    required this.onBookSelected,
    required this.onRecentSelected,
  });

  final BibleDataset dataset;
  final TextEditingController searchController;
  final TabController tabController;
  final List<BibleReference> recent;
  final ValueChanged<String> onBookSelected;
  final ValueChanged<BibleReference> onRecentSelected;

  @override
  State<_BooksView> createState() => _BooksViewState();
}

class _BooksViewState extends State<_BooksView> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String normalizedQuery = normalizeSearchText(_query.trim());

    final List<BibleBook> filtered = BibleCatalog.books.where((BibleBook book) {
      if (normalizedQuery.isEmpty) return true;
      return normalizeSearchText('${book.name} ${book.abbreviation}')
          .contains(normalizedQuery);
    }).toList();

    final List<BibleReference> availableRecent = widget.recent
        .where(widget.dataset.contains)
        .take(5)
        .toList();

    final int tabIndex = widget.tabController.index;
    final List<BibleBook> displayedBooks = switch (tabIndex) {
      1 =>
        filtered.where((BibleBook b) => b.testament == Testament.old).toList(),
      2 =>
        filtered
            .where((BibleBook b) => b.testament == Testament.newTestament)
            .toList(),
      _ => filtered,
    };

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: widget.searchController,
            onChanged: (String value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar un libro...',
              prefixIcon: const Icon(Icons.search_rounded),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar',
                      onPressed: () {
                        widget.searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: widget.tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerHeight: 0,
            indicator: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            labelColor: scheme.onPrimary,
            unselectedLabelColor: scheme.onSurfaceVariant,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
            ),
            tabs: const <Widget>[
              Tab(text: 'Todo'),
              Tab(text: 'Antiguo'),
              Tab(text: 'Nuevo'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              6,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: <Widget>[
              if (availableRecent.isNotEmpty &&
                  _query.isEmpty &&
                  tabIndex == 0) ...<Widget>[
                const _ListLabel('Continuar leyendo'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: availableRecent.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final BibleReference reference = availableRecent[index];
                      return ActionChip(
                        avatar: const Icon(Icons.history_rounded, size: 18),
                        label: Text(reference.chapterLabel),
                        onPressed: () => widget.onRecentSelected(reference),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (displayedBooks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: <Widget>[
                      Icon(
                        Icons.search_off_rounded,
                        size: 36,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ningún libro coincide con «$_query».',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              else if (tabIndex == 0 && _query.isEmpty) ...<Widget>[
                const _ListLabel('Antiguo Testamento (39 libros)'),
                ...displayedBooks
                    .where((BibleBook b) => b.testament == Testament.old)
                    .map(
                      (BibleBook book) => _BookTile(
                        book: book,
                        hasText: widget.dataset.hasBook(book.id),
                        onTap: () => widget.onBookSelected(book.id),
                      ),
                    ),
                const SizedBox(height: 12),
                const _ListLabel('Nuevo Testamento (27 libros)'),
                ...displayedBooks
                    .where(
                      (BibleBook b) => b.testament == Testament.newTestament,
                    )
                    .map(
                      (BibleBook book) => _BookTile(
                        book: book,
                        hasText: widget.dataset.hasBook(book.id),
                        onTap: () => widget.onBookSelected(book.id),
                      ),
                    ),
              ] else ...<Widget>[
                ...displayedBooks.map(
                  (BibleBook book) => _BookTile(
                    book: book,
                    hasText: widget.dataset.hasBook(book.id),
                    onTap: () => widget.onBookSelected(book.id),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ListLabel extends StatelessWidget {
  const _ListLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.book,
    required this.hasText,
    required this.onTap,
  });

  final BibleBook book;
  final bool hasText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: hasText ? 1 : 0.48,
      child: ListTile(
        enabled: hasText,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            book.abbreviation,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          book.name,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          hasText ? '${book.chapterCount} capítulos' : 'Sin texto disponible',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        trailing: hasText
            ? const Icon(Icons.chevron_right_rounded)
            : Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
      ),
    );
  }
}

class _ChaptersView extends StatelessWidget {
  const _ChaptersView({
    super.key,
    required this.bookId,
    required this.dataset,
    required this.selectedChapter,
    required this.onChapterSelected,
  });

  final String bookId;
  final BibleDataset dataset;
  final int? selectedChapter;
  final ValueChanged<int> onChapterSelected;

  @override
  Widget build(BuildContext context) {
    final HistoryController history = context.watch<HistoryController>();
    final BibleBook? book = BibleCatalog.byId(bookId);
    final BibleBookContent? content = dataset.bookContent(bookId);
    final List<int> chapters = content?.chapterNumbers ?? const <int>[];
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = (constraints.maxWidth / 64).floor().clamp(4, 8);

        return CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.format_list_numbered_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Capítulos de ${book?.name ?? ''}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate((
                  BuildContext context,
                  int index,
                ) {
                  final int chapter = chapters[index];
                  final bool selected = chapter == selectedChapter;
                  return _GridCell(
                    number: chapter,
                    selected: selected,
                    completed: history.isCompleted(
                      BibleReference(bookId: bookId, chapter: chapter),
                    ),
                    onTap: () => onChapterSelected(chapter),
                  );
                }, childCount: chapters.length),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VersesView extends StatelessWidget {
  const _VersesView({
    super.key,
    required this.bookId,
    required this.chapterNumber,
    required this.dataset,
    required this.selectedVerse,
    required this.onVerseSelected,
    required this.onFullChapterSelected,
  });

  final String bookId;
  final int chapterNumber;
  final BibleDataset dataset;
  final int? selectedVerse;
  final ValueChanged<int> onVerseSelected;
  final VoidCallback onFullChapterSelected;

  @override
  Widget build(BuildContext context) {
    final BibleBook? book = BibleCatalog.byId(bookId);
    final BibleChapter? chapter = dataset.chapter(bookId, chapterNumber);
    final List<Verse> verses = chapter?.verses ?? const <Verse>[];
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = (constraints.maxWidth / 64).floor().clamp(4, 8);

        return CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: onFullChapterSelected,
                      icon: const Icon(Icons.auto_stories_rounded, size: 20),
                      label: Text(
                        'Leer ${book?.name ?? ''} $chapterNumber completo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.touch_app_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'O elige un versículo para ir a él:',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                6,
                20,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate((
                  BuildContext context,
                  int index,
                ) {
                  final int verseNumber = verses[index].number;
                  final bool selected = verseNumber == selectedVerse;
                  return _GridCell(
                    number: verseNumber,
                    selected: selected,
                    onTap: () => onVerseSelected(verseNumber),
                  );
                }, childCount: verses.length),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.number,
    required this.selected,
    this.completed = false,
    required this.onTap,
  });

  final int number;
  final bool selected;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: <Widget>[
            if (completed)
              Positioned(
                top: 5,
                right: 5,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 13,
                  semanticLabel: 'Capítulo $number leído',
                  color: selected ? scheme.onPrimary : scheme.primary,
                ),
              ),
            Center(
              child: Text(
                '$number',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoTextMessage extends StatelessWidget {
  const _NoTextMessage();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.menu_book_outlined,
              size: 40,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              'No hay texto bíblico disponible.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
