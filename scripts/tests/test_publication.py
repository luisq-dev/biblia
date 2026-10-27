import importlib.util
from pathlib import Path
import unittest
from unittest import mock
import contextlib
import hashlib
import io
import stat
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]

def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

checker = load('check_publication')
signing = load('configure_signing')
release = load('prepare_release')

class PublicationTest(unittest.TestCase):
    def test_private_files(self):
        for path in ('android/local.properties', '.aws/config', 'android/key.properties',
                     '.private/signing/release.jks', 'biblia-1960-respaldo-example.json', 'build/app.apk'):
            self.assertTrue(checker.scan(path, b''), path)

    def test_detects_tokens_without_values_in_messages(self):
        token = 'ghp_' + 'A' * 36
        found = checker.scan('lib/example.dart', token.encode())
        self.assertIn('token de GitHub', found)
        self.assertNotIn(token, str(found))

    def test_paths_and_emails(self):
        private_path = '/' + 'home' + '/example/private.json'
        self.assertTrue(checker.scan('file.txt', private_path.encode()))
        self.assertTrue(checker.scan('file.txt', ('personal' + '@example.test').encode()))
        self.assertFalse(checker.scan('lib/app.dart', b"import 'package:biblia/ui/home/home_shell.dart';"))
        self.assertFalse(checker.scan('file.txt', b'123+example@users.noreply.github.com'))

    def test_public_examples_and_licenses(self):
        self.assertFalse(checker.scan('android/key.properties.example', b'storePassword=CHANGE_ME'))
        self.assertFalse(checker.scan('assets/fonts/OFL.txt', b'Public font attribution'))

    def test_java_properties_escaping(self):
        self.assertEqual(signing.property_value('a=b:c\\d'), 'a\\=b\\:c\\\\d')
        self.assertEqual(signing.property_value('a b'), 'a\\ b')
        self.assertEqual(signing.property_value('ñ'), '\\u00f1')
        self.assertEqual(signing.property_value('😀'), '\\ud83d\\ude00')


    def test_history_catches_a_removed_private_file(self):
        with tempfile.TemporaryDirectory() as directory:
            def fixture_git(*args, check=True):
                result = subprocess.run(['git', *args], cwd=directory,
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
                if check and result.returncode:
                    raise RuntimeError(result.stderr.decode())
                return result
            fixture_git('init', '-b', 'main')
            fixture_git('config', 'user.name', 'example')
            fixture_git('config', 'user.email', '123+example@users.noreply.github.com')
            private = Path(directory) / 'key.properties'
            private.write_text('private signing configuration')
            fixture_git('add', '.')
            fixture_git('commit', '-m', 'initial')
            private.unlink()
            (Path(directory) / 'README.md').write_text('Public project')
            fixture_git('add', '-A')
            fixture_git('commit', '-m', 'remove private file')
            with mock.patch.object(checker, 'git', side_effect=fixture_git):
                count, current = checker.scan_index()
                history_count, history = checker.scan_history()
            self.assertEqual(count, 1)
            self.assertFalse(current)
            self.assertEqual(history_count, 2)
            self.assertTrue(any('key.properties' in path for path, issue in history))

    def test_signing_writes_private_file_without_logging_password(self):
        with tempfile.TemporaryDirectory() as directory:
            keystore = Path(directory) / 'release.jks'
            keystore.write_bytes(b'fixture')
            properties = Path(directory) / 'key.properties'
            entered = 'local-' + 'passphrase'
            output = io.StringIO()
            with mock.patch.object(signing, 'KEYSTORE', keystore), mock.patch.object(signing, 'PROPERTIES', properties), \
                    mock.patch.object(signing.getpass, 'getpass', side_effect=[entered, '']), \
                    mock.patch.object(signing.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)), \
                    contextlib.redirect_stdout(output):
                signing.main()
                with self.assertRaises(SystemExit):
                    signing.main()
            self.assertEqual(stat.S_IMODE(properties.stat().st_mode), 0o600)
            self.assertIn('storePassword=' + entered, properties.read_text())
            self.assertNotIn(entered, output.getvalue())

    def test_release_asset_checksum_and_missing_build(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(release, 'ROOT', Path(directory)):
            with self.assertRaises(SystemExit):
                release.main()
            apk = Path(directory) / 'build/app/outputs/flutter-apk/app-release.apk'
            apk.parent.mkdir(parents=True)
            with zipfile.ZipFile(apk, 'w') as archive:
                archive.writestr('AndroidManifest.xml', 'manifest fixture')
                archive.writestr('lib/arm64-v8a/libapp.so', 'native fixture')
            with contextlib.redirect_stdout(io.StringIO()):
                release.main()
            asset = Path(directory) / 'build/release/biblia-1960.apk'
            self.assertEqual(asset.read_bytes(), apk.read_bytes())
            digest = hashlib.sha256(asset.read_bytes()).hexdigest()
            self.assertEqual((asset.parent / 'SHA256SUMS.txt').read_text(), digest + '  biblia-1960.apk\n')

if __name__ == '__main__':
    unittest.main()
