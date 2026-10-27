import 'dart:async';
import 'dart:math' as math;

import 'package:biblia/core/constants/bible_catalog.dart';
import 'package:biblia/data/bible_repository.dart';
import 'package:biblia/data/models/bible_book.dart';
import 'package:biblia/data/models/bible_content.dart';
import 'package:biblia/data/models/bible_dataset.dart';
import 'package:biblia/data/models/bible_reference.dart';
import 'package:biblia/data/models/favorite_verse.dart';
import 'package:biblia/data/models/reading_progress.dart';
import 'package:biblia/state/history_controller.dart';
import 'package:biblia/state/bible_library.dart';
import 'package:biblia/state/favorites_controller.dart';
import 'package:biblia/state/reading_controller.dart';
import 'package:biblia/state/settings_controller.dart';
import 'package:biblia/theme/app_theme.dart';
import 'package:biblia/ui/common/state_views.dart';
import 'package:biblia/ui/reading/passage_picker_sheet.dart';
import 'package:biblia/ui/settings/about_bible_screen.dart';
import 'package:biblia/ui/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class ReadingScreen extends StatelessWidget {
  const ReadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BibleLibrary library = context.watch<BibleLibrary>();
    final ReadingController reading = context.watch<ReadingController>();
    final SettingsController settings = context.watch<SettingsController>();
    final FavoritesController favorites = context.watch<FavoritesController>();
    final HistoryController history = context.watch<HistoryController>();
    final BibleReference? reference = reading.reference;
    final BibleChapter? chapter = reading.currentChapter;

    return Scaffold(
      appBar: _buildAppBar(context, library, reading),
      body: switch (library.status) {
        BibleLibraryStatus.initial ||
        BibleLibraryStatus.loading => const SizedBox.expand(),
        BibleLibraryStatus.error => AppErrorState(
          title: 'No se pudo cargar la Biblia',
          message:
              library.errorMessage ??
              'Ocurrió un problema al leer los datos locales.',
          onRetry: library.reload,
          secondaryLabel: 'Ajustes',
          onSecondary: () => _openSettings(context),
        ),
        BibleLibraryStatus.empty => AppEmptyState(
          icon: Icons.menu_book_outlined,
          title: 'El texto bíblico aún no está instalado',
          message:
              'No se encontró el texto bíblico local. Verifica los archivos.',
          actions: <Widget>[
            FilledButton.icon(
              onPressed: () => _openSettings(context),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Abrir Ajustes'),
            ),
            OutlinedButton(
              onPressed: () => _openAbout(context),
              child: const Text('Sobre la licencia'),
            ),
          ],
        ),
        BibleLibraryStatus.ready =>
          chapter == null || reference == null
              ? AppEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'Selecciona un pasaje',
                  message:
                      'Elige un libro y un capítulo disponibles para comenzar '
                      'a leer.',
                  actions: <Widget>[
                    FilledButton.icon(
                      onPressed: () => _openPicker(context, reading),
                      icon: const Icon(Icons.library_books_outlined),
                      label: const Text('Elegir pasaje'),
                    ),
                  ],
                )
              : _ReadingBody(
                  dataset: library.dataset!,
                  reference: reference,
                  chapter: chapter,
                  highlightedVerse: reading.highlightedVerse,
                  resumePosition: reading.resumePosition,
                  navigationRevision: reading.navigationRevision,
                  isCompleted: history.isCompleted(reference),
                  onToggleCompleted: () =>
                      unawaited(history.toggleCompleted(reference)),
                  fontSize: settings.readingFontSize,
                  source: library.source,
                  favoriteKeys: favorites.favorites
                      .map((FavoriteVerse favorite) => favorite.id)
                      .toSet(),
                  previous: reading.previousReference,
                  next: reading.nextReference,
                  onPrevious: reading.goToPreviousChapter,
                  onNext: reading.goToNextChapter,
                  onOpenPicker: () => _openPicker(context, reading),
                  onOpenSettings: () => _openSettings(context),
                ),
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    BibleLibrary library,
    ReadingController reading,
  ) {
    final BibleReference? reference = reading.reference;
    final String title = reference?.chapterLabel ?? 'Biblia';
    final String subtitle = library.dataset?.translation.isDemo == true
        ? 'Demostración · sin texto bíblico'
        : library.dataset?.translation.abbreviation ?? 'Reina-Valera 1960';

    return AppBar(
      leading: IconButton(
        tooltip: 'Elegir libro y capítulo',
        onPressed: library.hasData ? () => _openPicker(context, reading) : null,
        icon: const Icon(Icons.menu_book_outlined),
      ),
      title: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: library.hasData ? () => _openPicker(context, reading) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (library.hasData)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.expand_more_rounded, size: 20),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (reference != null)
          IconButton(
            tooltip: context.watch<HistoryController>().isCompleted(reference)
                ? 'Marcar como no leído'
                : 'Marcar capítulo como leído',
            onPressed: () => unawaited(
              context.read<HistoryController>().toggleCompleted(reference),
            ),
            icon: Icon(
              context.watch<HistoryController>().isCompleted(reference)
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
            ),
          ),
        IconButton(
          tooltip: 'Ajustes',
          onPressed: () => _openSettings(context),
          icon: const Icon(Icons.settings_outlined),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _openPicker(BuildContext context, ReadingController reading) async {
    final BibleReference? target = await showPassagePicker(
      context,
      reading: reading,
    );
    if (target != null && context.mounted) {
      reading.openReference(target);
    }
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  void _openAbout(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AboutBibleScreen()));
  }
}

