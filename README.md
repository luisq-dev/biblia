<p align="center">
  <img src="assets/branding/icon-512.png" width="96" height="96" alt="Icono de Biblia 1960">
</p>

# Biblia 1960

Aplicación para Android desarrollada con Flutter. Lectura bíblica sin conexión, búsqueda, favoritos y progreso guardado en el dispositivo.

[Descargar APK](https://github.com/luisq-dev/biblia/releases/latest/download/biblia-1960.apk) · [Ver versiones](https://github.com/luisq-dev/biblia/releases) · [Privacidad](PRIVACY.md)

> La descarga estará disponible cuando el mantenedor publique la primera release con el archivo `biblia-1960.apk`. El texto RVR1960 requiere autorización de redistribución; consulta [las licencias y avisos](THIRD_PARTY_NOTICES.md).

## Funciones

- Seleccionar y deseleccionar versículos con un toque, o seleccionar varios manteniendo pulsado y arrastrando.
- Copiar, compartir y guardar favoritos.
- Buscar palabras o frases, con filtros por libro y testamento.
- Marcar capítulos como leídos y consultar el progreso.
- Recuperar el versículo y el desplazamiento donde dejaste la lectura.
- Exportar e importar favoritos, capítulos leídos, historial, posición y ajustes en JSON.
- Elegir entre tema claro, oscuro o del sistema, ocho paletas y tres fuentes sin conexión: Literata, Clásica y Moderna.
- Animación de bienvenida con un libro, halo dorado y destellos: dura 2,4 segundos, se puede omitir y respeta la opción del sistema para reducir las animaciones. La lectura se prepara al mismo tiempo, sin un mensaje de «cargando versículos».

## Descargar e instalar

1. Abre [la última release](https://github.com/luisq-dev/biblia/releases/latest).
2. Descarga `biblia-1960.apk` en tu teléfono Android (Android 7 / API 24 o superior).
3. Abre el APK y permite la instalación desde el navegador o gestor de archivos cuando Android lo solicite.

La release incluye `SHA256SUMS.txt`. Para comprobar una descarga en Linux, coloca ambos archivos en la misma carpeta y ejecuta:

```sh
sha256sum --check SHA256SUMS.txt
```

Antes de cambiar entre una versión de desarrollo y la versión pública firmada, exporta tus datos desde Ajustes. Las actualizaciones de versiones públicas deben usar la misma firma; de lo contrario Android rechazará la actualización.

## Respaldos y privacidad

En **Ajustes → Respaldo**, elige «Exportar respaldo JSON» o «Importar respaldo JSON». La importación valida el archivo y solicita confirmación: **restaurar reemplaza los datos personales actuales** por los del respaldo.

Los respaldos incluyen el texto y la fecha de los favoritos, progreso, historial, posición y apariencia. No duplican la Biblia instalada. El formato es `biblia1960.backup`, versión `1`, con un límite de 32 MB. No publiques tus respaldos en GitHub. Más información en [PRIVACY.md](PRIVACY.md).

## Desarrollo

Requisitos: Flutter **3.47.7**, Dart compatible con `pubspec.yaml`, Android SDK, JDK compatible con Gradle y Python **3.11+** para las herramientas de publicación.

```sh
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos
flutter test
flutter run
```

La búsqueda completa se prepara cuando se solicita y el trabajo grande se ejecuta en un isolate. Las otras pestañas se crean en su primera visita y conservan su estado. La selección actualiza las filas afectadas y el tamaño de letra se previsualiza antes de aplicarlo al capítulo.

## Publicar en GitHub

La guía [docs/PUBLICAR.md](docs/PUBLICAR.md) contiene los comandos **uno por uno** para:

- Usar un correo público `noreply` en los commits.
- Revisar archivos y el historial antes del primer envío.
- Crear una clave de firma privada y compilar un APK de publicación.
- Crear una GitHub Release con APK y checksum.

La firma, sus contraseñas, rutas locales, cachés y respaldos se excluyen del repositorio. La clave permanece en el equipo del mantenedor; el flujo manual no requiere subir secretos de firma a GitHub Actions.

Antes de publicar, ejecuta después de `git add .`:

```sh
python3 scripts/check_publication.py --staged --history
```

GitHub Actions ejecuta la revisión del código y las pruebas. No publica APK ni dispone de claves privadas de firma.

## Texto bíblico, fuentes y licencia

El repositorio utiliza el formato JSON local de la app. El archivo de texto configurado es `assets/bible/rvr1960.json`; una importación local tiene prioridad.

La RVR1960 y sus marcas mantienen sus derechos propios. Una indicación de «uso personal» en un archivo no acredita permiso para redistribuir el texto completo. La publicación del código y la del texto son decisiones separadas del mantenedor.

Las fuentes incluyen sus licencias en `assets/fonts/`. El original del icono está en `assets/branding/icon.svg`.

Consulta [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). El titular aún no ha asignado una licencia de software al código propio; no se atribuye una licencia MIT ni se incluyen los contenidos de terceros bajo una licencia nueva.
