import 'package:biblia/data/models/bible_reference.dart';
import 'package:biblia/data/models/favorite_verse.dart';
import 'package:biblia/state/bible_library.dart';
import 'package:biblia/state/favorites_controller.dart';
import 'package:biblia/theme/app_theme.dart';
import 'package:biblia/ui/common/state_views.dart';
import 'package:biblia/ui/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.onOpenReference});

  final ValueChanged<BibleReference> onOpenReference;

  @override
  Widget build(BuildContext context) {
    final FavoritesController favorites = context.watch<FavoritesController>();
    final BibleLibrary library = context.watch<BibleLibrary>();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Favoritos'),
            if (favorites.count > 0)
              Text(
                favorites.count == 1
                    ? '1 versículo guardado'
                    : '${favorites.count} versículos guardados',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
        actions: <Widget>[
          if (favorites.count > 0)
            PopupMenuButton<_FavoritesAction>(
              tooltip: 'Más acciones',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (_FavoritesAction action) {
                if (action == _FavoritesAction.clear) {
                  _confirmClear(context, favorites);
                }
              },
              itemBuilder: (BuildContext context) =>
                  const <PopupMenuEntry<_FavoritesAction>>[
                    PopupMenuItem<_FavoritesAction>(
                      value: _FavoritesAction.clear,
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.delete_sweep_outlined),
                          SizedBox(width: 12),
                          Text('Vaciar favoritos'),
                        ],
                      ),
                    ),
                  ],
            ),
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: favorites.isEmpty
          ? const AppEmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'Aún no tienes favoritos',
              message:
                  'Selecciona versículos y abre «Acciones» → «Guardar» para '
                  'conservarlo aquí. Los favoritos se almacenan solo en este '
                  'dispositivo.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (!library.hasData)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: _OfflineNotice(
                      onOpenSettings: () => _openSettings(context),
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      10,
                      16,
                      28 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: favorites.favorites.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final FavoriteVerse favorite = favorites.favorites[index];
                      return _FavoriteCard(
                        key: ValueKey<String>(favorite.id),
                        favorite: favorite,
                        onTap: () => onOpenReference(favorite.reference),
                        onRemove: () =>
                            _removeWithUndo(context, favorites, favorite),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _removeWithUndo(
    BuildContext context,
    FavoritesController favorites,
    FavoriteVerse favorite,
  ) async {
    await favorites.remove(favorite.reference);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${favorite.label} eliminado de favoritos'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => favorites.add(favorite),
        ),
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    FavoritesController favorites,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('¿Vaciar favoritos?'),
          content: const Text(
            'Se eliminarán todos los versículos guardados en este dispositivo. '
            'Esta acción no se puede deshacer.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Vaciar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await favorites.clear();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Favoritos eliminados')));
      }
    }
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }
}

enum _FavoritesAction { clear }

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    super.key,
    required this.favorite,
    required this.onTap,
    required this.onRemove,
  });

  final FavoriteVerse favorite;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey<String>('dismiss-${favorite.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: scheme.onErrorContainer,
        ),
      ),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        favorite.label,
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: scheme.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        favorite.text,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: ReadingTypography.body(context, 17),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar de favoritos',
                  onPressed: onRemove,
                  icon: const Icon(Icons.bookmark_remove_outlined, size: 20),
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'El texto bíblico no está instalado. Tus favoritos guardados '
              'siguen visibles.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSecondaryContainer, height: 1.4),
            ),
          ),
          IconButton(
            tooltip: 'Ajustes',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined, size: 20),
            color: scheme.onSecondaryContainer,
          ),
        ],
      ),
    );
  }
}
