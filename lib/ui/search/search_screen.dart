import 'package:biblia/core/constants/bible_catalog.dart';
import 'package:biblia/data/models/bible_book.dart';
import 'package:biblia/data/models/bible_dataset.dart';
import 'package:biblia/data/models/bible_reference.dart';
import 'package:biblia/data/models/search_result.dart';
import 'package:biblia/state/bible_library.dart';
import 'package:biblia/state/bible_search_controller.dart';
import 'package:biblia/ui/common/state_views.dart';
import 'package:biblia/ui/settings/about_bible_screen.dart';
import 'package:biblia/ui/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.onOpenReference});

  final ValueChanged<BibleReference> onOpenReference;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController.text = context.read<BibleSearchController>().query;
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BibleLibrary library = context.watch<BibleLibrary>();
    final BibleSearchController search = context.watch<BibleSearchController>();
    final BibleDataset? dataset = library.dataset;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: SearchBar(
              controller: _textController,
              focusNode: _focusNode,
              hintText: 'Buscar palabras o frases',
              leading: const Icon(Icons.search_rounded),
              textInputAction: TextInputAction.search,
              onChanged: (String value) {
                search.updateQuery(value);
              },
              onSubmitted: (String value) => search.searchFor(value),
              trailing: <Widget>[
                if (_textController.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Limpiar búsqueda',
                    onPressed: () {
                      _textController.clear();
                      search.clear();
                      _focusNode.requestFocus();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
          if (dataset != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      FilterChip(
                        label: const Text('Toda la Biblia'),
                        selected:
                            search.testament == null && search.bookId == null,
                        onSelected: (_) {
                          search.setTestament(null);
                          search.setBookId(null);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Antiguo'),
                        selected:
                            search.testament == Testament.old &&
                            search.bookId == null,
                        onSelected: (_) {
                          search.setTestament(Testament.old);
                          search.setBookId(null);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Nuevo'),
                        selected:
                            search.testament == Testament.newTestament &&
                            search.bookId == null,
                        onSelected: (_) {
                          search.setTestament(Testament.newTestament);
                          search.setBookId(null);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: Icon(
                          search.bookId == null
                              ? Icons.filter_list_rounded
                              : Icons.check_rounded,
                          size: 16,
                        ),
                        label: Text(
                          search.bookId == null
                              ? 'Por libro'
                              : (BibleCatalog.byId(search.bookId!)?.name ??
                                    'Libro'),
                        ),
                        selected: search.bookId != null,
                        onSelected: (_) => _showBookPicker(context, search),
                      ),
                      if (search.bookId != null) ...<Widget>[
                        const SizedBox(width: 4),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Quitar filtro de libro',
                          icon: const Icon(Icons.cancel_rounded, size: 18),
                          onPressed: () => search.setBookId(null),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (dataset?.translation.isDemo == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: DemoDataBanner(
                compact: true,
                onOpenSettings: () => _openSettings(context),
              ),
            ),
          Expanded(
            child: _buildContent(
              context,
              library: library,
              search: search,
              dataset: dataset,
            ),
          ),
          if (search.status == BibleSearchStatus.searching)
            LinearProgressIndicator(
              minHeight: 2,
              color: scheme.primary,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
        ],
      ),
    );
  }

  void _showBookPicker(BuildContext context, BibleSearchController search) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return _SearchBookPickerSheet(
          selectedBookId: search.bookId,
          testament: search.testament,
          onBookSelected: (String? bookId) {
            search.setBookId(bookId);
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required BibleLibrary library,
    required BibleSearchController search,
    required BibleDataset? dataset,
  }) {
    if (dataset == null) {
      return AppEmptyState(
        icon: Icons.manage_search_rounded,
        title: 'No hay texto para buscar',
        message: 'El buscador trabaja con el texto bíblico local instalado.',
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
      );
    }

    if (search.query.trim().isEmpty) {
      return _SearchIntro(
        isDemo: dataset.translation.isDemo,
        onSuggestion: _applySuggestion,
      );
    }

    if (search.status == BibleSearchStatus.searching) {
      return const AppLoadingState(message: 'Buscando en el texto local…');
    }

    if (search.status == BibleSearchStatus.error) {
      return AppErrorState(
        title: 'No se pudo preparar la búsqueda',
        message: 'Vuelve a intentarlo para buscar en el texto local.',
        onRetry: () => search.searchFor(search.query),
      );
    }

    if (search.status == BibleSearchStatus.noResults) {
      final String filterDesc = search.bookId != null
          ? ' en ${BibleCatalog.byId(search.bookId!)?.name ?? 'el libro seleccionado'}'
          : (search.testament != null
                ? ' en el ${search.testament!.label.toLowerCase()}'
                : '');
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Sin resultados',
        message:
            'No se encontró «${search.query.trim()}»$filterDesc. Prueba con otra palabra.',
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: () => _applySuggestion(''),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Limpiar búsqueda'),
          ),
        ],
      );
    }

    final SearchResponse response = search.response;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  response.totalMatches == 1
                      ? '1 resultado'
                      : '${response.totalMatches} resultados',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (response.truncated)
                Text(
                  'Mostrando ${response.results.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              12,
              4,
              12,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: response.results.length,
            separatorBuilder: (BuildContext context, int index) => Divider(
              height: 1,
              indent: 72,
              endIndent: 24,
              color: Theme.of(context).colorScheme.outlineVariant
                  .withValues(alpha: 0.45),
            ),
            itemBuilder: (BuildContext context, int index) {
              final SearchResult result = response.results[index];
              return _SearchResultTile(
                result: result,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  widget.onOpenReference(result.reference);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _applySuggestion(String term) {
    _textController.value = TextEditingValue(
      text: term,
      selection: TextSelection.collapsed(offset: term.length),
    );
    final BibleSearchController search = context.read<BibleSearchController>();
    if (term.isEmpty) {
      search.clear();
    } else {
      search.searchFor(term);
    }
    if (term.isNotEmpty) {
      _focusNode.requestFocus();
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

class _SearchBookPickerSheet extends StatefulWidget {
  const _SearchBookPickerSheet({
    required this.selectedBookId,
    required this.testament,
    required this.onBookSelected,
  });

  final String? selectedBookId;
  final Testament? testament;
  final ValueChanged<String?> onBookSelected;

  @override
  State<_SearchBookPickerSheet> createState() => _SearchBookPickerSheetState();
}

class _SearchBookPickerSheetState extends State<_SearchBookPickerSheet> {
  final TextEditingController _filter = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<BibleBook> books = BibleCatalog.books.where((BibleBook book) {
      if (widget.testament != null && book.testament != widget.testament) {
        return false;
      }
      if (_query.trim().isEmpty) return true;
      return book.name.toLowerCase().contains(_query.toLowerCase()) ||
          book.abbreviation.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: <Widget>[
                Text(
                  'Filtrar búsqueda por libro',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _filter,
            decoration: InputDecoration(
              hintText: 'Buscar libro...',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
            ),
            onChanged: (String val) => setState(() => _query = val),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: Icon(
              Icons.all_inclusive_rounded,
              color: widget.selectedBookId == null
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
            title: const Text('Todos los libros (sin filtro)'),
            trailing: widget.selectedBookId == null
                ? Icon(Icons.check_rounded, color: scheme.primary)
                : null,
            onTap: () => widget.onBookSelected(null),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: books.length,
              itemBuilder: (BuildContext context, int index) {
                final BibleBook book = books[index];
                final bool isSelected = book.id == widget.selectedBookId;
                return ListTile(
                  title: Text(book.name),
                  subtitle: Text(
                    '${book.testament.shortLabel} · ${book.chapterCount} capítulos',
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: scheme.primary)
                      : null,
                  onTap: () => widget.onBookSelected(book.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchIntro extends StatelessWidget {
  const _SearchIntro({required this.isDemo, required this.onSuggestion});

  final bool isDemo;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<String> suggestions = isDemo
        ? <String>['demostración', 'texto', 'favoritos', 'capítulo']
        : <String>['amor', 'fe', 'esperanza', 'paz'];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: <Widget>[
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  Icons.travel_explore_rounded,
                  size: 38,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Encuentra un pasaje',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Busca una palabra o una frase en todo el texto disponible. '
                'La búsqueda ignora mayúsculas y tildes.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 26),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: suggestions
                    .map(
                      (String term) => ActionChip(
                        label: Text(term),
                        onPressed: () => onSuggestion(term),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result, required this.onTap});

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String abbreviation = BibleCatalog.displayAbbreviation(
      result.reference.bookId,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                abbreviation,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    result.reference.label,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: scheme.primary),
                  ),
                  const SizedBox(height: 5),
                  _HighlightedSnippet(result: result),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Icon(
                Icons.north_east_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedSnippet extends StatelessWidget {
  const _HighlightedSnippet({required this.result});

  final SearchResult result;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String text = result.snippet;
    final int start = result.matchStart.clamp(0, text.length);
    final int end = (start + result.matchLength).clamp(0, text.length);
    final TextStyle base = Theme.of(context).textTheme.bodyMedium!
        .copyWith(color: scheme.onSurfaceVariant, height: 1.5);
    final TextStyle highlighted = base.copyWith(
      color: scheme.onPrimaryContainer,
      backgroundColor: scheme.primaryContainer,
      fontWeight: FontWeight.w600,
    );

    if (start >= end) {
      return Text(text, style: base);
    }

    return Text.rich(
      TextSpan(
        style: base,
        children: <InlineSpan>[
          TextSpan(text: text.substring(0, start)),
          TextSpan(text: text.substring(start, end), style: highlighted),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}
