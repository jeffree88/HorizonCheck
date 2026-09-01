#!/usr/bin/env python3
"""Release contracts for HorizonCheck v7 state-integrity architecture."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
errors=[]

def read(rel):
    p=ROOT/rel
    if not p.is_file():
        errors.append(f'missing {rel}')
        return ''
    return p.read_text(encoding='utf-8')

runtime=read('horizoncheck.lua')
integrity=read('modules/integrity.lua')
deps=read('modules/dependencies.lua')
diag=read('modules/diagnostics.lua')
health=read('modules/releasehealth.lua')
ann=read('modules/anniversary.lua')
smart=read('modules/smartdashboard.lua')
selfheal=read('modules/selfheal.lua')
state=read('modules/state.lua')

checks=[
    ('integrity module loaded', "'integrity'" in runtime and 'integrity = {' in runtime),
    ('integrity event-driven invalidation', 'function M.invalidate' in integrity and 'dirty_due' in integrity and 'BATCH_SECONDS' in integrity),
    ('integrity periodic safety audit', 'FALLBACK_SECONDS' in integrity and 'fallback integrity safety audit' in integrity),
    ('integrity raw-evidence protection', 'Raw packet/native evidence is never deleted or downgraded.' in integrity),
    ('integrity uses dependency graph', "target=='integrity'" in deps and 'integrity' in deps),
    ('legacy selfheal scheduler disabled', 'if HC.modules.integrity then return; end' in selfheal),
    ('diagnostics use State Integrity', 'State Integrity / Automatic Repair' in diag and 'State integrity:' in diag),
    ('release health includes integrity', "add(rows,'integrity','State integrity'" in health),
    ('initial sync remains independent', "states.integrity" not in health.split('local setup_complete=',1)[1].split('local out=',1)[0]),
    ('Anniversary speaker lane bounds', 'npc_lane_bounds' in ann and 'speaker_from_label' in ann and 'mark_2024_lane_before' in ann),
    ('Anniversary automation status API', 'function M.automation_status' in ann and 'function M.valid_2024_pointer' in ann),
    ('Anniversary verified counters retained', 'Capture-verified NPC counter dialogue' in ann and 'TURN-IN COMPLETE' in ann),
    ('account compact summary v2', 'summary_version=2' in smart and 'last_seen_at' in smart),
    ('account sorting', "account_sort=='progress'" in smart and "account_sort=='last_seen'" in smart),
    ('account shared-pool state', "'POOL EMPTY'" in smart and 'dynamis_remaining' in smart),
    ('new profiles default Developer Mode off', "state.chars[name]={ settings={ developer_mode=false } }" in state and 'if new_profile then' in state and 'c.settings.developer_mode=false' in state),
]
for label,ok in checks:
    if not ok: errors.append(label)

# Integrity must not rebuild expensive recommendation/search structures synchronously.
for banned in ('search.rebuild', 'planner.build('):
    if banned in integrity:
        errors.append(f'integrity performs forbidden eager work: {banned}')

if errors:
    print(f'FAIL: {len(errors)} v7 integrity contract issue(s):')
    for e in errors: print(' -',e)
    sys.exit(1)
print('PASS: v7 State Integrity, Anniversary lane automation, and compact account-summary contracts are present.')
