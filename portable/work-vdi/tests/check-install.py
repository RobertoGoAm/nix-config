#!/usr/bin/env python3
"""Exercise installation safely in temporary homes, with network tools stubbed."""
import json, os, pathlib, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
def run(args,env,expected=0,installer="install.sh"):
    p=subprocess.run(['sh',str(ROOT/installer)]+args,env=env,capture_output=True,text=True)
    assert p.returncode==expected,(p.returncode,p.stdout,p.stderr)
    return p
with tempfile.TemporaryDirectory(prefix='work-vdi-install-') as tmp:
    base=pathlib.Path(tmp);home=base/'home';home.mkdir()
    config=base/'config with spaces';data=base/'data with spaces'
    env={**os.environ,'HOME':str(home),'XDG_CONFIG_HOME':str(config),'XDG_DATA_HOME':str(data)}
    # Default profiles must survive; work config symlinks must not write through.
    (home/'.vimrc').write_text('existing vim')
    (home/'.emacs').write_text('existing emacs')
    (config/'nvim').mkdir(parents=True);(config/'nvim/init.lua').write_text('existing nvim')
    run(['--offline'],env)
    for src,dest in [('init.lua',config/'work-nvim/init.lua'),('init.el',config/'work-emacs/init.el'),
                     ('early-init.el',config/'work-emacs/early-init.el'),('vimrc',data/'work-vdi/vimrc')]:
        assert dest.read_bytes()==(ROOT/src).read_bytes()
    (config/'work-nvim/init.lua').unlink()
    target=base/'old-work-config';target.write_text('old work config')
    (config/'work-nvim/init.lua').symlink_to(target)
    run(['--offline','--qwerty'],env)
    assert target.read_text()=='old work config'
    assert not (config/'work-nvim/init.lua').is_symlink()
    assert 'local colemak = false' in (config/'work-nvim/init.lua').read_text()
    assert 'defvar work/colemak nil ' in (config/'work-emacs/init.el').read_text()
    assert any(p.read_text()=='old work config' for p in (data/'work-vdi/backups').glob('*/init.lua'))
    assert (home/'.vimrc').read_text()=='existing vim'
    assert any(p.read_text()=='existing emacs' for p in (data/'work-vdi/backups').glob('*/defaults/.emacs'))
    assert (home/'.emacs.d').resolve()==(config/'work-emacs').resolve()
    assert any(p.read_text()=='existing nvim' for p in (data/'work-vdi/backups').glob('*/defaults/nvim/init.lua'))
    assert (config/'nvim').resolve()==(config/'work-nvim').resolve()
    # The colleague installer must select QWERTY without any layout flag.
    run(['--offline'],env,installer='install-qwerty.sh')
    assert 'local colemak = false' in (config/'work-nvim/init.lua').read_text()
    assert 'defvar work/colemak nil ' in (config/'work-emacs/init.el').read_text()
    assert "get(g:, 'work_colemak', 0)" in (data/'work-vdi/vimrc').read_text()
    # Reinstallation keeps that default; the original installer stays Colemak.
    run(['--offline'],env,installer='install-qwerty.sh')
    assert 'local colemak = false' in (config/'work-nvim/init.lua').read_text()
    run(['--offline'],env)
    assert 'local colemak = true' in (config/'work-nvim/init.lua').read_text()
    run(['--offline','--tools'],env,2)
    run(['--offline','--editors'],env,2)
    run(['--invalid-option'],env,2)
    # Verify all downloaded/build commands and launcher paths without downloading.
    stubs=base/'stubs';stubs.mkdir();log=base/'calls.jsonl'
    stub='''#!/usr/bin/env python3
import sys,os,json,pathlib
name=pathlib.Path(sys.argv[0]).name
with open(os.environ['WORK_TEST_LOG'],'a') as f: f.write(json.dumps([name,sys.argv[1:],os.environ.get('NVIM_APPNAME'),os.environ.get('WORK_VDI_BOOTSTRAP')])+'\\n')
if name=='git' and 'clone' in sys.argv: pathlib.Path(sys.argv[-1]).mkdir(parents=True,exist_ok=True)
if name=='npm' and '--prefix' in sys.argv:
 p=pathlib.Path(sys.argv[sys.argv.index('--prefix')+1]);(p/'lib/node_modules').mkdir(parents=True,exist_ok=True)
if name=='python3' and '-m' in sys.argv and 'venv' in sys.argv:
 p=pathlib.Path(sys.argv[-1])/'bin';p.mkdir(parents=True,exist_ok=True)
 (p/'python').write_text('#!/bin/sh\\nexit 0\\n');(p/'python').chmod(0o755)
'''
    # Resolve interpreter before placing the python3 stub on PATH.
    import sys
    stub=stub.replace('#!/usr/bin/env python3','#!'+sys.executable)
    for name in ['git','nvim','emacs','npm','python3','cc','c++','tree-sitter','composer','php']:
        p=stubs/name;p.write_text(stub);p.chmod(0o755)
    env.update(PATH=str(stubs)+os.pathsep+os.environ['PATH'],WORK_TEST_LOG=str(log))
    legacy=data/'work-nvim/lazy/nvim-treesitter-textobjects/plugin/nvim-treesitter-textobjects.vim'
    legacy.parent.mkdir(parents=True,exist_ok=True)
    legacy.write_text('legacy plugin')
    run(['--editors','--tools'],env)
    assert not legacy.exists()
    assert any(p.read_text()=='legacy plugin' for p in (data/'work-vdi/backups').glob('*/plugins/nvim-treesitter-textobjects/plugin/nvim-treesitter-textobjects.vim'))

    calls=[json.loads(line) for line in log.read_text().splitlines()]
    assert any(name=='python3' and any(arg.endswith('/install-editors.py') for arg in args) for name,args,_,_ in calls)
    assert any(name=='npm' and '@vue/typescript-plugin' in args for name,args,_,_ in calls)
    assert any(name=='emacs' and 'work/install-packages' in args and bootstrap=='1' for name,args,_,bootstrap in calls)
    assert any(name=='emacs' and 'work/install-grammars' in args for name,args,_,_ in calls)
    assert any(name=='nvim' and app=='work-nvim' and '+Lazy! sync' in args for name,args,app,_ in calls)
    subprocess.run([str(home/'.local/bin/work-nvim'),'example.ts'],env=env,check=True)
    subprocess.run([str(home/'.local/bin/work-emacs'),'-nw'],env=env,check=True)
    calls=[json.loads(line) for line in log.read_text().splitlines()]
    assert calls[-2][0]=='nvim' and calls[-2][2]=='work-nvim'
    assert calls[-1][0]=='emacs' and '--init-directory='+str(config/'work-emacs') in calls[-1][1]
print('Installer verified: full payload, layouts, backups/symlinks, XDG paths, default-profile activation and backups, bootstrap commands and launchers.')
