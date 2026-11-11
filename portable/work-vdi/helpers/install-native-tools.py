#!/usr/bin/env python3
"""Install shared Java/XML servers into the work-tools prefix; no administrator rights."""
import json, os, pathlib, platform, shlex, shutil, stat, subprocess, sys, tarfile, tempfile, urllib.request, zipfile

def fetch(url,target):
    request=urllib.request.Request(url,headers={'User-Agent':'work-vdi-editor-installer/1.0'})
    try:
        with urllib.request.urlopen(request,timeout=120) as source,open(target,'wb') as out:shutil.copyfileobj(source,out)
    except Exception as error:raise RuntimeError(f'{url}: {error}') from error
def safe_path(root,name):
    path=(root/name).resolve()
    if not path.is_relative_to(root.resolve()):raise RuntimeError('Archive path escapes destination')
    return path
def unpack_tar(archive,destination):
    with tarfile.open(archive) as tar:
        for member in tar.getmembers():
            safe_path(destination,member.name)
            if member.issym():safe_path(destination,str(pathlib.PurePosixPath(member.name).parent/member.linkname))
            elif member.islnk():safe_path(destination,member.linkname)
            elif not (member.isfile() or member.isdir()):raise RuntimeError('Unsupported archive member')
        tar.extractall(destination,**({'filter':'data'} if sys.version_info>=(3,12) else {}))
def activate(stage,target):
    previous=target.with_name(target.name+'.previous')
    if previous.exists():shutil.rmtree(previous)
    if target.exists():target.rename(previous)
    stage.rename(target)
def install(root,spec):
    share=root/'share';share.mkdir(parents=True,exist_ok=True);(root/'bin').mkdir(parents=True,exist_ok=True)
    target=share/'jdtls'
    if not (target/'.work-source').exists() or (target/'.work-source').read_text()!=spec['jdtls_url']:
        with tempfile.TemporaryDirectory(dir=share,prefix='.jdtls-') as tmp:
            tmp=pathlib.Path(tmp);archive=tmp/'jdtls.tar.gz';stage=tmp/'server';stage.mkdir()
            fetch(spec['jdtls_url'],archive);unpack_tar(archive,stage)
            if not (stage/'bin/jdtls').is_file():raise RuntimeError('JDTLS archive has no launcher')
            fetch(spec['lombok_url'],stage/'lombok.jar')
            (stage/'.work-source').write_text(spec['jdtls_url']);activate(stage,target)
    launcher=root/'bin/jdtls'
    launcher.write_text('#!/bin/sh\nexec python3 '+shlex.quote(str(target/'bin/jdtls'))+' '+shlex.quote('--jvm-arg=-javaagent:'+str(target/'lombok.jar'))+' "$@"\n');launcher.chmod(0o755)
    system={'Linux':'linux','Darwin':'osx'}.get(platform.system());arch={'x86_64':'x86_64','aarch64':'aarch_64','arm64':'aarch_64'}.get(platform.machine())
    if not system or not arch:raise RuntimeError('No LemMinX distribution for this OS/architecture')
    binary='lemminx-'+system+'-'+arch
    url=f"https://github.com/redhat-developer/vscode-xml/releases/download/{spec['lemminx_version']}/{binary}.zip"
    target=share/'lemminx'
    if not (target/'.work-source').exists() or (target/'.work-source').read_text()!=url:
        with tempfile.TemporaryDirectory(dir=share,prefix='.lemminx-') as tmp:
            tmp=pathlib.Path(tmp);archive=tmp/'server.zip';stage=tmp/'server';stage.mkdir();fetch(url,archive)
            with zipfile.ZipFile(archive) as zipped:
                for entry in zipped.infolist():
                    safe_path(stage,entry.filename)
                    if stat.S_ISLNK(entry.external_attr>>16):raise RuntimeError('Unexpected archive symlink')
                zipped.extractall(stage)
            candidate=next(iter(stage.rglob(binary)),None)
            if candidate is None:raise RuntimeError('LemMinX archive has no server executable')
            if candidate!=stage/binary:shutil.copyfile(candidate,stage/binary)
            (stage/binary).chmod(0o755);(stage/'.work-source').write_text(url);activate(stage,target)
    launcher=root/'bin/lemminx';launcher.write_text('#!/bin/sh\nexec '+shlex.quote(str(target/binary))+' "$@"\n');launcher.chmod(0o755)
    print('Installed shared JDTLS (with Lombok) and LemMinX servers.')
    if not shutil.which('java'):print('Java support needs JDK 21+ on PATH or JAVA_HOME.',file=sys.stderr)
if __name__=='__main__':
    try:install(pathlib.Path(sys.argv[1]).resolve(),json.loads(pathlib.Path(sys.argv[2]).read_text()))
    except Exception as error:print('Work server installation failed: '+str(error),file=sys.stderr);raise SystemExit(1)
