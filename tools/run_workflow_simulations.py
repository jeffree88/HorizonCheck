#!/usr/bin/env python3
"""HorizonCheck high-level workflow simulation suite.

These simulations intentionally model contracts between the runtime engines instead
of emulating Ashita. They catch regressions in evidence precedence, reset scope,
era gating, zone reconciliation, planner scoring, timeline dedupe, global search, saved-state rollback, runtime isolation, and release setup health.
"""
from pathlib import Path
import json, sys

ROOT=Path(__file__).resolve().parents[1]
SCENARIOS=ROOT/'tests'/'workflow_scenarios.json'

class Model:
    def __init__(self):
        self.bitmap={}; self.api={}; self.proofs={}; self.resolved={}
        self.weekly={'dynamis_character':0,'dynamis_account':0,'limbus':0}
        self.missions={}; self.zone=None; self.zone_phase=0; self.phase_runs={1:0,2:0,3:0}
        self.timeline=[]; self.timeline_seen=set(); self.planner=[]; self.search_rows=[]; self.search_results=[]
        self.limbus='UNKNOWN'
        self.canonical={}; self.native_bits={}; self.quest_states={}; self.derived={}; self.guided={}
        self.selfheal_repairs=0; self.canonical_missions={}
        self.assault_completed=set(); self.assault_native_imported=0
        self.state_schema=22; self.state_value=0; self.state_backup=None; self.migration_rolled_back=False
        self.guard={}; self.guard_total_errors=0
        self.error_rows={}; self.error_total=0; self.error_suppressed=0
        self.setup={'character':False,'storage':False,'schema':False,'manifest':False,'missions':False,'keyitems':False,'assault':False,'zonesync':False,'progression':False}
        self.setup_complete=False
        self.enm_observed={}; self.enm_hints=set(); self.enm_timer_count={}; self.enm_timer_confidence={}
        self.attention=[]
        self.anniversary={
            'tracent':{'status':None,'requested':set(),'items_complete':0,'completed':None,'remaining':None},
            'drowsy':{'status':None,'requested':set(),'items_complete':0,'completed':None,'remaining':None},
        }
    def resolve(self,i):
        if self.bitmap.get(i) is True: return True
        if self.proofs.get(i) is True: return True
        if self.bitmap.get(i) is False: return False
        # API false is not authoritative on HorizonXI for permanent KI ownership.
        if self.api.get(i) is True: return True
        return None
    def planner_score(self,r):
        base={'DO NOW':1000,'READY':700,'PREP':400,'SOON':250,'LOCKED':0}.get(r.get('tier'),0)
        s=base
        if r.get('here'): s+=300
        if r.get('category')=='quest': s+=30
        t=r.get('text','').lower()
        if 'key item ready' in t or 'held' in t: s+=120
        if 'capped' in t: s+=100
        return s
    def step(self,s):
        op=s['op']
        if op=='bitmap': self.bitmap[int(s['id'])]=bool(s['owned'])
        elif op=='bitmap_clear': self.bitmap={}
        elif op=='api': self.api[int(s['id'])]=bool(s['owned'])
        elif op=='proof': self.proofs[int(s['id'])]=bool(s['owned'])
        elif op=='reconcile_unlock':
            i=int(s['id']); owned=self.resolve(i)
            if owned is True and s.get('sticky'): self.proofs[i]=True
        elif op=='resolve': self.resolved[int(s['id'])]=self.resolve(int(s['id']))
        elif op=='limbus_state': self.limbus='READY' if self.resolve(734) is True and self.weekly['limbus']<2 else 'DONE' if self.weekly['limbus']>=2 else 'PREP'
        elif op=='weekly':
            for k in self.weekly:
                if k in s: self.weekly[k]=int(s[k])
        elif op=='weekly_reset':
            for k in self.weekly: self.weekly[k]=0
        elif op=='mission_availability': self.missions[f"{s['series']}_{s['number']}"]='FUTURE' if int(s['number'])>int(s['cap']) else 'AVAILABLE'
        elif op=='zone': self.zone=s['id']; self.zone_phase=0; self.phase_runs={1:0,2:0,3:0}
        elif op=='zone_phase':
            p=int(s['phase'])
            if p>self.zone_phase and p==self.zone_phase+1:
                self.zone_phase=p; self.phase_runs[p]+=1
        elif op=='timeline':
            sig=(s['key'],s['state'])
            if sig not in self.timeline_seen: self.timeline_seen.add(sig); self.timeline.append(sig)
        elif op=='planner_row': self.planner.append(dict(s))
        elif op=='planner_rank': self.planner.sort(key=lambda r:(-self.planner_score(r),r.get('text','').lower()))
        elif op=='search_add': self.search_rows.append({'kind':s['kind'],'name':s['name']})
        elif op=='search':
            q=s['query'].lower(); self.search_results=[r for r in self.search_rows if q in r['name'].lower() or q in r['kind'].lower()]
        elif op=='canonical':
            self.canonical[s['key']]={'policy':s['policy'],'content':s.get('content','AVAILABLE')}
        elif op=='native_bit':
            self.native_bits[s['key']]={'active':bool(s.get('active',False)),'completed':bool(s.get('completed',False))}
        elif op=='quest_resolve':
            key=s['key']; rule=self.canonical.get(key,{'policy':'QUARANTINE','content':'UNVERIFIED'}); raw=self.native_bits.get(key,{})
            if rule['content'] in ('UNAVAILABLE','FUTURE','DISABLED') or rule['policy']=='BLOCK': state='LOCKED'
            elif rule['policy']=='QUARANTINE' and (raw.get('active') or raw.get('completed')): state='ID QUARANTINED'
            elif raw.get('completed'): state='COMPLETE'
            elif raw.get('active'): state='ACTIVE'
            else: state='AVAILABLE'
            self.quest_states[key]=state
        elif op=='derived': self.derived[s['key']]=s['state']
        elif op=='selfheal':
            key=s['key']; rule=self.canonical.get(key,{}); raw=self.native_bits.get(key,{})
            if rule.get('policy') in ('BLOCK','QUARANTINE') and (raw.get('active') or raw.get('completed')):
                target='LOCKED' if rule.get('policy')=='BLOCK' else 'UNKNOWN'
                if self.derived.get(key)!=target:
                    self.derived[key]=target; self.selfheal_repairs+=1
        elif op=='canonical_mission':
            content=s.get('content','AVAILABLE')
            self.canonical_missions[f"{s['series']}_{s['number']}"]='BLOCK' if content in ('FUTURE','UNAVAILABLE','DISABLED') else 'ALLOW'
        elif op=='guided':
            before=bool(s.get('before')); after=bool(s.get('after')); packets=int(s.get('packets',0)); text=int(s.get('text',0))
            if not before and after: self.guided[s['key']]='HIGH'
            elif packets>0 and text>0: self.guided[s['key']]='MEDIUM'
            else: self.guided[s['key']]='LOW'
        elif op=='assault_manual':
            self.assault_completed.add(int(s['id']))
        elif op=='assault_native':
            for mission_id in s.get('ids',[]):
                mission_id=int(mission_id)
                if 1<=mission_id<=50 and mission_id not in self.assault_completed:
                    self.assault_completed.add(mission_id)
                    self.assault_native_imported+=1
        elif op=='state_seed':
            self.state_schema=int(s.get('schema',22)); self.state_value=int(s.get('value',0)); self.state_backup=None; self.migration_rolled_back=False
        elif op=='migration_backup':
            self.state_backup={'schema':self.state_schema,'value':self.state_value}
        elif op=='migration_apply':
            self.state_schema=int(s.get('schema',23)); self.state_value=int(s.get('value',self.state_value))
        elif op=='migration_validate':
            if not bool(s.get('valid',True)) and self.state_backup is not None:
                self.state_schema=self.state_backup['schema']; self.state_value=self.state_backup['value']; self.migration_rolled_back=True
        elif op=='guard_call':
            name=s['name']; row=self.guard.setdefault(name,{'errors':0,'state':'READY'})
            if not bool(s.get('ok',True)):
                row['errors']+=1; self.guard_total_errors+=1
                if row['errors']>=3: row['state']='PAUSED'
            else:
                row['errors']=0; row['state']='READY'
        elif op=='error_event':
            sig=f"{s.get('where','runtime')}|{s.get('error','unknown')}"; self.error_total+=1
            if sig in self.error_rows: self.error_rows[sig]+=1; self.error_suppressed+=1
            else: self.error_rows[sig]=1
        elif op=='setup_component':
            self.setup[s['name']]=bool(s.get('ready',True))
        elif op=='setup_check':
            self.setup_complete=all(self.setup.values())
        elif op=='enm_ki_hint':
            self.enm_hints.add(s['id'])
        elif op=='enm_ki_observe':
            i=s['id']; owned=bool(s.get('owned',False)); previous=self.enm_observed.get(i,None)
            self.enm_observed[i]=owned
            if previous is False and owned is True:
                self.enm_timer_count[i]=self.enm_timer_count.get(i,0)+1
                self.enm_timer_confidence[i]='PASSIVE VERIFIED' if i in self.enm_hints else 'KI TRANSITION'
                self.enm_hints.discard(i)
        elif op=='attention_add':
            self.attention.append({'urgency':s.get('urgency','DO NOW'),'text':s.get('text','activity')})
        elif op=='anniversary_riddle':
            npc=s['npc']; row=self.anniversary[npc]
            row['requested'].add(int(s['item']))
            if row['status']!='TURN-IN COMPLETE': row['status']='ITEMS REQUESTED'
        elif op=='anniversary_counter':
            npc=s['npc']; row=self.anniversary[npc]
            row['status']='TURN-IN COMPLETE'; row['items_complete']=4
            row['completed']=int(s['completed']); row['remaining']=int(s['remaining'])
        else: raise AssertionError(f'unknown op {op}')
    def value(self,key):
        if key=='limbus': return self.limbus
        if key=='limbus_used': return self.weekly['limbus']
        if key=='dynamis_effective_cap':
            char=max(0,min(2,int(self.weekly['dynamis_character']))); acct=max(0,min(3,int(self.weekly['dynamis_account'])))
            return max(char,min(2,char+max(0,3-acct)))
        if key=='dynamis_character_remaining':
            char=max(0,min(2,int(self.weekly['dynamis_character']))); cap=max(char,min(2,char+max(0,3-max(0,min(3,int(self.weekly['dynamis_account']))))))
            return max(0,cap-char)
        if key=='dynamis_character_complete':
            char=max(0,min(2,int(self.weekly['dynamis_character']))); cap=max(char,min(2,char+max(0,3-max(0,min(3,int(self.weekly['dynamis_account']))))))
            return max(0,cap-char)==0
        if key.startswith('ki_'): return self.resolve(int(key[3:]))
        if key.startswith('proof_'): return self.proofs.get(int(key[6:]))
        if key.startswith('resolved_'): return self.resolved.get(int(key[9:]))
        if key in self.weekly: return self.weekly[key]
        if key.startswith('toau_'): return self.missions.get('toau_'+key[5:])
        if key=='zone_phase': return self.zone_phase
        if key.startswith('phase') and key.endswith('_runs'): return self.phase_runs[int(key[5])]
        if key=='timeline_count': return len(self.timeline)
        if key=='planner_first': return self.planner[0]['text'] if self.planner else None
        if key=='search_count': return len(self.search_results)
        if key=='search_first': return self.search_results[0]['name'] if self.search_results else None
        if key.startswith('quest_'): return self.quest_states.get(key[6:])
        if key.startswith('derived_'): return self.derived.get(key[8:])
        if key.startswith('guided_'): return self.guided.get(key[7:])
        if key=='selfheal_repairs': return self.selfheal_repairs
        if key.startswith('canonical_mission_'): return self.canonical_missions.get(key[len('canonical_mission_'):])
        if key=='assault_count': return len(self.assault_completed)
        if key=='assault_native_imported': return self.assault_native_imported
        if key=='state_schema': return self.state_schema
        if key=='state_value': return self.state_value
        if key=='migration_backup_created': return self.state_backup is not None
        if key=='migration_rolled_back': return self.migration_rolled_back
        if key=='guard_total_errors': return self.guard_total_errors
        if key.startswith('guard_'): return self.guard.get(key[6:],{}).get('state')
        if key=='error_distinct': return len(self.error_rows)
        if key=='error_total': return self.error_total
        if key=='error_suppressed': return self.error_suppressed
        if key=='setup_complete': return self.setup_complete
        if key.startswith('enm_timer_count_'): return self.enm_timer_count.get(key[len('enm_timer_count_'):],0)
        if key.startswith('enm_timer_confidence_'): return self.enm_timer_confidence.get(key[len('enm_timer_confidence_'):])
        if key=='attention_visible': return len(self.attention)>0
        if key.startswith('anniversary_'):
            _,npc,field=key.split('_',2)
            row=self.anniversary[npc]
            if field=='requested_count': return len(row['requested'])
            return row.get(field)
        raise KeyError(key)

