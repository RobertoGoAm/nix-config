#!/usr/bin/env python3
"""Coverage and project-formatting tests; never download or mutate a real project."""
import importlib.util,json,os,pathlib,subprocess,sys,tarfile,tempfile,io,zipfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
stack=json.loads((ROOT/'export/language-stack.json').read_text())
assert {'java','php','php_only','blade','python','javascript','typescript','tsx','html','css','scss','vue','yaml','json','xml','dtd','properties'} <= set(stack['grammars'])
assert {'intelephense','@vue/language-server','pyright','blade-formatter','@prettier/plugin-xml','vscode-langservers-extracted'} <= set(stack['npm'])
assert {'black','ruff','yamllint'} <= set(stack['pip'])

def module(name,file):
    spec=importlib.util.spec_from_file_location(name,file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
native=module('work_native',ROOT/'export/install-native-tools.py')
with tempfile.TemporaryDirectory(prefix='work-stack-check-') as tmp:
    tmp=pathlib.Path(tmp);project=tmp/'project with spaces';(project/'vendor/bin').mkdir(parents=True)
    (project/'composer.json').write_text('{}')
    file=project/'Example.php';file.write_text('<?php ORIGINAL;')
    bin=tmp/'bin';bin.mkdir()
    php=bin/'php';php.write_text('#!/bin/sh\nexit 0\n');php.chmod(0o755)
    pint=project/'vendor/bin/pint';pint.write_text('#!'+sys.executable+'\nimport pathlib,sys\np=pathlib.Path(sys.argv[-1]);p.write_text(p.read_text().replace("UNFORMATTED", "FORMATTED"))\n');pint.chmod(0o755)
    env={**os.environ,'PATH':str(bin)+os.pathsep+os.environ['PATH']}
    formatter=[sys.executable,str(ROOT/'export/work-format.py')]
    result=subprocess.run(formatter+['--available','php',str(file)],env=env,capture_output=True);assert result.returncode==0
    result=subprocess.run(formatter+['php',str(file)],input=b'<?php UNFORMATTED;',env=env,capture_output=True)
    assert result.returncode==0,result.stderr
    assert result.stdout==b'<?php FORMATTED;' and file.read_text()=='<?php ORIGINAL;'
    assert not list(project.glob('.work-vdi-format-*'))
    pint.write_text('#!/bin/sh\nexit 1\n');pint.chmod(0o755)
    result=subprocess.run(formatter+['php',str(file)],input=b'BROKEN',env=env,capture_output=True)
    assert result.returncode==1 and file.read_text()=='<?php ORIGINAL;'
    assert not list(project.glob('.work-vdi-format-*'))
    # The native installer is tested with local archives through its download boundary.
    calls=[]
    def fixture_fetch(url,target):
        calls.append(url)
        if 'jdt-language-server-' in url:
            with tarfile.open(target,'w:gz') as archive:
                text=b'import sys\nprint("jdtls fixture",*sys.argv[1:])\n';entry=tarfile.TarInfo('bin/jdtls');entry.size=len(text);entry.mode=0o755;archive.addfile(entry,io.BytesIO(text))
        elif url.endswith('.zip'):
            system={'Linux':'linux','Darwin':'osx'}[native.platform.system()]
            arch={'x86_64':'x86_64','arm64':'aarch_64','aarch64':'aarch_64'}[native.platform.machine()]
            with zipfile.ZipFile(target,'w') as archive:archive.writestr('lemminx-'+system+'-'+arch,'#!/bin/sh\necho xml-fixture\n')
        else:pathlib.Path(target).write_bytes(b'lombok-fixture')
    native.fetch=fixture_fetch;tools=tmp/'native tools'
    native.install(tools,stack);assert len(calls)==3
    native.install(tools,stack);assert len(calls)==3,'Reinstallation downloaded unchanged assets'
    result=subprocess.run([str(tools/'bin/jdtls'),'-data',str(tmp/'workspace')],capture_output=True,text=True)
    assert result.returncode==0 and '-javaagent:' in result.stdout and 'workspace' in result.stdout
    result=subprocess.run([str(tools/'bin/lemminx')],capture_output=True,text=True)
    assert result.returncode==0 and 'xml-fixture' in result.stdout
    archive=tmp/'unsafe.tar.gz'
    with tarfile.open(archive,'w:gz') as tar:
        entry=tarfile.TarInfo('../escape');entry.size=1;tar.addfile(entry,io.BytesIO(b'x'))
    try:native.unpack_tar(archive,tmp/'extract')
    except RuntimeError:pass
    else:raise AssertionError('Archive escaped target')
print('Language stack, project formatter priority, unsaved-content isolation, failure cleanup, native launchers and repeat installation verified.')
