# Publicar Biblia 1960 manualmente

Ejecuta cada bloque por separado. Esta guía prepara un primer envío a un repositorio **vacío** en `https://github.com/luisq-dev/biblia.git`. No utiliza `push --force` ni incluye contraseñas en los comandos.

## Antes de empezar

Necesitas Git, GitHub CLI (`gh`), Python 3.11 o superior, Flutter 3.47.7 y Android SDK. Para compilar usa un JDK compatible con Gradle 9.3.1 (por ejemplo JDK 17); `keytool` viene con el JDK. Comprueba que `flutter doctor` reconoce Android.

El texto RVR1960 local declara uso personal. Antes de hacerlo público en el repositorio o dentro del APK, confirma que tienes autorización para redistribuirlo. No subas documentos privados de autorización. Consulta [las condiciones del titular](https://bibles.com/pages/american-bible-society-rights-and-permissions).

Esta sesión de preparación no modifica ni publica tu historial Git. Si tienes commits anteriores, la revisión `--history` debe pasar antes de enviar nada. Si el remoto ya tiene ramas, integra su contenido antes de seguir; no lo sobrescribas con un envío forzado.

## 1. Entrar y autenticarte

En Arch Linux, instala GitHub CLI si todavía no tienes `gh`:

```sh
sudo pacman -S --needed github-cli
```

Sustituye esta ruta por la carpeta del proyecto:

```sh
cd /ruta/a/biblia
```

```sh
gh auth login --hostname github.com --git-protocol https --web
```

```sh
gh auth setup-git
```

```sh
gh repo view luisq-dev/biblia
```

Si todavía no existe, créalo vacío y público:

```sh
gh repo create luisq-dev/biblia --public
```

Comprueba si ya hay ramas remotas:

```sh
git ls-remote --heads https://github.com/luisq-dev/biblia.git
```

Si devuelve referencias `refs/heads/...`, detente para integrar ese historial. El flujo que sigue asume que no existen ramas en el remoto.

## 2. Preparar Git sin exponer tu correo personal

```sh
git init -b main
```

```sh
git branch -M main
```

```sh
git config user.name "luisq-dev"
```

Esta instrucción usa tu identificador público de GitHub para construir una dirección `noreply`; no consulta tu correo personal:

```sh
git config user.email "$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"')"
```

```sh
git remote add origin https://github.com/luisq-dev/biblia.git
```

Si ya existe `origin`, consulta `git remote -v` y cambia únicamente su URL:

```sh
git remote set-url origin https://github.com/luisq-dev/biblia.git
```

## 3. Comprobar y publicar el código

```sh
flutter pub get --enforce-lockfile
```

```sh
flutter analyze --fatal-infos
```

```sh
flutter test
```

```sh
python3 -m unittest discover -s scripts/tests -v
```

```sh
git add .
```

```sh
python3 scripts/check_publication.py --staged --history
```

```sh
git diff --cached --stat
```

Revisa la lista. No debe contener `.private`, `key.properties`, `local.properties`, respaldos personales, claves, cachés ni APK. Los APK se distribuyen como adjuntos de Releases.

```sh
git commit -m "Preparar Biblia 1960 para publicación"
```

Vuelve a revisar para incluir el correo del nuevo commit:

```sh
python3 scripts/check_publication.py --staged --history
```

```sh
git push -u origin main
```

En GitHub, verifica que el repositorio es público y activa **Secret scanning / Push protection**, si aparece en sus ajustes de seguridad. La comprobación local es por patrones, no una garantía absoluta de ausencia de secretos. Los errores del verificador no imprimen las credenciales detectadas.

## 4. Crear la firma privada (solo la primera vez)

No ejecutes este paso si ya tienes la clave con la que publicaste una versión anterior. Las actualizaciones deben mantener esa clave. Una clave nueva no permite actualizar una instalación firmada con una clave distinta; exporta antes tus datos desde Ajustes si migras desde la app de desarrollo.

```sh
install -d -m 700 .private/signing
```

El certificado usa el nombre de la aplicación y no pide tu nombre personal ni tu correo. `keytool` solicitará las contraseñas de forma interactiva. En la contraseña de la clave puedes pulsar Enter para reutilizar la del almacén.

```sh
keytool -genkeypair -v -keystore .private/signing/release.jks -storetype JKS -alias biblia1960 -keyalg RSA -keysize 3072 -validity 10000 -dname "CN=Biblia 1960"
```

El siguiente script solicita las contraseñas sin mostrarlas y escribe `android/key.properties` con permisos `600`. No sobrescribe una configuración existente.

```sh
python3 scripts/configure_signing.py
```

Conserva una copia privada de la clave y sus contraseñas fuera del repositorio. `.private/` y `android/key.properties` están excluidos de Git.

## 5. Compilar el APK público

```sh
flutter build apk --release --obfuscate --split-debug-info=.private/symbols/v1.0.0
```

La compilación de publicación falla si falta la configuración de firma; no utiliza la firma de depuración como alternativa. Los símbolos privados permiten diagnosticar errores de la compilación ofuscada y no se adjuntan a la release.

```sh
python3 scripts/prepare_release.py
```

Se crean `build/release/biblia-1960.apk` y `build/release/SHA256SUMS.txt`. Prueba ese APK en un teléfono antes de publicarlo, incluyendo lectura, exportación e importación de JSON. Puedes instalarlo mediante:

```sh
adb install -r build/release/biblia-1960.apk
```

Comprueba que no se agregaron archivos privados accidentalmente:

```sh
git status --short
```

```sh
python3 scripts/check_publication.py --staged --history
```

## 6. Publicar la descarga

Las instrucciones usan la versión inicial `1.0.0+1` de `pubspec.yaml`. No reutilices etiquetas de versiones ya publicadas.

```sh
git tag v1.0.0
```

```sh
git push origin v1.0.0
```

```sh
gh release create v1.0.0 build/release/biblia-1960.apk build/release/SHA256SUMS.txt --repo luisq-dev/biblia --verify-tag --latest --title "Biblia 1960 v1.0.0" --notes-file docs/RELEASE_NOTES.md
```

```sh
gh release view v1.0.0 --repo luisq-dev/biblia --web
```

El enlace estable del README quedará operativo:

https://github.com/luisq-dev/biblia/releases/latest/download/biblia-1960.apk

Para futuras versiones, aumenta la versión y el número de compilación en `pubspec.yaml`, actualiza `AppInfo.version` y las notas, y usa una nueva etiqueta y carpeta de símbolos. Reutiliza la clave de firma original.

## Fuentes de referencia

- [Publicar y firmar Android con Flutter](https://docs.flutter.dev/deployment/android).
- [Crear una release con GitHub CLI](https://cli.github.com/manual/gh_release_create).
- [Enlaces permanentes a Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases).
- [Direcciones de correo privadas de GitHub](https://docs.github.com/en/account-and-profile/reference/email-addresses-reference).
