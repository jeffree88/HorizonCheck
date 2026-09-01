#!/usr/bin/env python3
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
errors=[]
def read(rel):
    p=ROOT/rel
    if not p.is_file(): errors.append('missing '+rel); return ''
    return p.read_text(encoding='utf-8')
runtime=read('horizoncheck.lua'); integrity=read('modules/integrity.lua'); seasonal=read('modules/seasonal.lua'); anniversary=read('modules/anniversary.lua'); watchdog=read('modules/performance_watchdog.lua'); coverage=read('modules/catalog_coverage.lua'); diag=read('modules/diagnostics.lua'); state=read('modules/state.lua')
checks=[
 ('watchdog module loaded', "'performance_watchdog'" in runtime and 'performance_watchdog = {' in runtime),
 ('watchdog low cadence', 'SAMPLE_SECONDS=60' in watchdog and 'function M.poll' in watchdog),
 ('watchdog scans profiler only', 'counter_snapshot' in watchdog and 'inventory.full_scan' in watchdog),
 ('watchdog diagnostics', 'Performance Watchdog' in diag),
 ('save telemetry', "state.save.write" in state and "state.save.request" in state),
 ('seasonal verified years', 'verified_years={2025}' in seasonal and "HISTORICAL" in seasonal and 'NOT AVAILABLE THIS YEAR' in seasonal and 'YEAR UNVERIFIED' in seasonal),
 ('seasonal year API', 'function M.year_status' in seasonal),
 ('integrity reset scope', 'scan_reset_keys' in integrity),
 ('integrity fame bounds', 'scan_fame_bounds' in integrity),
 ('integrity outposts', 'scan_outpost_consistency' in integrity),
 ('integrity Anniversary metrics', 'scan_anniversary_progress_bounds' in integrity),
 ('integrity Seasonal metadata', 'scan_seasonal_metadata' in integrity),
 ('integrity mission chain audit', 'scan_mission_chain_audit' in integrity),
 ('integrity quest chain audit', 'scan_quest_chain_audit' in integrity),
 ('catalog score', 'HorizonXI Catalog Verification Score' in coverage and 'completion_evidence' in coverage and 'waits' in coverage),
 ('catalog score diagnostics', 'Catalog coverage: %.1f%% verified' in diag),
 ('Anniversary 2024 live locations', 'draw_2024_item_location(name)' in anniversary and "[OWNED - '..tostring(loc)..']" in anniversary),
 ('Anniversary black chocobo feather exact ID', "['Black Chocobo Feather']={845}" in anniversary and "'Black C. Feather'" in anniversary and ('collection_item_location_ids(ids,aliases,false)' in anniversary or 'own.location_ids(ids,aliases,false)' in anniversary)),
 ('Anniversary full ID registry', 'anniv_2024_warm_id_registry' in anniversary and 'anniv_2024_resolve_ids' in anniversary and ('pcall(skills.collection_resolve_ids,candidates)' in anniversary or 'pcall(own.resolve_ids,candidates)' in anniversary) and 'item_id_registry_status' in anniversary),
 ('Anniversary guide label normalization', "while base:match('%s*%b()%s*$')" in anniversary and "gsub('%s+[xX]%d+%s*$','')" in anniversary),
 ('Anniversary locations reuse shared collection scan', ((('collection_item_location_ids(ids,aliases,false)' in anniversary or 'collection_item_location(aliases,false)' in anniversary) and 'collection_scan_token' in anniversary) or (('own.location_ids(ids,aliases,false)' in anniversary or 'own.current(aliases,false)' in anniversary) and 'own.status' in anniversary))),
 ('Anniversary quantity suffix normalization', "gsub('%s+[xX]%d+%s*$','')" in anniversary),
]
for label,ok in checks:
    if not ok: errors.append(label)
for banned in ('planner.build(', 'search.rebuild'):
    if banned in integrity: errors.append('integrity eager work: '+banned)
if errors:
    print('FAIL: %d v7.2 contract issue(s):'%len(errors))
    for e in errors: print(' -',e)
    sys.exit(1)
print('PASS: v7.2 State Integrity expansion, Seasonal year-awareness, Performance Watchdog, and Catalog Verification Score contracts are present.')
