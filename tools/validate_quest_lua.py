#!/usr/bin/env python3
"""Lightweight validator for HorizonCheck generated/overlay Lua tables.
Catches the common failure mode where an apostrophe terminates a single-quoted
Lua string and causes the whole metadata overlay to fail at runtime.
"""
from pathlib import Path
import sys

def validate(path: Path):
    text=path.read_text(encoding='utf-8')
    problems=[]
    for ln,line in enumerate(text.splitlines(),1):
        code=line.split('--',1)[0]
        state=None; esc=False; i=0
        while i < len(code):
            ch=code[i]
            if state:
                if esc:
                    esc=False
                elif ch=='\\':
                    esc=True
                elif ch==state:
                    # A raw apostrophe between letters inside a single-quoted
                    # Lua string is almost always an unescaped contraction/name
                    # (e.g. San d'Oria) and would terminate the string early.
                    if state == "'" and i > 0 and i + 1 < len(code) and code[i-1].isalpha() and code[i+1].isalpha():
                        problems.append((ln, 'unescaped apostrophe inside single-quoted string'))
                    else:
                        state=None
            elif ch in ("'", '"'):
                state=ch
            i+=1
        if state is not None:
            problems.append((ln,'unterminated quoted string'))
    return problems

def main():
    root=Path(__file__).resolve().parents[1]
    paths=sorted((root/'data').glob('quest_metadata*.lua'))
    bad=0
    for p in paths:
        probs=validate(p)
        if probs:
            bad += len(probs)
            for ln,msg in probs: print(f'{p}:{ln}: {msg}')
        else: print(f'OK: {p}')
    return 1 if bad else 0
if __name__=='__main__': raise SystemExit(main())