def source_contracts():
    checks={
        'global search module': (ROOT/'modules'/'search.lua','function M.query'),
        'overview module': (ROOT/'modules'/'smartdashboard.lua','What Should I Do?'),
        'planner ranked API': (ROOT/'modules'/'planner.lua','function M.ranked'),
        'planner canonical authority gate': (ROOT/'modules'/'planner.lua','canonical_actionable'),
        'canonical content registry': (ROOT/'modules'/'canonical.lua','function M.native_policy'),
        'canonical collision profile': (ROOT/'data'/'horizon_canonical_content.lua',"['3:92']"),
        'quest raw native quarantine API': (ROOT/'modules'/'quests.lua','function M.raw_native_state'),
        'catalog coverage dashboard': (ROOT/'modules'/'catalog_coverage.lua','Catalog Coverage / Verification Dashboard'),
        'guided capture wizard': (ROOT/'modules'/'capturewizard.lua','function M.start_quest'),
        'self-healing contradiction engine': (ROOT/'modules'/'selfheal.lua','function M.scan'),
        'self-healing idempotent quarantine': (ROOT/'modules'/'selfheal.lua','Already quarantined; no state write required.'),
        'future mission canonical block': (ROOT/'modules'/'canonical.lua',"content_state=='FUTURE' or content_state=='UNAVAILABLE'"),
        'mission search catalog': (ROOT/'modules'/'missions.lua','function M.catalog_entries'),
        'mission current-story wiki GO action': (ROOT/'modules'/'missions.lua',"SmallButton('GO##mission_story_wiki_"),
        'mission wiki numbered nation target': (ROOT/'modules'/'missions.lua',"return 'Windurst Mission '..num"),
        'mission wiki numbered Promathia target': (ROOT/'modules'/'missions.lua',"return 'Promathia Mission '..num"),
        'native Assault history importer': (ROOT/'modules'/'assaultprogress.lua','function M.sync_native_history'),
        'native Assault completed packet type': (ROOT/'modules'/'assaultprogress.lua','local NATIVE_HISTORY_TYPE=0x00C0'),
        'native Assault field offset': (ROOT/'modules'/'assaultprogress.lua','local NATIVE_ASSAULT_OFFSET=0x14'),
        'native Assault proof source': (ROOT/'modules'/'assaultprogress.lua','NATIVE ASSAULT HISTORY'),
        'dynamic per-character Dynamis quota': (ROOT/'modules'/'weekly.lua','function M.dynamis_limits'),
        'completed Dynamis row respects hide setting': (ROOT/'modules'/'weekly.lua','hide_completed_conquest==true and dynamis_limits.complete==true'),
        'Dynamis planner uses effective quota': (ROOT/'modules'/'systems.lua','Character %d/%d used | %d remaining'),
        'zone sync Assault history reconciliation': (ROOT/'modules'/'zonesync.lua','sync_native_history'),
        'A Mercenary Life in-game day wait': (ROOT/'modules'/'missions.lua',"A Mercenary Life','Cutscene','1 in-game day wait -> Undersea Scouting"),
        'ENM search catalog': (ROOT/'modules'/'enm.lua','function M.catalog_entries'),
        'ENM stale consumed-state cleanup': (ROOT/'modules'/'enm.lua','clear_stale_consumed_access'),
        'ENM consumed-state hidden from current status': (ROOT/'modules'/'enm.lua',"access.state~='KEY ITEM CONSUMED'"),
        'ENM first bitmap snapshot is baseline only': (ROOT/'modules'/'enm.lua','First authoritative observation is a baseline only'),
        'ENM passive false-to-true KI transition': (ROOT/'modules'/'enm.lua','previous.owned==false and owned==true'),
        'ENM transition plus dialogue confidence': (ROOT/'modules'/'enm.lua','0x055 key-item transition + obtain dialogue'),
        'ENM Verify Timer action label': (ROOT/'modules'/'enm.lua','Verify Timer##enm_moritz_'),
        'ENM Verify Timer conditional visibility': (ROOT/'modules'/'enm.lua','row_needs_timer_verification'),
        'empty Attention auto-hide': (ROOT/'modules'/'planner.lua','Empty Attention is hidden entirely'),
        'Attention urgency levels': (ROOT/'modules'/'planner.lua','EXPIRING SOON'),
        'Tracent counter completion tracking': (ROOT/'modules'/'anniversary.lua','bug%s*#([%d,]+)%s+down'),
        'Drowsy counter completion tracking': (ROOT/'modules'/'anniversary.lua','quest%s*#([%d,]+)%s+down'),
        'Anniversary riddle-only completion guard': (ROOT/'modules'/'anniversary.lua','Riddle-only dialogue must never erase a saved successful turn-in.'),
        'AF +1 counts as upgraded base AF proof': (ROOT/'modules'/'skills.lua','function af_base_progress_location_for_job'),
        'Relic +1 counts as upgraded base Relic proof': (ROOT/'modules'/'skills.lua','function relic_base_progress_location_for_job'),
        'upgraded base armor display label': (ROOT/'modules'/'skills.lua',"return 'UPGRADED'"),
        'Relic +1 makes matching Relic -1 not needed': (ROOT/'modules'/'skills.lua',"return 'NOT NEEDED',true"),
        'three-stage zone sync': (ROOT/'modules'/'zonesync.lua','PHASE_DELAYS'),
        'permanent unlock registry': (ROOT/'modules'/'unlocks.lua','saved unlock proof'),
        'disabled quest native-state suppression': (ROOT/'modules'/'quests.lua','quest_catalog_disabled'),
        'Chocobo on the Loose HorizonXI gate': (ROOT/'data'/'quest_metadata_checkreqs.lua',"['3:92']={ requirements_mapped=true, requirements={ fame=1, custom_blocking=false }, catalog_quality_verified=true, horizon={enabled=false"),
        'release initial synchronization wizard': (ROOT/'modules'/'releasehealth.lua','Initial Synchronization'),
        'initial sync requires Eeko-Weeko rotation': (ROOT/'modules'/'releasehealth.lua',"states.eco_sync=='PASS'"),
        'initial sync requires Rytaal tag count': (ROOT/'modules'/'releasehealth.lua',"states.assault_tags=='PASS'"),
        'initial sync requires Outpost menu sync': (ROOT/'modules'/'releasehealth.lua',"states.outpost_sync=='PASS'"),
        'initial sync requires fame checker visits': (ROOT/'modules'/'releasehealth.lua',"states.fame_sync=='PASS'"),
        'fame sync preserves per-NPC checker proof': (ROOT/'modules'/'fame.lua','fame_checker_sync'),
        'release health report export': (ROOT/'modules'/'releasehealth.lua','horizoncheck_release_health_'),
        'formal state schema 24': (ROOT/'modules'/'state.lua','local CURRENT_SCHEMA = 24'),
        'mandatory pre-migration backup': (ROOT/'modules'/'state.lua','migration not started; pre-migration backup could not be created'),
        'migration save verification': (ROOT/'modules'/'state.lua','save verification failed; automatic rollback completed'),
        'runtime operation isolation': (ROOT/'modules'/'runtimeguard.lua','QUARANTINE_SECONDS'),
        'runtime packed result preservation': (ROOT/'modules'/'runtimeguard.lua','result.n'),
        'runtime duplicate error collapse': (ROOT/'modules'/'diagnostics.lua','error_index'),
        'Assault history validation dashboard': (ROOT/'modules'/'assaultprogress.lua','function M.draw_native_diagnostics'),
        'release manifest': (ROOT/'data'/'release_manifest.lua',"state_schema = 24"),
        'release hardening package gate': (ROOT/'tools'/'prepare_release.py','audit_release_hardening.py'),
        'performance package gate': (ROOT/'tools'/'prepare_release.py','audit_performance_contracts.py'),
        'release installation guide': (ROOT/'INSTALL.md','Initial Synchronization'),
        'release troubleshooting guide': (ROOT/'TROUBLESHOOTING.md','Module Error Isolation'),
        'historical progression import engine': (ROOT/'modules'/'historyimport.lua','function M.reconcile'),
        'historical import canonical quest safety': (ROOT/'modules'/'historyimport.lua',"policy=='ALLOW'"),
        'historical import avoids repeatable cycle inference': (ROOT/'modules'/'historyimport.lua','Repeatable current-cycle completion is never inferred'),
        'advanced job unlock historical proof': (ROOT/'modules'/'historyimport.lua','ADVANCED_JOBS'),
        'limit break level-threshold proof': (ROOT/'modules'/'historyimport.lua','LIMIT_BREAKS'),
        'seasonal self-heal reconciliation': (ROOT/'modules'/'selfheal.lua','scan_seasonal'),
        'event-driven historical self-heal': (ROOT/'modules'/'selfheal.lua','periodic self-heal only invokes it before the first successful import'),
        'shared responsive collapsing section': (ROOT/'modules'/'uikit.lua','function M.collapsing_section'),
        'shared responsive simple table': (ROOT/'modules'/'uikit.lua','function M.simple_table'),
        'mission UI uses shared components': (ROOT/'modules'/'missions.lua','HC.modules.uikit.simple_table'),
        'anniversary UI uses shared progress labels': (ROOT/'modules'/'anniversary.lua','HC.modules.uikit.progress_label'),
        'job progression action-first summary': (ROOT/'modules'/'skills.lua',"Next Progression:"),
        'job progression compact status summary': (ROOT/'modules'/'skills.lua',"Lv.%d/75 | EXP %s/%s | Mapped quests %d/%d | Overall %d%%"),
        'clickable tab navigation request': (ROOT/'modules'/'ui.lua','function M.navigate'),
        'overview action navigation': (ROOT/'modules'/'smartdashboard.lua','navigation_for_action'),
        'search result navigation': (ROOT/'modules'/'search.lua','navigation_target'),
        'player recent activity feed': (ROOT/'modules'/'timeline.lua','function M.player_recent'),
        'seasonal exact item-id catalog resolution': (ROOT/'modules'/'seasonal.lua','reward_item_ids'),
        'anniversary duplicate current-riddle save suppression': (ROOT/'modules'/'anniversary.lua','if not cur or tonumber(cur.group)~=gi'),
        'historical import coverage report': (ROOT/'modules'/'historyimport.lua','Import Coverage'),
        'historical unsafe native mapping report': (ROOT/'modules'/'historyimport.lua','Skipped Native Quest Mappings'),
        'state schema 24 retired-field pruning': (ROOT/'modules'/'state.lua','cleanup_retired_character_state'),
        'safe state cleanup UI': (ROOT/'modules'/'state.lua','Run Safe State Cleanup'),
        'catalog verification queue filters': (ROOT/'modules'/'catalog_coverage.lua','issue_matches_filter'),
        'runtime cache telemetry': (ROOT/'modules'/'profiler.lua','function M.cache'),
        'runtime counter telemetry': (ROOT/'modules'/'profiler.lua','Runtime Counters / Cache Health'),
    }
    failed=[]
    for name,(path,needle) in checks.items():
        if not path.exists() or needle not in path.read_text(encoding='utf-8',errors='replace'): failed.append(name)

    # Lua locals are only visible from their declaration onward. The helper
    # native_quest_is_active() is defined before quest_active() is assigned, so
    # its forward declaration must stay above that helper or Lua resolves the
    # name as a nil global at runtime.
    quests_path=ROOT/'modules'/'quests.lua'
    if quests_path.exists():
        quests_text=quests_path.read_text(encoding='utf-8',errors='replace')
        decl=quests_text.find('local quest_active;')
        helper=quests_text.find('local function native_quest_is_active')
        assign=quests_text.find('quest_active = function')
        if decl<0 or helper<0 or assign<0 or not (decl<helper<assign):
            failed.append('quest_active forward declaration ordering')
    else:
        failed.append('quest_active forward declaration ordering')
    return failed

