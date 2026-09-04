#!/usr/bin/env python3
"""Offline HorizonCheck policy regression checks.

This does not execute Lua; the in-game runtime suite in modules/regression.lua
executes the actual Lua resolver.  This release-side suite validates the shared
fixture policy and makes sure the evidence/inspector/regression integration is
present in the shipped runtime tree.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def resolve(rows):
    rows = list(rows)
    rows.sort(key=lambda r: (int(r.get("rank", 0)), int(r.get("at", 0)), int(r.get("seq", 0))), reverse=True)
    if not rows:
        return {"value": None, "source": "no evidence", "conflict": False}
    winner = rows[0]
    known = [r for r in rows if r.get("value") is not None]
    conflict = any(r.get("value") != winner.get("value") for r in known[1:]) if winner.get("value") is not None else False
    return {"value": winner.get("value"), "source": winner.get("source"), "conflict": conflict}


def check_runtime_integration():
    errors = []
    main = (ROOT / "horizoncheck.lua").read_text(encoding="utf-8")
    evidence = (ROOT / "modules" / "evidence.lua").read_text(encoding="utf-8")
    diagnostics = (ROOT / "modules" / "diagnostics.lua").read_text(encoding="utf-8")
    keyitems = (ROOT / "modules" / "keyitems.lua").read_text(encoding="utf-8")
    regression = (ROOT / "modules" / "regression.lua").read_text(encoding="utf-8")
    skills = (ROOT / "modules" / "skills.lua").read_text(encoding="utf-8")
    questgraph = (ROOT / "modules" / "questgraph.lua").read_text(encoding="utf-8")
    systems = (ROOT / "modules" / "systems.lua").read_text(encoding="utf-8")
    catalog_integrity = (ROOT / "modules" / "catalog_integrity.lua").read_text(encoding="utf-8")
    planner = (ROOT / "modules" / "planner.lua").read_text(encoding="utf-8")
    ovens = (ROOT / "modules" / "ovens.lua").read_text(encoding="utf-8")
    canonical = (ROOT / "modules" / "canonical.lua").read_text(encoding="utf-8")
    coverage = (ROOT / "modules" / "catalog_coverage.lua").read_text(encoding="utf-8")
    wizard = (ROOT / "modules" / "capturewizard.lua").read_text(encoding="utf-8")
    selfheal = (ROOT / "modules" / "selfheal.lua").read_text(encoding="utf-8")
    ownership = (ROOT / "modules" / "ownership.lua").read_text(encoding="utf-8")
    state = (ROOT / "modules" / "state.lua").read_text(encoding="utf-8")
    henm = (ROOT / "modules" / "henm.lua").read_text(encoding="utf-8")
    seasonal = (ROOT / "modules" / "seasonal.lua").read_text(encoding="utf-8")
    seasky = (ROOT / "modules" / "seasky.lua").read_text(encoding="utf-8")
    anniversary = (ROOT / "modules" / "anniversary.lua").read_text(encoding="utf-8")
    blackcoffin = (ROOT / "modules" / "blackcoffin.lua").read_text(encoding="utf-8")
    isnm = (ROOT / "modules" / "isnm.lua").read_text(encoding="utf-8")
    assaultprogress = (ROOT / "modules" / "assaultprogress.lua").read_text(encoding="utf-8")
    smartdashboard = (ROOT / "modules" / "smartdashboard.lua").read_text(encoding="utf-8")
    uikit = (ROOT / "modules" / "uikit.lua").read_text(encoding="utf-8")
    limbus = (ROOT / "modules" / "limbus.lua").read_text(encoding="utf-8")
    ui = (ROOT / "modules" / "ui.lua").read_text(encoding="utf-8")
    progression = (ROOT / "modules" / "progression.lua").read_text(encoding="utf-8")
    search_src = (ROOT / "modules" / "search.lua").read_text(encoding="utf-8")
    itemlocator_src = (ROOT / "modules" / "itemlocator.lua").read_text(encoding="utf-8")
    dependencies = (ROOT / "modules" / "dependencies.lua").read_text(encoding="utf-8")
    zonesync = (ROOT / "modules" / "zonesync.lua").read_text(encoding="utf-8")
    weekly = (ROOT / "modules" / "weekly.lua").read_text(encoding="utf-8")
    releasehealth = (ROOT / "modules" / "releasehealth.lua").read_text(encoding="utf-8")
    beta_guide = (ROOT / "BETA_TESTING.md").read_text(encoding="utf-8")

    order = re.search(r"local order\s*=\s*\{(.*?)\};", main, re.S)
    if not order:
        errors.append("could not locate module load order")
    else:
        body = order.group(1)
        if body.find("'evidence'") < 0 or body.find("'keyitems'") < 0 or body.find("'evidence'") > body.find("'keyitems'"):
            errors.append("evidence must load before keyitems")
        if body.find("'regression'") < 0:
            errors.append("regression module missing from load order")
        for mod in ("'questgraph'", "'systems'", "'catalog_integrity'", "'canonical'", "'catalog_coverage'", "'capturewizard'", "'selfheal'", "'ownership'", "'reusableitems'"):
            if body.find(mod) < 0:
                errors.append(f"{mod.strip(chr(39))} module missing from load order")
        if body.find("'questgraph'") >= 0 and body.find("'quests'") >= 0 and body.find("'questgraph'") < body.find("'quests'"):
            errors.append("questgraph must load after quests")
        if body.find("'systems'") >= 0 and body.find("'planner'") >= 0 and body.find("'systems'") > body.find("'planner'"):
            errors.append("systems must load before planner")

    required_evidence = ["function M.submit", "function M.resolve", "function M.resolve_rows", "function M.inspect", "function M.register_provider"]
    for token in required_evidence:
        if token not in evidence:
            errors.append(f"evidence resolver missing {token}")
    if "function M.draw_evidence_inspector" not in diagnostics:
        errors.append("Detection Inspector not exported from diagnostics")
    if "HC.modules.evidence" not in keyitems or "function M.evidence_key" not in keyitems:
        errors.append("keyitems not integrated with unified evidence resolver")
    if "function M.run" not in regression:
        errors.append("runtime regression runner missing")
    if "HC.modules.regression.run" not in main:
        errors.append("runtime regression suite is not part of self-test")

    for token in ["function M.trace", "function M.summary", "function M.analyze_nodes"]:
        if token not in questgraph:
            errors.append(f"quest dependency graph missing {token}")
    for token in ["function M.snapshot", "function M.repeat_status", "function M.action_rows"]:
        if token not in systems:
            errors.append(f"system state engine missing {token}")
    for token in ["function M.run", "Missing prerequisite target", "Dependency cycle"]:
        if token not in catalog_integrity:
            errors.append(f"catalog integrity engine missing {token}")
    if "systems.action_rows" not in planner:
        errors.append("planner is not consuming normalized system actions")

    for token in ["function M.native_policy", "QUARANTINE", "function M.snapshot"]:
        if token not in canonical:
            errors.append(f"canonical content registry missing {token}")
    for token in ["Catalog Coverage / Verification Dashboard", "function M.issues"]:
        if token not in coverage:
            errors.append(f"catalog coverage dashboard missing {token}")
    for token in ["function M.start_quest", "Guided Capture Analysis", "function M.stop"]:
        if token not in wizard:
            errors.append(f"guided capture wizard missing {token}")
    for token in ["function M.scan", "UNSAFE_NATIVE_ID", "Raw packet evidence is never deleted"]:
        if token not in selfheal:
            errors.append(f"self-healing contradiction engine missing {token}")
    if "canonical_actionable" not in planner:
        errors.append("planner is not consuming canonical quest authority")

    # 2024 Boyahda capture: Kipling and Ah Puch emit all four request riddles
    # in one interaction.  Their riddle signatures may identify requested items,
    # but must not use current-riddle progression to infer completion.
    for token in [
        'KIPLING_AHPUCH_RIDDLES',
        "in the tomb's dark silence",
        'from flames reborn, i rise and fly',
        "observe_requested_riddle(c,a,'kipling'",
        "observe_requested_riddle(c,a,'ahpuch'",
    ]:
        if token not in anniversary:
            errors.append(f"Boyahda Anniversary riddle contract missing: {token}")
    boyahda = re.search(r"Capture-verified Boyahda pair request riddles(.*?)-- 2024 main hunt", anniversary, re.S)
    if not boyahda:
        errors.append("Boyahda Anniversary request-only parser block missing")
    elif 'observe_2024_current' in boyahda.group(1).replace('observe_2024_current()',''):
        errors.append("Boyahda batch riddles must not infer completion via observe_2024_current")

    # Kipling and Ah Puch use the same generic successful hand-in text. It is
    # authoritative only when paired with a recent exact requested-item
    # inventory delta from 0x020 for the matching NPC lane.
    for token in [
        'BOYAHDA_SUCCESS_NEEDLE',
        'yes this is one of the items i was looking for',
        'boyahda_on_item_update',
        'Capture-verified success dialogue + 0x020 inventory delta',
        "HC.modules.packets.register(0x020,'anniversary Boyahda inventory correlation'",
        "resolve_boyahda_success(c,a,'kipling',raw)",
        "resolve_boyahda_success(c,a,'ahpuch',raw)",
        'kipling=true,ahpuch=true',
    ]:
        if token not in anniversary:
            errors.append(f"Boyahda verified turn-in correlation missing: {token}")
    success_block = re.search(r"Capture-verified Boyahda successful trades(.*?)-- Capture-verified Boyahda pair request riddles", anniversary, re.S)
    if not success_block:
        errors.append("Boyahda verified trade parser block missing")
    elif "a['2024']" in success_block.group(1):
        errors.append("Generic Boyahda success text must not directly mark 2024 completion without inventory correlation")

    # Boyahda post-completion dialogue is authoritative for the full four-item
    # lane. This provides reconciliation when one of the individual trade
    # packets was missed, while the generic per-item success line remains
    # inventory-correlated only.
    for token in [
        'BOYAHDA_COMPLETE_SIGNATURES',
        "guess it is time to nerf aerec's favorite job again",
        'catch the cheaters, stop their game',
        'BOYAHDA_POST_COMPLETE_CLUES',
        "complete_boyahda_lane_from_dialogue(c,a,'kipling',raw)",
        "complete_boyahda_lane_from_dialogue(c,a,'ahpuch',raw)",
        'Capture-verified post-turn-in dialogue',
    ]:
        if token not in anniversary:
            errors.append(f"Boyahda completion-dialogue contract missing: {token}")

    # Anniversary live turn-ins must not rely on Dear ImGui's collapsing-header
    # state. The HorizonXI bridge can reset that state when a checkbox changes,
    # so Anniversary owns the open booleans in Lua and only a user click toggles
    # them. Dynamic progress text is therefore safe again.
    for token in [
        'local anniversary_open_state={};',
        'local function sticky_anniversary_header(id,label,default_open)',
        "pcall(imgui.Selectable,visible..'##hc_anniv_sticky_'..id,true)",
        "sticky_anniversary_header('year_2024',l24,false)",
        "sticky_anniversary_header('2024_group_'..tostring(gi),header,false)",
        "sticky_anniversary_header('2024_bonus',bonus_header,false)",
        "progress_label('2024 - 2nd Anniversary Item Hunt'",
    ]:
        if token not in anniversary:
            errors.append(f"Anniversary sticky-open contract missing: {token}")
    if "imgui.CollapsingHeader(l24..'##anniv_y2024')" in anniversary:
        errors.append('2024 Anniversary year header must not depend on Dear ImGui collapsing state')

    # Secrets of Ovens Lost is weekly on HorizonXI.  Its ACTIVE bit can be
    # resent on zone-in after the turn-in, so same-week COMPLETE must be sticky.
    for token in [
        "native_active_after_complete_at",
        "0x056 ACTIVE observed after current-week COMPLETE",
        "restored from current-week Miratete reward evidence",
        "c.dragon_weekly.mm_cookbook=true",
    ]:
        if token not in ovens:
            errors.append(f"Ovens weekly completion persistence contract missing: {token}")
    active_complete = re.search(r"if a\.state=='COMPLETE' then(.*?)elseif a\.state=='READY'", ovens, re.S)
    if active_complete and ("a.completed_at=nil" in active_complete.group(1) or "c.dragon_weekly.mm_cookbook=nil" in active_complete.group(1)):
        errors.append("Ovens 0x056 ACTIVE branch must not erase same-week COMPLETE")

    # After a weekly reset, a stale ACTIVE bit from the just-completed prior
    # cycle must not immediately turn the fresh cycle from READY to IN PROGRESS
    # merely because the player zoned. Fresh Jonette dialogue or Cookbook KI
    # evidence releases the guard.
    for token in [
        "native_active_reset_guard",
        "stale 0x056 ACTIVE ignored after weekly reset",
        "a.native_active_reset_guard=nil",
        "native_active_ignored_after_reset_at",
    ]:
        if token not in ovens:
            errors.append(f"Ovens post-reset stale-ACTIVE guard missing: {token}")

    # Capture-derived invariant: a cleared WHM and an uncleared RDM produced the
    # same normal Maat "reached the stars" dialogue. Individual job wins must
    # therefore only be armed by Shattering Stars entry + battlefield clear.
    if "reached the stars" in skills.lower():
        errors.append("Maat normal dialogue must not confirm an individual job victory")
    if "battlefield clear time:" not in skills.lower() or "shattering stars" not in skills.lower():
        errors.append("Maat auto-win detector must require Shattering Stars battlefield clear evidence")

    # Black Coffin live captures verify all three Halshaob acceptance lines and
    # the shared Ashu Talif successful battlefield completion message. The
    # generic completion line is only authoritative while a Black Coffin run is
    # already IN PROGRESS, then the current active stage advances automatically.
    for token in [
        "in exchange fer lettin' you take on",
        "b.active_state='ACTIVE'",
        "the order has been given to invade the ashu talif!",
        "b.active_state='IN PROGRESS'",
        "s:find('objective complete.',1,true)",
        "s:find('return on the lifeboat',1,true)",
        "M.complete(key,'Ashu Talif objective complete')",
        "finished.last_objective_complete_step=key",
    ]:
        if token not in blackcoffin:
            errors.append(f"Black Coffin automatic progression contract missing: {token}")

    completion_block = re.search(r"Capture-verified success signal shared by all three Ashu Talif stages(.*?)end\nend", blackcoffin, re.S)
    if not completion_block:
        errors.append("Black Coffin objective-complete parser block missing")
    elif "b.active_state=='IN PROGRESS'" not in completion_block.group(1):
        errors.append("Black Coffin generic objective-complete text must require an active battlefield run")

    # Currency capture verified Imperial Standing in the native 0x113 payload.
    # ISNM should consume that balance automatically while preserving separate
    # Shajaf/key-item eligibility evidence. Currency refresh is shared globally.
    for token in [
        "function HC.request_currency(force)",
        "pm:AddOutgoingPacket(0x010F",
    ]:
        if token not in main:
            errors.append(f"shared Currency refresh contract missing: {token}")
    for token in [
        "HC.modules.packets.register(0x113,'isnm_currency',on_currency_packet)",
        "local isp=u32le(raw,0x7C)",
        "sync_isp(HC.modules.state.get_char(),isp,'Currency data')",
        "Currency data proves only the current balance",
        "out=out..' | ISP: '..tostring(s.last_isp)",
    ]:
        if token not in isnm:
            errors.append(f"ISNM automatic ISP contract missing: {token}")
    if "ISP seen:" in isnm:
        errors.append("ISNM status still uses the stale ISP seen label")

    # The same native Currency payload carries five standard Assault Point pools
    # immediately after Imperial Standing. Their balances should be visible on
    # each Assault Point Rewards collapsible header without extra packet spam.
    for token in [
        "leujaoam=0x80",
        "mamool=0x84",
        "lebros=0x88",
        "periqia=0x8C",
        "ilrusi=0x90",
        "HC.modules.packets.register(0x113,'assault point currency',on_currency_packet)",
        "local ap=assault_point_balance(c,area.id)",
        "format_number(ap)..' AP'",
        "%-26s  %2d/%-2d  |  %9s  |  %-12s  |  %s##assault_rewards_%s",
    ]:
        if token not in assaultprogress:
            errors.append(f"Assault Point header/currency contract missing: {token}")
    for token in [
        "local function assault_reward_rows(c,area)",
        "status='AFFORDABLE'",
        "status='NEED '..format_number(need)..' AP'",
        "table.sort(rows,function(a,b)",
        "'%d affordable | %d owned | %d remaining'",
        "imgui.Text('✓ OWNED')",
    ]:
        if token not in assaultprogress:
            errors.append(f"Assault reward purchase-planner contract missing: {token}")

    for token in [
        "local function weekly_reset_text()",
        "local function draw_weekly_summary(imgui,b)",
        "Weekly status: COMPLETE",
        "Manual / Capture",
        "if developer then",
        "manual Complete/Fail and no-time-limit Capture controls are enabled",
    ]:
        if token not in blackcoffin:
            errors.append(f"Black Coffin simplified UI contract missing: {token}")

    # v7.9.13 Account Intelligence + unified status/freshness framework.
    for token in [
        "function M.normalize_status",
        "function M.status_meta",
        "function M.draw_status",
        "function M.data_freshness",
        "function M.data_badge",
        "s=='AFFORDABLE'",
    ]:
        if token not in uikit:
            errors.append(f"unified UI status/freshness contract missing: {token}")
    for token in [
        "local function intelligence_rows(c)",
        "function M.intelligence(c)",
        "Black Coffin - ",
        "unowned reward",
        "Cosmo-Cleanse held",
        "daily_valid=daily_current",
        "weekly_valid=weekly_current",
        "data_badge('saved'",
    ]:
        if token not in smartdashboard:
            errors.append(f"Account Intelligence/reset-safe Overview contract missing: {token}")
    for token in [
        "function M.reward_summary(c)",
        "HC.modules.uikit.collection_item(row.item,row.status)",
        "HC.modules.uikit.draw_status(row.status",
    ]:
        if token not in assaultprogress:
            errors.append(f"Assault unified status/intelligence contract missing: {token}")
    if "function M.summary(c)" not in blackcoffin:
        errors.append("Black Coffin intelligence summary missing")
    if "function M.summary(c)" not in limbus:
        errors.append("Limbus intelligence summary missing")

    # v7.9.15 stability / polish contracts: a single ownership facade, safe
    # self-healing for duplicate/legacy/chain contradictions, and shared table
    # primitives used by the large collection screens.
    for token in [
        "function M.resolve_ids", "function M.current(input,force)", "function M.account(input,opts)",
        "function M.location_ids", "PORTER MOOGLE", "item_locator_snapshot",
    ]:
        if token not in ownership:
            errors.append(f"v7.9.15 universal ownership contract missing: {token}")
    for token in [
        "scan_duplicate_profiles", "DUPLICATE_CHARACTER_PROFILE", "scan_blackcoffin_chain",
        "BLACK_COFFIN_CHAIN", "scan_retired_fields", "cleanup_all_retired",
    ]:
        if token not in selfheal and token not in state:
            errors.append(f"v7.9.15 self-healing contract missing: {token}")
    for token in ["function M.table_begin", "function M.table_cell", "function M.collection_row", "function M.section_gap"]:
        if token not in uikit:
            errors.append(f"v7.9.15 UI consistency primitive missing: {token}")
    for module_name,module_text in [("Assault",assaultprogress),("Limbus",limbus),("HENM",henm)]:
        if "ui.table_begin" not in module_text:
            errors.append(f"v7.9.15 {module_name} table is not using shared UI table primitives")
    for module_name,module_text in [("Assault",assaultprogress),("Limbus",limbus),("HENM",henm),("Seasonal",seasonal),("Sea/Sky",seasky),("Anniversary",anniversary)]:
        if "HC.modules.skills.collection_item_" in module_text or "HC.modules.skills.collection_resolve_ids" in module_text:
            errors.append(f"v7.9.15 {module_name} bypasses the universal ownership engine")


    # v7.9.18 EXP-weighted Job Progression contracts.
    for token in [
        "local EXP_TO_NEXT_75={",
        "EXP_TOTAL_TO_75=running; -- 801,350 EXP from Lv.1 to Lv.75.",
        "local function job_exp_progress(j)",
        "p.GetExpCurrent",
        "earned*100/EXP_TOTAL_TO_75",
        "EXP %s/%s | Mapped quests",
    ]:
        if token not in skills:
            errors.append(f"v7.9.18 EXP-weighted job progression contract missing: {token}")
    if "level*100/75" in skills:
        errors.append("v7.9.18 Job Progression still contains the retired level/75 overall formula")

    # v7.9.17 reusable-item / EXP-ring automation contracts.
    reusable = (ROOT / 'modules' / 'reusableitems.lua').read_text(encoding='utf-8')
    rings = (ROOT / 'modules' / 'rings.lua').read_text(encoding='utf-8')
    for token in [
        "function M.register(def)",
        "function M.subscribe(name,fn)",
        "function M.poll()",
        "reusable item recharge",
        "authoritative_until=now+5",
        "and 'used' or 'charges_increased'",
    ]:
        if token not in reusable:
            errors.append(f"v7.9.17 reusable-item framework contract missing: {token}")
    for token in [
        "group='exp_ring'",
        "mark_weekly_recharged",
        "ev.kind=='used'",
        "function M.status(c)",
        "CHARGES AVAILABLE",
    ]:
        if token not in rings:
            errors.append(f"v7.9.17 EXP-ring automation contract missing: {token}")
    if "run_present_poll('reusableitems',0.25" not in main:
        errors.append('v7.9.17 reusable-item background reconciliation is not centrally scheduled')
    if "if it.id=='exp_ring' and HC.modules.rings" not in weekly:
        errors.append('v7.9.17 Daily / Weekly EXP Ring row is not using live ring status')
    if "recharge available this week" not in systems or "low charges | weekly recharge available" not in systems:
        errors.append('v7.9.17 Overview system engine does not surface actionable low/empty EXP-ring charge state')

    # v7.9.31-v7.9.32 responsive Guild Point recipe-link layout.
    guild_7931 = (ROOT / 'modules' / 'guild.lua').read_text(encoding='utf-8')
    if "imgui.SameLine();\n                    HC.modules.guild.draw_recipe_link(c,'daily_weekly_gp_recipe');" in weekly:
        errors.append('v7.9.31 GP Recipe button is still forced onto the status line and can clip when resized')
    for token in [
        "HC.modules.guild.draw_recipe_link(c,'daily_weekly_gp_recipe'",
        "M.draw_recipe_link(c,'guild_detail_recipe')",
        "window/table is narrowed",
    ]:
        if token not in (weekly + guild_7931):
            errors.append(f"v7.9.31 responsive GP recipe-link contract missing: {token}")
    for token in [
        "local status_column_x=nil",
        "pcall(imgui.GetCursorPosX)",
        "draw_recipe_link(c,'daily_weekly_gp_recipe',status_column_x)",
        "pcall(imgui.SetCursorPosX,anchor_x)",
    ]:
        if token not in (weekly + guild_7931):
            errors.append(f"v7.9.32 wrapped GP Recipe button anchor contract missing: {token}")

    # v7.9.33 closed-beta support and safe defaults.
    for token in [
        "function M.open_reports_folder()",
        "Open Reports Folder##hc_release_health_open_reports",
        "action=='folder' or action=='reports'",
        "Diagnostics Errors",
        "HC.modules.diagnostics.errors",
    ]:
        if token not in releasehealth:
            errors.append(f"v7.9.33 beta support contract missing: {token}")
    if 'c.settings.developer_mode=false;' not in state or 'if new_profile then' not in state:
        errors.append('v7.9.33 fresh profiles no longer default Developer Mode to off')
    for token in ['/hcheck health export', '/hcheck health folder', 'Developer Mode off']:
        if token not in beta_guide:
            errors.append(f"v7.9.33 beta guide contract missing: {token}")

    # v7.9.30 character-switch / login baseline protection for reusable items.
    for token in [
        "local cache_owner = nil",
        "local session_seen = {}",
        "local function ensure_cache_owner()",
        "if observed~=nil and session_seen[id]~=true then",
        "session_seen[id]=true",
        "session_baselined=true",
    ]:
        if token not in reusable:
            errors.append(f"v7.9.30 reusable-item login baseline contract missing: {token}")
    if "fully recharged to %s charges" in rings:
        errors.append('v7.9.30 EXP Ring notification still uses misleading fully-recharged wording for generic charge increases')

    # v7.9.16 unified global search / account item locator contracts.
    ui_src = ui
    for token in ["Refresh Items##hc_global_item_refresh", "locator.query,M.text(),12", "saved char"]:
        if token not in search_src:
            errors.append(f"v7.9.16 unified search contract missing: {token}")
    if "safe_draw('Account Item Locator',HC.modules.itemlocator.draw,c)" in ui_src:
        errors.append("v7.9.16 Character Info still renders the duplicate Account Item Locator panel")
    if "Account item lookup is available from Find anything" not in itemlocator_src:
        errors.append("v7.9.16 item locator compatibility entry point does not point users to global search")

    # v7.9.14 performance / cleanup contracts. The D3D present hook should no
    # longer guarded-call every background subsystem every frame, and expensive
    # progression/history/inventory work should be event-driven or lazy.
    for token in [
        "local present_poll_at={}",
        "local function present_due",
        "local function run_present_poll",
        "present_due('currency',1.0",
        "run_present_poll('state',0.25",
        "run_present_poll('zonesync',0.50",
        "present_due('itemlocator',1.0",
        "if HC.ui.open[1] and u and u.draw then",
    ]:
        if token not in main:
            errors.append(f"v7.9.14 present scheduler contract missing: {token}")
    if "itemlocator.poll" in ui:
        errors.append("v7.9.14 item locator still polls from every UI draw")
    for token in [
        "local BATCH_SECONDS=1",
        "local FALLBACK_SECONDS=60",
        "function M.invalidate(source,reason)",
        "systems.snapshot,c,false",
        "if changed and HC.modules.state and HC.modules.state.request_save",
        "event-driven reconcile",
    ]:
        if token not in progression:
            errors.append(f"v7.9.14 progression performance contract missing: {token}")
    if "systems.snapshot,c,true" in progression:
        errors.append("v7.9.14 progression still force-rebuilds Systems snapshot")
    if "m.progression.invalidate" not in dependencies:
        errors.append("v7.9.14 dependency graph does not dirty Progression lazily")
    for token in [
        "local HISTORY_REFRESH_SECONDS=600",
        "local history_session_synced={}",
        "HC.modules.seasonal.invalidate",
        "history_session_synced[ck]~=true",
    ]:
        if token not in zonesync:
            errors.append(f"v7.9.14 zone-sync performance contract missing: {token}")
    if "HC.modules.seasonal.reconcile,c,true" in zonesync:
        errors.append("v7.9.14 zone sync still force-scans Seasonal inventory")
    if "HC.request_currency" in assaultprogress:
        errors.append("v7.9.14 Assault rendering still requests Currency directly")
    if "function M.status(c)\n    if HC and HC.request_currency" in isnm:
        errors.append("v7.9.14 ISNM status still requests Currency on read")
    if "last_verified_at or os.time()" in limbus:
        errors.append("v7.9.14 Limbus draw still requests Currency on render")


    # v7.9.20 Overview simplification contract.
    if 'More Suggestions' in smartdashboard:
        errors.append('v7.9.20 normal Overview still contains More Suggestions')
    if 'Things to Prepare' in smartdashboard:
        errors.append('v7.9.20 normal Overview still contains Things to Prepare')

    # v7.9.21 true Overview contract.
    for token in ('Current Character','Other Characters','Shared Account'):
        if token not in smartdashboard:
            errors.append('v7.9.21 true Overview missing: '+token)
    draw_at=smartdashboard.find('function M.draw(c)')
    draw_block=smartdashboard[draw_at:] if draw_at>=0 else ''
    if 'draw_simple_next(imgui,c);' in draw_block:
        errors.append('v7.9.21 normal Overview still renders What to Do Next')
    if 'draw_current_character_overview(imgui,c,a);' not in draw_block or 'draw_other_characters_overview(imgui,a);' not in draw_block:
        errors.append('v7.9.21 Overview does not render current + other character summaries')

    # v7.9.22 current-job Overview progression contract.
    for token in ('current_job_progress_detail','current_job_progress','Mapped quests %d/%d','Overall %d%%'):
        if token not in (skills + smartdashboard):
            errors.append('v7.9.22 current-job Overview progression missing: '+token)
    if 'HC.modules.skills.current_job_progress_detail' not in smartdashboard:
        errors.append('v7.9.22 Overview does not reuse Skills current-job progression data')

    # v7.9.23 Overview density contract.
    current_overview_at=smartdashboard.find('local function draw_current_character_overview')
    other_overview_at=smartdashboard.find('local function draw_other_characters_overview')
    shared_overview_at=smartdashboard.find('local function draw_shared_account_overview')
    current_overview_block=smartdashboard[current_overview_at:other_overview_at] if current_overview_at>=0 and other_overview_at>current_overview_at else ''
    other_overview_block=smartdashboard[other_overview_at:shared_overview_at] if other_overview_at>=0 and shared_overview_at>other_overview_at else ''
    for token in ("{'Missions',","{'Anniversary',","{'Seasonal Rewards',"):
        if token in current_overview_block:
            errors.append('v7.9.23 current Overview still renders retired metric: '+token)
    if "'Missions '..overview_ratio" in other_overview_block or "'Events '..overview_events_ratio" in other_overview_block:
        errors.append('v7.9.23 saved-character Overview still renders Missions/Events')
    if "label='Outposts'" not in other_overview_block:
        errors.append('v7.9.23 saved-character Overview must retain Outposts status')

    # v7.9.24 Overview dashboard contract (no progress bars).
    for token in ('draw_overview_cards','overview_other_','Shared Account','Dynamis Pool','current_job_progress'):
        if token not in smartdashboard:
            errors.append('v7.9.24 Overview dashboard missing: '+token)
    if 'hc_true_overview_other_chars_v7921' in smartdashboard:
        errors.append('v7.9.24 Overview still contains retired wide saved-character table')
    if 'ProgressBar' in current_overview_block or 'progress_bar' in current_overview_block:
        errors.append('v7.9.24 Overview must not render progress bars')
    if "focus={section='outposts'}" not in smartdashboard:
        errors.append('v7.9.24 Overview must deep-link Outposts')
    if "focus_section=='outposts'" not in ui:
        errors.append('v7.9.24 Daily / Weekly must consume Outposts Overview focus')

    # v7.9.19 Anniversary UI default-state contract.
    if "sticky_anniversary_header('year_2023',l23,false)" not in anniversary:
        errors.append('v7.9.19 2023 Anniversary section must default to collapsed')
    if "sticky_anniversary_header('year_2023',l23,true)" in anniversary:
        errors.append('v7.9.19 2023 Anniversary section still defaults open')

    validate_workflow=ROOT / '.github' / 'workflows' / 'validate.yml'
    release_workflow=ROOT / '.github' / 'workflows' / 'release.yml'
    if not validate_workflow.is_file():
        errors.append('GitHub validation workflow missing')
    if not release_workflow.is_file():
        errors.append('GitHub release workflow missing')
    if validate_workflow.is_file() and 'tools/prepare_release.py' not in validate_workflow.read_text(encoding='utf-8'):
        errors.append('GitHub validation workflow must run prepare_release.py')
    if release_workflow.is_file():
        release_text=release_workflow.read_text(encoding='utf-8')
        for token in ['v*.*.*','tools/prepare_release.py','gh release create','CHANGELOG.md']:
            if token not in release_text:
                errors.append(f'GitHub release workflow missing contract: {token}')

    # HorizonXI capture proved HasKeyItem(false) for owned KIs, including
    # Cosmo-Cleanse 734. Runtime ownership must therefore return the cached
    # server 0x055 bit directly and treat API false as diagnostic-only.
    for token in [
        "[normalize_ki_name('Cosmo-Cleanse')] = { id=734",
        "if bitmap_seen then",
        "return bitmap_owned,bitmap_error,id,'0x055 key-item bitmap'",
        "HasKeyItem=false ignored on HorizonXI",
        "pending_bitmap_reconcile or (resource_index_complete and not full_index_reconcile_done)",
    ]:
        if token not in keyitems:
            errors.append(f"authoritative key-item ownership contract missing: {token}")
    # v7.9.27 Overview command-center regression contracts.
    skills_7927 = (ROOT / 'modules' / 'skills.lua').read_text(encoding='utf-8')
    smart_7927 = (ROOT / 'modules' / 'smartdashboard.lua').read_text(encoding='utf-8')
    for token in ['draw_overview_cards','draw_character_identity','Character Status','Current Job','Dynamis Pool']:
        if token not in smart_7927:
            errors.append(f'v7.9.27 Overview command-center contract missing: {token}')
    if 'Gear summary appears here after Character Info has observed your AF / Relic collection.' not in smart_7927:
        errors.append('v7.9.27 Overview must not imply it performs its own gear scan')
    if 'M.gear_collection_snapshot' in smart_7927 or 'collection_inventory_snapshot' in smart_7927:
        errors.append('v7.9.27 Overview must not trigger full inventory/gear scans')
    for token in ['CURRENT_JOB_STATIC_CACHE_SECONDS=30','overview_profile.job_gear','skills_capped=']:
        if token not in skills_7927:
            errors.append(f'v7.9.27 current-job detail contract missing: {token}')

    # v7.9.29 Guild Point daily item-count regression contracts.
    guild = (ROOT / 'modules' / 'guild.lua').read_text(encoding='utf-8')
    for token in (
        'GP_ITEM_VALUES',
        'gp_items_to_cap',
        'Need %d NQ',
        'Daily item target:',
        "['mythril gauntlets']={cap=6560,nq=3960}",
        "['gold buckler']={cap=6640,nq=4080}",
    ):
        if token not in guild:
            errors.append(f'v7.9.29 Guild Point item-count contract missing: {token}')

    # v7.9.28 Overview polish regression contracts.
    smart_7928 = (ROOT / 'modules' / 'smartdashboard.lua').read_text(encoding='utf-8')
    for token in [
        'overview_progress_card', 'overview_entry_card', 'overview_session_delta',
        'overview_delta_note', 'overview_section_break',
        '##hc_overview_other_characters_v7928',
        "TableSetupColumn('Character'", "TableSetupColumn('Daily'",
        "TableSetupColumn('Weekly'", "TableSetupColumn('Dynamis'",
        "return 'COMPLETE'", "return 'READY'", "return 'RESET'",
        'this session',
    ]:
        if token not in smart_7928:
            errors.append(f'v7.9.28 Overview polish contract missing: {token}')
    if 'M.gear_collection_snapshot' in smart_7928 or 'collection_inventory_snapshot' in smart_7928:
        errors.append('v7.9.28 Overview polish must not trigger full inventory/gear scans')

    # v7.9.26 backend-stutter regression contracts.
    state_text = (ROOT / 'modules' / 'state.lua').read_text(encoding='utf-8')
    reusable_text = (ROOT / 'modules' / 'reusableitems.lua').read_text(encoding='utf-8')
    ui_text = (ROOT / 'modules' / 'ui.lua').read_text(encoding='utf-8')
    smart_text = (ROOT / 'modules' / 'smartdashboard.lua').read_text(encoding='utf-8')
    if 'function M.save(immediate)' not in state_text or 'return M.request_save(2)' not in state_text:
        errors.append('v7.9.26 legacy state.save calls must coalesce into deferred writes')
    if "p.register(0x020,'reusable item targeted update',on_item_update)" not in reusable_text:
        errors.append('v7.9.26 reusable items must use targeted 0x020 slot updates')
    if "p.register(0x01D,'reusable item inventory'" in reusable_text or "p.register(0x01E,'reusable item inventory'" in reusable_text or "p.register(0x01F,'reusable item inventory'" in reusable_text:
        errors.append('v7.9.26 reusable items must not blanket-rescan from 0x01D/0x01E/0x01F')
    if 'GLOBAL_ATTENTION_CACHE_SECONDS=2' not in ui_text:
        errors.append('v7.9.26 global Attention cache missing')
    if 'Do not keep recomputing those retired' not in smart_text:
        errors.append('v7.9.26 Overview retired-summary cleanup missing')

    # v7.9.25 rhythmic inventory-stutter regression contract.
    skills_src=(ROOT/'modules'/'skills.lua').read_text(encoding='utf-8')
    itemlocator_src=(ROOT/'modules'/'itemlocator.lua').read_text(encoding='utf-8')
    token_start=skills_src.find('function M.collection_scan_token()')
    token_end=skills_src.find('\nend',token_start) if token_start>=0 else -1
    token_body=skills_src[token_start:token_end] if token_start>=0 and token_end>token_start else ''
    if 'gear_scan_cache.at' in token_body and 'Do not include gear_scan_cache.at' not in token_body:
        errors.append('v7.9.25 collection scan token must not depend on gear_scan_cache.at')
    if "return 'inv:'..tostring(update_counter)" not in skills_src or "return 'inv:na'" not in skills_src:
        errors.append('v7.9.25 stable inventory-counter collection token missing')
    if 'NO_COUNTER_FALLBACK_SECONDS=120' not in itemlocator_src:
        errors.append('v7.9.25 item locator low-frequency no-counter fallback missing')

    return errors


def main() -> int:
    cases = json.loads((ROOT / "tests" / "evidence_cases.json").read_text(encoding="utf-8"))
    failed = 0
    for case in cases:
        got = resolve(case.get("rows", []))
        expected = case.get("expected", {})
        mismatches = [k for k, v in expected.items() if got.get(k) != v]
        if mismatches:
            failed += 1
            print(f"FAIL: {case['name']}: expected {expected}, got {got}")
        else:
            print(f"PASS: {case['name']}")

    integration = check_runtime_integration()
    for err in integration:
        failed += 1
        print("FAIL:", err)
    if not integration:
        print("PASS: evidence resolver, canonical registry, catalog coverage, guided capture, self-healing, dependency graph, system engines, inspector, and runtime regression integration present")

    if failed:
        print(f"FAIL: {failed} regression issue(s)")
        return 1
    print(f"PASS: {len(cases)} evidence policy regression case(s) + runtime integration")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
