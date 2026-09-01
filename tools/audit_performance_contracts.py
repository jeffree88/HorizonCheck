#!/usr/bin/env python3
"""Guard the open-window performance fixes against regression."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []

def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding='utf-8')

planner = read('modules/planner.lua')
smart = read('modules/smartdashboard.lua')
quests = read('modules/quests.lua')
zonesync = read('modules/zonesync.lua')
weekly = read('modules/weekly.lua')
runtime = read('horizoncheck.lua')
deps = read('modules/dependencies.lua')
selfheal = read('modules/selfheal.lua')
search = read('modules/search.lua')
integrity = read('modules/integrity.lua')
registry = read('modules/characterregistry.lua')
synchealth = read('modules/synchealth.lua')
watchdog = read('modules/performance_watchdog.lua')

checks = [
    ('Planner shared build cache', 'build_cache' in planner and 'BUILD_CACHE_SECONDS' in planner and 'function M.invalidate' in planner),
    ('Overview snapshot cache', 'cache={at=0,char=nil,data=nil}' in smart and 'CACHE_SECONDS' in smart),
    ('Overview avoids Planner rebuilds', 'planner.build(' not in smart and 'ranked_from_model' not in smart),
    ('Quest progression cache', 'progression_overview_cache' in quests or 'PROGRESSION_OVERVIEW_CACHE_SECONDS' in quests),
    ('Weekly header cache/invalidation', 'invalidate_progress' in weekly),
    ('Static coverage audit removed from zone sync', 'catalog_coverage.snapshot' not in zonesync and 'canonical.snapshot' not in zonesync),
    ('Per-operation profiler/guard wrapper', 'profiled_pcall' in runtime and 'runtimeguard' in runtime),
    ('Dependency invalidation graph', 'local GRAPH=' in deps and 'function M.invalidate_many' in deps),
    ('Search lazy invalidation API', 'function M.invalidate()' in search),
    ('Self-heal avoids eager Search rebuild', 'search.rebuild' not in selfheal),
    ('Integrity event-driven batching', 'BATCH_SECONDS' in integrity and 'dirty_due' in integrity and 'function M.invalidate' in integrity),
    ('Integrity avoids eager Search/Planner rebuilds', 'search.rebuild' not in integrity and 'planner.build(' not in integrity),
    ('Account Overview compact saved summaries', 'summary_version=2' in smart and 'ACCOUNT_CACHE_SECONDS' in smart),
    ('Character Registry saved-state only', 'state.raw' in registry and 'inventory' not in registry.lower() and 'quest' not in registry.lower()),
    ('Synchronization Health cached snapshot', 'CACHE_SECONDS' in synchealth and 'cache.data' in synchealth),
    ('Performance Watchdog low cadence', 'SAMPLE_SECONDS=60' in watchdog and 'counter_snapshot' in watchdog),
]
for label, ok in checks:
    if not ok:
        errors.append(label)

# Overview is read-only summary UI and must not rebuild Planner recommendations.
if 'planner.build(' in smart or 'ranked_from_model' in smart:
    errors.append('Overview unexpectedly rebuilds Planner recommendations')

if errors:
    print('FAIL: performance contract regression(s):')
    for e in errors:
        print(' -', e)
    sys.exit(1)

print('PASS: open-window performance contracts preserved.')
