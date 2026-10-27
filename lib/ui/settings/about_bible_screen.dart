import 'package:biblia/core/constants/app_info.dart';
import 'package:biblia/data/bible_repository.dart';
import 'package:biblia/state/bible_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class AboutBibleScreen extends StatelessWidget {
  const AboutBibleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BibleLibrary library = context.watch<BibleLibrary>();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Licencia y derechos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: <Widget>[
          Text(
            'Reina-Valera 1960',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'La Reina-Valera 1960 (RVR1960) es una traducción bíblica '
            'protegida por derechos de autor. Su texto no es de dominio '
            'público. Su redistribución requiere la autorización correspondiente.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.55),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SelectableText(
                    'El texto bíblico ha sido tomado de la versión Reina-Valera '
                    '© 1960 Sociedades Bíblicas en América Latina; © renovado '
                    '1988 Sociedades Bíblicas Unidas.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(height: 1.55),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Reina-Valera 1960® es una marca registrada de Sociedades '
                    'Bíblicas Unidas y se usa solamente bajo licencia.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Uso en aplicaciones móviles',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'La redistribución del texto completo RVR1960 requiere permiso '
            'escrito de sus titulares. La licencia de las fuentes y de los '
            'paquetes de software no concede derechos sobre el texto bíblico. '
            'Consulta las condiciones de uso del titular antes de distribuirlo.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.55),
          ),
          const SizedBox(height: 12),
          SelectableText(
            'licensing@americanbible.org\n'
            'https://bibles.com/pages/american-bible-society-rights-and-permissions',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.primary, height: 1.55),
          ),
          const SizedBox(height: 22),
          Text(
            'Estado en esta instalación',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                library.isDemo
                    ? Icons.science_outlined
                    : Icons.storage_outlined,
                color: scheme.primary,
              ),
              title: Text(library.source.label),
              subtitle: Text(
                library.dataset == null
                    ? 'No hay texto bíblico cargado.'
                    : library.dataset!.translation.isDemo
                    ? 'Los capítulos visibles contienen texto de interfaz de '
                          'prueba, no Escritura.'
                    : '${library.dataset!.translation.name} · '
                          '${library.dataset!.translation.bookCount} libros · '
                          '${library.dataset!.translation.verseCount} '
                          'versículos',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
              ),
            ),
          ),
          if (library.isDemo) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'El conjunto de demostración se activa únicamente en compilaciones '
              'de desarrollo o con la opción BIBLE_DEMO. No contiene texto de '
              'la RVR1960 ni de ninguna otra traducción. Su propósito es probar '
              'la lectura, la búsqueda, los favoritos y la persistencia.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
          const SizedBox(height: 22),
          Text(
            'Privacidad y funcionamiento sin conexión',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'La aplicación no solicita permiso de Internet para leer, buscar '
            'ni guardar favoritos. El texto, las preferencias, los favoritos y '
            'el historial permanecen en el almacenamiento privado de la '
            'aplicación. No se envían consultas ni datos de uso a servidores.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.55),
          ),
          const SizedBox(height: 22),
          Text('Tipografía', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.font_download_outlined,
                color: scheme.primary,
              ),
              title: const Text('Literata'),
              subtitle: const Text(
                'Tipografía de lectura incluida en la aplicación, con licencia '
                'SIL Open Font License 1.1.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showFontLicense(context),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.font_download_outlined,
                color: scheme.primary,
              ),
              title: const Text('Liberation Sans y Liberation Serif'),
              subtitle: const Text(
                'Fuentes incluidas para los estilos Moderna y Clásica. SIL Open Font License 1.1.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showFontLicense(
                context,
                asset: 'assets/fonts/Liberation-LICENSE.txt',
                name: 'Liberation',
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${AppInfo.name} · ${AppInfo.version}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFontLicense(
    BuildContext context, {
    String asset = 'assets/fonts/OFL.txt',
    String name = 'Literata',
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Licencia de $name'),
          content: SizedBox(
            width: 560,
            child: FutureBuilder<String>(
              future: rootBundle.loadString(asset),
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                if (snapshot.hasError) {
                  return const Text('No se pudo leer el archivo de licencia.');
                }
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return SingleChildScrollView(
                  child: SelectableText(
                    snapshot.data!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(height: 1.45),
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}
