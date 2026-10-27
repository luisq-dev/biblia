#!/usr/bin/env python3
"""Guarda la firma local sin contraseñas en argumentos, historial ni archivos públicos."""
import getpass
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
KEYSTORE = ROOT / '.private' / 'signing' / 'release.jks'
PROPERTIES = ROOT / 'android' / 'key.properties'


def property_value(value):
    # Escapar Unicode también evita problemas con la codificación ISO-8859-1 de Java Properties.
    result = []
    for char in value:
        code = ord(char)
        if code > 0xFFFF:
            code -= 0x10000
            result.extend((f'\\u{0xD800 + (code >> 10):04x}', f'\\u{0xDC00 + (code & 0x3FF):04x}'))
        elif code > 0x7E or code < 0x20:
            result.append(f'\\u{code:04x}')
        elif char in '\\ =:#!':
            result.append('\\' + char)
        else:
            result.append(char)
    return ''.join(result)


def main():
    if not KEYSTORE.is_file():
        sys.exit('Primero crea .private/signing/release.jks siguiendo docs/PUBLICAR.md.')
    if PROPERTIES.exists():
        sys.exit('android/key.properties ya existe. No se sobrescribió tu configuración de firma.')
    store_password = getpass.getpass('Contraseña del almacén de claves: ')
    key_password = getpass.getpass('Contraseña de la clave (Enter para usar la misma): ') or store_password
    if not store_password:
        sys.exit('La contraseña no puede estar vacía.')
    # Comprobar el almacén sin revelar la contraseña en la línea de comandos.
    verification_env = dict(os.environ)
    verification_env['BIBLIA_SIGNING_PASSWORD'] = store_password
    checked = subprocess.run(
        ['keytool', '-list', '-keystore', str(KEYSTORE), '-alias', 'biblia1960',
         '-storepass:env', 'BIBLIA_SIGNING_PASSWORD'], env=verification_env,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False,
    )
    if checked.returncode:
        sys.exit('No se pudo validar el almacén, su contraseña o el alias biblia1960. No se escribió ningún archivo.')
    values = {'storeFile': str(KEYSTORE), 'storePassword': store_password,
              'keyAlias': 'biblia1960', 'keyPassword': key_password}
    descriptor = os.open(PROPERTIES, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w', encoding='ascii') as output:
        output.write(''.join(f'{key}={property_value(value)}\n' for key, value in values.items()))
    print('Firma configurada en android/key.properties (privado, excluido de Git).')


if __name__ == '__main__':
    main()
