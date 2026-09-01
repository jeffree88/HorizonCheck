#!/usr/bin/env python3
"""Compact shadowed quest metadata assignments while preserving fallback + final state.

For each quest/field, HorizonCheck loads metadata in a fixed order. When a field is
assigned three or more times, every assignment between the first and last is dead
at the end of a normal load. This tool removes only those middle assignments,
retaining the earliest fallback and final authoritative value. Requirement and
behavior-authority fields are excluded.
"""
from __future__ import annotations
from pathlib import Path
import re
import sys
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'data'
FILES = [
    'quest_metadata.lua','quest_metadata_bulk.lua','quest_metadata_generated.lua',
    'quest_metadata_scope.lua','quest_metadata_completion.lua','quest_metadata_completion2.lua',
    'quest_metadata_completion3.lua','quest_metadata_completion4.lua','quest_metadata_quality.lua',
    'quest_metadata_verify.lua','quest_metadata_checkreqs.lua',
]
PROTECTED = {
    'requirements','requirements_mapped','catalog_quality_verified','catalog_scope_excluded',
}
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

def collect():
    occ=defaultdict(list)
    parsed={}
    seq=0
    for name in FILES:
        path=DATA/name
        lines=path.read_text(encoding='utf-8',errors='replace').splitlines()
        parsed[name]=lines
        for li,line in enumerate(lines):
            m=ENTRY.match(line)
            if not m: continue
            for fi,frag in enumerate(split_fields(m.group(3))):
                k,_=parse_field(frag)
                if k and k not in PROTECTED:
                    occ[(m.group(2),k)].append((seq,name,li,fi))
                    seq += 1
    return occ,parsed

def process(check: bool=False) -> int:
    occ, parsed = collect()
    doomed=set()
    by_file=defaultdict(int)
    for key, xs in occ.items():
        if len(xs) >= 3:
            for _,name,li,fi in xs[1:-1]:
                doomed.add((name,li,fi)); by_file[name]+=1
    if check:
        empty_rows=[]
        for name,lines in parsed.items():
            for li,line in enumerate(lines, 1):
                m=ENTRY.match(line)
                if m and not split_fields(m.group(3)):
                    empty_rows.append((name,li,m.group(2)))
        if doomed or empty_rows:
            if doomed:
                print(f'FAIL: {len(doomed)} shadowed middle metadata assignment(s) remain')
                for name,count in sorted(by_file.items()): print(f'  {name}: {count}')
            if empty_rows:
                print(f'FAIL: {len(empty_rows)} empty metadata row(s) remain')
                for name,li,key in empty_rows[:20]: print(f'  {name}:{li}: {key}')
            return 1
        print('PASS: no removable shadowed middle assignments or empty metadata rows remain')
        return 0
    removed=0; empty_removed=0
    for name in FILES:
        path=DATA/name; out=[]
        for li,line in enumerate(parsed[name]):
            m=ENTRY.match(line)
            if not m:
                out.append(line); continue
            fields=split_fields(m.group(3)); kept=[]
            for fi,frag in enumerate(fields):
                if (name,li,fi) in doomed:
                    removed += 1
                else:
                    kept.append(frag)
            if not kept:
                empty_removed += 1
                continue
            out.append(m.group(1)+' '+', '.join(kept)+' '+m.group(4))
        path.write_text('\n'.join(out)+'\n',encoding='utf-8')
    print(f'Removed {removed} shadowed middle assignment(s) and {empty_removed} empty row(s)')
    for name,count in sorted(by_file.items()): print(f'  {name}: {count}')
    return 0

def main():
    return process('--check' in sys.argv[1:])

if __name__=='__main__':
    raise SystemExit(main())