def test_global_text_wrapping_contract():
    ui = (ROOT / 'modules' / 'ui.lua').read_text(encoding='utf-8')
    diag = (ROOT / 'modules' / 'diagnostics.lua').read_text(encoding='utf-8')
    assert 'PushTextWrapPos' in ui and 'PopTextWrapPos' in ui
    # Diagnostics now renders inside the main window and inherits its global wrap.
    assert "imgui.Begin('HorizonCheck Diagnostics" not in diag
    assert 'Open Diagnostics Window' not in ui
    assert "safe_draw('Diagnostics',HC.modules.diagnostics.draw,c)" in ui
    return 'global text wrapping / single diagnostics workspace contract'


def main():
    data=json.loads(SCENARIOS.read_text(encoding='utf-8'))
    failed=[]
    for sc in data:
        m=Model()
        try:
            for step in sc['steps']: m.step(step)
            for k,want in sc['expect'].items():
                got=m.value(k)
                if got!=want: raise AssertionError(f'{k}: expected {want!r}, got {got!r}')
            print('PASS:',sc['name'])
        except Exception as e:
            failed.append((sc['name'],str(e))); print('FAIL:',sc['name'],e)
    for name in source_contracts():
        failed.append((name,'source contract missing')); print('FAIL: source contract -',name)
    try:
        label=test_global_text_wrapping_contract(); print('PASS:',label)
    except Exception as e:
        failed.append(('global text wrapping contract',str(e))); print('FAIL: global text wrapping contract',e)
    if failed:
        print(f'FAIL: {len(failed)} workflow simulation/source contract failure(s)')
        return 1
    print(f'PASS: {len(data)} workflow simulation(s) + source integration contracts')
    return 0
if __name__=='__main__': raise SystemExit(main())
