#!/usr/bin/env python3
"""Revisa el índice de Git y, opcionalmente, el historial sin mostrar secretos."""
import argparse
from pathlib import PurePosixPath
import re
import subprocess
import sys

PRIVATE_PARTS = {
    '.aws', '.ssh', '.gnupg', '.codex', '.agents', '.private', '.dart_tool',
    '.gradle', '.idea', '.vscode', '.pub-cache', '__pycache__', '.venv',
    'backups', 'exports', 'build', 'coverage',
}
PRIVATE_NAMES = {
    'key.properties', 'local.properties', '.flutter-plugins-dependencies',
    'google-services.json', 'googleservice-info.plist', 'imported_bible.json',
    'favorites.json', 'reading-progress.json',
}
PRIVATE_SUFFIXES = {'.jks', '.keystore', '.p12', '.pfx', '.pem', '.key', '.apk', '.aab', '.iml', '.log'}
BINARY_SUFFIXES = {'.png', '.ttf', '.otf', '.jar', '.ico', '.jpg', '.jpeg', '.webp'}
PATTERNS = {
    'clave privada': re.compile(r'-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----'),
    'token de GitHub': re.compile(r'(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})'),
    'clave de AWS': re.compile(r'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b'),
    'clave de Google': re.compile(r'\bAIza[0-9A-Za-z_-]{35}\b'),
    'token de servicio': re.compile(r'\b(?:sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{24,}|xox[baprs]-[A-Za-z0-9-]{20,})'),
    'credenciales en URL': re.compile(r'https?://[^\s/:@]+:[^\s/@]+@'),
    'ruta personal absoluta': re.compile(r'(?<![A-Za-z0-9_./:\\-])(?:/(?:home|Users)/[^/\s\'"<>]+|[A-Z]:\\Users\\[^\\\s\'"<>]+)'),
}
LITERAL_SECRET = re.compile(
    r"(?:api[_-]?key|client[_-]?secret|access[_-]?token)\s*[:=]\s*[\"']([A-Za-z0-9_+/=\-]{16,})[\"']", re.IGNORECASE)
EMAIL = re.compile(r'[A-Za-z0-9_.+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}')
PUBLIC_EMAILS = {'licensing@americanbible.org'}


def git(*args, check=True):
    result = subprocess.run(['git', *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if check and result.returncode:
        raise RuntimeError('No se pudo leer Git. Ejecuta este comando dentro del repositorio después de git add.')
    return result


def scan(path, data):
    """Devuelve categorías de problemas, nunca los valores encontrados."""
    name = PurePosixPath(path)
    lower_parts = {part.lower() for part in name.parts}
    lower_name = name.name.lower()
    problems = []
    if (lower_parts & PRIVATE_PARTS or lower_name in PRIVATE_NAMES
            or name.suffix.lower() in PRIVATE_SUFFIXES
            or (lower_name.startswith('.env') and lower_name not in {'.env.example', '.env.sample'})
            or lower_name.startswith('biblia-1960-respaldo-')
            or 'service-account' in lower_name or 'service_account' in lower_name
            or 'credentials' in lower_name):
        problems.append('archivo privado o generado incluido en Git')
    if name.suffix.lower() in BINARY_SUFFIXES:
        return problems
    if len(data) > 64 * 1024 * 1024:
        return problems + ['archivo demasiado grande para la revisión automática']
    text = data.decode('utf-8', errors='replace')
    for description, pattern in PATTERNS.items():
        if pattern.search(text):
            problems.append(description)
    for match in LITERAL_SECRET.finditer(text):
        if not match.group(1).startswith(('CHANGE_ME', 'YOUR_', 'EXAMPLE_')):
            problems.append('posible credencial literal')
            break
    if not path.startswith('assets/fonts/'):
        emails = EMAIL.findall(text)
        if any(email not in PUBLIC_EMAILS and not email.endswith('@users.noreply.github.com') for email in emails):
            problems.append('correo electrónico no permitido en archivos públicos')
    return problems


def scan_index():
    problems = []
    entries = git('ls-files', '--stage', '-z').stdout.split(b'\0')
    count = 0
    for entry in entries:
        if not entry:
            continue
        metadata, raw_path = entry.split(b'\t', 1)
        mode, oid, stage = metadata.split()
        path = raw_path.decode('utf-8', errors='replace')
        count += 1
        if stage != b'0' or mode not in {b'100644', b'100755'}:
            problems.append((path, 'enlace, submódulo o conflicto: revisar antes de publicar'))
            continue
        data = git('cat-file', 'blob', oid.decode()).stdout
        problems.extend((path, issue) for issue in scan(path, data))
    if not count:
        raise RuntimeError('No hay archivos en el índice. Ejecuta git add . antes de la revisión.')
    return count, problems


def scan_history():
    problems = []
    # Se revisan también archivos eliminados en commits antiguos y correos de autor/committer.
    commits = git('log', '--all', '--format=%h%x09%ae%x09%ce').stdout.decode().splitlines()
    for entry in commits:
        commit, author, committer = entry.split('\t')
        if any(not email.endswith('@users.noreply.github.com') for email in (author, committer)):
            problems.append((f'commit {commit}', 'correo de autor o committer sin protección noreply'))
    seen = set()
    for entry in git('rev-list', '--objects', '--all').stdout.splitlines():
        parts = entry.split(b' ', 1)
        if len(parts) != 2:
            continue
        oid, raw_path = parts
        path = raw_path.decode('utf-8', errors='replace')
        if git('cat-file', '-t', oid.decode()).stdout.strip() != b'blob':
            continue
        # Un mismo contenido puede haber tenido nombres seguros y privados.
        data = git('cat-file', 'blob', oid.decode()).stdout
        for issue in scan(path, data):
            key = (path, issue)
            if key not in seen:
                seen.add(key)
                problems.append((f'historial: {path}', issue))
    return len(commits), problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--staged', action='store_true', help='Revisar archivos del índice (comportamiento predeterminado).')
    parser.add_argument('--history', action='store_true', help='Revisar también todo el historial local accesible.')
    options = parser.parse_args()
    try:
        count, problems = scan_index()
        history_count = None
        if options.history:
            history_count, history_problems = scan_history()
            problems.extend(history_problems)
    except (RuntimeError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 2
    if problems:
        print('Revisión bloqueada. No se imprimen los valores sensibles:')
        for path, issue in problems:
            print(f'- {path!r}: {issue}')
        print('Retira estos datos del índice y del historial antes de publicar.')
        return 1
    print(f'Revisados {count} archivos del índice: no se detectaron patrones de credenciales, rutas personales ni archivos privados.')
    if options.history:
        print(f'Revisados {history_count} commits del historial local sin coincidencias ni correos personales.')
    print('Esta comprobación por patrones complementa la revisión manual; no garantiza ausencia absoluta de secretos.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
