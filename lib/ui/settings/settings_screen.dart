import 'dart:async';

import 'package:biblia/core/constants/app_info.dart';
import 'package:biblia/data/preferences_repository.dart';
import 'package:biblia/ui/settings/backup_card.dart';
import 'package:biblia/state/favorites_controller.dart';
import 'package:biblia/state/history_controller.dart';
import 'package:biblia/state/settings_controller.dart';
import 'package:biblia/theme/app_theme.dart';
import 'package:biblia/ui/common/state_views.dart';
import 'package:biblia/ui/settings/about_bible_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    final HistoryController history = context.watch<HistoryController>();
    final FavoritesController favorites = context.watch<FavoritesController>();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          40 + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 2),
            child: Text(
              'Personaliza tu lectura',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Elige cómo quieres ver y leer tu Biblia.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SectionLabel(
            'Apariencia',
            padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.dark_mode_outlined,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tema de la aplicación',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const <ButtonSegment<ThemeMode>>[
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          label: Text('Sistema'),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          label: Text('Claro'),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          label: Text('Oscuro'),
                        ),
                      ],
                      selected: <ThemeMode>{settings.themeMode},
                      showSelectedIcon: false,
                      onSelectionChanged: (Set<ThemeMode> selection) {
                        unawaited(settings.setThemeMode(selection.first));
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.palette_outlined,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Paleta de colores',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<AppColorPalette>(
                    key: const ValueKey<String>('color-palette'),
                    initialValue: settings.colorPalette,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Seleccionar paleta',
                    ),
                    items: <DropdownMenuItem<AppColorPalette>>[
                      for (final AppColorPalette palette
                          in AppColorPalette.values)
                        DropdownMenuItem<AppColorPalette>(
                          value: palette,
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: palette.seedColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(palette.label),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (palette) {
                      if (palette != null) {
                        unawaited(settings.setColorPalette(palette));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SectionLabel(
            'Lectura',
            padding: EdgeInsets.fromLTRB(4, 26, 4, 10),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DropdownButtonFormField<ReadingFont>(
                    key: const ValueKey<String>('reading-font'),
                    initialValue: settings.readingFont,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Fuente de lectura',
                      prefixIcon: Icon(Icons.font_download_outlined),
                    ),
                    items: <DropdownMenuItem<ReadingFont>>[
                      for (final ReadingFont font in ReadingFont.values)
                        DropdownMenuItem<ReadingFont>(
                          value: font,
                          child: Text(
                            font.label,
                            style: TextStyle(
                              fontFamily: font.family,
                              fontSize: 18,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (font) {
                      if (font != null) {
                        unawaited(settings.setReadingFont(font));
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.readingFont.description,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  _ReadingSizeControls(
                    size: settings.readingFontSize,
                    onCommitted: settings.setReadingFontSize,
                  ),
                ],
              ),
            ),
          ),
          const SectionLabel(
            'Datos locales',
            padding: EdgeInsets.fromLTRB(4, 26, 4, 10),
          ),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.task_alt_rounded, color: scheme.primary),
                  title: const Text('Capítulos leídos'),
                  subtitle: Text(
                    '${history.completedChapters.length} capítulos marcados',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showCompleted(context, history),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.history_rounded, color: scheme.primary),
                  title: const Text('Historial de lectura'),
                  subtitle: Text(
                    history.recentChapters.isEmpty
                        ? 'Sin capítulos recientes'
                        : '${history.recentChapters.length} capítulos recientes',
                  ),
                  trailing: history.recentChapters.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () =>
                              _confirmClearHistory(context, history),
                          child: const Text('Borrar'),
                        ),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                ListTile(
                  leading: Icon(
                    Icons.bookmark_outline_rounded,
                    color: scheme.primary,
                  ),
                  title: const Text('Favoritos'),
                  subtitle: Text(
                    favorites.count == 1
                        ? '1 versículo guardado'
                        : '${favorites.count} versículos guardados',
                  ),
                ),
              ],
            ),
          ),
          const SectionLabel(
            'Respaldo',
            padding: EdgeInsets.fromLTRB(4, 26, 4, 10),
          ),
          const BackupCard(),
          const SectionLabel(
            'Acerca de',
            padding: EdgeInsets.fromLTRB(4, 26, 4, 10),
          ),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.gavel_outlined, color: scheme.primary),
                  title: const Text('Licencia y derechos'),
                  subtitle: const Text('Reina-Valera 1960'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openAbout(context),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.article_outlined, color: scheme.primary),
                  title: const Text('Licencias de código abierto'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: AppInfo.name,
                    applicationVersion: AppInfo.version,
                  ),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('Versión'),
                  subtitle: Text(
                    '${AppInfo.version} · ${AppInfo.name} Offline',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Funciona completamente sin conexión.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  void _showCompleted(BuildContext context, HistoryController history) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider<HistoryController>.value(
        value: history,
        child: Consumer<HistoryController>(
          builder: (context, history, child) {
            final chapters = history.completedChapters;
            return SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.65,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Capítulos leídos · ${chapters.length}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Expanded(
                    child: chapters.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Marca los capítulos desde la lectura para ver tu progreso aquí.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: chapters.length,
                            itemBuilder: (context, index) {
                              final chapter = chapters[index];
                              return ListTile(
                                title: Text(chapter.chapterLabel),
                                leading: const Icon(Icons.check_circle_rounded),
                                trailing: IconButton(
                                  tooltip: 'Marcar como no leído',
                                  icon: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                  ),
                                  onPressed: () => unawaited(
                                    history.toggleCompleted(chapter),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory(
    BuildContext context,
    HistoryController history,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('¿Borrar el historial?'),
          content: const Text(
            'Se eliminarán los capítulos recientes y la posición de lectura '
            'guardada. Se conservarán tus favoritos y capítulos leídos.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Borrar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await history.clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Historial eliminado')));
      }
    }
  }

  void _openAbout(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AboutBibleScreen()));
  }
}

class _ReadingSizeControls extends StatefulWidget {
  const _ReadingSizeControls({required this.size, required this.onCommitted});
  final double size;
  final Future<void> Function(double) onCommitted;

  @override
  State<_ReadingSizeControls> createState() => _ReadingSizeControlsState();
}

class _ReadingSizeControlsState extends State<_ReadingSizeControls> {
  double? _previewSize;

  @override
  Widget build(BuildContext context) {
    final double size = _previewSize ?? widget.size;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.text_fields_rounded, size: 20, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tamaño del texto bíblico',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              '${size.round()} pt',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: scheme.primary),
            ),
          ],
        ),
        Slider(
          value: size,
          min: PreferencesRepository.minFontSize,
          max: PreferencesRepository.maxFontSize,
          divisions:
              (PreferencesRepository.maxFontSize -
                      PreferencesRepository.minFontSize)
                  .round(),
          label: '${size.round()} pt',
          onChanged: (value) => setState(() => _previewSize = value),
          onChangeEnd: (double value) {
            unawaited(widget.onCommitted(value));
            setState(() => _previewSize = null);
          },
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            'Un momento de calma para leer, comprender y reflexionar.',
            style: ReadingTypography.body(context, size),
          ),
        ),
      ],
    );
  }
}
