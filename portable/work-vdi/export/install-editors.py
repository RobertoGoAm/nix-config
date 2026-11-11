#!/usr/bin/env python3
"""Install versioned Linux editors and ordinary commands in a user's home."""
import hashlib, importlib.util, os, pathlib, platform, shlex, shutil, subprocess, sys, tempfile, time

NVIM_VERSION = '0.12.6'
EMACS_VERSION = '30.2'
NVIM_HASHES = {
    'x86_64': '474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87',
    'aarch64': '8f1f64a0bdb97247034038c3823c6cbad5bdf9ecd5751b85494b71c3ee04c815',
}
EMACS_HASHES = {
    'x86_64': '9bce97b2f3638d9d74181d0ff6a8a8da79368aafe27727d6cd8519f1502aa31d',
    'aarch64': '55ab47ac564bfbc94ff92e71d14a231dd195cce61427d7b64c97ce7d177048a5',
}


def support():
    spec = importlib.util.spec_from_file_location('native_tools', pathlib.Path(__file__).with_name('install-native-tools.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def download(native, url, path, digest):
    native.fetch(url, path)
    with path.open('rb') as stream:
        actual = hashlib.file_digest(stream, 'sha256').hexdigest() if sys.version_info >= (3, 11) else None
    if actual is None:
        hasher = hashlib.sha256()
        with path.open('rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                hasher.update(chunk)
        actual = hasher.hexdigest()
    if actual != digest:
        raise RuntimeError('Checksum mismatch for ' + url)


def validate(name, command):
    if name == 'nvim':
        args = ['--headless', '-u', 'NONE', '-i', 'NONE', '+lua if vim.fn.has("nvim-0.12")==0 then vim.cmd("cquit 1") end', '+qa']
    else:
        args = ['--batch', '-Q', '--eval', '(unless (and (>= emacs-major-version 29) (fboundp (quote treesit-available-p)) (treesit-available-p) (bound-and-true-p module-file-suffix)) (kill-emacs 1))']
    result = subprocess.run([str(command), *args], capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise RuntimeError(f'{name} cannot run with the required features on this VDI:\n{result.stderr[-3000:]}')


def replace_file(path, text, executable=False):
    if path.is_file() and not path.is_symlink() and path.read_bytes() == text.encode():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() or path.is_symlink():
        backup = path.with_name(path.name + '.before-work-vdi-' + str(time.time_ns()))
        path.rename(backup)
    path.write_text(text)
    if executable:
        path.chmod(0o755)


def install(home, data):
    if platform.system() != 'Linux':
        raise RuntimeError('--editors currently supports Linux/WSL; install editors normally on macOS.')
    arch = {'x86_64': 'x86_64', 'aarch64': 'aarch64', 'arm64': 'aarch64'}.get(platform.machine())
    if arch is None:
        raise RuntimeError('Editor downloads support Linux x86_64 and aarch64.')
    native = support()
    root = data / 'work-vdi/editors'
    root.mkdir(parents=True, exist_ok=True)
    installed = {}
    for name, version in [('nvim', NVIM_VERSION), ('emacs', EMACS_VERSION)]:
        target = root / (name + '-' + version)
        binary = target / ('bin/nvim' if name == 'nvim' else 'AppRun')
        if not binary.is_file():
            with tempfile.TemporaryDirectory(prefix='.' + name + '-', dir=root) as tmp:
                tmp = pathlib.Path(tmp)
                if name == 'nvim':
                    package = 'nvim-linux-' + ('arm64' if arch == 'aarch64' else arch)
                    archive = tmp / 'nvim.tar.gz'
                    download(native, f'https://github.com/neovim/neovim/releases/download/v{version}/{package}.tar.gz', archive, NVIM_HASHES[arch])
                    native.unpack_tar(archive, tmp)
                    stage = tmp / package
                    candidate = stage / 'bin/nvim'
                else:
                    image = tmp / 'emacs.AppImage'
                    url = f'https://github.com/blahgeek/emacs-appimage/releases/download/github-action-build-17008212441/Emacs-{version}-lucid-{arch}.AppImage'
                    download(native, url, image, EMACS_HASHES[arch])
                    image.chmod(0o755)
                    # Extract once: no FUSE package or privileged mount is needed.
                    result = subprocess.run([str(image), '--appimage-extract'], cwd=tmp, capture_output=True, text=True, timeout=180)
                    if result.returncode:
                        raise RuntimeError('Cannot extract Emacs AppImage: ' + result.stderr[-2000:])
                    stage = tmp / 'squashfs-root'
                    candidate = stage / 'AppRun'
                validate(name, candidate)
                native.activate(stage, target)
        validate(name, binary)
        command = home / '.local/bin' / name
        replace_file(command, '#!/bin/sh\nexec ' + shlex.quote(str(binary)) + ' "$@"\n', executable=True)
        installed[name] = command
    env_file = data / 'work-vdi/env.sh'
    replace_file(env_file, '# Work VDI user-installed editor commands\nexport PATH="$HOME/.local/bin:$PATH"\n')
    marker = '# Work VDI editor commands'
    block = '\n' + marker + '\n. ' + shlex.quote(str(env_file)) + '\n'
    shell_files = ['.profile', '.bashrc', '.zshrc']
    shell_files += [name for name in ['.bash_profile', '.bash_login'] if (home / name).exists()]
    for filename in shell_files:
        rc = home / filename
        old = rc.read_text() if rc.exists() else ''
        if marker not in old:
            # Preserve the shell file's identity (including symlinks) and contents.
            if rc.exists():
                shutil.copyfile(rc, rc.with_name(rc.name + '.before-work-vdi-' + str(time.time_ns())))
            with rc.open('a') as stream:
                stream.write(block)
    for name, command in installed.items():
        # Desktop Exec fields use double-quote escaping, not shell quoting.
        quoted = '"' + str(command).replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%') + '"'
        desktop = f'[Desktop Entry]\nType=Application\nName={"Emacs" if name == "emacs" else "Neovim"}\nExec={quoted} %F\nIcon=accessories-text-editor\nTerminal={"true" if name == "nvim" else "false"}\nCategories=Development;TextEditor;\n'
        replace_file(data / 'applications' / (name + '.desktop'), desktop)
    print('Installed Neovim ' + NVIM_VERSION + ' and Emacs ' + EMACS_VERSION + ' without sudo.')
    print('Open a new terminal, or run: . ' + shlex.quote(str(env_file)))


if __name__ == '__main__':
    try:
        install(pathlib.Path.home(), pathlib.Path(os.environ.get('XDG_DATA_HOME', str(pathlib.Path.home() / '.local/share'))).resolve())
    except Exception as error:
        print('Editor installation failed: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
