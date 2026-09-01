#!/usr/bin/env python3
"""Static release-candidate hardening audit for HorizonCheck."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def require_file(rel: str) -> str:
    p = ROOT / rel
    if not p.is_file():
        errors.append(f'missing required release-hardening file: {rel}')
        return ''
    return p.read_text(encoding='utf-8')


runtime = require_file('horizoncheck.lua')
state = require_file('modules/state.lua')
ui = require_file('modules/ui.lua')
diag = require_file('modules/diagnostics.lua')
guard = require_file('modules/runtimeguard.lua')
health = require_file('modules/releasehealth.lua')
synchealth = require_file('modules/synchealth.lua')
dependencies = require_file('modules/dependencies.lua')
integrity = require_file('modules/integrity.lua')
manifest = require_file('data/release_manifest.lua')
assault = require_file('modules/assaultprogress.lua')
chocobo = require_file('modules/chocobo.lua')
weekly = require_file('modules/weekly.lua')
haap = require_file('modules/haap.lua')
eco = require_file('modules/eco.lua')
rings = require_file('modules/rings.lua')
learning = require_file('modules/learning.lua')
prepare = require_file('tools/prepare_release.py')

for rel in ('INSTALL.md', 'TROUBLESHOOTING.md', 'KNOWN_LIMITATIONS.md', 'CHANGELOG.md', 'RELEASE_CHECKLIST.md'):
    require_file(rel)

contracts = [
    ('runtimeguard loaded', "'runtimeguard'" in runtime),
    ('releasehealth loaded', "'releasehealth'" in runtime),
    ('synchronization health loaded', "'synchealth'" in runtime and 'Synchronization Health' in synchealth),
    ('dependency reconciliation loaded', "'dependencies'" in runtime and 'Dependency-Driven Reconciliation' in dependencies),
    ('state integrity loaded', "'integrity'" in runtime and 'State Integrity' in integrity and 'function M.invalidate' in integrity and 'function M.poll' in integrity),
    ('historical importer loaded', "'historyimport'" in runtime),
    ('historical importer release file', (ROOT/'modules'/'historyimport.lua').is_file()),
    ('shared responsive UI helpers', 'function M.simple_table' in require_file('modules/uikit.lua') and 'function M.collapsing_section' in require_file('modules/uikit.lua')),
    ('guard self-test contract', 'runtimeguard = {' in runtime),
    ('release health self-test contract', 'releasehealth = {' in runtime),
    ('formal schema marker', 'local CURRENT_SCHEMA = 24' in state),
    ('pre-migration backup', 'create_migration_backup' in state),
    ('migration validation', 'validate_state_table' in state),
    ('automatic rollback text', 'automatic rollback completed' in state),
    ('migration requires backup', 'migration not started; pre-migration backup could not be created' in state),
    ('migration save verification', 'save verification failed; automatic rollback completed' in state),
    ('migration status API', 'function M.migration_status' in state),
    ('storage write test API', 'function M.storage_status' in state),
    ('first-run release wizard', 'draw_setup' in health and 'Initial Synchronization' in health),
    ('permanent initialization milestones', 'sync_milestones' in health and 'Finished steps stay finished.' in health),
    ('global UI guarded draws', ui.count('safe_draw(') >= 16),
    ('runtime duplicate suppression', 'error_index' in diag and 'suppressed' in diag),
    ('runtime guard preserves nil returns', 'result.n' in guard),
    ('heavy release-health scan cache', 'RELIC_STATUS_SECONDS' in health and 'relic_cache' in health),
    ('Assault validation diagnostics', 'function M.native_diagnostics' in assault and 'mapping_version' in assault),
    ('Assault persistent mission notes', 'p.notes' in assault and "InputText('##assault_note_'" in assault and 'Saved mission notes were preserved.' in assault),
    ('Chocobo server elapsed calibration', 'server_elapsed_seconds' in chocobo and "time elapsed:" in chocobo and "(earth time)" in chocobo),
    ('Chocobo destination reward mapping', "npc='Orlaine'" in chocobo and "destination='Port Jeuno'" in chocobo and "cutoff='15:29'" in chocobo and "reward='Windurst Woods Glyph'" in chocobo and "npc='Sariale'" in chocobo and "cutoff='28:36'" in chocobo and "npc='Camereine'" in chocobo and "cutoff='19:59'" in chocobo and "npc='Meuneille'" in chocobo and "cutoff='13:15'" in chocobo),
    ('Daily avatar fight readiness panel', 'function M.draw_daily_avatars' in weekly and 'Moon Bauble' in weekly and 'Vial of Dream Incense' in weekly and 'Tuning fork of lightning' in weekly and 'ownership_name' in weekly),
    ('Daily avatar hide-completed tracking', 'hide_completed_daily_avatars' in weekly and 'avatar_seen_held' in weekly and "state=is_complete and 'COMPLETE'" in weekly),
    ('HAAP weekly status omits verification chatter', "return pts..' | '..scrolls;" in haap and "| verified " not in haap.split('function M.status(c)',1)[1].split('function M.row_status',1)[0]),
    ('Windurst Eco capture lifecycle', 'Lumomo acceptance dialogue' in eco and 'Ahko assignment dialogue' in eco and 'Indigested Meat obtained' in eco and 'RETURN TO LUMOMO' in eco and 'accepted_weekly_key' in eco),
    ('Windurst Eco final turn-in proof', 'Lumomo reward dialogue + Page from the Dragon Chronicles' in eco and 'completion_pending_weekly_key' in eco and 'windurst_final_reward' in eco and "Eco-Warrior Windurst COMPLETE [VERIFIED BY LUMOMO REWARD]" in eco),
    ('Windurst Eco stale-active guard', 'ACTIVE bit observed but not promoted without current-week Lumomo/Ahko evidence' in eco),
    ('Developer capture text dedupe', 'capture_text_signature' in learning and 'duplicate_capture_text' in learning and 'recent_text_sigs' in learning),
    ('EXP Ring dirty-cache reconcile', 'cached_scan' in rings and 'local function reconcile(c)' in rings and 'M.dirty=false' in rings),
    ('retired Dragon tab visibility removed', 'dragon=true' not in state and 'c.settings.tabs.dragon=nil' in state),
    ('release health report excluded', 'horizoncheck_release_health_' in prepare),
    ('release manifest generated', 'write_release_manifest' in prepare and 'state_schema = 24' in manifest),
    ('initial sync one-time completion report', 'setup_completion_report_pending' in health and 'Finish Setup' in health and 'function M.initial_sync_report' in health),
    ('initial sync Outpost step', "states.outpost_sync=='PASS'" in health and 'Talk to your Outpost NPC once.' in health),
    ('actionable synchronization health', "imgui.TableSetupColumn('Action'" in require_file('modules/synchealth.lua') and 'No action needed.' in require_file('modules/synchealth.lua')),
    ('character registry management', 'Character Registry' in require_file('modules/characterregistry.lua') and 'current character cannot be removed' in require_file('modules/characterregistry.lua')),
]
for label, ok in contracts:
    if not ok:
        errors.append(f'missing contract: {label}')

# Normal-user buttons intentionally removed during production UI cleanup.
for banned in ('Refresh Dynamis Gear##', 'Resync Missions##', 'Compact Mode##', 'HorizonCheck Compact##'):
    for p in (ROOT / 'modules').glob('*.lua'):
        if banned in p.read_text(encoding='utf-8'):
            errors.append(f'production UI still contains banned control {banned!r} in {p.name}')

# Known capture controls must remain behind Developer Mode.
for rel, token in (
    ('modules/chocobo.lua', "capture_button('chocobo'"),
    ('modules/enm.lua', "capture_button('enm'"),
    ('modules/fame.lua', "capture_button('fame'"),
    ('modules/anniversary.lua', "capture_button('anniversary'"),
):
    text = require_file(rel)
    pos = text.find(token)
    if pos >= 0:
        nearby = text[max(0, pos - 500):pos]
        if 'developer' not in nearby:
            errors.append(f'{rel}: capture control is not visibly guarded by Developer Mode')

if 'Evidence: unlock registry' in require_file('modules/dynamis.lua'):
    errors.append('normal Dynamis UI contains raw evidence-source text')

# HorizonXI ships older Ashita/sugar combinations where ImVec2 field access can
# route through libs/sugar/math.lua and throw on `.x` / `.y`. Keep shared window
# geometry on scalar ImGui APIs so reload cannot take down the main UI.
for rel in ('modules/ui.lua', 'modules/uikit.lua'):
    text = require_file(rel)
    code = '\n'.join(line for line in text.splitlines() if not line.lstrip().startswith('--'))
    for token in ('.DisplaySize.x', '.DisplaySize.y', 'size.x', 'size.y', 'v.x', 'v.y'):
        if token in code:
            errors.append(f'{rel}: unsafe ImVec2 component access remains: {token}')


# Redundant normal-user summaries removed during the v6.92.6 polish pass.
redundant_tokens = (
    ('modules/smartdashboard.lua', 'Planner: Do Now'),
    ('modules/smartdashboard.lua', 'Zone Sync:'),
    ('modules/missions.lua', 'Mission Sync: Active'),
    ('modules/missions.lua', 'Native: Nations / Zilart / CoP / ToAU'),
    ('modules/outposts.lua', 'Permanent 17/17 status:'),
    ('modules/outposts.lua', 'Last verified by:'),
    ('modules/ui.lua', 'Quest status: Active'),
    ('modules/ui.lua', 'Completed history:'),
    ('modules/ui.lua', 'Catalog source audit:'),
    ('modules/ui.lua', "'PRODUCTION'"),
)
for rel, token in redundant_tokens:
    if token in require_file(rel):
        errors.append(f'{rel}: redundant production text remains: {token}')

planner = require_file('modules/planner.lua')
if "local ATTENTION_TIERS={'DO NOW'}" not in planner:
    errors.append('Attention is not restricted to urgent DO NOW activities')
if 'Empty Attention is hidden entirely' not in planner or 'No urgent activity alerts right now.' in planner:
    errors.append('empty Attention is not fully hidden while Next Up remains available')
if 'EXPIRING SOON' not in planner or 'CRITICAL' not in planner:
    errors.append('Attention urgency levels are missing')

enm = require_file('modules/enm.lua')
if 'row_needs_timer_verification' not in enm or 'local show_verify=developer or row_needs_timer_verification' not in enm:
    errors.append('ENM Verify Timer is not conditional for normal users')

quests = require_file('modules/quests.lua')
if (ROOT/'modules'/'why.lua').exists():
    errors.append('retired Why inspector module is still packaged')
if 'HC.modules.why' in require_file('modules/ui.lua') or 'Why Inspector' in require_file('modules/ui.lua'):
    errors.append('retired Why inspector is still wired into the main UI')
if 'Advanced Details##quest_detail_advanced_' not in quests:
    errors.append('Quest Details does not retain the collapsed Advanced Details section')
if 'proven/effective:' in quests or ' | manual: ' in quests or ' | inferred floor: ' in quests:
    errors.append('Quest Details still exposes technical fame-profile diagnostics in the normal requirements view')
if "CONFIRMED - BELOW REQUIREMENT" not in quests or "required [%s]" not in quests:
    errors.append('Quest Details does not render the concise confirmed fame requirement status')
if 'proven/effective:' in quests or "' | manual: '" in quests:
    errors.append('Quest Details still exposes the old technical fame requirement line')
if "required [%s]" not in quests or "CONFIRMED - BELOW REQUIREMENT" not in quests:
    errors.append('Quest Details does not render the cleaned confirmed fame summary')

anniversary = require_file('modules/anniversary.lua')
for token in ('TRACENT_DROWSY_RIDDLES','TURN-IN COMPLETE','Capture-verified NPC counter dialogue','npc_lane_bounds','automation_status','same-NPC current-riddle progression','unmapped_2024','BOYAHDA_SUCCESS_NEEDLE','boyahda_on_item_update','Capture-verified success dialogue + 0x020 inventory delta','BOYAHDA_COMPLETE_SIGNATURES','Capture-verified post-turn-in dialogue'):
    if token not in anniversary:
        errors.append('Anniversary Tracent/Drowsy production tracker missing: ' + token)

smartdashboard = require_file('modules/smartdashboard.lua')
# v7.6.4 keeps Overview action-first: detailed Character / Activity /
# Progression / Collections panels were intentionally removed because their
# authoritative data already lives in dedicated tabs. Preserve the action
# planner, Zone Intelligence, compact saved account summaries, and optional
# collapsed Account / Characters comparison instead.
for token in ('What Should I Do?','Zone Intelligence','Account / Characters','summary_version=2','Last Seen','POOL EMPTY'):
    if token not in smartdashboard:
        errors.append('Slim Overview missing production section/token: ' + token)
for retired in ('Current Activity','Events & Collections','Current Job Gear','Permanent Unlocks'):
    if retired in smartdashboard:
        errors.append('Slim Overview still contains retired duplicate summary UI: ' + retired)
for retired in ('Best Next','More in This Zone','Recommendations combine urgency'):
    if retired in smartdashboard:
        errors.append('Overview still contains retired recommendation UI: ' + retired)

outposts = require_file('modules/outposts.lua')
outpost_complete = outposts.find("imgui.Text('All outposts obtained');")
if outpost_complete < 0 or 'return;' not in outposts[outpost_complete:outpost_complete+180]:
    errors.append('completed Outposts view is not reduced to its single-line summary')

skills = require_file('modules/skills.lua')
fame_note = skills.find('FFXI does not expose a direct fame number in player memory.')
if fame_note >= 0 and 'if developer then' not in skills[max(0, fame_note-250):fame_note]:
    errors.append('normal Fame view still exposes developer capture guidance')


for rel, token in (
    ('horizoncheck.lua', "sub == 'compact'"),
    ('horizoncheck.lua', 'HC.ui.compact'),
    ('modules/ui.lua', 'HC.ui.compact'),
    ('modules/planner.lua', "imgui.Text('Activity Snapshot')"),
    ('modules/planner.lua', "'FOCUS - '"),
    ('modules/planner.lua', 'focus_for_filter'),
    ('modules/planner.lua', 'planner_filter'),
):
    if token in require_file(rel):
        errors.append(f'{rel}: retired production feature remains: {token}')

if errors:
    print(f'FAIL: {len(errors)} release-hardening issue(s):')
    for e in errors:
        print(' -', e)
    sys.exit(1)

print('PASS: release-candidate hardening contracts are present.')
print('PASS: production UI controls, migration safety, runtime isolation, setup health, and documentation audited.')
