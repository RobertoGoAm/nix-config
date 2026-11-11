#!/usr/bin/env python3
"""Shared stdin formatter. Prefer project tools; never replace the real source file."""
import json, os, pathlib, shutil, subprocess, sys, tempfile

def ancestors(file):
    parent=pathlib.Path(file).expanduser().resolve().parent
    return [parent,*parent.parents]
def local_tool(file,relative,fallback):
    for parent in ancestors(file):
        candidate=parent/relative
        if candidate.is_file() and os.access(candidate,os.X_OK):return str(candidate)
    return shutil.which(fallback)
def php_tool(file):
    for parent in ancestors(file):
        for relative,name in [('vendor/bin/pint','pint'),('vendor/bin/php-cs-fixer','php-cs-fixer'),('tools/php-cs-fixer/vendor/bin/php-cs-fixer','php-cs-fixer')]:
            p=parent/relative
            if p.is_file():return str(p),name,parent
    for name in ['pint','php-cs-fixer']:
        found=shutil.which(name)
        if found:return found,name,next((p for p in ancestors(file) if (p/'composer.json').exists()),pathlib.Path(file).resolve().parent)
    return None

def xml_plugin(file):
    tools=pathlib.Path(os.environ.get('XDG_DATA_HOME',str(pathlib.Path.home()/'.local/share')))/'work-vdi/tools'
    for root in [*(p/'node_modules' for p in ancestors(file)),tools/'lib/node_modules']:
        plugin=root/'@prettier/plugin-xml'
        if (plugin/'package.json').is_file():
            result=subprocess.run(['node','-e','process.stdout.write(require.resolve(process.argv[1]))',str(plugin)],capture_output=True,text=True)
            if result.returncode==0:return result.stdout
    return None

def main():
    args=sys.argv[1:];check=bool(args and args[0]=='--available')
    if check:args=args[1:]
    if len(args)!=2:raise SystemExit('usage: work-format [--available] php|xml|blade FILE')
    kind,file=args;file=str(pathlib.Path(file).expanduser().resolve())
    if kind=='php':
        selected=php_tool(file)
        if check:return 0 if selected and shutil.which('php') else 1
        if not selected:raise RuntimeError('Install project vendor/bin/pint or PHP-CS-Fixer, or use the PHP language-server formatter')
        executable,name,cwd=selected
        # A sibling temporary file preserves project-relative configuration lookup.
        with tempfile.NamedTemporaryFile(prefix='.work-vdi-format-',suffix='.php',dir=str(pathlib.Path(file).parent),delete=False) as out:
            temporary=pathlib.Path(out.name);out.write(sys.stdin.buffer.read())
        try:
            command=([executable,str(temporary)] if name=='pint' else [executable,'fix','--using-cache=no',str(temporary)])
            result=subprocess.run(command,cwd=cwd,capture_output=True,timeout=60)
            if result.returncode:raise RuntimeError(result.stderr.decode(errors='replace') or result.stdout.decode(errors='replace'))
            sys.stdout.buffer.write(temporary.read_bytes())
        finally:temporary.unlink(missing_ok=True)
        return 0
    if kind=='blade':
        executable=local_tool(file,'node_modules/.bin/blade-formatter','blade-formatter')
        if check:return 0 if executable else 1
        command=[executable,'--stdin'] if executable else None
        cwd=next((p for p in ancestors(file) if (p/'composer.json').exists()),pathlib.Path(file).parent)
    elif kind=='xml':
        executable=local_tool(file,'node_modules/.bin/prettier','prettier');plugin=xml_plugin(file) if executable else None
        if check:return 0 if executable and plugin else 1
        command=[executable,'--plugin',plugin,'--parser','xml','--stdin-filepath',file] if executable and plugin else None
        cwd=pathlib.Path(file).parent
    else:raise RuntimeError('Unknown formatter '+kind)
    if not command:raise RuntimeError('Formatter unavailable for '+kind)
    result=subprocess.run(command,input=sys.stdin.buffer.read(),cwd=cwd,capture_output=True,timeout=60)
    if result.returncode:raise RuntimeError(result.stderr.decode(errors='replace'))
    sys.stdout.buffer.write(result.stdout)
    return 0
if __name__=='__main__':
    try:raise SystemExit(main())
    except (OSError,RuntimeError,subprocess.SubprocessError) as error:
        print(str(error),file=sys.stderr);raise SystemExit(1)
