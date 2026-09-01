#!/usr/bin/env python3
"""Audit HorizonCheck canonical-content/native-ID safety integration."""
from pathlib import Path
import re, sys

ROOT=Path(__file__).resolve().parents[1]

def fail(msg):
    print('FAIL:',msg)
    return 1

def main():
    data=ROOT/'data'/'horizon_canonical_content.lua'
    canonical=ROOT/'modules'/'canonical.lua'
    quests=ROOT/'modules'/'quests.lua'
    coverage=ROOT/'modules'/'catalog_coverage.lua'
    healer=ROOT/'modules'/'selfheal.lua'
    wizard=ROOT/'modules'/'capturewizard.lua'
    mainlua=ROOT/'horizoncheck.lua'
    for p in (data,canonical,quests,coverage,healer,wizard,mainlua):
        if not p.exists(): return fail(f'missing {p.relative_to(ROOT)}')
    dt=data.read_text(encoding='utf-8',errors='replace')
    if "['3:92']" not in dt or "native_policy = 'BLOCK'" not in dt or "availability = 'UNAVAILABLE'" not in dt:
        return fail('Chocobo on the Loose canonical block rule missing')
    # Static override keys must be unique.
    keys=re.findall(r"\['(\d+:\d+)'\]\s*=\s*\{",dt)
    dup=sorted({k for k in keys if keys.count(k)>1})
    if dup: return fail('duplicate canonical quest override(s): '+', '.join(dup))
    ct=canonical.read_text(encoding='utf-8',errors='replace')
    qt=quests.read_text(encoding='utf-8',errors='replace')
    mt=mainlua.read_text(encoding='utf-8',errors='replace')
    contracts=[
        ('canonical native policy API','function M.native_policy',ct),
        ('quarantine policy','QUARANTINE',ct),
        ('raw native state accessor','function M.raw_native_state',qt),
        ('batched native cache sync','function M.sync_native_cache',qt),
        ('quest active canonical gate','canonical_native_policy',qt),
        ('canonical module load',"'canonical'",mt),
        ('coverage module load',"'catalog_coverage'",mt),
        ('self-heal module load',"'selfheal'",mt),
        ('capture wizard module load',"'capturewizard'",mt),
    ]
    missing=[name for name,needle,text in contracts if needle not in text]
    if missing: return fail('missing integration contract(s): '+', '.join(missing))
    print(f'PASS: canonical content audit clean ({len(keys)} explicit quest override(s)).')
    return 0

if __name__=='__main__': raise SystemExit(main())
