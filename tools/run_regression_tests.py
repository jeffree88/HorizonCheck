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
    anniversary = (ROOT / "modules" / "anniversary.lua").read_text(encoding="utf-8")
    blackcoffin = (ROOT / "modules" / "blackcoffin.lua").read_text(encoding="utf-8")
    isnm = (ROOT / "modules" / "isnm.lua").read_text(encoding="utf-8")
    assaultprogress = (ROOT / "modules" / "assaultprogress.lua").read_text(encoding="utf-8")
    smartdashboard = (ROOT / "modules" / "smartdashboard.lua").read_text(encoding="utf-8")
    uikit = (ROOT / "modules" / "uikit.lua").read_text(encoding="utf-8")
    limbus = (ROOT / "modules" / "limbus.lua").read_text(encoding="utf-8")

    order = re.search(r"local order\s*=\s*\{(.*?)\};", main, re.S)
    if not order:
        errors.append("could not locate module load order")
    else:
        body = order.group(1)
        if body.find("'evidence'") < 0 or body.find("'keyitems'") < 0 or body.find("'evidence'") > body.find("'keyitems'"):
            errors.append("evidence must load before keyitems")
        if body.find("'regression'") < 0:
            errors.append("regression module missing from load order")
        for mod in ("'questgraph'", "'systems'", "'catalog_integrity'", "'canonical'", "'catalog_coverage'", "'capturewizard'", "'selfheal'"):
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
        "if HC.request_currency then pcall(HC.request_currency); end",
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
        "if HC.request_currency then pcall(HC.request_currency); end",
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
