#!/usr/bin/env python3
"""Static dependency-reference audit for HorizonCheck quest metadata layers.

The runtime questgraph module audits the final merged catalog. This release-side
check is deliberately conservative: it validates reference shapes and hard
self-dependencies across source layers without pretending to reproduce Lua's
overlay merge semantics.
"""
from pathlib import Path
import re, sys

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/'data'
KEY_RE=re.compile(r"\['(\d+):(\d+)'\]\s*=\s*\{")
REF_RE=re.compile(r"(?:log_id|log)\s*=\s*(\d+)\s*,\s*(?:quest_id|id)\s*=\s*(\d+)")

def extract_record_body(text,start):
    depth=0; quote=None; esc=False
    for i in range(start,len(text)):
        c=text[i]
        if quote:
            if esc: esc=False
            elif c=='\\': esc=True
            elif c==quote: quote=None
            continue
        if c in "'\"": quote=c; continue
        if c=='{': depth+=1
        elif c=='}':
            depth-=1
            if depth==0: return text[start+1:i]
    return None

def main():
    keys=set(); refs=[]; errors=[]; records=0
    files=sorted(DATA.glob('quest_metadata*.lua'))
    for p in files:
        text=p.read_text(encoding='utf-8')
        for m in KEY_RE.finditer(text):
            records+=1; k=(int(m.group(1)),int(m.group(2))); keys.add(k)
            body=extract_record_body(text,m.end()-1)
            if body is None:
                errors.append(f'{p.name} {k[0]}:{k[1]} unterminated record'); continue
            # Limit references to requirement-like portions of the record. False
            # positives are harmless for missing-target statistics, but self refs
            # are only fatal when "quests" is also present in the record.
            if 'quests' in body:
                for rm in REF_RE.finditer(body):
                    to=(int(rm.group(1)),int(rm.group(2))); refs.append((k,to,p.name))
                    if to==k: errors.append(f'{p.name} {k[0]}:{k[1]} hard self dependency')
    missing={(a,b) for a,b,_ in refs if b not in keys}
    print(f'Quest metadata records scanned: {records}')
    print(f'Unique quest keys: {len(keys)}')
    print(f'Quest-like references scanned: {len(refs)}')
    print(f'References without a metadata record in any layer: {len(missing)} (runtime graph will resolve against merged catalog/name resources)')
    if errors:
        for e in errors[:50]: print('ERROR:',e,file=sys.stderr)
        return 2
    print('PASS: no hard self-dependency/reference-shape errors detected')
    return 0
if __name__=='__main__': raise SystemExit(main())
