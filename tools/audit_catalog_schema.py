#!/usr/bin/env python3
"""Audit HorizonCheck quest catalog source and runtime metadata schema.

This is intentionally conservative: it validates shapes/keys and rejects unsupported
requirement fields, malformed source records, duplicate source rows inside one file,
and invalid quest ids without changing runtime quest behavior.
"""
from __future__ import annotations
from pathlib import Path
import json,re,sys
from collections import Counter,defaultdict

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/'data'
SOURCES=ROOT/'catalog'/'sources'

SOURCE_FIELDS={
 'log_id','quest_id','source','source_label','source_url','name','expansion','start_npc','start_zone',
 'objective','items_needed','reward','repeat_type','requirements','next_step','keywords','priority',
 'source_date','catalog_override_fields','catalog_override_requirements'
}
REQ_FIELDS={
 'fame','fame_log_id','rank','job','level','quests','quests_started','key_items','key_item','mission','missions',
 'mission_key','mission_keys','reputation','reputation_level','weapon_skill','weapon_skill_level','fishing_skill',
 'mercenary_points','status_any','wait_jst_midnight_after_quest','zone_after_wait','zone_after_quest','inventory_items',
 'party_size','party_max_level','equip_proof_items','maat_jobs','avatar_unlocks',
 'mercenary_rank_min','mission_active','mission_progress_min','wait_seconds_after_quest','manual_flags',
 'ws_trial_exclusive','custom','custom_blocking','exclusive_active_quests','exclusive_quests','world_presence'
}
RUNTIME_FIELDS={
 'name','expansion','start_npc','start_zone','objective','items_needed','reward','repeat_type','requirements',
 'requirements_mapped','next_step','keywords','horizon','catalog_generated','catalog_sources',
 'catalog_quality_verified','catalog_override_fields','catalog_override_requirements','catalog_scope_excluded','era','notes'
}
KEY_RE=re.compile(r"\['(\d+):(\d+)'\]\s*=\s*\{")
FIELD_RE=re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*=")
REQ_RE=re.compile(r"requirements\s*=\s*\{([^\n}]*(?:\{[^\n}]*\}[^\n}]*)*)\}")

def fail(msg, errors): errors.append(msg)

def audit_sources(errors):
    files=sorted(SOURCES.glob('*.json'))
    total=0; overlaps=Counter(); per_file_dups=0
    for path in files:
        try: rows=json.loads(path.read_text(encoding='utf-8'))
        except Exception as e:
            fail(f'{path.name}: invalid JSON: {e}',errors); continue
        if not isinstance(rows,list):
            fail(f'{path.name}: top-level value must be a list',errors); continue
        seen=Counter()
        for i,row in enumerate(rows,1):
            total+=1
            if not isinstance(row,dict): fail(f'{path.name} row {i}: record must be object',errors); continue
            unknown=set(row)-SOURCE_FIELDS
            if unknown: fail(f'{path.name} row {i}: unknown fields {sorted(unknown)}',errors)
            for f in ('log_id','quest_id'):
                if not isinstance(row.get(f),int) or row[f] < 0: fail(f'{path.name} row {i}: invalid {f}',errors)
            for f in ('source','source_label','keywords','next_step'):
                if not isinstance(row.get(f),str) or not row[f].strip(): fail(f'{path.name} row {i}: missing/blank {f}',errors)
            req=row.get('requirements')
            if req is not None:
                if not isinstance(req,dict): fail(f'{path.name} row {i}: requirements must be object',errors)
                else:
                    bad=set(req)-REQ_FIELDS
                    if bad: fail(f'{path.name} row {i}: unsupported requirement fields {sorted(bad)}',errors)
            k=(row.get('log_id'),row.get('quest_id'))
            seen[k]+=1; overlaps[k]+=1
        dups=[k for k,n in seen.items() if n>1]
        if dups:
            per_file_dups+=len(dups); fail(f'{path.name}: duplicate quest keys inside source file: {dups[:10]}',errors)
    return total,len([k for k,n in overlaps.items() if n>1]),per_file_dups

def split_top_fields(body):
    fields=[]; depth=0; quote=None; esc=False; token='';
    # Lightweight field-name extraction at top level only.
    i=0
    while i<len(body):
        c=body[i]
        if quote:
            if esc: esc=False
            elif c=='\\': esc=True
            elif c==quote: quote=None
            i+=1; continue
        if c in "'\"": quote=c; i+=1; continue
        if c=='{': depth+=1; i+=1; continue
        if c=='}': depth=max(0,depth-1); i+=1; continue
        if depth==0:
            m=re.match(r'\s*([A-Za-z_][A-Za-z0-9_]*)\s*=',body[i:])
            if m:
                fields.append(m.group(1)); i+=m.end(); continue
        i+=1
    return fields

def extract_record_body(text,start):
    # start points at opening { for one-line/multiline Lua table record.
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

def audit_lua(errors):
    files=sorted(DATA.glob('quest_metadata*.lua')); records=0; bad_req=0
    for path in files:
        text=path.read_text(encoding='utf-8')
        for m in KEY_RE.finditer(text):
            records+=1
            body=extract_record_body(text,m.end()-1)
            if body is None: fail(f'{path.name} {m.group(1)}:{m.group(2)}: unterminated record',errors); continue
            fields=split_top_fields(body)
            bad=set(fields)-RUNTIME_FIELDS
            if bad: fail(f'{path.name} {m.group(1)}:{m.group(2)}: unknown runtime fields {sorted(bad)}',errors)
            # Inspect requirement table field names by a small balanced search.
            rm=re.search(r'\brequirements\s*=\s*\{',body)
            if rm:
                rb=extract_record_body(body,rm.end()-1)
                if rb is not None:
                    rf=set(split_top_fields(rb)); unsupported=rf-REQ_FIELDS
                    if unsupported:
                        bad_req+=1; fail(f'{path.name} {m.group(1)}:{m.group(2)}: unsupported requirement fields {sorted(unsupported)}',errors)
    return len(files),records,bad_req

def main():
    errors=[]
    src_total, overlap_keys, src_dups=audit_sources(errors)
    lua_files,lua_records,bad_req=audit_lua(errors)
    print(f'Source JSON records: {src_total}')
    print(f'Source quest keys with intentional cross-file overlap: {overlap_keys}')
    print(f'Duplicate keys inside one source file: {src_dups}')
    print(f'Lua metadata layers: {lua_files}')
    print(f'Lua metadata record assignments audited: {lua_records}')
    print(f'Unsupported requirement records: {bad_req}')
    if errors:
        for e in errors[:100]: print('ERROR:',e,file=sys.stderr)
        if len(errors)>100: print(f'ERROR: ... {len(errors)-100} more',file=sys.stderr)
        return 2
    print('PASS: quest catalog schema/source audit clean')
    return 0
if __name__=='__main__': raise SystemExit(main())
