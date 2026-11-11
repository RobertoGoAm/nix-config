#!/usr/bin/env python3
"""Test user editor installation with executable archive fixtures; no network."""
import hashlib, importlib.util, io, os, pathlib, subprocess, tarfile, tempfile
from unittest.mock import patch
ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('editors', ROOT / 'export/install-editors.py')
editors = importlib.util.module_from_spec(spec)
spec.loader.exec_module(editors)
with tempfile.TemporaryDirectory(prefix='work-editors-') as tmp:
    base = pathlib.Path(tmp)
    home = base / 'home with spaces'; home.mkdir()
    data = home / '.local/share'
    (home / '.local/bin').mkdir(parents=True)
    (home / '.local/bin/nvim').write_bytes(b'old nvim\xff')
    (home / '.bashrc').write_text('# original bashrc\n')
    archive = base / 'nvim.tar.gz'
    with tarfile.open(archive, 'w:gz') as tar:
        payload = b'#!/bin/sh\nexit 0\n'
        entry = tarfile.TarInfo('nvim-linux-x86_64/bin/nvim')
        entry.size = len(payload); entry.mode = 0o755
        tar.addfile(entry, io.BytesIO(payload))
    # The fixture AppImage exercises extraction, validation, relocation and args.
    image = b'''#!/bin/sh
if [ "$1" = --appimage-extract ]; then
  mkdir -p squashfs-root
  printf '#!/bin/sh\\nprintf "%%s\\\\n" "$@"\\n' > squashfs-root/AppRun
  chmod +x squashfs-root/AppRun
fi
'''
    native = editors.support()
    calls = []
    def fetch(url, target):
        calls.append(url)
        target.write_bytes(archive.read_bytes() if 'neovim' in url else image)
    editors.NVIM_HASHES['x86_64'] = hashlib.sha256(archive.read_bytes()).hexdigest()
    editors.EMACS_HASHES['x86_64'] = hashlib.sha256(image).hexdigest()
    with patch.object(editors.platform, 'system', return_value='Linux'), patch.object(editors.platform, 'machine', return_value='x86_64'), patch.object(editors, 'support', return_value=native), patch.object(native, 'fetch', side_effect=fetch):
        editors.install(home, data)
        assert len(calls) == 2
        assert any(p.read_bytes() == b'old nvim\xff' for p in (home / '.local/bin').glob('nvim.before-work-vdi-*'))
        assert (home / '.bashrc').read_text().startswith('# original bashrc\n')
        assert (home / '.bashrc').read_text().count('# Work VDI editor commands') == 1
        subprocess.run([str(home / '.local/bin/nvim'), '--version'], check=True)
        args = subprocess.check_output([str(home / '.local/bin/emacs'), 'file with spaces.py', '-nw'], text=True)
        assert 'file with spaces.py' in args and '-nw' in args
        assert 'Terminal=false' in (data / 'applications/emacs.desktop').read_text()
        assert 'Terminal=true' in (data / 'applications/nvim.desktop').read_text()
        env_file = data / 'work-vdi/env.sh'
        found = subprocess.check_output(['sh', '-c', '. "$1"; command -v nvim; command -v emacs', 'sh', str(env_file)], env={**os.environ, 'HOME': str(home)}, text=True)
        assert str(home / '.local/bin/nvim') in found and str(home / '.local/bin/emacs') in found
        editors.install(home, data)
        assert len(calls) == 2
        assert (home / '.bashrc').read_text().count('# Work VDI editor commands') == 1
        try:
            editors.download(native, 'bad-download', base / 'bad', '0' * 64)
        except RuntimeError as error:
            assert 'Checksum mismatch' in str(error)
        else:
            raise AssertionError('Bad download was accepted')
print('Editor download verification, extraction, validation, command arguments, PATH, desktop entries, backups and repeat installation passed (fixtures).')