class _ReadingBody extends StatefulWidget {
  const _ReadingBody({
    required this.dataset,
    required this.reference,
    required this.chapter,
    required this.highlightedVerse,
    required this.resumePosition,
    required this.navigationRevision,
    required this.isCompleted,
    required this.onToggleCompleted,
    required this.fontSize,
    required this.source,
    required this.favoriteKeys,
    required this.previous,
    required this.next,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenPicker,
    required this.onOpenSettings,
  });

  final BibleDataset dataset;
  final BibleReference reference;
  final BibleChapter chapter;
  final int? highlightedVerse;
  final ReadingPosition? resumePosition;
  final int navigationRevision;
  final bool isCompleted;
  final VoidCallback onToggleCompleted;
  final double fontSize;
  final BibleSource source;
  final Set<String> favoriteKeys;
  final BibleReference? previous;
  final BibleReference? next;
  final bool Function() onPrevious;
  final bool Function() onNext;
  final VoidCallback onOpenPicker;
  final VoidCallback onOpenSettings;

  @override
  State<_ReadingBody> createState() => _ReadingBodyState();
}

class _ReadingBodyState extends State<_ReadingBody>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _verseKeys = <int, GlobalKey>{};
  final Set<int> _selectedVerses = <int>{};
  final Map<int, ValueNotifier<bool>> _verseSelections =
      <int, ValueNotifier<bool>>{};
  final ValueNotifier<int> _selectionCount = ValueNotifier<int>(0);
  final GlobalKey _viewportKey = GlobalKey();
  int? _dragAnchor;
  Set<int> _selectionBeforeDrag = <int>{};
  Offset? _dragPosition;
  Timer? _autoScrollTimer;
  bool _restoringScroll = true;
  bool _positionSaveScheduled = false;
  late final HistoryController _history;

  @override
  void initState() {
    super.initState();
    _history = context.read<HistoryController>();
    WidgetsBinding.instance.addObserver(this);
    _initVerseKeys();
    _scheduleScroll();
  }

  void _initVerseKeys() {
    for (final Verse verse in widget.chapter.verses) {
      _verseKeys[verse.number] = GlobalKey();
      _verseSelections[verse.number] = ValueNotifier<bool>(false);
    }
  }

  @override
  void didUpdateWidget(covariant _ReadingBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool chapterChanged =
        oldWidget.reference.bookId != widget.reference.bookId ||
        oldWidget.reference.chapter != widget.reference.chapter;

    if (chapterChanged) {
      _verseKeys.clear();
      for (final ValueNotifier<bool> selection in _verseSelections.values) {
        selection.dispose();
      }
      _verseSelections.clear();
      _selectedVerses.clear();
      _selectionCount.value = 0;
      _endDrag();
      _initVerseKeys();
      _scheduleScroll();
    } else if (oldWidget.navigationRevision != widget.navigationRevision ||
        (oldWidget.highlightedVerse != widget.highlightedVerse &&
            widget.highlightedVerse != null)) {
      _scheduleScroll();
    }
  }

  void _scheduleScroll() {
    _restoringScroll = true;
    final int revision = widget.navigationRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) return;
      final int? target = widget.highlightedVerse;
      final ReadingPosition? saved = widget.resumePosition;
      final BuildContext? targetContext = _verseKeys[target]?.currentContext;
      if (targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          alignment: 0.15,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else if (saved != null &&
          saved.reference.chapterReference() == widget.reference) {
        final RenderObject? verse = _verseKeys[saved.reference.verse]
            ?.currentContext
            ?.findRenderObject();
        final RenderObject? viewport = _viewportKey.currentContext
            ?.findRenderObject();
        if (verse is RenderBox && viewport is RenderBox) {
          final double top = verse
              .localToGlobal(Offset.zero, ancestor: viewport)
              .dy;
          final double offset = _scrollController.offset + top + saved.offset;
          _scrollController.jumpTo(
            offset.clamp(0.0, _scrollController.position.maxScrollExtent),
          );
        } else {
          _scrollController.jumpTo(0);
        }
      } else {
        _scrollController.jumpTo(0);
      }
      if (!mounted || revision != widget.navigationRevision) return;
      _restoringScroll = false;
      _queueSavePosition();
    });
  }

  void _queueSavePosition() {
    if (_positionSaveScheduled) return;
    _positionSaveScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionSaveScheduled = false;
      if (mounted && _dragAnchor == null) _savePosition();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _savePosition() {
    if (_restoringScroll ||
        !_scrollController.hasClients ||
        _verseKeys.isEmpty) {
      return;
    }
    final RenderObject? viewport = _viewportKey.currentContext
        ?.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached) return;
    int anchor = widget.chapter.verses.last.number;
    double offset = 0;
    for (final entry in _verseKeys.entries) {
      final RenderObject? verse = entry.value.currentContext
          ?.findRenderObject();
      if (verse is! RenderBox || !verse.attached || !verse.hasSize) continue;
      final double top = verse
          .localToGlobal(Offset.zero, ancestor: viewport)
          .dy;
      anchor = entry.key;
      offset = -top;
      if (top + verse.size.height > 0) break;
    }
    unawaited(
      _history.savePosition(
        ReadingPosition(
          reference: widget.reference.withVerse(anchor),
          offset: offset,
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _savePosition();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _endDrag();
    for (final ValueNotifier<bool> selection in _verseSelections.values) {
      selection.dispose();
    }
    _selectionCount.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BibleBook? book = BibleCatalog.byId(widget.reference.bookId);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool showDemoBanner = widget.dataset.translation.isDemo;
    final bool showPartialBanner =
        !showDemoBanner && !widget.dataset.translation.isComplete;

    return Column(
      children: <Widget>[
        Expanded(
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (notification) {
              if (notification.depth == 0) _queueSavePosition();
              return false;
            },
            child: Scrollbar(
              key: _viewportKey,
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  top: 12,
                  bottom: 32 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (showDemoBanner || showPartialBanner)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
                            child: showDemoBanner
                                ? DemoDataBanner(
                                    onOpenSettings: widget.onOpenSettings,
                                  )
                                : PartialDataBanner(
                                    bookCount:
                                        widget.dataset.translation.bookCount,
                                    chapterCount:
                                        widget.dataset.translation.chapterCount,
                                    onOpenSettings: widget.onOpenSettings,
                                  ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 10, 28, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                book?.testament.label.toUpperCase() ?? '',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      book?.name ?? widget.reference.bookName,
                                      style: ReadingTypography.title(context),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Capítulo ${widget.chapter.number}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                widget.source == BibleSource.demo
                                    ? 'Texto de interfaz · no es la Biblia'
                                    : '${widget.dataset.translation.name} · '
                                          '${widget.chapter.verseCount} versículos',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPressStart: _startDrag,
                            onLongPressMoveUpdate: (details) =>
                                _updateDrag(details.globalPosition),
                            onLongPressEnd: (_) => _endDrag(),
                            onLongPressCancel: _endDrag,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                for (final Verse verse in widget.chapter.verses)
                                  ValueListenableBuilder<bool>(
                                    key: _verseKeys[verse.number],
                                    valueListenable:
                                        _verseSelections[verse.number]!,
                                    builder: (context, selected, child) =>
                                        RepaintBoundary(
                                          child: _VerseRow(
                                            verse: verse,
                                            reference: widget.reference
                                                .withVerse(verse.number),
                                            fontSize: widget.fontSize,
                                            highlighted:
                                                selected ||
                                                widget.highlightedVerse ==
                                                    verse.number,
                                            isFavorite: widget.favoriteKeys
                                                .contains(
                                                  widget.reference
                                                      .withVerse(verse.number)
                                                      .key,
                                                ),
                                            selected: selected,
                                            onTap: () =>
                                                _toggleVerse(verse.number),
                                          ),
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _ChapterFooter(
                            current: widget.reference,
                            isCompleted: widget.isCompleted,
                            onToggleCompleted: widget.onToggleCompleted,
                            previous: widget.previous,
                            next: widget.next,
                            onPrevious: () {
                              widget.onPrevious();
                            },
                            onNext: () {
                              widget.onNext();
                            },
                            onOpenPicker: widget.onOpenPicker,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: _selectionCount,
          builder: (context, count, child) {
            if (count == 0) return const SizedBox.shrink();
            return Material(
              color: scheme.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Deseleccionar todo',
                      onPressed: () => _applySelection(<int>{}),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    Expanded(
                      child: Text(
                        count == 1
                            ? '1 versículo seleccionado'
                            : '$count versículos seleccionados',
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: _showVerseActions,
                      child: const Text('Acciones'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _toggleVerse(int number) {
    final bool wasSelected =
        _selectedVerses.contains(number) || widget.highlightedVerse == number;
    context.read<ReadingController>().clearHighlight();
    final Set<int> selection = Set<int>.of(_selectedVerses);
    if (wasSelected) {
      selection.remove(number);
    } else {
      selection.add(number);
    }
    _applySelection(selection);
    HapticFeedback.selectionClick();
  }

  void _applySelection(Set<int> selection) {
    for (final int number in _selectedVerses.difference(selection)) {
      _verseSelections[number]?.value = false;
    }
    for (final int number in selection.difference(_selectedVerses)) {
      _verseSelections[number]?.value = true;
    }
    _selectedVerses
      ..clear()
      ..addAll(selection);
    _selectionCount.value = selection.length;
  }

  int? _verseAt(Offset position) {
    for (final MapEntry<int, GlobalKey> entry in _verseKeys.entries) {
      final RenderObject? object = entry.value.currentContext
          ?.findRenderObject();
      if (object is RenderBox && object.hasSize) {
        final Offset local = object.globalToLocal(position);
        if (local.dy >= 0 && local.dy < object.size.height) return entry.key;
      }
    }
    return null;
  }

  void _startDrag(LongPressStartDetails details) {
    final int? anchor = _verseAt(details.globalPosition);
    if (anchor == null) return;
    context.read<ReadingController>().clearHighlight();
    _dragAnchor = anchor;
    _selectionBeforeDrag = Set<int>.of(_selectedVerses);
    _updateDrag(details.globalPosition);
    HapticFeedback.selectionClick();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final Offset? position = _dragPosition;
      final RenderObject? object = _viewportKey.currentContext
          ?.findRenderObject();
      if (position == null ||
          object is! RenderBox ||
          !_scrollController.hasClients) {
        return;
      }
      final double y = object.globalToLocal(position).dy;
      final double delta = y < 56
          ? -12
          : (y > object.size.height - 56 ? 12 : 0);
      if (delta == 0) return;
      final ScrollPosition scroll = _scrollController.position;
      final double target = (scroll.pixels + delta).clamp(
        scroll.minScrollExtent,
        scroll.maxScrollExtent,
      );
      if (target != scroll.pixels) {
        _scrollController.jumpTo(target);
        _updateDrag(position);
      }
    });
  }

  void _updateDrag(Offset position) {
    _dragPosition = position;
    final int? anchor = _dragAnchor;
    final int? current = _verseAt(position);
    if (anchor == null || current == null) return;
    final int first = math.min(anchor, current);
    final int last = math.max(anchor, current);
    _applySelection(<int>{
      ..._selectionBeforeDrag,
      ...widget.chapter.verses
          .where((verse) => verse.number >= first && verse.number <= last)
          .map((verse) => verse.number),
    });
  }

  void _endDrag() {
    if (_dragAnchor != null) _queueSavePosition();
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _dragAnchor = null;
    _dragPosition = null;
    _selectionBeforeDrag = <int>{};
  }

  Future<void> _showVerseActions() async {
    final List<Verse> verses = widget.chapter.verses
        .where((verse) => _selectedVerses.contains(verse.number))
        .toList();
    if (verses.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => _VerseActionsSheet(
        verses: verses,
        reference: widget.reference,
        translation: widget.dataset.translation.abbreviation,
      ),
    );
  }
}

class _VerseRow extends StatelessWidget {
  const _VerseRow({
    required this.verse,
    required this.reference,
    required this.fontSize,
    required this.highlighted,
    required this.selected,
    required this.isFavorite,
    required this.onTap,
  });

  final Verse verse;
  final BibleReference reference;
  final double fontSize;
  final bool highlighted;
  final bool selected;
  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${reference.label}. ${verse.text}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                color: highlighted
                    ? scheme.primaryContainer.withValues(alpha: 0.5)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: highlighted
                      ? scheme.primary.withValues(alpha: 0.35)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 34,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${verse.number}',
                        textAlign: TextAlign.right,
                        style: ReadingTypography.verseNumber(context, fontSize)
                            .copyWith(
                              fontWeight: highlighted
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: highlighted ? scheme.primary : null,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      verse.text,
                      style: ReadingTypography.body(context, fontSize),
                    ),
                  ),
                  if (isFavorite)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 6),
                      child: Icon(
                        Icons.bookmark_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterFooter extends StatelessWidget {
  const _ChapterFooter({
    required this.current,
    required this.isCompleted,
    required this.onToggleCompleted,
    required this.previous,
    required this.next,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenPicker,
  });

  final BibleReference current;
  final bool isCompleted;
  final VoidCallback onToggleCompleted;
  final BibleReference? previous;
  final BibleReference? next;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onOpenPicker;

  String _label(BibleReference? reference, String fallback) {
    if (reference == null) return fallback;
    if (reference.bookId == current.bookId) {
      return 'Capítulo ${reference.chapter}';
    }
    return reference.chapterLabel;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            key: const ValueKey<String>('toggle-chapter-read'),
            onPressed: onToggleCompleted,
            icon: Icon(
              isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
            ),
            label: Text(
              isCompleted ? 'Capítulo leído' : 'Marcar capítulo como leído',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: previous == null ? null : onPrevious,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(
                  _label(previous, 'Anterior'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: next == null ? null : onNext,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  _label(next, 'Siguiente'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: onOpenPicker,
          icon: const Icon(Icons.grid_view_rounded, size: 18),
          label: const Text('Elegir otro capítulo'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _VerseActionsSheet extends StatelessWidget {
  const _VerseActionsSheet({
    required this.verses,
    required this.reference,
    required this.translation,
  });

  final List<Verse> verses;
  final String translation;
  final BibleReference reference;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final FavoritesController favorites = context.watch<FavoritesController>();
    final bool isFavorite = verses.every(
      (verse) => favorites.isFavorite(reference.withVerse(verse.number)),
    );
    final String label = verses.length == 1
        ? reference.withVerse(verses.first.number).label
        : '${reference.chapterLabel}:${verses.map((verse) => verse.number).join(', ')}';
    final String text = verses.length == 1
        ? verses.first.text
        : verses.map((verse) => '${verse.number} ${verse.text}').join('\n');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                translation,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.35,
            ),
            child: SingleChildScrollView(
              child: Text(
                text,
                style: ReadingTypography.body(
                  context,
                  19,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    final bool saved = !isFavorite;
                    for (final Verse verse in verses) {
                      final BibleReference target = reference.withVerse(
                        verse.number,
                      );
                      if (!saved) {
                        await favorites.remove(target);
                      } else if (!favorites.isFavorite(target)) {
                        await favorites.toggle(
                          reference: target,
                          text: verse.text,
                        );
                      }
                    }
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          saved
                              ? (verses.length == 1
                                    ? 'Versículo guardado en favoritos'
                                    : 'Versículos guardados en favoritos')
                              : (verses.length == 1
                                    ? 'Versículo eliminado de favoritos'
                                    : 'Versículos eliminados de favoritos'),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: Icon(
                    isFavorite
                        ? Icons.bookmark_remove_rounded
                        : Icons.bookmark_add_rounded,
                    size: 18,
                    color: isFavorite ? scheme.error : scheme.primary,
                  ),
                  label: Text(isFavorite ? 'Quitar' : 'Guardar'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: '$text\n\n— $label ($translation)'),
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          verses.length == 1
                              ? 'Versículo copiado'
                              : 'Versículos copiados',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copiar'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await SharePlus.instance.share(
                      ShareParams(text: '«$text»\n\n— $label ($translation)'),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Compartir'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
