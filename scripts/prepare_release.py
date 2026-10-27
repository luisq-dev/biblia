#!/usr/bin/env python3
"""Copia el APK ya compilado y genera su checksum para GitHub Releases."""
import hashlib
from pathlib import Path
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def main():
    source = ROOT / 'build/app/outputs/flutter-apk/app-release.apk'
    output = ROOT / 'build/release'
    if not source.is_file():
        sys.exit('Primero ejecuta flutter build apk --release siguiendo docs/PUBLICAR.md.')
    if not zipfile.is_zipfile(source):
        sys.exit('El archivo de compilación no es un APK válido.')
    with zipfile.ZipFile(source) as apk:
        names = set(apk.namelist())
        if 'AndroidManifest.xml' not in names or not any(name.startswith('lib/') for name in names):
            sys.exit('El APK no contiene la estructura esperada de una aplicación Flutter.')
    output.mkdir(parents=True, exist_ok=True)
    target = output / 'biblia-1960.apk'
    shutil.copyfile(source, target)
    with target.open('rb') as artifact:
        digest = hashlib.file_digest(artifact, 'sha256').hexdigest()
    (output / 'SHA256SUMS.txt').write_text(f'{digest}  {target.name}\n', encoding='ascii')
    print('Preparados: build/release/biblia-1960.apk y build/release/SHA256SUMS.txt')


if __name__ == '__main__':
    main()
