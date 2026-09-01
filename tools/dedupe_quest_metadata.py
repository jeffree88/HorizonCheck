#!/usr/bin/env python3
"""Remove exact duplicate descriptive assignments from later quest metadata layers.

The quest loader applies files in a fixed order. If a later layer assigns exactly
what an earlier layer already supplied for the same quest/field, the assignment is
redundant. This tool removes only those exact duplicates. Requirement fields,
quality/scope authority flags, and horizon provenance are intentionally excluded.
"""
from __future__ import annotations
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'data'
FILES = [
    'quest_metadata.lua','quest_metadata_bulk.lua','quest_metadata_generated.lua',
    'quest_metadata_scope.lua','quest_metadata_completion.lua','quest_metadata_completion2.lua',
    'quest_metadata_completion3.lua','quest_metadata_completion4.lua','quest_metadata_quality.lua',
    'quest_metadata_verify.lua','quest_metadata_checkreqs.lua',
]
SKIP = {'requirements','requirements_mapped','catalog_quality_verified','catalog_scope_excluded','horizon'}
ENTRY = re.compile(r"^(\s*\['([^']+)'\]\s*=\s*\{)(.*)(\}\s*,?\s*)$")

def split_fields(s: str):
    out=[]; start=0; depth=0; quote=None; esc=False
    for i,ch in enumerate(s):
        if quote:
            if esc: esc=False
            elif ch=='\\': esc=True
            elif ch==quote: quote=None
        else:
            if ch in "'\"": quote=ch
            elif ch=='{': depth+=1
            elif ch=='}': depth-=1
            elif ch==',' and depth==0:
                out.append(s[start:i].strip()); start=i+1
    tail=s[start:].strip()
    if tail: out.append(tail)
    return out

def parse_field(f: str):
    depth=0; quote=None; esc=False
    for i,ch in enumerate(f):
        if quote:
            if esc: esc=False
            elif ch=='\\': esc=True
            elif ch==quote: quote=None
        else:
            if ch in "'\"": quote=ch
            elif ch=='{': depth+=1
            elif ch=='}': depth-=1
            elif ch=='=' and depth==0:
                return f[:i].strip(), f[i+1:].strip()
    return None, None

def process(check: bool=False) -> int:
    state={}; total=0
    for name in FILES:
        path=DATA/name
        lines=path.read_text(encoding='utf-8',errors='replace').splitlines()
        out=[]; removed=0
        for line in lines:
            m=ENTRY.match(line)
            if not m:
                out.append(line); continue
            key=m.group(2); dst=state.setdefault(key,{})
            kept=[]
            for frag in split_fields(m.group(3)):
                k,v=parse_field(frag)
                if k and k not in SKIP and k in dst and dst[k]==v:
                    removed += 1; total += 1
                    continue
                kept.append(frag)
                if k and k!='requirements':
                    dst[k]=v
            out.append(m.group(1)+' '+', '.join(kept)+' '+m.group(4))
        if removed and not check:
            path.write_text('\n'.join(out)+'\n',encoding='utf-8')
        if removed:
            print(f'{name}: {removed} redundant assignment(s)')
    if check:
        if total:
            print(f'FAIL: {total} exact duplicate descriptive assignment(s) remain')
            return 1
        print('PASS: no exact duplicate descriptive assignments remain')
    else:
        print(f'Removed {total} exact duplicate descriptive assignment(s)')
    return 0

def main():
    return process('--check' in sys.argv[1:])

if __name__=='__main__':
    raise SystemExit(main())
