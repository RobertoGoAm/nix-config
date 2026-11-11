#!/usr/bin/env python3
"""Export the repository's actual work modules; Nix is only needed to regenerate."""
import json, re, subprocess, pathlib
ROOT=pathlib.Path(__file__).resolve().parents[3]
OUT=ROOT/'portable/work-vdi'
BASE=ROOT/'modules/home-manager/features/development'
source=subprocess.check_output(['nix','eval','--impure','--raw','--expr',f'(builtins.getFlake "{ROOT}").inputs.nixpkgs.outPath'],text=True).strip()
run=subprocess.run(['nix','eval','--impure','--json','--expr',f'import {OUT}/export/evaluate.nix {{ nixpkgsSource = {json.dumps(source)}; root = {json.dumps(str(ROOT))}; }}'],capture_output=True,text=True)
if run.returncode:
    print(run.stderr);raise SystemExit(run.returncode)
data=json.loads(run.stdout)
plugin_sources={}
generated=pathlib.Path(source)/'pkgs/applications/editors/vim/plugins/generated.nix'
for block in re.findall(r'  [\w-]+ = buildVimPlugin \{(.*?)\n  \};',generated.read_text(),re.S):
    owner=re.search(r'owner = "([^"\n]+)"',block)
    repo=re.search(r'repo = "([^"\n]+)"',block)
    rev=re.search(r'(rev|tag) = "([^"\n]+)"',block)
    if owner and repo and rev:plugin_sources[owner[1]+'/'+repo[1]]={rev[1]:rev[2]}
data['plugin_sources']=plugin_sources
(OUT/'export/evaluated.json').write_text(json.dumps(data,indent=2))
print(f"Exported {len(data['emacs'])} Emacs modules and {len(data['helpers'])} coding helper tools")
