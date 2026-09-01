### v7.9.13 highlights
- Overview now has an **Account Intelligence** layer that can surface the current Black Coffin step/cost, affordable Assault rewards, and ready Limbus entries alongside normal zone/activity recommendations.
- Offline daily/avatar/weekly values are reset-safe: stale cycles show as unavailable rather than looking like fresh `0/x` progress, while permanent progression remains saved.
- Assault, Limbus, and HENM collections begin using one shared HorizonCheck status vocabulary and live/saved freshness language for a more consistent UI.

### v7.9.12 highlights
- Assault Point rewards now act as a live purchase planner: **AFFORDABLE** items rise to the top, unaffordable items show the exact AP still needed, and owned rewards move below useful purchases.
- Black Coffin now opens with a compact current/next-step summary plus entry cost and weekly reset timer; manual/capture controls are Developer Mode only.
- GitHub can now validate every main/PR update and automatically build + publish a release ZIP whenever a matching `vX.Y.Z` tag is pushed.

### v7.9.11 highlights
- Assault Point Rewards headers now use aligned fixed-width columns so all five areas are easier to scan vertically.
- Live AP balances are right-aligned, with vendor and Whitegate location columns aligned independently.

### v7.9.10 highlights
- Assault Point Rewards headers now show your live area balance, for example `Leujaoam Sanctum 0/11 | 2,610 AP | Yahsra - Whitegate L-10`.
- All five Assault Point pools update automatically from HorizonXI's native Currency data and share the existing one-minute Currency refresh.

### v7.9.9 highlights

- ISNM Imperial Standing now refreshes automatically from HorizonXI's native Currency data; talking to Shajaf is no longer required just to update the ISP number.
- HorizonCheck shares one throttled Currency refresh across ISP, HAAP, and Ancient Beastcoins to avoid duplicate requests.
- ISNM eligibility/order state remains based on direct Shajaf/key-item evidence; the automatic ISP balance cannot falsely change eligibility by itself.

### v7.9.8 highlights

- Black Coffin's three-stage weekly chain now advances automatically from captured live HorizonXI dialogue: `NEXT -> ACTIVE -> IN PROGRESS -> COMPLETE`.
- Scouting the Ashu Talif, Royal Painter Escort, and Targeting the Captain all use Halshaob's confirmed acceptance line and the battlefield's confirmed objective-complete message.
- Completing the third stage automatically marks Black Coffin `3/3 COMPLETE`; manual Complete/Fail controls remain available as fallback.
- Black Coffin Capture remains manual-stop with no time limit for future verification runs.

### v7.8.17 highlights

- Character Info's compact Job Progression rows no longer show aggregate gear counts.
- `Overall` is now a simple leveling percentage from the current level to the Lv.75 cap; gear, quests, and Maat no longer change that percentage.
- Full AF/Relic and missing-gear detail remains available when a job is expanded.

### v7.8.15 highlights

- Reworks the Black Coffin tab into a compact Chocobo-style table for the three weekly chain steps.
- Condenses the large per-mission reward accordions into one three-row reward summary.
- Cross-checks the displayed reward notes against the current HorizonXI Wiki, including Koga Shuriken, Yoichi's Sash, Barbarossa gear, Mog Wardrobe 3 +5 slots, Ancient Lockbox counts, and documented bonus-box conditions.

### v7.8.14 highlights

- Removes the duplicate **Chocobo Riding Game** row from **Weekly EXP Scrolls**.
- Weekly EXP Scrolls now counts only its five remaining scroll-source objectives; Chocobo Riding Game remains under Weekly Objectives.

### v7.8.12 highlights

- Renames the Daily / Weekly **Dragon Chronicles / EXP Scroll Sources** section to **Weekly EXP Scrolls**.

# HorizonCheck

### v7.8.11 highlights

- Initial Synchronization now has a fifth simple step: talk to your nation Outpost NPC, open Regional Teleport, and flip through the pages once.
- The Outpost step automatically checks off after HorizonCheck receives a trusted Regional Teleport menu snapshot and shows how many current outposts were learned.
- Previously synchronized trusted Outpost data counts automatically, so established characters are not forced to repeat the scan.

### v7.8.10 highlights

- Initial Synchronization is now a simple five-step first-run checklist written for brand-new users: change zones, talk to Eeko-Weeko, talk to Rytaal, and visit the fame checkers.
- Technical state/schema/package/inventory details are hidden from the normal setup view and remain available in Developer Mode / Diagnostics.
- The completion screen and setup buttons use simpler language such as **Check Again**, **Hide for Now**, and **Finish Setup**.

### v7.8.9 highlights

- Chocobo `NPC/route phase` is now developer-only and `CAPTURE VERIFIED` is strictly per-route.
- Only routes backed by a user-supplied capture are marked verified; currently Quelle -> Southern San d'Oria and Orlaine -> Port Jeuno.
- Kazham no longer shows separate Chocobo Ticket, requirements, or source-reference rows in the normal UI.

### v7.8.8 highlights

- Chocobo Riding now includes a **Kazham (F-9)** section between Windurst and Run History, using the supplied FFXIclopedia route data for Tielleque -> Norg.
- The Kazham block shows the source reward windows, requirements, current availability phase, account-wide personal best/completed runs, and latest observed result.
- Kazham is now recognized as a supported Riding Game origin in-zone, so future runs are recorded under the correct Kazham route and character.
- Source-derived Kazham values remain clearly labeled as reference data until independently verified by a HorizonXI capture.


### v7.8.7 highlights

- Chocobo Riding run statistics are now account-wide across every HorizonCheck character profile in the shared state file.
- Run History shows the character that completed each ride, and histories from all characters are merged newest-first.
- Personal bests identify the character holding the best time, while Completed runs totals are summed across all characters for each route.
- Observed reward results for a route are also combined account-wide and labeled with the character that recorded them.


### v7.8.6 highlights

- Plant-pot daily completion now comes from **examining** pots only; crystal-feed interactions no longer count as daily checks.
- Successfully feeding a pot removes that pot's earlier check credit for the current day, so after feeding you must examine that pot again before **Check Plant Pots** can auto-complete.
- The Moogle `Use this crystal, kupo?` prompt arms the following flowerpot packet as a feed action, preventing the shared `0x0FA` interaction from briefly being counted as an examine.


### v7.8.5 highlights

- Mog House plant-pot tracking now counts successful crystal feeds from the capture-verified Moogle confirmation line while retaining the existing unique-pot daily check tracker.
- Feed counts reset daily and are shown beside the plant-pot status; the existing daily objective still completes from checking every unique planted pot and does not require a feed when a plant is not ready for one.
- Sea / Sky material locations now use a dash separator, for example `Aern Organ - 8/3 - Inv(3), Satchel(5)`.


### v7.8.4 highlights

- Sea / Sky → **Elemental Obis / Gorgets** now shows the physical container location beside every material stack, such as `Aern Organ - 8/3 @ Inv(3), Satchel(5)`.
- Split stacks are broken down by container while retaining the existing total owned/required count.
- Location reporting reuses HorizonCheck's cached inventory scan, so it does not add another per-frame inventory walk.


### v7.8.3 highlights

- Missions → **Current Story / Next Mission** now places a **GO** button immediately to the right of each current mission.
- **GO** opens the matching HorizonXI Wiki mission guide in the player's default browser, including numbered mission-page handling for nation, Zilart, and Promathia storylines.
- The link is click-only and does not add background network activity to HorizonCheck.


### v7.8.2 highlights

- Cleans migrated user/account files out of `Game\addons\horizoncheck\` after the config-backed state has loaded and passed migration/validation.
- Every legacy file is copied and byte-verified before removal; differing name collisions are preserved as `legacy_addon_*` files in the appropriate config folder instead of being overwritten.
- Removes abandoned state temp/write-test files only after the authoritative config state validates, leaving the addon install folder code-only without risking account data.


### v7.8.1 highlights

- Restores the Diagnostics tab after a v7.8.0 Lua string-escape regression prevented `modules/diagnostics.lua` from loading.
- The new external User Data path display remains intact, with Windows path separators escaped safely in Lua source.


### v7.8.0 highlights

- HorizonCheck now stores user-generated data under `Game\config\addons\horizoncheck\` instead of beside the addon code.
- State/settings, backups, Developer captures, logs, reports, and persistent Outpost data survive full replacement of `Game\addons\horizoncheck\` during updates.
- Existing state is copied and validated automatically on first load; the original addon-folder state is retained as a rollback copy.
- If the config folder cannot be used safely, HorizonCheck automatically falls back to the legacy addon-folder location instead of risking saved data.


### v7.7.15 highlights

- Windurst Eco-Warrior is now capture-verified end to end, including the final Lumomo turn-in.
- Lumomo's `Indigested Meat` reward dialogue is correlated with the subsequent **Page from the Dragon Chronicles** reward before the weekly objective is marked complete.
- The verified completion updates the Eco rotation and remains complete through reloads until the normal Conquest-cycle progression/reset logic applies.


### v7.7.14 highlights

- Guild Points now shows a **Recipe** link beside today's detected requested item in Daily / Weekly and the detailed Guild Points view.
- Fishing requests show **Item Wiki** instead, while crafted requests open the corresponding HorizonXI Wiki item search/page for recipe details.
- Adds a **GP Item List** shortcut to HorizonXI's server-specific Guild Points/Items master table.
- No runtime scraping is used; HorizonCheck only opens the wiki when the player clicks a link.

### v7.7.13 highlights

- Requiem of Sin now auto-completes its Weekly Objectives row from current-cycle key-item evidence plus the successful Boneyard Gully battlefield-clear message.
- The consumed entry key item is remembered for the current Conquest cycle, so a successful clear stays checked through reloads until weekly reset.
- Developer Mode now has a dedicated Requiem capture profile instead of requiring the Eco capture button.


### v7.7.12 highlights

- Attention / Next Up no longer disappears just because Overview is selected.
- The global Attention section remains visible across every tab when an urgent `DO NOW` activity exists.
- Empty/non-urgent Attention still stays hidden to avoid UI bloat.


### v7.7.11 highlights

- Removes the extra divider line between Sky Gods and Sea Bosses.
- Elemental Obis / Gorgets now keeps its open/closed state independently of live checkbox/count updates, so checking a completed item no longer collapses the section.

### v7.7.10 highlights

- Fixes manual Elemental Obi/Gorget checkboxes so clicks persist without a transient Sea / Sky runtime error.
- Manual ownership now updates immediately, then cache/save work is handled defensively in the background.

### v7.7.9 highlights

- Elemental Obi/Gorget materials now turn white as soon as the live owned quantity satisfies the required quantity; unmet counts stay dim.
- Each material keeps an explicit current/required count such as `Phuabo Organ - 7/7`.
- Obi/Gorget pairs are grouped into bordered alternating sections with a center divider, making the two-column material tracker easier to scan.


### v7.7.8 highlights

- Fixes the remaining error when expanding Elemental Obis / Gorgets.
- The expanded section no longer creates ImGui tables or column stacks; it uses the most basic HorizonCheck rendering primitives while keeping Obis left, Gorgets right, and material counts visible.
- A problem with one reward row now degrades only that row instead of closing Sea / Sky.

### v7.7.7 highlights

- Reworks the Elemental Obi/Gorget renderer again using HorizonCheck's proven shared responsive two-column UI helper.
- The section is collapsed by default, so opening Sea / Sky no longer runs the material renderer automatically.
- Collection/material lookup failures now degrade to CHECKING instead of taking down the whole Sea / Sky tab.

### v7.7.6 highlights

- Fixes the Sea / Sky runtime error introduced by the new Obi/Gorget material tracker.
- Obi/Gorget progression now uses one flat side-by-side table instead of nested tables for better Ashita compatibility.
- Material-count failures are isolated so Sea / Sky remains usable even if a container scan is unavailable.

### v7.7.5 highlights

- Sea / Sky now has a collapsible **Elemental Obis / Gorgets** tracker beneath Sea Bosses.
- Eight Obis are shown on the left and eight Gorgets on the right, with exact base-item/chip/organ requirements and live `owned / required` material counts.
- Finished items remain complete after their materials are consumed, while unfinished items show `READY` when every required material is on hand.

### v7.7.4 highlights

- Assault Notes now begin closer to the mission/location text instead of at the exact center of the window.
- The divider uses a tighter 38% / 62% mission-to-notes split while preserving clean alignment and avoiding overlap.
- Persistent notes and completion tracking are unchanged.

### v7.7.3 highlights

- Assault mission rows now use aligned **Assault / Location** and **Notes** columns.
- A consistent vertical divider separates the mission information from the note editor, so all notes line up cleanly.
- Existing persistent notes, completion tracking, and Developer controls are unchanged.

### v7.7.2 highlights

- Weekly Objectives now includes **Requiem of Sin (X's Knife)** immediately below Uninvited Guests.
- The row recognizes the two Requiem entry key items and shows when the character is ready to head to Boneyard Gully.
- `Go` opens Requiem of Sin directly in Quest Details.


### v7.7.1 highlights

- Weekly EXP Scrolls now uses the same clean table-first layout as the other Daily / Weekly collapsible sections.
- Rows are aligned into Objective, Status, and Notes columns while existing tracking and Developer capture behavior remain unchanged.

### v7.7.0 highlights

- Missions now starts with an action-first **Current Story / Next Mission** table for your active nation, Zilart, CoP, and current HorizonXI ToAU progression.
- Overview gains a compact **Content Readiness** section for major lockout/entry systems such as Dynamis, Limbus, Assault, ENM, Avatars, Eco-Warrior, Black Coffin, and Chocobo Riding.
- **While You're Here** replaces the older generic Zone Intelligence presentation and ranks unfinished current-zone quests, avatar fights, ENMs, Sea/Sky gear targets, Outposts, and supported Assault opportunities as DO NOW / READY / PREP.
- Current mission rows can flow into What Should I Do? and `Go` directly to the matching Missions section.


### v7.6.8 highlights

- Windurst Eco-War now follows capture-verified Lumomo/Ahko lifecycle evidence through the level-20 field phase and Indigested Meat return phase.
- Fresh-week Windurst status is protected from stale native ACTIVE bits until current-week dialogue or proof-key-item evidence confirms the quest is really underway.
- Developer capture reports deduplicate repeated normalized dialogue mirrors, and EXP Ring scanning now uses a dirty-cache/reconcile path instead of rescanning every draw.
- Removes stale Dragon-tab visibility state and corrects the Notifications description.

### v7.6.7 highlights

- Normal play is quieter: routine automatic ACTIVE / IN PROGRESS / sync chatter is Developer Mode only, while meaningful completions, rewards, warnings, and errors remain visible.
- Overview no longer renders an empty Zone Intelligence section when there is nothing actionable in the current zone.
- Removes obsolete Overview summary scans left behind by the recent UI consolidation and centralizes more shared table/header rendering in the UI kit.
- Runtime/package audit found no orphan Lua modules in the release.

### v7.6.6 highlights

- Normal HorizonCheck load/reload is now quiet; the extra addon-generated version/initialized chat line has been removed.
- Ashita's native addon-loaded line remains, while actual HorizonCheck self-test failures still produce a visible warning and open Diagnostics.

### v7.6.5 highlights

- Prevents a stale Secrets of Ovens Lost `0x056 ACTIVE` bit from falsely starting the new weekly cycle when zoning immediately after reset.
- A prior-week verified completion now arms a reset guard; only fresh Jonette dialogue or current-week Cookbook ownership can advance the new cycle.
- Removes the misleading automatic IN PROGRESS chat message caused by that stale zone-in packet.

### v7.6.4 highlights

- Reduces normal UI bloat: the top line now shows only Daily/Weekly totals, and global Attention only appears outside Overview when something is genuinely urgent.
- Weekly Objectives now use compact Objective / Status / Open rows; detailed explanations are hover help and dedicated trackers can be opened with `Go`.
- Conquest / Outpost Details and Account / Characters are collapsed by default, with their heavier work deferred until opened.
- Removes retired Overview rendering code plus the unused legacy dashboard and standalone Collections UI modules.


### v7.6.3 highlights

- Aggressively simplifies Overview by removing the duplicate Character, Current Activity, Progression, Events & Collections, and Current Job Gear blocks.
- Overview now focuses on actionable recommendations, current-zone intelligence, and account/character comparison.
- Detailed tracking remains in the dedicated tabs; no progression data was removed.

### v7.6.2 highlights

- Moves the complete Weekly EXP Scrolls tracker into Daily / Weekly directly beneath Weekly Objectives.
- Removes the redundant standalone Dragon / EXP tab while preserving its rows, statuses, capture controls, and Hide Completed preference.
- Old Dragon / EXP navigation now opens the new Daily / Weekly subsection automatically.

### v7.6.1 highlights

- `Go` actions that target a quest now open that quest directly in the Quests tab's **Quest Details** pane.
- Applies to Overview recommendations, Universal Search quest results, and Zone Intelligence quest actions.
- Zone Intelligence now forwards exact quest identifiers for reliable selection.

### v7.6.0 highlights

- Adds a Progression Blocker Engine that explains exactly what is preventing mapped quests from becoming available and follows quest dependencies to the next actionable prerequisite.
- Overview now has a **Blocked** view, while locked Quest details and Universal Search expose the same blocker guidance.
- Sea / Sky now has per-section **Missing gear only** and **Hide completed bosses** filters to keep the collection tracker short as progress increases.
- Sky boss completion/Zone Intelligence counts respect the consolidated NQ/HQ collection slots introduced in v7.5.2.


### v7.5.2 highlights

- Sky abjuration NQ/HQ gear is now shown as one collection piece, such as `Zenith Mitts / Zenith Mitts +1`.
- Either quality counts as obtained; HorizonCheck no longer implies that both NQ and HQ versions are required.
- Combined rows retain automatic location detection, saved ownership, manual reconciliation, and Universal Search support.

### v7.5.1 highlights

- Removes Recent Activity from Overview so the dashboard stays focused on current progression and recommendations.
- The internal timeline/history system remains intact for diagnostics and evidence tracking.

### v7.5.0 highlights

- Overview recommendations and Zone Intelligence now have **Go** buttons that jump directly to the relevant tracker tab.
- Universal Search results are actionable too, including direct job focus for Job Gear results and section focus for Daily Avatar and Sea / Sky results.
- **Job Progression 3.0** is more compact and action-first: each expanded job starts with its next useful progression step instead of repeating summary information.
- Overview now includes a compact **Recent Activity** feed filtered to meaningful automatic/progression changes instead of Diagnostics noise.

### v7.4.3 highlights

- Removes the outer `Show Job Progression` collapsible header.
- Job Progression content is now immediately visible when the tab opens, while each individual job remains collapsible.

### v7.4.2 highlights

- Removes the redundant all-job Progression Summary table from Job Progression.
- The tab now goes directly to Job Progression Planner and the per-job expandable sections.
- Level, Maat, AF/Relic progress, overall progress, and missing gear are still shown within each job.

### v7.4.1 highlights

- Removes the redundant Jobs / Levels roster from Job Progression.
- Job levels remain visible in the Progression Summary alongside Maat and AF/Relic progress.
- Job Progression now opens directly into the useful summary/planner content.

### v7.4.0 highlights

- **Job Progression 2.0** adds an all-job Level / Maat / AF / Relic summary, overall progression scores, a Missing gear only filter, mapped quest counts, and next-missing-gear callouts.
- **Progression Dashboard 3.0** emphasizes the Best Next action and adds views for In This Zone, Do Now, Ready Now, Ending Soon, Prep / Verify, Quests, and Activities.
- Overview now shows a compact missing-gear shortlist for the current job.
- **Universal Search** now searches quests, missions, unlocks, ENMs, Daily Avatars, AF/Relic gear, Sea/Sky gear, and tracked systems, with State / Where / Tab columns and exact-match ranking.

### v7.3.1 highlights

- Removes the redundant standalone **Collections** tab.
- AF / Relic gear remains in **Job Progression**, and Sea/Sky drops remain in **Sea / Sky**.
- Existing ownership data and Overview collection totals are preserved internally.

### v7.3.0 highlights

- Overview is now a **Progression Dashboard** with ranked Next Actions and filters for All, Current Zone, Activities, and Quests.
- **Zone Intelligence** automatically shows tracked quests, Daily Avatar fights, ENMs, and Sea/Sky bosses relevant to the current zone.
- Adds a new **Collections** tab after Sea / Sky with all-job AF / AF +1 / Relic / Relic +1 / Relic -1 / Relic Accessory progress, item locations, and a Missing Only detail view.
- Sea/Sky and AF/Relic collection totals are also surfaced on the Overview.


### v7.2.37 highlights

- Diagnostics is now organized into six main troubleshooting groups instead of dozens of top-level collapsible headers.
- A compact health summary shows Release, Sync, Errors, State Integrity, and Performance at the top of the tab.
- Existing diagnostics and repair capabilities are preserved, with low-level development tools grouped under Advanced / Developer.

### v7.2.36 highlights

- Sea / Sky boss headers now show the boss zone directly.
- Each gear row has a visible Location column showing the inventory/storage/wardrobe container where the item was detected.
- Manually or historically confirmed pieces that are not currently detected show `SAVED` instead of pretending to have a live bag location.

### v7.2.35 highlights

- Cleans up the Sea / Sky header so the title and totals are no longer squeezed together on one line.
- The tab now shows `Sea / Sky Collection` with a dedicated `Obtained: Sky Gods X/Y | Sea Bosses X/Y` summary line underneath.
- Shortens the explanatory auto-scan note while preserving the same tracking behavior.

### v7.2.34 highlights

- Sea / Sky now keeps only the main Sky Gods and Sea Bosses collapsible headers.
- Individual bosses are always visible inside their section and are arranged two per row to greatly shorten the tab.
- Boss cards use compact Gear / Owned tables; locations and item-source details remain available on hover.

### v7.2.33 highlights

- Sea / Sky is cleaner and more compact, with a single-line Sky/Sea collection summary.
- Boss rows now use compact `Boss | Zone | obtained/total` headers with less vertical spacing.
- Gear tables use tighter proportional Gear / Source / Owned columns and compact ownership controls.
- The Sky/Sea divider remains clear without the oversized gap.

### v7.2.32 highlights

- Adds a stronger visual divider and extra spacing between Sky Gods and Sea Bosses in the Sea / Sky tab.
- Keeps both collection sections collapsible and otherwise unchanged.

### v7.2.31 highlights

- Adds a **Sea / Sky** collection tab immediately after Seasonal.
- Tracks Sky god direct drops and abjuration gear, plus Sea Jailer/Ix'aern/Absolute Virtue equipment.
- Uses automatic inventory/storage/wardrobe ownership detection with persistent per-character obtained history and manual reconciliation checkboxes.
- Sky/Sea and individual boss sections are collapsible with collection progress counts.

### v7.2.30 highlights

- Chocobo Riding now uses the same cleaner HorizonCheck styling language as the Eco-War tab instead of its separate blue-gray presentation.
- Route details, history, observed results, rewards, and riding-time information now render in the shared table-first layout with visible column headers.
- The Developer Capture control now sits on the main Chocobo header line for a more uniform layout.

### v7.2.29 highlights

- Daily Objectives, Daily Avatar Fights, and Weekly Objectives are now collapsible like the Black Coffin Weekly Chain section.
- Progress and reset timing remain visible in the collapsible headers.
- Existing tables, hide-completed filters, automatic tracking, and Daily Avatar developer capture are preserved.

### v7.2.28 highlights

- Adds a Developer Mode manual Capture / Stop Capture button after the Daily Avatar Fights Japanese-midnight status.
- The capture stays armed until manually stopped so full avatar-fight evidence can be collected.
- Normal users do not see the control because it is Developer Mode only.

### v7.2.27 highlights

- Daily Avatar Fights now has its own **Hide completed objectives** toggle.
- A daily avatar is only considered complete after its required key item was observed held during the current daily window and is later observed consumed/not held; this state survives reloads and resets at Japanese midnight.
- HAAP Weekly Scrolls no longer displays the extra `verified` / `not verified` suffix in its normal weekly status row.

### v7.2.26 highlights

- Daily / Weekly now uses the same table-first visual format as the Eco-War tab.
- Daily Objectives are split into Objective, Status, and Notes columns.
- Daily Avatar Fights are split into Avatar, NPC / Location, Key Item, and Status columns.
- Weekly Objectives, Dynamis, and Limbus use the same aligned Objective / Status / Notes layout.

### v7.2.25 highlights

- Adds **Daily Avatar Fights** between Daily Objectives and Weekly Objectives.
- Shows all six elemental Prime Avatar fights plus Fenrir and Diabolos, including NPC, location, required key item, and live key-item ownership.
- Avatar readiness uses the existing HorizonCheck key-item bitmap/evidence system and does not alter the normal Daily Objectives completion total.

### v7.2.24 highlights

- Assault mission rows now show `- Notes:` after the location for clearer separation.
- The persistent per-character Assault note box is three times wider and supports longer notes.

### v7.2.23 highlights

- Adds a `Notes:` editor directly after the location on every Assault mission row.
- Assault notes are saved per character and persist through reloads and logout/login.
- Notes are kept separate from completion proof, so native Assault history sync cannot overwrite them.
- Clearing Assault completion progress preserves the user's notes.

### v7.2.22 highlights

- Corrects Chocobo reward targets/cutoffs so they follow each verified destination rather than the old rotation phase.
- Orlaine -> Port Jeuno now shows **Windurst Woods Glyph <= 15:29**; a capture-verified 15:34 run ended at Narsha and awarded Gysahl Greens.
- Sariale -> Southern San d'Oria now shows **Miratete's Memoirs <= 28:36**.
- San d'Oria routes are corrected to Bastok = Dragon Chronicles <= 19:59, Windurst = Miratete's Memoirs <= 28:19, and Upper Jeuno = East San d'Oria Glyph <= 13:15.

### v7.2.21 highlights

- Corrects Windurst Woods Chocobo Riding NPC rotation to Orlaine -> Sariale -> Amimi.
- Prevents the tracker from showing Amimi when Orlaine is actually active.

### v7.2.20 highlights

- Chocobo Riding now calibrates its live Earth-time timer from HorizonXI's capture-verified `Time elapsed` messages after zone transitions.
- A full Quelle -> Southern San d'Oria capture verifies a 19:25 completion at Camereine and a Page from the Dragon Chronicles reward.
- Final route completion and reward tracking remain evidence-driven; the server elapsed messages only improve live timer accuracy.

### v7.2.19 highlights

- New character profiles now explicitly start with **Developer Mode OFF**.
- Existing characters keep their saved Developer Mode setting.
- Developer-only controls remain available from Settings when intentionally enabled.

### v7.2.18 highlights

- Adds capture-verified full-turn-in dialogue detection for both Kipling and Ah Puch after all four Boyahda items are handed in.
- Those completion lines can reconcile a missed individual hand-in and mark the entire four-item NPC lane complete.
- Individual generic success dialogue remains inventory-correlated only, so it still cannot guess which single item was traded.

### v7.2.17 highlights

- Adds the same clearer separation between the top-level 2023, 2024, and 2025 Anniversary sections.
- Keeps the extra spacing between 2024 NPC/location rows and before the Aerec Bonus section.
- Preserves the sticky open-state behavior, so trading an item still will not collapse the menu.

### v7.2.16 highlights

- Adds extra separation between each 2024 Anniversary NPC/location section so the list is easier to scan.
- Adds the same clearer spacing before the Aerec Bonus section.
- Keeps the sticky open-state behavior from v7.2.15, so trading an item still will not collapse the menu.

### v7.2.15 highlights

- Anniversary year and NPC sections now use HorizonCheck-owned sticky open-state, so trading an item cannot collapse the menu.
- 2024 NPC-group and year header identities stay stable while progress changes.
- Progress/COMPLETE text is shown inside each section so the user's open/collapsed state is preserved.

### v7.2.13 highlights

- Adds capture-verified successful turn-in detection for **Kipling** in The Boyahda Tree.
- Confirms Kipling uses the same generic acceptance line and the same `0x020` inventory-update correlation pattern already verified for Ah Puch.
- Both Boyahda NPC lanes now auto-check only the exact item actually removed/decreased from inventory; dialogue alone still cannot complete anything.

### v7.2.12 highlights

- Ah Puch successful trades can now auto-check the exact 2024 Anniversary item when his capture-verified acknowledgement is paired with the matching Inventory `0x020` item decrease/removal.
- Generic acceptance dialogue alone still cannot complete anything; HorizonCheck requires the item-ID inventory correlation.
- Boyahda status now shows partially verified hand-ins and the exact items already turned in.

### v7.2.11 highlights

- Learns the capture-verified Kipling + Ah Puch 2024 Anniversary riddles from The Boyahda Tree.
- Shows their requested items automatically without treating a batch of four clues as completion evidence.
- Keeps Anniversary completion conservative: only verified turn-in evidence can complete items automatically.

### v7.2.10 highlights

- Fixes the Anniversary Developer Capture reload/UI compatibility issue and hardens capture controls against optional ImGui binding differences.
- The Developer Mode Capture / Stop Capture control remains beside the Anniversary Quest Guide heading.
- UI-frame failures now echo the real runtime error in chat in addition to the generic recovery notice.
- Anniversary tab now exposes a **Capture** / **Stop Capture** control beside **HorizonXI Anniversary Quest Guide** when Developer Mode is enabled.
- Anniversary captures run until manually stopped so complete NPC dialogue/turn-in sequences can be collected without leaving the tab.

### v7.2.1 highlights
- One consolidated Diagnostics workspace inside the main HorizonCheck window.
- No separate floating diagnostics window or duplicate diagnostic section list.
- All maintenance, health, capture, audit, integrity, and performance tools remain available in the Diagnostics tab.


### v7.1 highlights
- One-time Initial Synchronization recovery summary before setup closes.
- Actionable Synchronization Health with exact refresh steps.
- Character Registry for safe management of offline saved HorizonCheck profiles.
- Expanded conservative Anniversary lane automation and unmapped-riddle evidence collection.
 v6.98.0


## v6.98.0 - Release Readiness, Import Coverage, State Cleanup, Telemetry

- Expands Historical Progression Import diagnostics into a source-by-source coverage report, including observed native quest IDs, safely imported mappings, blocked/quarantined mappings, missions, permanent unlocks, advanced jobs, Limit Breaks, and native Assault history.
- Adds a filtered Catalog Verification Work Queue for collisions, unsafe native IDs, HorizonXI availability gaps, and incomplete catalog fields.
- Advances saved-state schema to 24 and safely prunes retired UI/cache fields behind the existing pre-migration backup, validation, verified save, and automatic rollback protections. Progression/evidence/manual state is never pruned by this pass.
- Adds Diagnostics → State Cleanup / Migration Pruning with a manual safe cleanup action and a report of retired fields removed.
- Adds runtime cache/event telemetry to the Performance Profiler, including Planner/Search/Seasonal/inventory/history-import cache health and expensive scan counters.
- Adds missing current tab defaults for Seasonal, Character Info, and Job Progression while preserving existing user tab choices.
- Keeps the new work event-driven and cached so the v6.91.1 open-window performance fixes remain intact.


## v6.97.1 - Why Inspector Removal

- Removes the clickable Why inspector feature completely, including its popup window and `?` controls.
- Keeps technical Quest Details information under a neutral collapsed **Advanced Details** section.
- Simplifies shared Overview/UI helpers so they no longer build inspector metadata.



## v6.96.0 - Historical Import, Self-Healing, Shared UI

- Adds an event-driven Historical Progression Import engine. Native completed quest history is imported only when the HorizonXI canonical mapping is ALLOW; repeatable current-cycle completion is never inferred from permanent history.
- Backfills permanent mission proof, permanent key-item unlocks, advanced job unlocks proven by job levels, and Limit Break 1-5 proof from observed level thresholds.
- Adds Historical Progression Import to first-run synchronization, zone reconciliation, Diagnostics, and the release-health report.
- Expands self-healing to reconcile Seasonal collection ownership and the initial historical import while keeping the whole-catalog importer off the normal periodic poll after its first successful run.
- Expands the shared responsive UI toolkit with reusable collapsing sections, progress labels, and tables. Missions, Assault Tags, Dynamis, Anniversary, Weekly, Overview, ENM, Eco-War and Seasonal now share more of the same responsive presentation rules.
- Keeps expensive work event-driven and cached to preserve the v6.91.1 open-window performance fixes.

## v6.93.4 - Relic -1 Upgrade Satisfaction

- Shows matching Relic -1 rows in bright text as `[NOT NEEDED]` whenever the character already owns or stores the corresponding Relic +1 piece.
- If the physical Relic -1 is also present, keeps its actual location and displays `[OBTAINED | NOT NEEDED]` or `[STORED | NOT NEEDED]`.
- Does not inflate the Relic -1 `found` total merely because the upgraded +1 piece exists.



## v6.93.3 - Upgraded AF and Relic Progress Credit

- Counts an owned or Porter-stored AF +1 piece as proof that its corresponding base AF piece was obtained.
- Counts an owned or Porter-stored Relic +1 piece as proof that its corresponding base Relic piece was obtained.
- Displays the matching base AF or Relic row in bright text with `[UPGRADED]` instead of leaving it dimmed as missing.
- Includes upgraded pieces in the base `AF Armor` and `Relic Armor` completion totals.
- Keeps the separate AF +1 and Relic +1 columns unchanged so the current upgraded-piece location is still visible.



## v6.93.2 - Confirmed Fame Requirement Display

- Simplifies Quest Details fame requirements into a readable `current / required` line.
- Displays directly confirmed fame and reputation profiles in normal bright text instead of disabled gray text.
- Labels confirmed profiles as **CONFIRMED** and clearly identifies confirmed profiles that are still below the requirement.
- Keeps inferred-only fame floors dimmed and distinguishes them from directly confirmed fame.
- Removes normal-user implementation details such as manual profile, inferred floor, effective value, and fame-log identifiers.

## v6.93.1 - Adaptive Smart Dashboard Layout

- Hides **More in This Zone** when it has no recommendations that are not already present in **Best Next**.
- Expands **Best Next** across the full Dashboard width whenever the second column would be empty.
- Automatically restores the two-column layout when unique current-zone objectives are available.
- Adds a release-hardening check to prevent the redundant empty column from returning.


## v6.93.0 - Production UX and Anniversary Tracking

- Removes the empty **Attention** area when no urgent activity exists; **Next Up** remains visible independently.
- Groups urgent activities as **CRITICAL**, **EXPIRING SOON**, or **DO NOW**.
- Cleans up normal **Quest Details** and moves native IDs, catalog QA, evidence sources, FFXIclopedia/report tools, and technical state reasoning into **Advanced / Why This State**.
- Adds capture-verified **Tracent** and **Drowsy** tracking. Their riddle dialogue records requested items without checking completion; `Bug #... down` and `Quest #... down` counter dialogue confirms the four-item turn-in and stores the following clue.
- Makes **Verify Timer** conditional on ENM rows marked `TIMER UNKNOWN` or `ESTIMATED`; Developer Mode retains unrestricted access.
- Adds workflow and release-hardening tests for the new behaviors.


## v6.92.6 - Production Information Cleanup

- Restricts the persistent **Attention** panel to urgent **DO NOW** activities; ordinary ready work remains on the Dashboard.
- Changes the Dashboard's second column to **More in This Zone**, excluding objectives already shown under **Best Next**.
- Removes Dashboard Planner/Zone Sync diagnostics from the normal interface.
- Hides healthy Mission Sync details, Outpost verification internals, and Quest catalog statistics from normal tabs.
- Makes Fame capture and memory-exposure notes Developer Mode-only.
- Shows ENM timer help only when at least one timer is unknown or estimated.
- Keeps Dynamis scanning explanations in a hover tooltip instead of permanent text.
- Removes the redundant `[PRODUCTION]` header label while retaining `[DEVELOPER]` when Developer Mode is enabled.
- Adds release-hardening checks so these normal-user cleanup rules cannot silently regress.


## v6.92.5 - Attention Focus Cleanup

- Removes the redundant **FOCUS** row from the persistent **What Should I Do?** panel.
- Keeps the ranked **DO NOW**, **READY**, and **Next Up** activity lists as the actionable summary.
- Leaves full recommendation ranking and quest guidance on the Dashboard.
- Adds a release-hardening check that prevents the retired Focus row from returning.


## v6.92.4 - Main UI Simplification

- Removes Compact Mode completely, including its header button, alternate window, runtime state, and `/hcheck compact` command.
- Removes the redundant **Activity Snapshot** block from the normal Attention/Planner area.
- Keeps detailed progression-engine and activity diagnostics under Diagnostics instead of duplicating them in the primary interface.
- Adds release-hardening checks that prevent Compact Mode or the Activity Snapshot from being reintroduced accidentally.


## v6.92.3 - Passive ENM Timer Tracking

- Starts the five-day ENM timer from an authoritative session-observed `0x055` key-item ownership transition (`NOT OWNED -> OWNED`).
- Treats the first owned bitmap snapshot after addon load as a baseline only, preventing login/reload from inventing a fresh timer.
- Uses matching key-item acquisition dialogue as corroboration without allowing chat text to shift the structured timer.
- Labels transition timers as `KI VERIFIED` or `PASSIVE VERIFIED`; first-seen held KIs with no known origin show `TIMER UNKNOWN`.
- Renames the row action from `Moritz` to `Verify Timer`; Moritz remains the recovery/correction path for unknown or estimated timers.
- Preserves existing clear history and prevents repeated true bitmap observations from restarting the timer.

## v6.92.2 - ENM Consumed-State Cleanup

- Fixes expired/available ENMs displaying the contradictory status `AVAILABLE | KEY ITEM CONSUMED`.
- Treats `KEY ITEM CONSUMED` as transient battlefield evidence and clears it after completion, authoritative Moritz synchronization, or timer expiry.
- Repairs stale consumed markers already saved by older builds during addon initialization.
- Keeps historical battlefield and clear evidence intact.

## v6.92.0 - Release Candidate Hardening

- Replaces the old three-item onboarding notice with a complete **Initial Synchronization** wizard for character detection, state writability, schema migration, mission history, permanent key items, historical Assault clears, inventory/relic access, zone reconciliation, and progression facts.
- Adds a unified **Release Health Check** in Settings and Diagnostics, plus `/hcheck health`, `/hcheck health export`, and `/hcheck setup`.
- Formalizes saved-state schema 23 with pre-migration backups, structure validation, verified disk writes, automatic rollback, migration history, and migration status reporting.
- Adds per-operation **Runtime Guard** isolation. A failing tab/module no longer takes down unrelated tabs; repeated failures are collapsed and the failing operation is temporarily paused with a retry control.
- Adds detailed **Assault History Validation** for the `0x056 / 0x00C0` table, payload/bitmap sizes, mapping coverage, mapping version, native bits, imported proof, and one-way proof preservation.
- Adds persistent performance-health classification to the existing profiler.
- Adds release-side production UI and open-window performance contract audits to every generated ZIP.
- Adds `INSTALL.md`, `TROUBLESHOOTING.md`, `KNOWN_LIMITATIONS.md`, `CHANGELOG.md`, and `RELEASE_CHECKLIST.md`.
- Excludes generated release-health reports and migration backups from distribution packages.
- Preserves the v6.91.1 performance fixes, v6.91.2 quest runtime hotfix, v6.91.3 wait correction, and v6.91.4 historical Assault import.


## v6.91.4 - Native Assault History Import

- Imports previously completed standard Assault missions from the native `0x056` subtype `0x00C0` history table after zoning.
- Decodes the dedicated 16-byte Completed Assaults field and maps native Assault IDs 1 through 50 to HorizonCheck's existing mission rows.
- Automatically checks old clears for new HorizonCheck users; no repeated clears or manual entry are required when the native table is available.
- Reuses HorizonCheck's saved raw `0x056` cache, so historical clears can also populate immediately after an addon reload once the table has been observed.
- Treats set native bits as one-way authoritative proof. Missing bits never erase saved manual, live-clear, or prior native proof.
- Adds an **Assault History** synchronization line to the Assault view and `/hcheck assaultprogress sync` for status troubleshooting.
- Records imported-history summaries in the Activity Timeline without emitting one chat message per mission.
- Throttles cache reconciliation and avoids repeated work while the Assault tab is open, preserving the v6.91.1 performance improvements.
- Adds a workflow regression covering old-clear import and one-way proof preservation.


## v6.91.3 - A Mercenary Life Wait Correction

- Updates **A Mercenary Life** to show a **1 in-game day wait** before **Undersea Scouting** instead of a JP-midnight wait.
- Preserves all v6.91.1 performance optimizations and the v6.91.2 quest-active runtime hotfix.

## v6.91.2 - Quest Active Runtime Error Hotfix

- Fixes `attempt to call global 'quest_active' (a nil value)` from quest requirement evaluation.
- Moves the `quest_active` forward declaration above every helper that captures it, so Lua resolves the intended local function instead of a nonexistent global.
- Adds a release regression contract that verifies the declaration remains before `native_quest_is_active()` and the later function assignment.
- Preserves all v6.91.1 open-window performance optimizations.


## v6.91.1 - Open-Window Performance Hotfix

- Adds a one-second shared Planner cache so Attention and Dashboard reuse the same model instead of rebuilding the full quest/activity recommendation set multiple times per rendered frame.
- Makes Smart Dashboard derive ranked rows from the already-built Planner model and cache its display snapshot.
- Replaces repeated whole-catalog dependency scans with one static dependency index, removing an O(N^2) quest-ranking path.
- Caches canonical HorizonXI quest/native-policy records instead of recalculating them thousands of times during quest-state evaluation.
- Extends the quest progression overview cache to ten seconds with immediate invalidation on native quest packets and zone changes.
- Caches header Daily/Weekly/Dragon totals for one second instead of reconciling HAAP and Outposts every frame.
- Removes static canonical/coverage catalog rebuilds from the live zone-sync path; those diagnostic audits now build lazily and remain cached until explicitly invalidated.
- Reduces the fallback self-healing audit cadence from 30 seconds to 120 seconds while preserving the authoritative on-zone reconciliation scan.

## v6.91.0 - Canonical HorizonXI Authority, Catalog Verification, and Self-Healing

- Adds a **HorizonXI Canonical Content Registry** that evaluates every cataloged quest against server-specific availability and native-ID authority before raw quest bits can affect Active, Completed, Search, Dashboard, or Planner state.
- Introduces explicit native mapping policies: **ALLOW**, **QUARANTINE**, and **BLOCK**. Quarantined bits remain visible as raw evidence for diagnostics and guided captures, but cannot independently activate or complete a quest.
- Protects the confirmed `3:92` HorizonXI mismatch for **Chocobo on the Loose!** as an explicit blocked collision rule, and provides a centralized location for future HorizonXI corrections.
- Makes FUTURE and unavailable missions use blocked canonical authority while preserving their reference listings.
- Adds **Catalog Coverage / Verification Dashboard** with per-quest-log totals for verified, incomplete, unavailable, future, unverified, and quarantined records, plus a prioritized queue of missing fields and unsafe native mappings.
- Adds a Developer-only **Guided Capture Wizard** that records before/after native quest state, complete `0x056`/`0x063`/`0x119` packet evidence, dialogue, zone changes, key-item differences, and a confidence-rated analysis report for one selected quest.
- Adds a periodic and on-zone **Self-Healing Contradiction Engine** that repairs stale derived quest state, consumable KI bridges, permanent-unlock progression, and reset scope while preserving raw packet evidence and recording actual repairs in the Activity Timeline.
- Makes native quarantine repair idempotent, so an already-repaired unsafe bit does not repeatedly save/reconcile state every polling cycle.
- Batches the self-healing native-state audit through one quest-cache synchronization instead of resynchronizing once per catalog record.
- Extends Zone Sync, Diagnostics, Catalog Integrity, Search, Planner, the Progression Engine, and the Performance Profiler with canonical authority, coverage, capture-wizard, and contradiction status.
- Adds a release-side canonical-content audit and expands workflow simulations to **14 scenarios**, including reused native IDs, quarantine behavior, self-healing idempotence, future mission blocking, and guided-capture confidence.

## v6.90.6 - HorizonXI Quest Availability Correction

- Marks **Chocobo on the Loose!** as not currently available on HorizonXI.
- Removes it from normal Active, Ready, Dashboard, and Planner recommendations even when the same native quest bit is set for another server-side mapping.
- Makes explicit HorizonXI availability restrictions override raw active/completed bitmap interpretation.
- Keeps unavailable reference records searchable for diagnostics, where they are labeled not currently available.
- Removes the incorrect HorizonXI source row so future catalog rebuilds do not re-enable the quest.

## v6.89.0 - Horizon Availability, Unlock Registry, and Performance Profiler

- Adds a centralized HorizonXI availability/era engine with explicit AVAILABLE, FUTURE, HORIZON_CUSTOM, UNVERIFIED, and DISABLED states.
- Marks ToAU missions 19-48 as FUTURE reference content while keeping them visible; mission 1-18 remain current.
- Prevents FUTURE/DISABLED quests from being surfaced as actionable planner recommendations.
- Adds a persistent Permanent Unlock Registry for access passes, teleport crystals, maps, crafting unlocks, and Dynamis clear key items.
- Makes the unlock registry the preferred source for Dynamis clear ownership and feeds unlock facts into the progression engine.
- Extends staged zone reconciliation to refresh availability and permanent unlock state.
- Adds a low-overhead Performance Profiler for poll modules, planner builds, UI rendering, and each zone-sync phase, with per-section budgets and warnings in Diagnostics.
- Adds Diagnostics sections for Availability / Era Validation, Permanent Unlock Registry, and Performance Profiler.


## v6.88.0 - Progression Engine, Activity Timeline, and Zone Reconciliation

- Adds a central progression state engine with canonical states and explicit evidence priority.
- Adds a durable Activity Timeline / Repair History that mirrors automatic changes, state transitions, zone reconciliations, and undo repairs.
- Adds automatic staged zone synchronization: state reconcile, mission sync, evidence/key-item refresh, normalized progression reconcile, and deferred save.
- Adds Diagnostics panels for the progression engine, activity timeline, and zone snapshot status.
- The planner now reconciles through the central progression layer before rendering recommendations.





## v6.87.9 - Dense UI Fix
- Fixes **Dense UI** so the setting now makes a visible layout change instead of only suppressing one optional separator.
- Dense mode now reduces main-window padding, control/frame padding, vertical item spacing, inner spacing, table-cell padding, and indentation across all main HorizonCheck tabs.
- Keeps the density styling scoped to HorizonCheck so it does not modify Ashita's global ImGui appearance or other addons.

## v6.87.8 - Settings Tab Rename
- Renames the **Status / Misc** tab to **Settings** for a clearer, more conventional label.
- Updates in-game helper text to point to **Settings**.
- No settings, behavior, or saved-state keys were changed.

## v6.87.7 - Status / Misc UI Cleanup
- Reorganizes **Status / Misc** into a compact overview plus focused collapsible sections: Character Systems, Display & Tabs, Notifications, Quest Preferences, and Maintenance & Advanced.
- Adds a top summary for initialization, state health, Guild Points, and HAAP so the most useful status information is visible without opening maintenance details.
- Lays out Visible Tabs in a three-column grid and Notification choices in a two-column grid when the Ashita ImGui table API is available, with safe single-column fallbacks.
- Moves initialization details, tracker-confidence output, self-test/repair controls, Developer Mode, and UI reset under **Maintenance & Advanced** to reduce everyday clutter.
- Preserves all existing Status / Misc controls and tracking behavior; this release is a presentation/organization cleanup only.


## v6.87.6 - Diagnostics Button Cleanup
- Removes the global **Open Diagnostics** button that appeared beneath every normal tab while Developer Mode was enabled.
- Uses a single **Diagnostics** tab inside the main HorizonCheck window; the old floating diagnostics window has been removed.
- Leaves all Diagnostics tools, Quick Actions, and Developer Mode behavior unchanged.


## v6.87.5 - Diagnostics UI Cleanup
- Moves **Save Now** and **Undo Last AUTO** out of the main/compact action rows and into Diagnostics under a dedicated **Quick Actions** section.
- Cleans up the Diagnostics tab by grouping State Audit, Key Items, Detection Inspector, System State Engines, Catalog Integrity, and Regression tools into collapsible sections.
- Renames and reorganizes the standalone diagnostics window with compact System Health, Quick Actions, Automation & Sessions, Event History, Learning/Capture, Runtime Errors, and Recent Packets sections.
- Runtime Errors automatically expand only when errors exist; lower-level packet/catalog/debug sections stay collapsed by default to reduce visual clutter.

## v6.87.4 - Header Compact Mode Placement
- Moves the **Compact Mode** button from the bottom action row to the same header row as the character name.
- Right-aligns the button against the far edge of the main HorizonCheck window while leaving the character/progress/version summary on the same row.
- The bottom action row now contains only Automation Monitor (developer mode), Undo AUTO, and Save Now.

## v6.87.3 - Dynamis Permanent KI Clear Persistence
- Dynamis clear checks now use the verified exact key-item ID path first, so Hydra Corps and Dreamworld sliver clears do not depend on resource-name indexing.
- Every bitmap-confirmed permanent KI in the verified registry is persisted automatically when 0x055 tables arrive, even when no UI panel queried that KI during the session.
- Saved permanent proof bridges reloads until the next authoritative bitmap arrives; Ashita `HasKeyItem(false)` remains diagnostic-only on HorizonXI.
- Permanent-key-item captures also persist bitmap-confirmed permanent proof.

## v6.87.2 - Authoritative 0x055 Key-Item Ownership

- Makes the cached server `0x055` key-item bitmap the direct authoritative result for runtime KI ownership checks; Ashita `HasKeyItem(false)` can no longer override or downgrade it.
- Pins capture-verified critical permanent KIs and Cosmo-Cleanse to their exact HorizonXI resource IDs, including `Cosmo-Cleanse = 734`, so these checks work before the incremental resource-name index finishes.
- Accepts `HasKeyItem(true)` only as positive fallback evidence when the bitmap table is unavailable; `HasKeyItem(false)` is diagnostic-only on HorizonXI and now resolves to UNKNOWN rather than NOT OWNED.
- Reconciles verified IDs on the frame immediately after each `0x055` packet, while preserving the incremental resource-index performance fix and doing one final full reconciliation after indexing completes.
- When a permanent KI is observed owned in `0x055`, saves sticky permanent proof for reload bridging.

## v6.87.1 - Direct Permanent Key-Item Capture
- Adds a dedicated `permkeyitems` Learn profile that snapshots key-item ownership directly at capture start and stop instead of waiting for a `0x055` packet to arrive during the capture window.
- The snapshot reads HorizonCheck's already-cached server `0x055` bitmap, so a report can identify owned key items even when the only packets seen during the Learn window are unrelated traffic such as `0x020`.
- Each owned KI row now records the resource ID, bitmap table, resource name, evidence source (`0x055`, `HasKeyItem`, or both), and whether it matches HorizonCheck's current known-permanent map.
- When the incremental KI resource index is ready, the capture also performs a user-triggered `HasKeyItem` discovery pass across only real indexed KI resource IDs; it never restores the 65,536-ID ResourceManager scan that caused zone hitching.
- The report includes a separate known-permanent ownership section for validating exact IDs and extending HorizonCheck's permanent-KI map safely.

## v6.87.0 - Dynamis Clear / Relic Drop Tracker
- Adds a dedicated **Dynamis** tab covering all 10 Horizon Dynamis areas: San d'Oria, Bastok, Windurst, Jeuno, Beaucedine, Xarcabard, Valkurm, Buburimu, Qufim, and Tavnazia.
- Clear status is read from each zone's permanent boss-reward key item (Hydra Corps progression items for original Dynamis and Slivers for Dreamworld Dynamis).
- Each zone lists the Relic Armor that drops there for all 18 jobs tracked by HorizonCheck, plus Dreamworld Relic Accessories and Relic Armor -1.
- Relic ownership reuses the Job Progression inventory/storage/wardrobe/Porter Slip scanner. `[STORED]` counts as obtained, and a Relic +1 permanently proves that its NQ and -1 components were obtained.
- The Dynamis tab remembers observed Relic ownership per character, so an item that is later upgraded/consumed does not revert to missing.
- Adds a **Missing Only** filter and a manual **Refresh Dynamis Gear** button. The expensive inventory scan runs only while the Dynamis tab is open and remains cached.


## v6.86.2 weekly completion persistence fix
- Fixes **Secrets of Ovens Lost** changing from COMPLETE back to IN PROGRESS when zoning after the weekly turn-in.
- A same-week verified COMPLETE now outranks a stale/resend `0x056 ACTIVE` bit until the weekly reset rolls over.
- Adds automatic recovery for characters already affected by v6.86.1: current-week verified Miratete reward evidence restores COMPLETE on reload.
- The native ACTIVE observation is retained as conflict/debug evidence instead of deleting the weekly completion record.


## v6.86.1 zone-performance fix
- Removed full 65,536-ID key-item resource scans from the 0x055 packet callback. Key-item names are now indexed incrementally across frames, and zone packet callbacks only cache bitmap data.
- Batched/deferred state writes during 0x055 reconciliation so multiple key-item detectors cannot serialize the full character profile repeatedly during zone-in.
- Batched native 0x056 quest-log persistence: zone-in quest packets now request one deferred save instead of writing the entire state file once per packet.
- Added resource-index progress to the Key Item Test Lab for diagnostics.


## v6.86.0
- Adds a **Quest Dependency Graph** over the final merged quest catalog. HorizonCheck now follows prerequisite quest chains recursively, detects missing references/cycles, counts direct and transitive unlock impact, and shows the shortest mapped path to the **first actionable prerequisite** directly in Quest Details.
- Adds **System-Specific State Engines** (`systems.lua`) for Assault Tags, ISNM, ENM, Limbus, Dynamis, EXP Ring, and Eco-Warrior. The planner now consumes normalized system actions/timers instead of maintaining separate copies of each activity's reset and entry rules. Repeatable quest reset interpretation also delegates to this engine with a safe fallback.
- Adds a runtime **Catalog Integrity Engine** that audits the merged catalog for missing prerequisite targets, circular/self dependencies, unknown requirement fields, source problems, repeat-policy problems, and live AVAILABLE/prerequisite contradictions. It is available in Developer Diagnostics and through `/hcheck catalogaudit`.
- Adds a release-side dependency audit (`tools/audit_quest_dependencies.py`) and makes it part of `prepare_release.py` so hard self-dependency/reference-shape problems are caught before packaging.
- Expands the regression suite with dependency-graph, system-reset, and catalog-integrity integration tests.
- The dashboard behavior from v6.85.2 is preserved: only **DO NOW / READY** actions are shown and quest recommendations remain **current-zone only**.


## v6.85.2
- Simplifies **What Should I Do?** to only **DO NOW**, **READY**, and **Next Up**. The PREP and BLOCKED sections are no longer displayed on the dashboard.
- Quest rows on the dashboard/planner are now strictly **current-zone only**. Non-local Ready, Active, Check, and Locked quests stay in the full Quests tab instead of cluttering the planner.
- The planner FOCUS recommendation now chooses only from DO NOW / READY actions, so a preparation or blocker row can never become the dashboard focus.
- Planner Snapshot now reports only `Quests here: Ready | Active` plus `Actions: Do Now | Ready`.
- The legacy dashboard quest attention/progression surfaces also filter to current-zone quests for consistent behavior everywhere.


## v6.85.1
- Rebuilds the top **What Should I Do?** area into a real cross-system planner with **DO NOW**, **READY**, **PREP**, **BLOCKED**, and **Next Up** tiers.
- Adds a single **FOCUS** recommendation chosen from the highest-priority current action. Capped Assault tags, active/in-progress content, current-zone quests, and weekly opportunities near reset are promoted ahead of ordinary Ready work.
- Merges quest progression into the dashboard: active quests, current-zone Ready quests, top Ready recommendations, verification/preparation quests, and high-impact locked quest blockers now appear alongside Assault, ENM, Limbus, Dynamis, ISNM, and EXP Ring work.
- Adds **All / Activities / Quests** planner filters and a snapshot showing Ready/Here/Active/Check/Locked quest totals plus Do Now/Ready/Prep/Blocked action totals.
- Limbus planner state now preserves the Evidence Resolver's three-state result: held = READY, proven missing = PREP to obtain, unknown = PREP to verify. It no longer treats UNKNOWN as definitely missing.
- Adds urgency promotion for unused Limbus/Dynamis/EXP Ring opportunities during the last six hours before Conquest reset.
- Adds **Next Up** timers for Assault regeneration, ENM cooldowns, daily reset, and Conquest reset, sorted by time remaining.
- Expands `quests.progression_overview()` with ranked Active, Check, and Locked rows using a precomputed dependency-impact map, avoiding expensive repeated full-catalog scans for blocker ranking.
- Caches the full cross-catalog quest planner snapshot for two seconds so the always-visible dashboard does not rescan the entire quest catalog every rendered frame.
- Extends the regression suite with planner tier contracts for capped work, expiring Ready work, normal Ready work, verification/prep work, and hard blockers.


## v6.85.0
- Adds a **Unified Evidence Resolver** with explicit source priority, confidence, recency, conflict detection, and true/false/unknown handling so weaker detectors cannot silently overwrite stronger evidence.
- Key-item ownership now publishes Ashita API, `0x055` bitmap, saved packet state, and permanent historical proof into the same resolver. The resolver also accepts non-boolean facts and now publishes confirmed Fame / Reputation levels.
- Adds a **Detection Inspector** to Developer Diagnostics and the Automation Monitor. It shows the final resolved fact, confidence, winning source, conflicting sources, and source stack, with filter and refresh controls.
- Adds an in-game **Regression Suite** (`/hcheck regression`) covering evidence precedence, UNKNOWN handling, permanent proof, consumable state clearing, source conflicts, numeric facts, key-item integration, and Inspector integration. It runs silently as part of HorizonCheck's startup self-test.
- Adds `tests/evidence_cases.json` plus `tools/run_regression_tests.py` for release-side regression checks. Release packaging now refuses to build if the regression suite or runtime integration checks fail.
- Adds capture-derived safeguards for the Maat tracker: normal `reached the stars` dialogue is explicitly not accepted as a per-job win; auto-confirmation must remain tied to **Shattering Stars** battlefield entry plus `Battlefield clear time:` evidence.
- Adds a Cosmo-Cleanse regression contract enforcing source strength: live `0x055` bitmap is authoritative; saved **HELD** state outranks an API false-negative, while a live API **true** can supersede stale saved NOT-HELD state.


## v6.84.37
- Fixed the **What Should I Do?** Limbus row falsely saying `Cosmo-Cleanse needed` while the key item is actually held.
- The dashboard now uses the same multi-candidate key-item ownership resolver as quest checks, testing every exact `Cosmo-Cleanse` resource entry through both Ashita `HasKeyItem()` and the incoming `0x055` bitmap instead of checking only the first legacy resource ID.

## v6.84.37

- Attention dashboard now treats all immediately actionable `AVAILABLE` activities as `READY NOW`.
- Assault Tags, Dynamis, and Limbus eligibility are grouped with ENMs under a single READY NOW section instead of a separate AVAILABLE section.
- Limbus without Cosmo-Cleanse now says `READY - Limbus: Cosmo-Cleanse needed` so the next action is explicit while still being treated as ready/actionable.
- Underlying module lifecycle states remain unchanged; this is a dashboard presentation/prioritization change only.

- Fixes Eco-Warrior quest details so the unresolved one-per-Conquest gate is reported as **World State**, not Fame.
- A historical Eco-Warrior completion without a HorizonCheck timestamp now reads `CHECK` with an explicit note that the completion predates reset tracking.
- A timestamped completion in the current Conquest period reads `LOCKED` with the actual repeat lockout reason.
- When the repeat window is known ready, the Eco-Warrior custom rule is informational and no longer creates a redundant manual blocker.
- Repeatable quests no longer display `Already completed` in the `Can I start this?` section merely because native history records a prior completion.
- The `Mark Manual Reqs Satisfied` button is hidden for Eco-Warrior because Conquest eligibility is tracked automatically rather than manually overridden.


- Reworded completed Job Progression status to `Job progression complete - X mapped job quests completed.` for capped jobs with no remaining mapped quests.
- Completed Job Progression status now renders in normal white text instead of disabled gray.
- Jobs below cap with no further mapped quest use `No additional mapped job quests available at this time. X completed.` in white.
- Fixed Porter Moogle Storage Slip 04 AF detection by tracking stored item IDs directly, so pieces such as Healer's Pantaloons no longer depend on resource-name lookup.
- Fixes AF +1 detection by using direct Storage Slip 05 item IDs for all 18 Horizon-era jobs, so +1 pieces in inventory, Satchel, wardrobes, or Porter storage count toward the base AF row.
- Job Progression performance: caches full gear/wardrobe/Porter scans for 5 seconds, caches resource item-ID resolution, and caches mapped job-plan evaluation for 2 seconds. Added a Refresh Gear button for immediate rescans.
- Fixed Warrior\'s Calligae -1 detection with verified direct item ID 2037, so copies in Satchel/storage are detected even when Ashita cannot resolve the long resource name.
- Fixed damaged Warrior relic feet detection when Ashita exposes Warrior's Calligae -1 under the compact resource/log alias "War. Calligae -1".

- Job Progression now shows three gear columns per job: AF Armor, Relic Armor, and Relic -1.
- Relic and Relic -1 pieces are highlighted white when found in inventory/storage/wardrobes.
- Porter Moogle Storage Slip 06 (Relic) and Storage Slip 12 (Relic -1) are decoded alongside Storage Slip 04 (AF).
- A completed 5/5 gear column turns white. Relic +1 counts as proof that the corresponding base Relic piece was obtained.

## v6.84.8
- Fixed AF detection in Wardrobe 2 and other wardrobe containers by probing wardrobe slots even when Ashita reports a zero container count.
- Added direct AF item-ID matching so wardrobe detection no longer depends on resource-name localization.

## v6.84.7
- Added direct Porter Moogle Storage Slip 04 decoding for original Artifact Armor.
- AF pieces stored on the slip are read from the slip item's Extra-data bitmask and now count toward Job Progression without withdrawing them.
- Stored AF is shown in white as `[STORED]`; physically held/container AF remains `[OBTAINED]`.
- The decoder scans the same inventory/storage/wardrobe container range as the normal AF ownership scanner.

- Added a Maat Progress evidence capture to the Job Progression tab for discovering HorizonXI's persistent per-job Shattering Stars clear tracking.
- Maat capture preserves full non-movement packet payloads, more unique samples, current-job context, and existing confirmed Maat wins for safe comparison.
- No Maat victory bits are auto-assigned until capture evidence proves the mapping.

## v6.84.4
- Moves Jobs / Levels and the Job Progression Planner out of Character Info into a dedicated Job Progression tab.
- Places Job Progression immediately after Character Info in the main tab order.
- Character Info keeps Combat Skills, Fame / Reputation, and Craft Skills.

## v6.84.2

- Added a **Priority** sort for Active and Ready quests. Priority weighs pinned quests, current-zone starts, downstream unlock count, valuable progression rewards, and repeatable readiness.
- Added per-character **Pin / Unpin** support in Quest Details. Pinned quests are visibly marked in lists and can be isolated with the new **Pinned** sort/filter.
- Quest Details now shows the selected quest's computed priority score and the reasons contributing to it.
- Added a compact **Progression Planner** to the Dashboard with Ready/Here/Active/Check/Locked/Pinned counts and the top five recommended Ready quests.
- Existing Available Here, repeatable status, evidence/provenance, self-audit, and state-report features remain intact.

- Added **Available Here** to the Ready quest view. HorizonCheck now shows the current zone, counts proven-ready quests that start there, and can filter Ready to only those quests with one click.
- Fixed the Ready **Here** sort so it actually applies to Ready rows instead of falling back to the default alphabetical order.
- The current-zone filter is character-view state only and is cleared by **Reset Quest Tab**.

## v6.83.0

- Adds a visible **Sort by** control directly under the everyday **Active** and **Ready** quest views; it no longer requires Advanced mode.
- Active quests can sort by **Smart**, **Name**, **Zone**, or **Next Step**.
- Ready quests can sort by **Smart**, **Name**, **Zone**, **Reward**, or **Unlocks** (quests that directly unlock the most mapped follow-up quests first).
- Active and Ready keep independent sort preferences, and both persist in simple mode without affecting Locked/Completed/diagnostic sorting.

## v6.82.2

- Added Locked reason filters with live counts for Fame, Reputation, Rank, Job/Level, Skill/Trial, Previous Quest, Mission, Key Item, World State, Party, and Other blockers.
- Requirement evidence now carries explicit confidence/provenance badges such as LIVE, NATIVE, CONFIRMED, INFERRED, PROFILE, CATALOG, and UNKNOWN.
- Quest Details now shows progression impact by counting mapped later quests that directly depend on the selected quest.
- Existing v6.82.1 stale-manual auto-resolution and safe self-audit fixes remain unchanged.

## v6.82.1

- Centralized stale-manual-condition auto-resolution now suppresses duplicate manual checks when the same requirement is already proven by confirmed fame, live skills, rank, completed quest history, or owned key items.
- Added Kazham/Mhaura reputation aliases to the Windurst fame profile.
- Self-audit now groups contradictions, stale manual checks, missing live evidence, and mapped-but-unknown cases.
- Added Apply Safe Auto-Fixes for monotonic evidence only; transient live skills/items are never persisted by the fixer.


- Added centralized quest state/reason classification shared by list views, quest details, and diagnostics.
- Added **WHY THIS STATE** plus requirement evidence/source lines in Quest Details.
- Added an Advanced **Self-audit** scanner for classification contradictions and mapped requirements that still lack live evidence.
- This is the first reliability-focused improvement pack; existing Character Info, fame, craft-skill, job-level, key-item, and mission checks remain intact.

## v6.81.28
- Renames the Skills / Fame tab to Character Info.
- Keeps the existing Jobs / Levels, Craft Skills, and Fame / Reputation content unchanged.

## v6.81.27
- Adds live Craft Skills directly underneath Jobs / Levels in the Skills / Fame tab.
- Shows Fishing, Woodworking, Smithing, Goldsmithing, Clothcraft, Leathercraft, Bonecraft, Alchemy, and Cooking with current skill, guild rank, and capped state when Ashita exposes it.

## v6.81.23

- Contextual Outlands fame resolution: generic fame gates now use Norg/Tenshodo in Norg, Selbina/Rabao in Rabao/Selbina, and Windurst fame in Kazham/Mhaura.
- Fixed An Undying Pledge so confirmed Norg/Tenshodo fame satisfies its Fame 4 gate automatically.
- Fixed **Trial-Size Trial by Wind** prerequisite evaluation: its confirmed Fame 2 gate now uses the shared **Selbina / Rabao** reputation profile (Waylea) instead of the Outlands quest-log ID. A confirmed Rabao fame rank now satisfies/locks the quest automatically.


## v6.81.19
- Added automatic fame/reputation detection from HorizonXI fame-checker dialogue for Flaco, Namonutice, Zabirego-Hajigo, Ney Hiparujah, Mendi, Vaultimand, and Waylea.
- Exact dialogue matches now save the corresponding per-character fame/reputation rank automatically; Capture remains available only for verification or unexpected HorizonXI dialogue variants.
- Corrected the captured Vaultimand "household name 'round Norg" response to Norg/Tenshodo rank 7.

# HorizonCheck

### v7.1 highlights
- One-time Initial Synchronization recovery summary before setup closes.
- Actionable Synchronization Health with exact refresh steps.
- Character Registry for safe management of offline saved HorizonCheck profiles.
- Expanded conservative Anniversary lane automation and unmapped-riddle evidence collection.
 v6.80.0

## Quest-tab cleanup and multi-user readiness

- Adds a clean **Simple** Quest-tab layout by default. Catalog diagnostics, QA tools, era filters, sorting controls, and the two-pane browser are now grouped under **Advanced tools**.
- Splits the old combined Candidates workflow into clear **Ready** and **Check** views. **Ready** contains only quests HorizonCheck can prove are startable for the current character.
- Adds a compact status summary, full-width search, one-click Quest-tab reset, shorter region headers, and cleaner quest rows.
- Adds a collapsible **Character Evidence Profile** for fame, reputation, ranks, skills, party, mission, avatar, Maat, and other character-specific prerequisite evidence.
- Makes the two-pane Details browser opt-in so the Quest tab works at narrow and wide resolutions.
- Stores Quest-tab settings and prerequisite evidence per character. Before a character name is available, HorizonCheck uses a transient profile that is never written as a shared `Unknown` character.
- Fixes the state schema migration to remain on schema 21 and updates the global Reset UI action with the new Quest-tab defaults.
- Release ZIPs never include `horizoncheck_state.lua`; each installation creates its own local state file.

### Using HorizonCheck with more than one character

Each character receives an independent Quest profile inside `horizoncheck_state.lua`. Manual fame, skill, mission fallback, Maat, avatar, and other prerequisite confirmations do not transfer to another character. Account-wide trackers remain shared only where HorizonCheck explicitly defines them as account-wide.

For distribution, extract the `horizoncheck` folder into each user's Ashita `addons` directory. Do not distribute another player's `horizoncheck_state.lua`.

---

# HorizonCheck

### v7.1 highlights
- One-time Initial Synchronization recovery summary before setup closes.
- Actionable Synchronization Health with exact refresh steps.
- Character Registry for safe management of offline saved HorizonCheck profiles.
- Expanded conservative Anniversary lane automation and unmapped-riddle evidence collection.
 v6.78.0

## v6.78.0 runtime prerequisite evidence pass

- Adds live party-size and party-level evaluation for party-gated quests; The Kuftal Tour now checks six members at level 40 or below instead of remaining a permanent custom blocker.
- Adds equipped-item proof for the Bow of Trials and Club of Trials weapon-skill quests. Equipping the trial weapon proves the character can wield it without guessing job eligibility.
- Adds a character-specific 15-job Maat victory matrix for Beyond the Sun, replacing the previous all-or-nothing custom prerequisite.
- Expands quest Details with per-condition evidence for status effects, party composition, Maat victories, Fishing skill, trial-weapon proof, key items, inventory items, mercenary points, Japanese-midnight waits, and zone transitions.
- Renames the combined Available* button to Candidates so only the top-level Available number is presented as proven ready-now availability.
- Adds a dedicated Party CHECK filter and preserves conservative UNKNOWN behavior whenever the relevant Ashita runtime API is unavailable.
- Does not change native 0x056 Active/Completed decoding or Eco-Warrior weekly behavior.

# HorizonCheck

### v7.1 highlights
- One-time Initial Synchronization recovery summary before setup closes.
- Actionable Synchronization Health with exact refresh steps.
- Character Registry for safe management of offline saved HorizonCheck profiles.
- Expanded conservative Anniversary lane automation and unmapped-riddle evidence collection.
 v6.13.2


## v6.13.2 quest row Details alignment
- Moved the Details button to the beginning of every quest row for a consistent, easier-to-scan layout.
- Applies uniformly to Active, Attention, Available, Locked, and Completed quest views through the shared row renderer.
- Quest status decoding, catalog metadata, and selection behavior are unchanged.

## v6.13.1 digging fatigue chat warning fix

- Restores the once-per-day digging chat warnings at 75%, 90%, 95%, and daily cap.
- Fixes a regression where the global exact-text notification deduper could permanently suppress a threshold message after it had fired on a previous day.
- Digging notification settings and the short duplicate-message guard still apply.

## v6.13.0 bulk enrichment expansion

- Expanded the HorizonXI bulk source set across Bastok, Windurst, Jeuno, Other Areas, and Outlands.
- Pipeline-enriched native identities increased from 236 to 420 of 590 supported DAT/native quest identities (71.2%).
- Added 356 table-backed source records in this pass; overlapping records are merged field-by-field with provenance/conflict reporting.
- Region pipeline coverage after this pass: San d'Oria 63/82, Bastok 88/93, Windurst 87/98, Jeuno 75/158, Other Areas 57/101, Outlands 50/58.
- Continued using HorizonXI as the preferred descriptive source; FFXIclopedia remains restricted to September 2007 or earlier.
- Native 0x056 Active/Completed quest-state decoding is unchanged.


## v6.13.0 bulk catalog enrichment

- Added 228 HorizonXI quest-table records to the bulk catalog source pipeline.
- Large NPC/location/reward/fame enrichment pass across San d'Oria, Bastok, Windurst, Jeuno, Other Areas, and Outlands.
- Generated catalog pipeline now enriches 236 of the 590 supported DAT/native identities (40.0%) before legacy metadata is merged at runtime.
- Added a generic NPC/location next-step for imported table records so the Details panel remains actionable even when a full walkthrough/objective has not yet been mapped.
- Field provenance and conflict/gap reports were regenerated; native 0x056 Active/Completed decoding is unchanged.


## v6.11.1 hotfix
- Fixes invalid apostrophe quoting in `data/quest_metadata_bulk.lua` that prevented the entire bulk quest metadata overlay from loading.
- Restores enriched metadata for records already present in the bulk catalog, including Windurst `Know One\'s Onions` (`log 2 / quest 40`).
- Adds a quest-catalog Lua string validator and makes bulk/generated overlay load failures visible in the addon log instead of failing silently.

- Quest catalog enrichment pass: 17 Bastok records upgraded with verified HorizonXI NPC/location/reward/fame metadata while preserving native quest-state detection.

- Quest catalog bulk-enrichment pass, with a new optional `data/quest_metadata_bulk.lua` overlay for future large imports.
- Adds full mapped details for Jeuno quest **Fistful of Fury** (Vola, Lower Jeuno J-8, required items, Brown Belt reward, Tenshodo reputation requirement, and quest-chain notes).
- Adds starter NPC/location metadata for dozens more Jeuno quests from the HorizonXI Wiki city quest tables, including AF hands, limit break, fellow, and general quests.
- Native 0x056 Active/Completed detection is unchanged.

# HorizonCheck

### v7.1 highlights
- One-time Initial Synchronization recovery summary before setup closes.
- Actionable Synchronization Health with exact refresh steps.
- Character Registry for safe management of offline saved HorizonCheck profiles.
- Expanded conservative Anniversary lane automation and unmapped-riddle evidence collection.
 v6.9.88

## v6.9.88
- Restores the exact Ashita `packet_in(function(e) ... end)` event-table handoff used by the earlier working quest probe.
- Removes the v6.9.88 split-argument normalization layer that regressed 0x056 quest decoding on this client.
- Keeps the newer ACTIVE/COMPLETED persistence code, but feeds it through the proven packet path.
- Corrects runtime version metadata to 6.9.88.
- Fixes the 0x056 quest packet handoff discovered by the diagnostic build.
- `packet_in` now forwards all callback arguments and `modules/packets.lua` normalizes both Ashita event-table and legacy `(id, data, modified, injected, blocked)` signatures.
- Quest handlers once again receive a normal event table with `e.id` and string `e.data`, restoring ACTIVE/COMPLETED 0x056 decoding without changing the proven quest bitmap offsets.

# HorizonCheck

### v7.1 highlights
- One-time Initial Synchronization recovery summary before setup closes.
- Actionable Synchronization Health with exact refresh steps.
- Character Registry for safe management of offline saved HorizonCheck profiles.
- Expanded conservative Anniversary lane automation and unmapped-riddle evidence collection.
 v6.9.88
- Diagnostic quest-state build. Every incoming 0x056 now prints `QUEST056 RX` with packet length, Type, ACTIVE/COMPLETED classification, region, bit count, and character.
- Every classified table then prints `QUEST056 CACHE` showing whether the per-character cache save succeeded.
- No new packet offsets or inferred quest state were added; this build is designed to identify exactly where reload/zone state is failing.
- After install: `/addon reload`, zone once, then screenshot or capture the `QUEST056 RX` / `QUEST056 CACHE` lines.

# HorizonCheck

### v7.1 highlights
- One-time Initial Synchronization recovery summary before setup closes.
- Actionable Synchronization Health with exact refresh steps.
- Character Registry for safe management of offline saved HorizonCheck profiles.
- Expanded conservative Anniversary lane automation and unmapped-riddle evidence collection.
 v6.9.82
- Restores the original verified 0x056 packet path by preferring Ashita `e.data`; `data_raw` is fallback-only. This fixes ACTIVE quest tables disappearing after v6.9.79.
- Adds a per-character ACTIVE quest bitmap cache so `/addon reload` no longer blanks the Active tab while waiting for the next live 0x056 dump.
- Keeps completed tables persistent and non-destructive: a San d'Oria-only refresh cannot erase Bastok/Windurst/Jeuno/Other Areas/Outlands/ToAU history already captured.
- Removes the broad raw-byte Type scan that could false-match a quest-log Type inside packet payload data.

# HorizonCheck

### v7.1 highlights
- One-time Initial Synchronization recovery summary before setup closes.
- Actionable Synchronization Health with exact refresh steps.
- Character Registry for safe management of offline saved HorizonCheck profiles.
- Expanded conservative Anniversary lane automation and unmapped-riddle evidence collection.
 v6.9.79
- Completed quest collector now persists **every** incoming 0x056 Type immediately, not only tables already classified by the current UI path.
- 0x056 decoding now accepts both Ashita `data_raw` and `data` packet representations and handles header-inclusive/headerless layouts defensively.
- Completed history is rebuilt from the persistent raw-Type cache on reload, so Bastok/Windurst/Jeuno/Other Areas/Outlands/ToAU completed tables no longer disappear when only San d'Oria refreshes later.

# v6.9.78
- Fixes the misleading quest history capture button: it now immediately recovers any completed 0x056 tables already observed in the current session, persists them, shows ARMED status, and clearly tells you to zone once when the server must resend missing history tables.
- Renames the control to Refresh Missing History.

# HorizonCheck

### v7.1 highlights
- One-time Initial Synchronization recovery summary before setup closes.
- Actionable Synchronization Health with exact refresh steps.
- Character Registry for safe management of offline saved HorizonCheck profiles.
- Expanded conservative Anniversary lane automation and unmapped-riddle evidence collection.
 v6.9.78

- Fixes Available/Locked quest generation only appearing for San d'Oria when ACTIVE 0x056 tables were not received for otherwise empty regional logs.
- Available/Locked now use authoritative completed-history coverage for every supported HorizonXI-era quest log and suppress ACTIVE quests whenever a native active table for that region is present.
- Region counts and Recently Unlocked use the same corrected coverage rule.

### Uninvited Guests verified turn-in (v6.9.66)
- Adds capture-verified Justinius completion handling for Uninvited Guests.
- Requires the Monarch Linn clear-confirmation dialogue followed by Justinius's reward dialogue (or the named Uninvited Guests achievement within the same short turn-in window).
- Marks the weekly complete only at the final turn-in and clears the intermediate CLEARED / Return to Justinius state.
- A generic Miratete item acquisition by itself is not treated as authoritative completion evidence.

### Quest progression UI (v6.9.65)

- Adds a dedicated Locked quest view for quests blocked by verified mapped prerequisites.
- Adds Ready Now filtering to Available so unknown requirements can be hidden.
- Region headers now summarize active, available, locked, and completed counts.
- Quest Details now surfaces mapped fame, nation rank, job/level, mission, key-item, and HorizonXI-specific requirement fields without guessing unsupported runtime state.

### Fire in the Sky clear automation (v6.9.64)
- Persists verified ENM clear evidence from the active named battlefield session.
- Stores the actual clear duration (for example `2:27`) without changing the five-day cooldown timestamp, since Horizon starts ENM cooldown when the entry KI is obtained.
- Shows the last cleared ENM and clear time in the ENM tab and keeps the row on its existing cooldown when a verified timer is already present.

### v6.9.59
- Quests: added a selectable Quest Details panel for Active, Available*, and Completed rows.
- Mapped tracked quests now show start NPC, zone, repeat cadence, live tracker status, and a concise next step.
- Quest search now also matches mapped NPC/zone/detail keywords.
- Native 0x056 remains authoritative for active/completed state; unmapped quests clearly say detail metadata is not yet mapped.

### v6.9.57
- Fixes EXP Ring weekly completion carrying over across Conquest reset.
- The weekly EXP Ring checkbox is now cleared as part of the authoritative weekly reset before the UI renders.
- Preserves the last observed ring name/charge count as the new-cycle baseline so a genuine recharge can still auto-check the objective.
- Manual weekly reset now clears the EXP Ring cycle latch the same way.

### v6.9.56
- Restricts the generated **Available*** quest view to HorizonXI-era quest logs through **Treasures of Aht Urhgan**.
- Hides Crystal War / Wings of the Goddess, Abyssea, Adoulin, and Coalition quest logs from Available*.
- Leaves native **Active** and **Completed** views unfiltered and authoritative.
- Keeps unknown prerequisite candidates labeled **CHECK REQUIREMENTS** rather than claiming they are available.

### v6.9.55
- Fixes Secrets of Ovens Lost remaining at READY after the weekly request is accepted.
- The captured paired Jonette request dialogue now advances READY -> IN PROGRESS immediately, but can never mark the quest complete.
- Native 0x056 ACTIVE state now also outranks stale READY state after zone-in and restores IN PROGRESS (or COOKBOOK OBTAINED when the cookbook KI is verified).

### v6.9.54
- Quest tab adds an **Available\*** candidate view built from the quest catalog minus native ACTIVE and COMPLETED `0x056` states.
- Availability is intentionally conservative: quests without mapped HorizonXI prerequisites show **CHECK REQUIREMENTS** instead of being falsely labeled available.
- Adds per-region active/completed progress counts to quest section headers.
- Completed `0x056` transitions remain authoritative for quest state; the separate Recently Completed history panel was removed in v6.9.71.
- Adds an availability-rule framework so verified fame/rank/prerequisite rules can be added incrementally in later builds.


### v6.9.53
- Promoted native 0x056 completed quest history from Diagnostics into the Quests tab.
- Added Active / Completed views with authoritative per-region counts and quest names.
- Completed quests are never inferred from absence in ACTIVE; only completed-history bits are displayed.
- Search works in both Active and Completed views; region expansion state is remembered separately.

# HorizonCheck

### v7.1 highlights
- One-time Initial Synchronization recovery summary before setup closes.
- Actionable Synchronization Health with exact refresh steps.
- Character Registry for safe management of offline saved HorizonCheck profiles.
- Expanded conservative Anniversary lane automation and unmapped-riddle evidence collection.
 v6.9.39


## v6.9.39

- Expands the native Quest Menu learning capture based on the Admiral evidence capture.
- Quest Menu captures now preserve the complete payload for incoming `0x063` and `0x119` packets rather than truncating them to 48 bytes.
- Quest Menu mode keeps up to 32 unique samples per packet ID/size so the many `0x063` subtypes/records seen while browsing quest categories are not discarded after only three samples.
- No quest completion/status assumptions are enabled yet; this remains evidence gathering for authoritative native quest-log decoding.

## v6.9.38
- Eco-Warrior proof key items now use the authoritative 0x055 key-item bitmap.
- Indigested Ore (Bastok), Indigested Stalagmite (San d'Oria), and Indigested Meat (Windurst) show KEY ITEM READY / TURN IN when owned.
- Proof KI disappearance never marks completion; existing NPC/reward verification remains authoritative for CLEARED.

## v6.9.35
- Adds `Imperial Army I.D. Tag` to the authoritative `0x055` key-item bitmap map.
- Assault `On Character` tag ownership now reconciles from the server key-item bitmap when available; Rytaal's stored/account tag count remains independently sourced from Rytaal.
- Shows `[KI VERIFIED]` beside the carried Assault tag count when the latest ownership evidence came from `0x055`.
- Fixes a weaker total-minus-Rytaal inference path so it can no longer override stronger bitmap ownership evidence.


- Promotes the server-provided incoming `0x055` key-item bitmap to authoritative ownership evidence for Miasma Filter, Zephyr Fan, Secret Imperial Order, and Cosmo-Cleanse.
- ENM held-KI state now self-restores/clears after zone-in without inventing a new cooldown timestamp.
- ISNM stale `ORDER HELD` state is cleared when the bitmap proves the Secret Imperial Order is absent, while consumed/active/completed run transitions are protected.
- Limbus now surfaces `COSMO-CLEANSE HELD | KI VERIFIED` and prioritizes Limbus as READY in Attention when appropriate.
- Ashita `HasKeyItem()` probes remain diagnostics only because the confirmed Cosmo-Cleanse test returned a false negative.

# HorizonCheck

### v7.1 highlights
- One-time Initial Synchronization recovery summary before setup closes.
- Actionable Synchronization Health with exact refresh steps.
- Character Registry for safe management of offline saved HorizonCheck profiles.
- Expanded conservative Anniversary lane automation and unmapped-riddle evidence collection.
 v6.9.33

- Adds authoritative H.A.A.P. Point auto-sync from FFXI's native Currency menu.
- Decodes the full incoming `0x113` Currency packet and reads HAAP as a little-endian uint32 at zero-based offset `0xE0` (224), verified by the captured `0B 00 00 00` value for 11 points.
- Opening the Currency menu refreshes the stored HAAP balance, clears stale reward-pending state, and records before/after balance changes.
- HAAP status now reports whether the last authoritative verification came from the Currency menu or HAAP.I.
- Existing HAAP.I dialogue synchronization remains as a fallback.

# v6.9.29

## v6.9.29
- Expands Currency capture mode so the complete 0x113 packet payload is preserved instead of only the first 48 bytes.
- This is specifically for mapping the native Currency menu values (known sample: HAAP 11, Shining Stars 0, Imperial Standing 1305, Leujaoam Sanctum Assault Points 2610) to authoritative packet offsets.
- Does not guess a HAAP offset yet; one new full-payload Currency capture is required before enabling automatic HAAP balance updates.
- Keeps all v6.9.28 plant-pot automation and prior trackers unchanged.

# v6.9.28

## v6.9.28
- Fixes automatic Mog House plant-pot detection on live Ashita packets by preferring `e.data` (the same payload used by the capture system) before the optional `e.data_raw` field.
- `Relearn Pots` now receives the verified `0x0FA` pot IDs correctly, so unique pots can populate `0/?`, learn the per-character total, and auto-complete the daily objective.

## v6.9.27
- Adds automatic duplicate-safe Mog House plant-pot tracking from verified `0x0FA` flowerpot interaction packets.
- Tracks each unique pot only once per day using the per-pot identifier seen in capture evidence.
- Makes the per-character pot target dynamic: existing 10-pot characters retain 10; new/relearned characters learn their current total after a short idle period.
- Adds `Relearn Pots` for characters whose number of planted pots changes.
- Daily reset clears only today's checked-pot set while preserving the learned per-character target.


- Upgrades the Daily Objective plant-pot tracker for a 10-pot Mog House: shows 0/10 through 10/10, auto-completes at 10/10, and resets the counter at the daily reset.
- Adds manual + Checked / Undo controls while capture evidence is gathered for duplicate-safe automatic unique-pot detection.
- Keeps the dedicated Pots capture profile for learning the exact furniture interaction signature without guessing.

- Polishes the production UI so version labels always match the running build and Attention focuses on actionable states instead of completed/capped noise.
- Adds actionable ISNM READY / IN PROGRESS states to Attention.
- Fixes account-wide Black Coffin weekly reset so failed/completed chain state cannot carry into the next Conquest week.
- Adds capture-verified Black Coffin lifecycle tracking for Halshaob acceptance and Ashu Talif entry (READY -> IN PROGRESS), including the verified 30-minute mission limit.
- Keeps existing specialized tracker data and developer diagnostics intact; no new diagnostic UI is added.

# v6.9.22

- Cleans up the Assault tab: removes the redundant Current Assault block, duplicated Assault Tags diagnostics, packet/debug evidence text, and repair/developer controls from the normal mission-progress view.
- Keeps the authoritative Assault tag tracking logic and compact tag counts/timer in the main Assault Tags section.
- Removes the visible Advanced / Historical Sync controls from Missions now that authoritative mission syncing is the normal path. Historical fallback logic remains internal for legacy-state migration/recovery.
- Retains the v6.9.21 Black Coffin failure auto-check behavior and all existing automation.

# HorizonCheck

### v7.1 highlights
- One-time Initial Synchronization recovery summary before setup closes.
- Actionable Synchronization Health with exact refresh steps.
- Character Registry for safe management of offline saved HorizonCheck profiles.
- Expanded conservative Anniversary lane automation and unmapped-riddle evidence collection.
 v6.9.21

- Adds a shared activity lifecycle layer (`AVAILABLE / PREP / READY / IN_PROGRESS / CLEARED / COOLDOWN / LOCKED`) without replacing existing specialized tracker storage.
- ENM now mirrors authoritative NPC, key-item, battlefield-entry, clear, and cooldown evidence into that lifecycle layer.
- Adds load-time stale-state validation for abandoned ENM runs, expired lifecycle records, and impossible persisted ENM timers.
- Preserves the existing Attention layout and avoids adding another redundant summary block.

# HorizonCheck

### v7.1 highlights
- One-time Initial Synchronization recovery summary before setup closes.
- Actionable Synchronization Health with exact refresh steps.
- Character Registry for safe management of offline saved HorizonCheck profiles.
- Expanded conservative Anniversary lane automation and unmapped-riddle evidence collection.
 v6.9.19

## v6.9.19
- Rejects implausible ENM Earth-time timestamps instead of overwriting a valid cooldown (for example, a corrupt Moritz year decades in the future).
- Preserves the previous ENM state when an NPC timestamp fails sanity validation.
- Learns battlefield time limits generically from the normal `The time limit for this battle is N minutes` message.
- Stores the actual clear duration from `Battlefield clear time` when available.
- ENM cooldown rows now show both remaining time and the exact local ready timestamp.
- Expired NPC `NO KEY ITEM / AVAILABLE ...` hints no longer clutter an already-available row.
- Corrects internal addon version metadata so the displayed/runtime version matches the package version.


- Removes the redundant Conquest Cycle Summary; the same status is already shown in the existing activity/Attention UI.
- Retains the standardized ENM lifecycle wording and Dynamis/Limbus used/remaining counters from v6.9.16.
- Retains the clearer ISNM no-order verification state.
- Confirms the existing user-armed Moritz sync correctly accepts Boneyard Gully's exact Earth-time cooldown response.
- Retains all Boneyard Gully prerequisite, Miasma Filter, entry, clear, cooldown, and Anniversary automation from prior builds.

# HorizonCheck

### v7.1 highlights
- One-time Initial Synchronization recovery summary before setup closes.
- Actionable Synchronization Health with exact refresh steps.
- Character Registry for safe management of offline saved HorizonCheck profiles.
- Expanded conservative Anniversary lane automation and unmapped-riddle evidence collection.
 v6.0

HorizonXI activity tracker for Ashita v4.

## v6.0 highlights

- Experimental **Rytaal Assault Tag packet synchronization** from incoming `0x034`.
- Validates the Rytaal menu signature and requires Rytaal target/recent Rytaal interaction before decoding.
- Decodes `0x0C` as tags waiting with Rytaal and `0x14` as the carried Imperial Army I.D. Tag flag.
- Synchronizes total usable tags as `waiting + carried`, sanity-checked to `0-4`.
- Dry Run previews packet-decoded totals without changing the tracker.
- `/hcheck tags auto on|off|status` controls the experimental packet sync independently.
- Existing manual `/hcheck tags <count> [cap]` remains available as a fallback.
- Count synchronization is packet-based; regeneration time remains an estimate because the captured menu packet does not expose a proven exact timer field.

## Commands

- `/hcheck` - toggle main window
- `/hcheck diagnostics` - open Automation Monitor
- `/hcheck selftest` - run module self-test
- `/hcheck auto` - show automation status
- `/hcheck auto on|off` - enable/disable all automation
- `/hcheck auto dryrun on|off` - detect and log without changing checklist state
- `/hcheck auto <system> on|off` - toggle one detector
- `/hcheck undo` - undo the most recent undoable automatic event
- `/hcheck undo <event-id>` - undo a specific recent automatic event by ID
- `/hcheck session status` - show active activity sessions
- `/hcheck session abort <type>` - manually close a stuck session
- `/hcheck learn <activity> [seconds]` - start a bounded learning capture
- `/hcheck learn mark <label>` - begin a named capture phase at an important moment
- `/hcheck learn stop|status|profiles|clear` - manage learning capture
- `/hcheck tags <count> [cap]` - sync Assault Tag count
- `/hcheck enm <id> [hours-ago]` - manually set/correct an ENM timer
- `/hcheck reset daily|weekly` - manually reset checklist data

Supported automation systems:

## Recommended detector-learning workflow

1. Turn on Dry Run: `/hcheck auto dryrun on`.
2. Start a targeted capture, for example `/hcheck learn assault`.
3. Before the important action, use `/hcheck learn mark action`.
4. When the reward/result appears, use `/hcheck learn mark reward`.
5. Stop with `/hcheck learn stop`.
6. Review or share the generated `horizoncheck_capture_...txt` evidence report.
7. After a detector is verified, turn Dry Run off with `/hcheck auto dryrun off`.

Packet samples remain bounded to the first 48 bytes with at most three unique samples per packet ID/size shape. Learning mode is still time-bounded (15-900 seconds) and auto-stops on addon unload.


## v6.0 Assault Tag automation + learner

- Dedicated Rytaal / Assault Tag evidence mode on `/hcheck learn tags`.
- Captures full candidate incoming `0x034` packets during tag sessions.
- Recognizes Rytaal welcome/tag-related text in the evidence report.
- Label a known stored-tag count with `/hcheck learn known 0` through `/hcheck learn known 4`.
- Known-count packet observations persist across captures and are compared byte-by-byte.
- `/hcheck learn tagstatus` reports how many known states and candidate offsets have been learned.
- `/hcheck learn cleartags` clears only the Assault Tag learner database.
- Experimental automatic tag synchronization is now enabled from the validated `0x0C` waiting-count and `0x14` carried-tag fields; the learner remains available for additional validation captures.


## v6.0 Activity Session Engine
- Unified persistent sessions for Dynamis, Limbus, and Assault completion inference.
- Reloading inside Dynamis/Limbus creates a recovery baseline instead of double-counting a run.
- Session history stores recent activity lifecycle records and confidence labels.
- Daily/Conquest reset snapshots are archived in state (up to 20 reset records) before counters clear.
- Automation events receive stable IDs and are appended to `horizoncheck_audit_<character>.log`.
- `/hcheck undo <event-id>` can reverse a specific recent undoable automatic event; `/hcheck undo` still reverses the newest eligible event.
- `/hcheck session status` shows active sessions; `/hcheck session abort <type>` manually closes a stuck session.
- Rytaal Assault Tag packet synchronization from v5.9 remains experimental and unchanged.


### Chocobo Digging daily tracker (v6.0.5)
- Replaces the old Crafting / Gathering daily row with Digging only.
- Tracks successful items dug today and automatically checks the daily row at the rank cap.
- HorizonXI rank caps used by the addon: Amateur 100, Recruit 110, Initiate 120, Novice 130, Apprentice 140, Journeyman 150, Craftsman 160, Artisan 170, Adept 180, Veteran 190, Expert 200.
- `/hcheck digging status`
- `/hcheck digging rank <rank>`
- `/hcheck digging set <count>`
- `/hcheck digging +` / `/hcheck digging -`
- `/hcheck digging reset`
- Rank is retained across daily resets; the item count resets at the normal HorizonCheck daily boundary.
\n\n### Guild Point dialogue sync (v6.0.6)\n- Parses the Guild Union NPC's explicit `you have X guild points accumulated` line as the authoritative GP balance.\n- Remembers the current requested guild item when present in the same NPC dialogue.\n- A `trade X guild points for ITEM?` prompt creates a pending transaction only; no points are removed until the matching `Obtained: ITEM.` receipt is seen.\n- Confirmed purchases subtract from the cached GP balance until the next authoritative NPC balance reconciliation.\n- `/hcheck gp textauto on|off|status` controls the dialogue-based GP sync independently.\n- Existing packet learning and manual `/hcheck gp ...` fallback remain available.\n

### Guild Point purchase matching (v6.0.7)
- Debounces duplicate Guild Union NPC balance dialogue.
- Normalizes simple singular/plural item-name differences when matching a GP purchase prompt to the later `Obtained:` line.
- GP is subtracted only after the matching item receipt is confirmed.
- Pending purchase confirmations expire after 30 seconds.


### Guild Point receipt fix (v6.0.8)
- Accepts HorizonXI `Obtained:` receipts that contain trailing control bytes after the visible period.
- Debounces repeated Guild Union NPC balance lines and repeated purchase prompts.
- Keeps singular/plural item matching and only subtracts GP after the receipt is confirmed.


### Quality-of-life automation (v6.0.9)
- Guild Point NPC balance checks now automatically satisfy the Daily / Regular Guild Points row.
- Confirmed GP purchases also satisfy the daily row and store a Last GP Change record.
- Guild Point details show the most recent delta/source and cached before/after totals.
- Spice Gals recurring completion now uses Rouva's Rivernewort turn-in context followed by the Miratete reward; the one-time HorizonXI achievement line is not used as a recurring trigger.
- Digging records the last successful-dig text signature and exposes detector status in the UI/diagnostics.
- Digging duplicate suppression now keys on the success text as well as time.


### Spice Gals recurring completion correction (v6.0.10)
- Removed the one-time HorizonXI achievement message as an authoritative recurring completion trigger.
- The repeatable weekly detector now arms only from Rouva's Rivernewort turn-in / gratitude dialogue.
- `Obtained: Page from Miratete's Memoirs.` within 45 seconds of that turn-in context confirms Spice Gals for the week.


### Guild Point turn-in earnings (v6.0.11)
- Parses HorizonXI's explicit `Obtained: <number> guild points.` reward line from Guild Union item turn-ins.
- Adds the exact amount to the cached Guild Point balance immediately.
- Records before/after balance and source in the GP history.
- Marks the Daily / Regular Guild Points task complete on a confirmed turn-in.
- Duplicate copies of the same GP gain line are debounced.


### Guild Point turn-in hotfix (v6.0.12)
- Fixes v6.0.11 placing the GP gain parser in the wrong helper function.
- `Obtained: <number> guild points.` is now parsed in the live Guild Point text handler.
- The cached GP total updates immediately and records the turn-in in the UI.


### Digging packet-window detector (v6.0.13)
- Successful HorizonXI digs are detected from the digging action packet sequence plus the nearby `Obtained:` item line.
- Uses packet `0x02F` to arm a short result window and only increments when an item is obtained during that window.
- Ordinary loot, Guild Point rewards, key items, purchases, and unrelated `Obtained:` lines do not count as digs.
- Keeps the existing manual digging count/rank correction controls.


### Digging callback fix (v6.0.14)
- Fixes v6.0.13 generic incoming packet callbacks not being dispatched.
- Fixes the local Lua scope/order bug in the Digging `Obtained:` result helper.
- Successful digs now use `0x02F` to arm a 5-second result window and count the next item `Obtained:` line.
- `/hcheck digging status` now reports whether the 0x02F packet itself is being observed, making live verification easier.


### Digging statistics, remaining count, and fatigue warnings (v6.0.15)
- Shows successful digs completed, cap, and exact digs remaining.
- Shows daily progress percentage and successful digs/hour once enough samples exist.
- Fatigue warnings at 75%, 90%, 95%, and 100% of the configured rank cap.
- No item history, zone statistics, price/value tracking, or other digging features were added.


### Digging rate baseline correction (v6.0.16)
- Existing daily dig totals no longer prevent Today's Rate from appearing after an upgrade or reload.
- The first successful dig observed after upgrade/reload establishes a fresh rate baseline while preserving the existing daily count.
- Rate is calculated from subsequent successful digs observed after that baseline.
- The UI shows how many successful digs are included in the current rate sample.


### Eeko-Weeko rotation reconciler (v6.0.17)
- Adds a safe Eco-Warrior rotation sync based on the captured Eeko-Weeko dialogue state.
- Recognizes the specific confirmed dialogue where Eeko-Weeko says the user's name came from the Windurst and Bastok consulates and recommends checking with San d'Oria next week.
- Reconciles the rotation to: Windurst complete, Bastok complete, San d'Oria next/active.
- Does not guess other Eeko-Weeko rotation states until additional captures support them.


### Eeko-Weeko reconciler fix (v6.0.18)
- Fixes the Eeko text handler calling the local Eco state helper before it was declared.
- Initializes persistent Eeko synchronization metadata correctly.
- Announces a successful Eeko-Weeko rotation confirmation even when the saved rotation already matches and no correction is required.


### Authoritative Eeko rotation correction (v6.0.19)
- Eeko-Weeko's confirmed Windurst+Bastok-cleared / San d'Oria-next dialogue now repairs stale manual state.
- If San d'Oria was incorrectly marked complete, the reconciler clears it.
- Clears a stale `completed_this_week = sandoria` value when Eeko explicitly says San d'Oria is next.
- The resulting rotation is 2/3 cleared with San d'Oria active/next.


### Authoritative HorizonXI digging cap (v6.0.20)
- Detects HorizonXI's `You have maxed your player digging for today!` message.
- Treats that message as authoritative: Digging is marked complete, remaining digs become 0, and the UI shows `CONFIRMED BY HORIZONXI`.
- Preserves the actual successful-dig count observed by HorizonCheck instead of forcing the count to the configured rank maximum.
- Removed Today's Rate from the Digging UI and `/hcheck digging status`.


### HAAP authoritative synchronization (v6.0.21)
- Parses HAAP.I's `You currently have <N> points!` line as the authoritative HAAP point balance.
- Tracks the last verified time and before/after HAAP balance changes.
- Recognizes the captured `Thank you for being a friend! Here is your reward!` context followed by `Obtained: Page from the Dragon Chronicles.` as a confirmed weekly HAAP reward.
- Marks both HAAP Weekly Rewards and HAAP.I Dragon Chronicles complete after the confirmed reward receipt.
- After a reward claim, shows `balance awaiting HAAP.I refresh` until the NPC reports the authoritative point total again.
- `/hcheck haap status` shows the current synchronization state.


### HAAP weekly scroll tracking (v6.0.22)
- Tracks HAAP.I's weekly Dragon Chronicles and Miratete's Memoirs claims independently.
- `Obtained: Page from the Dragon Chronicles.` after HAAP reward dialogue marks the Dragon claim.
- `Obtained: Page from Miratete's Memoirs.` after HAAP reward dialogue marks the Miratete claim.
- The main HAAP Weekly Scrolls row completes only when both weekly scrolls are claimed.
- HAAP status shows `Dragon DONE/OPEN | Miratete DONE/OPEN`.


### HAAP row-specific status display (v6.0.23)
- Both HAAP EXP-scroll rows show the current HAAP point balance.
- Dragon Chronicles row shows only `Dragon DONE/OPEN`.
- Miratete's Memoirs row shows only `Miratete DONE/OPEN`.
- Removes the combined Dragon+Miratete status string from the individual EXP-scroll rows.


### Highwind entity kill detection (v6.0.24)
- Replaces reliance on an unobserved 3,000 EXP/gil reward-text pattern with a direct monster watcher.
- Arms only when the player's actual target entity is named `Highwind`.
- Remembers that entity index/server ID and marks the weekly complete only when the same watched Highwind reaches 0% HP.
- Includes a 5-minute stale-watch timeout and server-ID mismatch protection.
- Highwind's weekly row shows `AUTO READY TO DETECT`, `AUTO WATCHING`, or `AUTO COMPLETE`.


### HAAP parent-row reconciliation (v6.0.25)
- `HAAP Weekly Scrolls` is now derived continuously from the two individual HAAP scroll flags.
- When both `HAAP.I - Dragon Chronicles` and `HAAP.I - Miratete's Memoirs` are DONE, the parent weekly row automatically becomes complete.
- Existing/reloaded saved states self-correct even if both child scrolls were already DONE before this patch.
- If either child scroll is reopened/undone, the parent HAAP weekly row reopens automatically.


### HorizonXI content cleanup (v6.0.26)
- Removed `The Big One` from HorizonCheck because the quest is not available on HorizonXI.


### HorizonXI content cleanup (v6.0.27)
- Removed HENM tracking/content from HorizonCheck because it is gated endgame linkshell content rather than a broadly useful personal weekly activity.


### Automation Monitor ImGui fix (v6.0.28)
- Corrected the Automation Monitor Begin/End lifecycle.
- `imgui.End()` is now explicitly guaranteed for every `imgui.Begin()`, including collapsed/closed window states.
- Prevents Dear ImGui's `Missing End()` assertion from hiding the main HorizonCheck window.


### Automation Monitor protected-body fix (v6.0.29)
- The complete Automation Monitor body now runs inside `xpcall`.
- `imgui.End()` executes unconditionally even when a diagnostics subsection throws an error.
- Diagnostics-body errors are recorded instead of escaping into the main UI draw loop.
- Prevents a monitor subsection error from causing Dear ImGui `Missing End()` and hiding the main HorizonCheck window.


### Automation systems restoration (v6.0.30)
- Fixes the actual Automation Monitor failure introduced during the HENM cleanup.
- Restores the `SYSTEMS` table with: Dynamis, Limbus, Assault, Guild Points, Eco-Warrior, Dragon/EXP-scroll automation, and Highwind.
- HENM remains removed.
- Retains protected Automation Monitor rendering and throttles repeated diagnostics chat errors.


### Black Coffin rotation (v6.0.31)
- Adds a dedicated 3-week Black Coffin rotation section modeled after Eco-Warrior.
- Rotation order: `Scouting the Ashu Talif` -> `Royal Painter Escort` -> `Targeting the Captain`.
- Tracks each quest as CLEARED / NEXT / PENDING.
- Rotation state persists across weekly resets and can be manually reset when starting a new 3-week cycle.
- No unverified NPC/reward details were added.


### Black Coffin quest details (v6.0.32)
- Adds the start NPC and required item for each Black Coffin rotation quest.
- Scouting the Ashu Talif: Halshaob - Nashmau (H-10), Imperial Bronze Piece x3.
- Royal Painter Escort: Halshaob - Nashmau (H-10), Imperial Silver Piece x1.
- Targeting the Captain: Halshaob - Nashmau (H-10), Imperial Mythril Piece x1.


### One-click debug capture (v6.0.33)
- Adds reusable `Capture` buttons that start the existing HorizonCheck Learning/evidence recorder.
- When that activity's capture is active, the same button becomes `Stop Capture`.
- Added explicit learning profiles for HAAP, Chocobo Riding Game, and Black Coffin.
- Capture buttons are exposed on supported Daily/Weekly activities, EXP-scroll sources, Eco-Warrior, Black Coffin Rotation, and ENM Timers.
- Existing `/hcheck learn ...`, marker, stop, and evidence-report behavior is unchanged.


### Chocobo Riding Game Bastok predictor (v6.0.34)
- Adds automatic Bastok Riding Game starter/route prediction from Vana'diel time.
- Confirmed capture cycle:
  - Azette -> Windurst Woods
  - Eulaphe -> Lower Jeuno
  - Quelle -> Southern San d'Oria
  - then repeats.
- Shows the current starter, destination, next starter/route, and Earth-time countdown to the next Vana'diel-day change.
- Uses the established FFXI Vana'diel conversion `(Unix + 92514960) * 25`, so no manual anchor is required.


### Chocobo route-time / gear guidance (v6.0.35)
- Bastok -> Southern San d'Oria: Dragon Chronicles cutoff 20:13; no riding-time gear required.
- Bastok -> Windurst Woods: Miratete's Memoirs cutoff 32:29; base riding time is 30:00, so at least +3 minutes Chocobo Riding Time is required/recommended.
- Bastok -> Lower Jeuno: City Glyph cutoff 18:49; no riding-time gear required.
- Displays Chocobo Riding Time gear bonuses: Body +5, Legs +4, Hands +3, Feet +3, full set +15 minutes.


### Chocobo manual-stop capture (v6.0.36)
- Chocobo Riding Game one-click captures no longer auto-stop after 120 seconds.
- Chocobo capture remains active until `Stop Capture` is clicked or `/hcheck learn stop` is used.
- Other learning profiles keep their existing automatic timeouts.
- Chocobo evidence capture is intended to span the full pickup -> ride -> zone transitions -> finish -> reward sequence.


### City-aware Chocobo Riding Game predictor (v6.0.37)
- Detects Bastok Mines, Southern San d'Oria, or Windurst Woods from the current zone.
- Shows the predicted current starter NPC, destination, best-reward cutoff, reward, gear requirement, and next rotation.
- Bastok NPC/route phase mapping is capture-verified.
- San d'Oria and Windurst NPC/route phase mappings are included using the same 3-day model but labeled as needing direct capture validation.
- Route targets:
  Bastok -> San d'Oria 20:13; Windurst 32:29; Jeuno 18:49.
  San d'Oria -> Bastok 19:59; Windurst 28:19; Jeuno 13:15.
  Windurst -> San d'Oria 28:36; Bastok 32:29; Jeuno 15:29.
- Riding-time gear is required for the 32:29 Bastok<->Windurst routes; +3 minutes minimum.


### ENM full-battle capture window (v6.0.38)
- ENM one-click Capture duration increased from 3 minutes to 20 minutes.
- Covers a full 15-minute Boneyard Gully ENM plus entry and post-battle reward/cooldown evidence.
- Chocobo Riding Game remains manual-stop only.


### Assault manual-stop capture (v6.0.39)
- Assault one-click Capture no longer auto-stops after a fixed timer.
- Assault capture remains active until `Stop Capture` is clicked or `/hcheck learn stop` is used.
- Intended for long Assault runs that can approach one hour.
- Chocobo Riding Game remains manual-stop only; ENM remains a 20-minute timed capture.


### Dragon Chronicles UI cleanup (v6.0.40)
- Removed visible `[UNLEARNED]` quest-flag status labels and `Learn Flag` buttons from Dragon Chronicles / EXP Scroll rows.
- Capture buttons remain available and continue to collect packet/text evidence for future checkbox automation.
- Underlying quest-flag learning/debug code remains available internally/through diagnostics.


### Dynamis / Limbus entry capture buttons (v6.0.41)
- Adds one-click Capture buttons beside the Dynamis and Limbus weekly run counters.
- Dynamis capture window is 3 minutes and is intended only for entry/zone-transition evidence used to count one of the two weekly lockouts.
- Limbus capture window is 5 minutes and is intended for Cosmo-Cleanse acquisition/consumption plus Temenos/Apollyon entry evidence.
- Full Dynamis/Limbus runs are not required for these captures.


### Conquest / Outpost ownership tracker (v6.0.42)
- Tracks all 17 HorizonXI Supply Run / Outpost Teleport regions.
- Conquest / Outposts row shows `X/17 obtained | Y missing` or `All outposts obtained`.
- Detailed section lists every missing region and its outpost area.
- Parent Conquest / Outposts checkbox is derived automatically from individual ownership.
- Adds Mark All / Clear controls and an Outpost NPC capture path for future automatic menu synchronization.


### Weekly / Conquest layout correction (v6.0.43)
- Moves the Dynamis and Limbus 0/2 run lines back directly underneath the Weekly / Conquest Tally checklist.
- Conquest / Outpost Details now appears after the Dynamis and Limbus lines.
- Dynamis/Limbus Capture, + Run, Undo, and AUTO status controls are unchanged.


### ENM battlefield tracking + long-capture evidence fix (v6.0.44)
- Detects known ENM battlefield entry from `Entering the battlefield for <ENM>!`.
- Confirmed from Boneyard Gully capture: `Sheep in Antlion's Clothing`, 15-minute limit.
- ENM section shows the active battlefield, elapsed time, and nominal remaining time.
- Does NOT invent an ENM victory detector; completion remains unconfirmed until an end-of-fight capture provides authoritative evidence.
- Evidence reports now retain the first 120 AND rolling last 160 text messages, preventing long fights from dropping their reward/victory/failure messages.


### Manual-stop capture bug fix (v6.0.45)
- Fixes Assault and Chocobo captures immediately expiring at start.
- Root cause: Lua's `and/or` pseudo-ternary cannot preserve a nil result.
- Manual-stop profiles now explicitly set `capture.ends_at = nil`.
- Assault and Chocobo captures remain active until Stop Capture or `/hcheck learn stop`.
- Timed profiles such as ENM, Dynamis, Limbus, HAAP, etc. are unchanged.


### Assault lifecycle + safe tag tracking (v6.0.46)
- Learns the full Assault lifecycle from the captured Lebros Supplies run:
  ACCEPTED -> ORDERS RECEIVED -> COMMAND VERIFIED -> STAGING -> ENTERED -> OBJECTIVE COMPLETE -> COMPLETED.
- Assault Tag count now decrements when an Assault Orders key item is obtained, matching the actual tag-consumption point.
- Successful completion is confirmed by either `You gain <N> assault points!` or the explicit `awarded assault points for the successful completion of your mission` message.
- Duplicate success messages are de-duplicated so a single Assault cannot decrement/count twice.
- The Daily Assault checkbox auto-completes only on authoritative success evidence.
- Rytaal 0x034 packet decoding is now learning-only. Captures at known stored counts 0-4 proved the previous 0x0C/0x14 arithmetic was unsafe for live synchronization, so HorizonCheck no longer overwrites the live tag count from those bytes.


### Assault Tag carried / Rytaal split (v6.0.47)
- Assault Tags now display `On Character` and `Rytaal` separately.
- Example at 4 total with one carried: `4/4 tags | Character 1 | Rytaal 3`.
- Obtaining `Imperial Army I.D. Tag` sets Character=1 without changing the total.
- Obtaining Assault Orders consumes the carried tag and decrements total by one.
- Existing states without observed carried ownership default to one carried when total > 0 and are marked estimated with `*`.
- Manual override: `/hcheck tags carried 0` or `/hcheck tags carried 1`.


### Assault Tag display clarity (v6.0.48)
- Assault Tags now show separate explicit lines for Total, On Character, and Rytaal Holding.
- Rytaal Holding displays its effective cap based on the carried tag.
- Example with one carried tag: `Rytaal Holding: 2/3`.
- Shows `Next Rytaal Tag: HH:MM:SS` while regenerating.
- When full, displays `Rytaal Holding: 3/3 CAPPED` and `Next Rytaal Tag: CAPPED`.
- Existing carried/tag timer estimates remain clearly marked with `*` until directly observed.


### Assault Mission Progress (v6.0.49)
- Adds all 50 standard Assault missions grouped by Mercenary Rank PSC through FL.
- Shows rank progress as 0/5 through 5/5 and overall progress as X/50.
- Completed missions appear checked normally.
- Incomplete missions are greyed out.
- Confirmed Assault success automatically marks the accepted mission complete.
- Manual `Mark Complete` fallback is available for missions cleared before HorizonCheck began tracking.
- 50/50 displays Captain Assault requirement complete.


### Assault checklist cleanup (v6.0.50)
- Removed the old standalone `Assault [Capture] - Leujaoam Sanctum / Mamool Ja Training Grounds / Lebros Cavern / Periqia / Ilrusi Atoll` checklist row.
- Dedicated Assault Tags, Assault lifecycle automation, manual-stop capture, and Assault Mission Progress remain intact.


### Assault section placement + Attention notification (v6.0.51)
- Moves Assault Mission Progress directly below Attention near the top of the main window.
- Moves Assault Tags into the top of Assault Mission Progress.
- Removes the old Assault Tags row from Daily / Regular and the duplicate tag panel from Status Details.
- Attention now provides a prominent Assault Tags status:
  - READY/CAPPED warning when total tags are full.
  - Available-tag notice when Rytaal is holding tags.
  - Next Rytaal regeneration countdown when not capped.
- Assault Tags Capture remains available beside the moved tag status.


### UI placement (v6.0.52)
- Moved Assault Mission Progress below ENM Timers and directly above Status Details.
- Assault Tags remain inside Assault Mission Progress.
- Attention Assault Tag notifications remain unchanged.


### EXP Ring placement (v6.0.53)
- Moved the EXP Ring charge/recharge status from Status Details into Attention.
- The Attention line keeps the ring name, current/max charges, and weekly recharge status.
- Removed the duplicate EXP Ring line from Status Details.


### Assault Tag regeneration rollover fix (v6.0.54)
- Fixes the tag timer reaching zero and restarting without increasing the tracked tag total.
- Every elapsed 24-hour regeneration interval now increments the total by one before scheduling the next interval.
- With one tag carried, regenerated tags correctly increase `Rytaal Holding` from 0/3 -> 1/3 -> 2/3 -> 3/3.
- Regeneration changes are immediately persisted to character state.
- Adds a one-time chat notification when HorizonCheck detects a regenerated Assault Tag.
- Catch-up logic handles more than one elapsed regeneration interval if the addon was not running continuously.


### Legacy Assault Tag missed-regeneration repair (v6.0.55)
- Adds `Repair +1 Stored` beside Assault Tags.
- Adds `/hcheck tags repair`.
- Intended for state already damaged by the pre-v6.0.54 rollover bug.
- Adds exactly one missing regenerated tag while preserving the currently-running next-tag timer.
- Do not use repeatedly unless multiple regenerations are known to have been missed.
- Normal future timer rollover remains automatic from v6.0.54 onward.


### Rytaal automatic tag reconciliation (v6.0.56)
- Talking to Rytaal now immediately reconciles Assault Tag timer-derived state.
- Rytaal's 0x034 menu packet also triggers reconciliation if dialogue text is filtered.
- Normal elapsed 24-hour intervals are caught up before displaying the result.
- Adds a one-time safe migration repair for the known pre-v6.0.54 `Character 1 / Rytaal 0` missed-rollover state when talking directly to Rytaal.
- The migration repair preserves the currently-running next-tag timer and can only fire once.
- Assault Mission Progress shows the last Rytaal reconciliation time.
- `Repair +1 Stored` remains available as a manual fallback.


### Rytaal legacy reconciliation correction (v6.0.57)
- Fixes a mismatch where the UI displayed `Character 1` from an estimated carried split while Rytaal reconciliation read the raw nil carried field as zero.
- Rytaal reconciliation now uses the exact same effective Character/Rytaal split shown in the UI.
- If the one-time legacy missed-regeneration repair fires from an estimated Character=1 state, it promotes that state to explicit Character=1.
- Forward-declares the Rytaal reconciliation callback so both dialogue and 0x034 menu triggers use the same local function safely.
- Adds internal reconciliation diagnostics for future troubleshooting.


### Guild Points completion tightening (v6.0.58)
- Guild Points no longer auto-checks merely from speaking to the Guild Union NPC or reading the current GP balance.
- Buying an item with Guild Points no longer checks the daily Guild Points row.
- Removed the broad generic `guild points` reward matcher from automation.
- The daily Guild Points checkbox now auto-completes only from a confirmed positive requested-item turn-in message such as `Obtained: 1054 guild points.`
- NPC dialogue still syncs the cached GP balance and requested item normally.


### EXP Ring weekly auto-check fix (v6.0.59)
- A confirmed increase in charges on a rechargeable EXP ring now checks `EXP Ring` under Weekly / Conquest.
- Works from both the Attention ring scanner and the full ring scanner.
- If `Recharge this week: YES` was already detected before this patch but the weekly checkbox remained unchecked, the next scan reconciles and checks it automatically.
- Records the automatic weekly update in automation history for Undo AUTO.


### Conquest NPC endpoint auto-sync (v6.0.60)
- Uses two user-captured, known-ground-truth HorizonXI samples:
  - ALL outposts obtained.
  - NO outposts obtained.
- Conquest Supply Mission 0x034 bytes 0x18-0x1A and 0x20-0x22 are used only as verified endpoint fingerprints.
- Verified NONE endpoint: `00 00 00 / 00 00 00`.
- Verified ALL endpoint: `E0 FF 9F / EA 89 03`.
- Talking to a recognized Conquest NPC can now automatically set 0/17 or 17/17 when one of those verified endpoint fingerprints is observed.
- Intermediate/partial patterns are captured and displayed as `PARTIAL/UNKNOWN` but DO NOT alter individual outpost checkboxes yet.
- This intentionally avoids inventing individual region-bit mappings from only two endpoint samples.


### Conquest partial outpost mapping: Gustaberg (v6.0.61)
- Adds the first verified individual partial ownership state from captured HorizonXI data.
- Verified NONE state: `00 00 00 / 00 00 00` -> 0/17.
- Verified Gustaberg-only state: `00 01 00 / 0A 00 00` -> Gustaberg obtained, 1/17.
- Verified ALL state: `E0 FF 9F / EA 89 03` -> 17/17.
- Talking to a recognized Conquest NPC now auto-syncs these three verified states.
- Other partial patterns remain `PARTIAL/UNKNOWN` and do not alter individual outpost checkboxes yet.


### Conquest NPC packet-order fix (v6.0.62)
- Fixes Gustaberg not auto-checking after talking to the Conquest NPC.
- HorizonXI can deliver the 0x034 NPC menu packet before the associated Conquest dialogue.
- v6.0.61 required dialogue first and therefore discarded the ownership packet.
- v6.0.62 caches a 52-byte 0x034 for up to 8 seconds and consumes it when matching Conquest/Supply Mission dialogue confirms the NPC context.
- If dialogue arrives first, the packet is still processed immediately.
- Adds `Last Conquest NPC sync` to Outpost Ownership diagnostics.


### Conquest auto-sync Lua scope fix (v6.0.63)
- Fixes the actual reason verified Outpost fingerprints were not applying.
- `apply_endpoint()` referenced `sync_parent` before the local function was declared, so Lua resolved it as a nil global inside the packet callback.
- `sync_parent` is now forward-declared before `apply_endpoint`, allowing 0/17, Gustaberg-only 1/17, and 17/17 states to update correctly.
- Keeps the packet-before-dialogue cache from v6.0.62.
- Adds visible `Last classifier` and `Outpost auto-sync error` diagnostics if a future sync fails.


### Verified Outpost fingerprint direct sync (v6.0.64)
- Removes the Conquest-dialogue timing requirement for the three exact verified 0x034 ownership fingerprints.
- Exact 0/17, Gustaberg-only 1/17, and 17/17 fingerprints now apply immediately when the 52-byte packet is received.
- Unknown partial patterns remain non-destructive and still require Conquest context for learning.
- Accepts either `e.data` or `e.data_raw`.
- Adds raw diagnostics showing the last 0x034 time, packet size, classifier, and A/B ownership bytes.


### Outpost packet-tap routing fix (v6.0.65)
- Moves live Outpost 0x034 observation onto `packets.register_tap`, the same packet dispatcher used by Detector Capture.
- This removes dependence on the id-specific packet handler path that was not producing live Outpost diagnostics.
- Adds always-visible diagnostics:
  - `Outpost packet tap: waiting for 0x034`
  - or `Outpost packet tap: 0x034 seen HH:MM:SS | size 52 | data string`
- Verified NONE, Gustaberg-only, and ALL fingerprints still auto-apply immediately.
- If a 0x034 reaches the tap without usable packet bytes, the UI now shows that explicitly.


### Outpost padded-buffer apply fix (v6.0.66)
- Fixes verified fingerprints classifying correctly but never updating ownership.
- Root cause: `consume_conquest_packet` required `#e.data == 52`, while Ashita can report `e.size = 52` with a larger padded Lua data buffer.
- The apply path now accepts any packet buffer long enough to read the verified ownership fields.
- Adds `Last ownership apply` diagnostics showing timestamp and applied owned-count.
- Gustaberg-only classification now writes directly to `c.outposts.owned.gustaberg` and persists immediately.


### Conquest / Outpost section separation (v6.0.67)
- Moves `Conquest / Outpost Details` out of the `Weekly / Conquest Tally` collapsible section.
- Conquest / Outpost Details is now its own top-level collapsible section directly below Weekly / Conquest Tally.
- Collapsing Weekly no longer hides Outpost ownership, packet diagnostics, or Capture Outpost NPC controls.
- All outpost auto-sync logic from v6.0.66 is unchanged.


### Persistent Outpost ownership schema (v6.0.68)
- Adds `c.outposts` and `c.outposts.owned` explicitly to the persistent character-state schema.
- Outpost ownership is kept outside weekly state and survives Conquest resets/reloads.
- State schema bumped to 14.
- Migration restores Gustaberg from a saved `GUSTABERG ONLY` verified endpoint if an older build lost the checkbox table.
- Verified ALL/NONE endpoint state is also restored on addon initialization.
- Adds `Saved Gustaberg ownership: YES/NO` diagnostic.


### Verified Outpost ownership ledger (v6.0.69)
- Adds a separate persistent `c.outposts.verified_owned` ledger.
- Verified packet evidence is stored independently from the UI checkbox table.
- On every load/draw, visible ownership is rebuilt from verified evidence.
- Migration reconstructs Gustaberg from any saved v6.0.61-v6.0.68 classifier, endpoint, or verified byte-pair evidence.
- Gustaberg confirmation now writes both `owned.gustaberg` and `verified_owned.gustaberg`.
- ALL fills the verified ledger; NONE clears it.
- Adds `Verified ledger: YES/NO` diagnostic beside Saved Gustaberg ownership.


### Durable Outpost persistence outside addon folder (v6.0.70)
- Stores verified Outpost ownership in `Ashita/config/HorizonCheck_outposts.lua` instead of relying only on files inside the HorizonCheck addon folder.
- This survives replacing/deleting the versioned HorizonCheck folder during updates.
- On every load, durable verified ownership is merged back into the visible Outpost checkboxes.
- Verified Conquest packet detections, manual Outpost checkbox changes, Mark All, and Clear all update the durable file.
- Adds a `Durable: YES/NO` diagnostic and displays the durable file path.


### Repeated 17/17 Outpost fingerprint refinement (v6.0.71)
- Uses the new Mabalzich 17/17 capture to refine ALL-outposts detection.
- Repeated known-complete captures show ownership field A remains `E0 FF 9F`.
- The previously-used B field changes between complete-state interactions, so it is no longer required for 17/17 classification.
- `A = E0 FF 9F` now auto-classifies the character as ALL outposts obtained and writes all 17 regions into the durable ownership ledger.
- Gustaberg-only and NONE mappings remain unchanged.


### Permanent 17/17 Conquest / Outposts completion (v6.0.72)
- Once all 17 outposts are verified, `Conquest / Outposts` becomes permanent character progression.
- Adds a durable `permanent_complete` marker outside the weekly checklist state.
- Automatic and manual weekly/conquest resets explicitly preserve the Conquest / Outposts check when 17/17 is permanent.
- The Weekly / Conquest row derives its checked state from permanent outpost completion and ignores attempts to clear it through weekly reset behavior.
- Durable Outpost storage also retains the permanent 17/17 marker across addon-folder replacements.
- Adds `Permanent 17/17 status: YES - ignores weekly reset` diagnostics.


### Conquest NPC context guard (v6.0.73)
- Fixes false `AUTO: Conquest NPC confirms no outposts obtained (0/17)` messages when talking to unrelated NPCs.
- Verified 0/17, Gustaberg-only, and 17/17 fingerprints now require an actual Conquest guard target or recent Conquest dialogue before applying.
- Recognizes Conquest guard title suffixes T.K. / I.M. / W.W.
- Random NPC 0x034 packets that resemble a verified fingerprint are rejected and cannot modify Outpost ownership.
- Adds `Rejected non-Conquest 0x034` diagnostics for troubleshooting.


### Activity confidence labels (v6.0.74)
- Replaces raw session confidence strings in Automation Monitor with normalized confidence tiers.
- `VERIFIED`: authoritative completion/reward evidence, such as explicit success/AP/reward chat.
- `CONFIRMED`: direct zone entry or matching activity context + zone transition.
- `INFERRED`: reconstructed after reload or derived from completion without a recorded start.
- `MANUAL`: state explicitly entered by the user.
- `OBSERVED`: activity seen but without enough evidence for a stronger tier.
- Each active session now shows an Evidence line and retains the original raw confidence string for diagnostics.
- Recent closed sessions use the same normalized labels.


### Highwind verified reward-pair detector (v6.0.75)
- Uses the recent captured Highwind completion as authoritative evidence.
- Arms from direct The Highwind target/combat context.
- Requires BOTH exact rewards within 5 seconds:
  - `gains 3000 experience points`
  - `obtained 3000 gil`
- Requires recent Highwind context within 120 seconds.
- HP reaching 0% is supporting evidence only and no longer independently checks the weekly row.
- Successful reward-pair detection marks Weekly Highwind complete with Activity confidence `VERIFIED`.
- Weekly Highwind displays `[VERIFIED: 3000 EXP + 3000 gil]`.


### Highwind capture cleanup (v6.0.76)
- Removes the Capture button from the Highwind weekly row.
- Highwind completion now relies on the verified automatic detector: recent Highwind combat context + 3000 EXP + 3000 gil.
- Other activity capture buttons are unchanged.


### Digging cap reconciliation + automatic rank detection (v6.0.77)
- Uses HorizonXI's authoritative `You have maxed your player digging for today!` message to reconcile the final daily count.
- Fixes the observed 189/190 Veteran case: when HorizonXI confirms the cap and only one successful item result was missed, the counter is reconciled to 190/190 and the daily checkbox completes.
- Automatically infers digging rank from the confirmed capped total when the observed count is either exactly at a known cap or one dig short.
- Known caps remain 100/110/120/.../200 for Amateur through Expert.
- Rank inference is deliberately limited to a maximum one-dig shortfall to avoid guessing from incomplete captures.
- Adds `Rank detection: ... VERIFIED BY HORIZONXI DAILY CAP` and `Counter reconciliation` diagnostics.


### Verified Outpost partial state: Gustaberg + Sarutabaruta (v6.0.78)
- Adds a verified 2/17 Conquest NPC ownership state from known character ground truth.
- `A=00 05 00 / B=14 00 00` now maps to exactly Gustaberg + Sarutabaruta obtained.
- Auto-checks both regions and writes both into the durable verified ownership ledger.
- Migration/backward repair recognizes the previously saved PARTIAL/UNKNOWN diagnostic bytes and can restore both checkboxes without requiring another capture.
- Existing NONE, Gustaberg-only, and ALL mappings remain intact.
- Partial-state help text now accurately lists the verified mappings instead of claiming all individual bits are mapped.


### Eeko-Weeko Eco-Warrior rotation auto-sync (v6.0.79)
- Adds the first two capture-verified Eeko-Weeko dialogue states.
- Verified state 1: Windurst + Bastok cleared, San d'Oria next.
- Verified state 2: Windurst cleared, San d'Oria or Bastok available this week.
- Eeko dialogue updates the Eco-Warrior rotation directly and records `VERIFIED BY EEKO-WEEKO`.
- When Eeko names two remaining nations, HorizonCheck does not guess a single active nation.
- Unknown Eeko dialogue states remain unmapped and do not alter rotation state.
- Eco-Warrior UI shows the last Eeko rotation-sync confidence and interpretation.


### Manual capture buttons: Uninvited Guests + EXP Ring (v6.0.80)
- Adds a manual Start/Stop Capture button to the Uninvited Guests weekly row.
- Adds a manual Start/Stop Capture button to the EXP Ring weekly row.
- Both profiles have no automatic timeout and continue until the same button is pressed again.
- Uninvited Guests captures can cover entry, victory/reward, or post-completion lockout interactions.
- EXP Ring captures can cover recharge/replacement interaction, charge changes, and weekly eligibility evidence.


### Verified Outpost partial state: + Qufim (v6.0.81)
- Adds the verified 3/17 ownership state: Gustaberg + Sarutabaruta + Qufim.
- `A=00 85 00 / B=50 00 00` now maps to those three exact outposts.
- Auto-checks Qufim and stores all three regions in the durable verified ownership ledger.
- Backward repair recognizes the already-saved PARTIAL/UNKNOWN evidence and can restore Qufim immediately after reload.
- Preserves the sequential evidence that adding Qufim changed field A from `00 05 00` to `00 85 00`, useful for future bitfield decoding.


### Verified Outpost partial state: + Derfland (v6.0.82)
- Adds the verified 4/17 ownership state: Gustaberg + Sarutabaruta + Qufim + Derfland.
- `A=00 87 00 / B=78 00 00` maps to those four exact outposts.
- Auto-checks Derfland and stores all four regions in the durable verified ownership ledger.
- Backward repair recognizes the already-saved PARTIAL/UNKNOWN evidence and can restore Derfland immediately after reload.


### Verified Outpost partial state: + Li'Telor (v6.0.83)
- Adds the verified 5/17 ownership state: Gustaberg + Sarutabaruta + Qufim + Derfland + Li'Telor.
- `A=00 87 01 / B=A0 00 00` maps to those five exact outposts.
- Auto-checks Li'Telor and stores all five regions in the durable verified ownership ledger.
- Backward repair recognizes the already-saved PARTIAL/UNKNOWN evidence and can restore Li'Telor immediately after reload.
- Preserves the sequential Li'Telor delta from 4/17 (`00 87 00`) to 5/17 (`00 87 01`) for future bitfield decoding.


### Conquest section load fix (v6.0.84)
- Fixes the Conquest / Outpost Details section disappearing in v6.0.83.
- Root cause was an unescaped apostrophe in the new `Li'Telor` partial-mapping help text, which caused `modules/outposts.lua` to fail parsing.
- All 5/17 Li'Telor mapping, backward repair, and durable persistence logic from v6.0.83 is retained.


### Verified Outpost partial state: + Zulkheim (v6.0.85)
- Adds the verified 6/17 ownership state: Gustaberg + Sarutabaruta + Qufim + Derfland + Li'Telor + Zulkheim.
- `A=40 87 01 / B=BE 00 00` maps to those six exact outposts.
- Auto-checks Zulkheim and stores all six regions in the durable verified ownership ledger.
- Backward repair recognizes the already-saved PARTIAL/UNKNOWN evidence and can restore Zulkheim immediately after reload.
- Preserves the sequential Zulkheim delta from 5/17 (`00 87 01`) to 6/17 (`40 87 01`) for future bitfield decoding.


### Full Regional Teleport menu capture for Outposts (v6.0.86)
- Outposts evidence captures now retain the complete payload of every sampled `0x017` packet instead of truncating it to 48 bytes.
- This specifically targets Regional Teleportation Service `_CUSTOM_MENU` packets, whose destination entries can extend beyond the original 48-byte sample window.
- Other packet IDs remain limited to 48 bytes to keep reports compact.
- Reports explicitly label Outposts captures as full-`0x017` mode.
- Intended comparison workflow: capture the teleport menu on a known partial character and a known 17/17 character, then compare the full menu payloads for destination IDs/names.


### Regional Teleport Menu ownership decoder (v6.0.87)
- Parses full `0x017 _CUSTOM_MENU` Regional Teleportation Service packets.
- Trusted ownership NPCs: Conrad (Bastok), Jeanvirgaud (San d'Oria), Rottata (Windurst).
- For trusted NPCs, the region names across all menu pages replace the ownership table directly and are saved to the durable verified ledger.
- Supports arbitrary combinations instead of only cumulative hard-coded Conquest fingerprints.
- Custom HorizonXI teleport services such as Sprinkstix are parsed for diagnostics only and never overwrite ownership.
- Existing Conquest `0x034` mappings remain as fallback/secondary verification.
- Adds `VERIFIED BY TELEPORT MENU` confidence/status diagnostics.


### Conquest UI syntax fix + functional Clear Outposts (v6.0.90)
- Fixes the Conquest / Outpost Details section disappearing in v6.0.89.
- Root cause: an extra Lua `end` was inserted immediately before the Clear Outposts helper, causing `modules/outposts.lua` to fail parsing.
- Rebased on the known-working v6.0.87 Outposts module and inserted the reset helper without the extra `end`.
- Retains the trusted Regional Teleport Menu decoder.
- Clear Outposts now removes current/durable ownership and cached repair evidence so Conrad / Jeanvirgaud / Rottata can rebuild the list from zero for testing.


### Conquest / Outposts module parser fix (v6.0.91)
- Fixes the Conquest section remaining missing in v6.0.87-v6.0.90.
- Root cause was in the Regional Teleport Menu packet handler: the `for k,v in pairs(regions) do ...` loop closed the inner `if`, but was missing the second `end` required to close the `for` loop.
- This caused Lua to fail parsing `modules/outposts.lua`, so the entire Conquest / Outpost Details module never loaded.
- Retains the Regional Teleport Menu decoder and the functional Clear Outposts test reset.
- The complete `outposts.lua` file was syntax-validated with a Lua runtime before packaging.


### Trusted Regional Teleport context fix (v6.0.92)
- Fixes Conrad being treated as a custom/untrusted teleport NPC when HorizonXI clears the live target as the custom menu opens.
- Recent trusted dialogue from Conrad, Jeanvirgaud, or Rottata is accepted for 10 seconds as authoritative menu context.
- The direct Regional Teleport ownership decoder and Clear Outposts test reset remain enabled.


### Digging rank inference fixes (v6.0.93)
- Fixes `.1` Chocobo Digging skill-up messages incorrectly resetting a high rank to Amateur.
- Skill-up parsing now reads the final value after `raising it to` (for example `99.2`) instead of the `.1` increase amount.
- Automatic skill evidence is promotion-only and can never downgrade a stronger current rank.
- Automatically promotes a stale digging rank whenever successful digs exceed that rank's daily cap.
- Promotion selects the first rank whose cap can contain the observed count:
  - 101-110 -> Recruit
  - 111-120 -> Initiate
  - 121-130 -> Novice
  - continuing through Expert.
- Rank promotion occurs before daily completion is calculated, preventing impossible states such as `115/100 Amateur`.
- Manual `+1` testing uses the same rank reconciliation logic.


### Guild Points daily verification improvements (v6.0.94)
- Adds the capture-verified HorizonXI Guild Union lockout detector:
  `You are not eligible to receive guild points at this time.`
- That line now marks today's Guild Points row complete as `VERIFIED BY GUILD NPC`, even if HorizonCheck missed the original GP reward message.
- Positive `Obtained: #### guild points.` rewards continue to mark the daily row and now record `VERIFIED BY GP REWARD`.
- Existing authoritative NPC balance parsing remains intact (`You have #### guild points accumulated.`).
- Existing requested-item parsing and confirmed GP purchase subtraction remain intact.
- Guild Points UI now shows the daily completion confidence and verifying NPC when available.


### Guild Union auto-detection + daily eligibility state (v6.0.95)
- Automatically identifies the current Guild Points guild from the Guildworker Union NPC:
  - Fennella -> Fishing
  - Andreas -> Woodworking
  - Lorena / Macuillie -> Smithing
  - Ellard -> Goldsmithing
  - Hauh Colphioh -> Clothcraft
  - Alivatand -> Leathercraft
  - Samigo-Pormigo -> Bonecraft
  - Hemewmew -> Alchemy
  - Qhum Knaidjn -> Cooking
- `Guild: UNKNOWN` now updates as soon as recognized Union NPC dialogue is seen.
- Adds capture-verified daily AVAILABLE state from:
  `You can still receive up to #### guild points...`
- AVAILABLE explicitly unchecks today's Guild Points daily row and records remaining GP.
- COMPLETE remains verified from either the positive GP reward or the NPC no-longer-eligible message.


### Guild Points collapsed-line requested item (v6.0.96)
- Adds the currently detected Guild Points requested item directly to the main/collapsed Guild Points status line.
- Example: `Guild: Woodworking | GP: 2184 | Requested: Chest | AUTO TEXT`
- The requested item remains visible in the expanded Guild Points details as well.
- Guild NPC auto-detection and daily AVAILABLE/COMPLETE verification from v6.0.95 are retained.


### Guild auto-detection runtime fix (v6.0.97)
- Fixes `Guild: UNKNOWN` remaining after talking to a recognized Guildworker Union NPC.
- Root cause: `normalize_npc_name()` called the local `trim()` helper before `trim()` was declared, causing guild identification to error while balance/requested-item parsing continued.
- NPC normalization is now self-contained and safe at its declaration point.
- Adds a fallback known-NPC search for HorizonXI/Ashita text wrappers that obscure the speaker prefix.
- Andreas -> Woodworking and the existing Guild Union mappings are retained.
- Requested item remains on the collapsed Guild Points line.


### Full-menu trusted Outpost scan fix (v6.0.98)
- Fixes 17/17 characters such as Admiral failing to auto-check after paging through Rottata's full teleport menu.
- Root cause: trusted NPC dialogue context expired after 10 seconds, while the captured 17/17 menu took ~15 seconds to reach the terminal `Go Back` page.
- Once a scan begins from Conrad, Jeanvirgaud, or Rottata, the trusted NPC identity now remains locked for the entire menu session.
- Recent trusted dialogue fallback is also extended to 20 seconds for initial-page robustness.
- Adds menu page-count diagnostics for future troubleshooting.


### Tavnazian Archipelago outpost alias fix (v6.0.99)
- Fixes the 17/17 Regional Teleport scan leaving Tavnazian Archipelago unchecked.
- The teleport menu says `Tavnazia`, while HorizonCheck's checkbox key is `tavnazian`.
- The menu alias now maps `Tavnazia -> tavnazian`, allowing the full 17/17 set to apply correctly.


### Guild Points PARTIAL daily state (v6.1.00)
- Distinguishes `AVAILABLE` from `PARTIAL`.
- `AVAILABLE`: the Guild Union NPC says more GP can still be earned, but no GP reward has been observed in the current cycle.
- `PARTIAL`: HorizonCheck has already observed a positive `Obtained: #### guild points.` reward and the NPC subsequently reports additional GP remaining.
- Exact remaining GP is retained from the authoritative NPC dialogue.
- Example from Admiral's Cooking capture:
  - reward observed: +2595 GP
  - NPC balance: 3087 GP
  - NPC says 1405 GP remains
  - status becomes `PARTIAL | 1405 GP remaining | VERIFIED BY GUILD NPC`


### Guild Points collapsed remaining GP + capture button removal (v6.1.01)
- Adds daily remaining GP directly to the collapsed/main Guild Points line.
- `AVAILABLE` / `PARTIAL` show the NPC-reported remaining GP.
- `COMPLETE` shows `Remaining: 0 GP`.
- Removes the Guild Points detector capture button now that the core GP states are verified.
- Existing guild auto-detection, requested item, balance, PARTIAL/AVAILABLE/COMPLETE logic remain intact.


### Guild Points capture button removal correction (v6.1.02)
- Removes the Guild Points evidence Capture button from the Daily / Regular row.
- v6.1.01 added remaining GP to the collapsed status line but the button itself was generated by `weekly.lua`, not `guild.lua`.
- Guild capture profile is now disabled while Assault/Tag capture buttons remain available.


### ISNM row location + manual capture (v6.1.03)
- Updates the ISNM Order / Run row to show:
  `Shajaf - Aht Urhgan Whitegate (F-8)`
- Adds an ISNM Capture button directly on the same Daily / Regular row.
- ISNM capture is manual-start/manual-stop with no automatic timeout.
- Intended evidence: Shajaf order purchase, order eligibility/lockout dialogue, battlefield entry, and completion/run evidence.


### Guild Points daily progress tracking (v6.1.04)
- Tracks cumulative GP earned from confirmed requested-item turn-ins.
- Derives the daily maximum from `earned + NPC-reported remaining`.
- Shows PARTIAL progress on the collapsed line, e.g.:
  `Cooking | GP: 3087 | Requested: dhalmel stew | PARTIAL 2595/4000 GP (64.9%)`
- AVAILABLE shows the exact NPC-reported remaining GP.
- COMPLETE shows the known earned/max total when available.
- Expanded Guild Points details now show earned, maximum, remaining, percentage, and a progress bar.
- Compact requested-item display removes common leading phrases such as `a bowl of` while preserving the exact NPC wording in expanded details.
- If the requested item changes, per-assignment progress is reset so old earned/remaining values are not carried into the new GP assignment.


### ISNM Secret Imperial Order detector (v6.1.05)
- Adds a dedicated ISNM/Shajaf detector.
- Capture-verified automatic order-held evidence:
  - `Obtained key item: secret imperial order.`
  - Shajaf: `Hey, hey... What are you doing, running off from a job? Get back out there!`
- Automatically checks the ISNM Order / Run daily row when Secret Imperial Order possession is verified.
- Shows `Secret Imperial Order | ORDER HELD` directly on the ISNM row.
- Parses Shajaf's spoken Imperial Standing balance for diagnostics/status.
- Records the earlier `Here, you'll need this secret imperial order.` handoff as supportive evidence.
- Keeps the manual ISNM Capture button for battlefield-entry and completion captures.


### Conquest / Outpost Details cleanup (v6.1.06)
- Removes legacy packet/classifier/debug text from the normal Conquest panel.
- Removes obsolete buttons:
  - Capture Outpost NPC
  - Mark All Obtained
  - Clear Outposts
- Keeps per-region ownership checkboxes as a manual fallback.
- Normal panel now focuses on:
  - obtained count / all-outposts status
  - missing regions
  - verification source
  - permanent 17/17 status
  - last trusted teleport NPC verification
  - region checklist
- Manual checkbox changes clear stale permanent/teleport verification when appropriate.


### Conquest update instructions (v6.1.07)
- Adds an inline instruction to the Conquest / Outposts row:
  `Update: talk to Conrad (Bastok), Jeanvirgaud (San d'Oria), or Rottata (Windurst) and page through the Regional Teleport menu.`
- This tells players exactly how to trigger HorizonCheck's automatic outpost ownership refresh.


### Chocobo Digging Gysahl Greens inventory count (v6.1.08)
- Adds the live number of Gysahl Greens remaining in the character's main Inventory directly to the Digging row.
- Uses HorizonXI/FFXI item ID 4545 (`bunch_of_gysahl_greens`).
- Main-row example:
  `190/190 successful digs - 0 remaining - Veteran rank - 47 Gysahl Greens`
- Expanded Digging details also show `Gysahl Greens in Inventory: ##`.
- The value is read live from Ashita's inventory manager, so it updates as greens are consumed.


### Dynamis 3.5-hour run-window counting fix (v6.1.09)
- Fixes leaving and re-entering Dynamis incorrectly consuming the second weekly opportunity.
- The first verified Dynamis entry starts a persistent 3.5-hour run window.
- Any Dynamis re-entry during that same 3.5-hour window is detected but does not increment the 1/2 -> 2/2 weekly counter.
- The first eligible Dynamis entry after the 3.5-hour window expires can increment the next weekly opportunity.
- The run-window state survives addon reloads/character state saves.
- A new Conquest tally clears the stored Dynamis run window.
- Dynamis timing is used only internally to prevent duplicate weekly counting; no run countdown is shown in the UI.


### Account-wide Dynamis 3-lockout tracking (v6.1.10)
- Changes Dynamis from 2 per character to 3 per Conquest tally shared account-wide.
- All characters using the same HorizonCheck state file read/write the same shared Dynamis count.
- Entering Dynamis on any character increments the shared `0/3 -> 3/3` total.
- Switching characters shows the same shared total immediately.
- Re-entry within the same 3.5-hour run window still does not count again.
- The shared run-window timestamp also spans characters, preventing character swaps/re-entry from falsely consuming another lockout.
- Manual `+ Run` / `Undo` controls now modify the shared account-wide Dynamis total.
- New Conquest tally resets the shared Dynamis count and run window.


### Dynamis account-wide 3 / per-character 2 limits (v6.1.11)
- Keeps 3 Dynamis lockouts shared account-wide per Conquest tally.
- Adds a separate maximum of 2 lockouts per character.
- A character at 2/2 cannot increment the account-wide total again.
- The third shared lockout must be consumed by another character that is below 2/2.
- Same-run re-entry inside the 3.5-hour window still does not count again.
- UI shows `Account X/3 | Character Y/2`.
- Manual +Run / Undo respects both limits.


### Chocobo Riding Game nation-aware capture update (v6.1.12)
- The Riding Game row selects Bastok, San d'Oria, or Windurst automatically from the current stable zone.
- Corrects the capture-verified Vana'diel phase seen on 2026-08-19:
  - San d'Oria: Emoussine -> Windurst Woods
  - Windurst: Sariale -> Southern San d'Oria
- Adds route-level `VERIFIED` / `PREDICTED` labeling instead of treating an entire city as verified from one phase.
- Bastok routes remain capture verified from prior evidence.
- San d'Oria/Windurst phases not yet directly captured remain predicted, so the Chocobo capture button is retained.


### Chocobo Riding Game full route verification (v6.1.13)
- All three San d'Oria NPC/destination rotations are now capture verified:
  - Camereine -> Bastok Mines
  - Emoussine -> Windurst Woods
  - Meuneille -> Upper Jeuno
- All three Windurst NPC/destination rotations are now capture verified:
  - Amimi -> Bastok Mines
  - Sariale -> Southern San d'Oria
  - Orlaine -> Port Jeuno
- Keeps the Chocobo capture button intentionally so a complete accepted ride through completion/reward can be captured next.
- Existing cutoff/reward metadata is unchanged; this verification specifically covers the captured NPC/destination rotation.


### Chocobo Riding Game full-run automation (v6.1.14)
- Adds capture-verified automatic ride state tracking.
- Acceptance detector:
  `Oh, thank you so very much! You shall be rewarded by our associates upon delivery of the chocobo.`
  -> status becomes `IN PROGRESS`.
- Destination confirmation:
  `You've helped our poor girl find her way home!`
  -> status becomes `ARRIVED - REWARD PENDING`.
- Final completion requires the recent destination confirmation plus:
  `Obtained: page from the Dragon Chronicles.`
  -> automatically checks both the weekly Chocobo Riding Game and Dragon Chronicles Chocobo source.
- Reward context is intentionally required so an unrelated Dragon Chronicles reward cannot falsely complete the ride.
- Chocobo Capture button is retained for live validation.


### Chocobo Riding Game completion/reward separation (v6.1.15)
- Successful destination delivery now marks the weekly Riding Game COMPLETE immediately.
- No particular reward item is required for completion.
- Reward items are recorded separately as informational run results.
- Low-tier rewards such as Chocobo Ticket no longer leave a successful run incomplete.
- Captures the Earth-time completion result from destination NPC dialogue.
- Status can show `COMPLETE | VERIFIED BY DELIVERY | Last: 28:54 | Reward: chocobo ticket`.
- Dragon Chronicles source completion is checked only when the actual reward is a Dragon Chronicles page.
- Chocobo Capture button remains for additional validation.


### Chocobo Riding Game progress wording + reward guide (v6.1.16)
- Main row now uses progress states: READY -> IN PROGRESS -> COMPLETE.
- READY shows the current NPC -> destination and target time.
- IN PROGRESS explains that the lost chocobo has been accepted and must be delivered.
- COMPLETE shows the recorded Earth-time result and reward when available.
- Expanded section lists known reward categories:
  - Page from the Dragon Chronicles
  - Page from Miratete's Memoirs
  - Chocobo Ticket
  - Gysahl Greens
  - Other lower-tier route/time-dependent rewards
- Successful delivery, not the reward item, determines weekly completion.
- Recovers legacy stuck IN PROGRESS state when a captured destination completion time already exists.
- Unconfirmed active ride state expires after 90 minutes so it cannot remain stuck forever.
- Chocobo Capture button remains available.


### Chocobo Riding Game Run Tracker v2 (v6.1.17)
- Adds a live Earth-time elapsed timer while a Riding Game is IN PROGRESS.
- Stores persistent personal best times independently for each NPC -> destination route.
- READY and IN PROGRESS status show the route PB when known.
- Stores up to 20 recent completed rides with route, time, reward, and completion timestamp.
- Stores up to 12 route-specific time -> reward observations for automatic reward-table learning.
- Displays the latest five run-history entries and latest observations for the current route.
- Fixes completion-time parsing when the destination NPC says the successful-delivery line before the Earth-time result.
- Reward observations update the just-completed history entry and route record.
- Unknown reward thresholds are not inferred automatically; observed results are kept as evidence for future refinement.
- Weekly completion resets remain separate from permanent route PB/history data.


### Chocobo Riding Game any-reward source completion (v6.1.18)
- The Dragon/Reward-source Chocobo Riding Game checkbox now auto-checks when any verified post-delivery Riding Game reward is received.
- Supported examples include Dragon Chronicles, Miratete's Memoirs, Chocobo Ticket, Gysahl Greens, and other captured route/time rewards.
- Exact reward text and captured run time are stored with the reward-source state.
- The row displays `[Reward: <item> | Time: mm:ss]` when available.
- Weekly Riding Game completion still comes from verified successful delivery, independent of reward tier.


### Secrets of Ovens Lost progress tracker (v6.1.19)
- Adds capture-verified progress states:
  READY -> IN PROGRESS -> COOKBOOK OBTAINED -> TURNING IN -> COMPLETE.
- Jonette's weekly request dialogue starts IN PROGRESS.
- `Obtained key item: Tavnazian Cookbook` advances to COOKBOOK OBTAINED.
- Jonette recognizing the Tavnazian Cookbook advances to TURNING IN.
- Repeatable completion requires Miratete's Memoirs within the recent Jonette cookbook turn-in context.
- The HorizonXI `Achievement Unlocked: Complete 'Secrets of Ovens Lost'` line is recorded only as optional evidence and is never required for weekly completion because it is one-time.
- The Weekly EXP Scrolls row shows live Secrets of Ovens Lost progress.


### Secrets of Ovens Lost post-completion reconciliation (v6.1.20)
- Adds capture-verified post-completion recovery from Jonette dialogue.
- Requires BOTH:
  - `I feel sorry for the children all cooped up here in the safehold...`
  - `there are three troublemakers who have taken it upon themselves to ignore this rule.`
- Both lines must occur within 10 seconds; one line alone cannot mark the weekly source complete.
- When this verified sequence is seen, Secrets of Ovens Lost and its Miratete source are reconciled to COMPLETE.
- Useful after addon reload/login when the weekly quest was already completed before HorizonCheck witnessed the reward.
- Existing live progression remains:
  READY -> IN PROGRESS -> COOKBOOK OBTAINED -> TURNING IN -> COMPLETE.
- The one-time achievement message remains non-authoritative.


### Secrets of Ovens Lost UI cleanup (v6.1.21)
- Removes the Capture button from the Secrets of Ovens Lost row.
- Keeps all automatic progression and post-completion Jonette verification logic.
- Simplifies the expanded panel to:
  - current status
  - Jonette location
  - next objective
  - completion/reward
- Removes detector-evidence/debug wording from the normal UI.
- Shortens the row note while retaining the login/reload verification reminder.


### Secrets of Ovens Lost single-line UI (v6.1.22)
- Removes the expanded Secrets of Ovens Lost section from EXP Scroll Sources.
- Keeps the Capture button removed.
- Consolidates all useful status onto the main row:
  - READY | Jonette (G-9) | Talk to Jonette
  - IN PROGRESS | Obtain Tavnazian Cookbook
  - COOKBOOK OBTAINED | Return to Jonette
  - TURNING IN | Finish Jonette dialogue
  - COMPLETE | VERIFIED BY JONETTE | Reward: Miratete's Memoirs
- All automatic detection and post-completion Jonette verification remain unchanged.

### Guild Points daily reset fix (v6.1.23)
- Clears yesterday's requested Guild Point item when the daily key changes.
- Clears stale COMPLETE/PARTIAL/AVAILABLE status, remaining GP, earned/max daily progress, verification metadata, and the daily checklist flag.
- Preserves the detected guild and current accumulated GP balance.
- The new day starts with no requested item or completion state until fresh Guild Union NPC dialogue is observed.


### Digging / Guild / Uninvited / Monarch Linn update (v6.1.24)
- Chocobo Digging:
  - tracks attempts, successful finds, misses, success rate, and per-session item counts;
  - shows up to four most common session finds;
  - authoritative HorizonXI daily-cap message changes the row to CAPPED and freezes further dig-result counters.
- Guild Points:
  - compact row format: Guild | GP | Requested Item | Daily Status;
  - removes AUTO TEXT and stale-age clutter from the normal row while retaining it internally.
- Uninvited Guests:
  - Justinius offer dialogue -> OFFERED;
  - accepted/permit dialogue -> PERMIT READY;
  - existing completion/lockout logic remains authoritative.
- Monarch Linn ENM:
  - Morangeart's capture-verified already-have-artifact dialogue -> KEY ITEM READY.


### Digging UI cleanup (v6.1.25)
- Removes miss counts, attempt counts, and success percentage from the visible Digging UI.
- Removes `- Rank`, `+ Rank`, `-1`, and `+1` buttons.
- Keeps automatic rank detection and successful-dig counting.
- Keeps HorizonXI daily-cap verification.
- Keeps Gysahl Greens inventory count.
- Keeps compact session-find summaries.
- Simplifies the Digging row to:
  `CAPPED | 190/190 successful | Veteran rank | 57 Gysahl Greens | AUTO`


### Digging single-line cleanup (v6.1.26)
- Removes `AUTO` from the visible Digging row.
- Removes redundant daily-cap confirmation and rank-verification detail lines.
- Automatic cap detection and automatic rank verification remain active internally.
- Gysahl Greens now read naturally as `57 Gysahl Greens remain`.
- Session finds remain available when the current session has recorded items.


### Black Coffin weekly chain correction (v6.1.27)
- Replaces the incorrect 3-week rotation model.
- All three Ashu Talif battlefields may be completed in the same week.
- Progress is account-wide and shared by all characters.
- Weekly order is:
  1. Scouting the Ashu Talif
  2. Royal Painter Escort
  3. Targeting the Captain
- Every weekly reset returns progress to 0/3 and requires Scouting first.
- A tag carried over from the prior week is kept conceptually separate from current-week progress; using an old tag does not advance the new weekly chain.
- A failed battlefield sets FAILED / LOCKED OUT account-wide for the remainder of the week.
- Manual Complete / Fail controls are provided until capture-verified battlefield success/failure detectors are available.


### Chocobo Riding Game post-completion reconciliation (v6.1.28)
- Adds capture-verified weekly recovery after addon reload/login.
- Tracks the ordinary 100-gil rental dialogue from:
  - Camereine
  - Emoussine
  - Meuneille
- Requires all three named NPCs during the same weekly key before marking the Riding Game COMPLETE.
- One or two NPCs alone cannot trigger completion.
- After all three are verified, both the weekly Riding Game and its reward-source checkbox are reconciled complete.
- If the historical reward was not observed, the reward-source record is stored as `Previously completed - reward not observed` rather than inventing an item.
- Status shows `COMPLETE | VERIFIED BY 3 STABLE NPCS`.


### Guild Points UI cleanup (v6.1.29)
- Removes the redundant red daily GP ProgressBar from Status Details.
- Keeps the text-only `Daily GP progress` line with earned, maximum, remaining, and percentage.
- No Guild Points detection, balance, requested-item, completion, or daily-reset logic changed.


### ENM key-item display and Promyvion censer detection (v6.1.30)
- ENM rows now always display the associated entry key item:
  - Promyvion - Dem | Censer of Antipathy
  - Promyvion - Holla | Censer of Abandonment
  - Promyvion - Mea | Censer of Animus
  - Promyvion - Vahzl | Censer of Acrimony
  - Monarch Linn | Monarch Beard
- Capture-verified Venessa dialogue sets Dem/Holla/Mea to KEY ITEM READY.
- Vahzl selection is detected separately; Venessa's `no more censers` response is shown as `NO MORE CENSERS` rather than falsely claiming a new censer was issued.
- Existing Morangeart detection now renders `Monarch Linn | Monarch Beard | KEY ITEM READY`.
- Battlefield completion/cooldown tracking remains separate from access-item dialogue.


### ENM aligned columns + Vahzl cooldown correction (v6.1.31)
- ENM rows now use fixed-width columns:
  `Location | Key Item | Status | Action`
- Location names, key-item names, statuses, and KI/Reset buttons line up vertically for easier scanning.
- Vahzl now remains `KEY ITEM READY` when Censer of Acrimony is already held.
- Venessa's `no more censers` dialogue is stored separately as `NEXT KI COOLDOWN` rather than replacing current key-item readiness.
- Vahzl can therefore display:
  `Promyvion - Vahzl | Censer of Acrimony | KEY ITEM READY / NEXT KI COOLDOWN`
- Existing Dem/Holla/Mea and Monarch Linn key-item verification remains unchanged.


### Assault Tags account-wide Rytaal pool fix (v6.1.32)
- Moves Rytaal/total Assault Tag pool and regeneration timer into persistent account-wide state.
- Keeps the carried Imperial Army I.D. Tag character-specific.
- Switching characters now shows the same Rytaal stored-tag count and regeneration timer across the account.
- Talking to Rytaal on any character updates the shared account pool.
- Receiving/using a carried tag only changes that character's carried split while the account total remains shared.
- Includes one-time migration from the first existing v6.1.31 character state with known Assault Tag data.


### Assault Tag shared-state migration fix (v6.1.33)
- Fixes v6.1.32 migration when the first character loaded had no Assault Tag data.
- Searches all saved character states for a known Rytaal/total tag pool.
- Uses the most recently reconciled known character state to seed the persistent account pool.
- Does not mark migration complete when no known data exists.
- Saves the shared pool immediately once valid tag data is found.
- Runs migration again during Assault module initialization after reload.
- If no historical data exists at all, talking to Rytaal once on any character seeds the shared account pool for every character.


### Rytaal authoritative `(N left)` synchronization (v6.1.34)
- Parses Rytaal's visible menu text such as `Imperial Army I.D. tag. (2 left)`.
- Treats that number as authoritative for the account-wide stored-tag pool.
- Example: carried 1 + Rytaal `(2 left)` = Character 1 | Rytaal 2/3 | Total 3/4.
- Direct Rytaal menu evidence overrides stale regeneration/cap estimates.
- Prevents the legacy missed-regeneration repair from adding another tag after an authoritative menu observation.
- Timer estimation is retained only for future regeneration between direct Rytaal observations.


### Rytaal 0x034 stored-tag decoder (v6.1.35)
- Promotes the previously learned Rytaal 0x034 packet field to authoritative decoding.
- Byte offset 0x0C is the number of tags stored at Rytaal (0-3), not the total including a carried tag.
- Total = Rytaal stored count + this character's carried tag.
- Example: byte 0x0C = 2 and Character = 1 -> Rytaal 2/3 | Total 3/4.
- Direct Rytaal packet evidence now overrides stale regeneration/cap estimates immediately.
- Removes the old reconcile-first behavior that could add a phantom tag before the menu was processed.


### Spice Gals initial progress tracking (v6.1.36)
- Adds `READY | Talk to Rouva (L-6)` as the default weekly state.
- Capture-verified Rouva Rivernewort request dialogue advances to `IN PROGRESS | Obtain Rivernewort`.
- Existing verified Miratete reward state reconciles the row to COMPLETE.
- The Capture button remains available because Rivernewort acquisition and full turn-in/completion still need capture verification.
- No guessed `RIVERNEWORT OBTAINED` or `TURNING IN` detector has been added yet.


### Spice Gals post-pickup recovery (v6.1.37)
- Adds capture-verified IN PROGRESS recovery after addon reload/login.
- Requires BOTH Rouva generic lines within 10 seconds:
  - `my lady is concerned about San d'Oria's future... bound to ceremony`
  - `the convergence of old and new has always been part of who we are...`
- One line alone cannot mark the quest in progress.
- Verified state displays:
  `IN PROGRESS | VERIFIED BY ROUVA | Obtain Rivernewort`
- Existing request-dialogue pickup detection remains unchanged.
- Capture button remains available for Rivernewort acquisition and completion evidence.


### San d'Oria Eco-War progress tracking (v6.1.38)
- Adds READY state: `READY | Talk to Norejaie`.
- Capture-verified acceptance dialogue advances to:
  `IN PROGRESS | Go to Ordelle's Caves`.
- Capture-verified post-pickup Norejaie dialogue restores after reload/login:
  `IN PROGRESS | VERIFIED BY NOREJAIE | Talk to Rojaireaut in Ordelle's Caves`.
- Existing Eco-War completion logic marks the San d'Oria activity COMPLETE when the active nation is San d'Oria.
- The San d'Oria status is shown both in the Eco-War panel and on the Dragon Chronicles / EXP Scroll source row.
- Capture controls remain available for Rojaireaut, battle/proof, and final Norejaie turn-in evidence.


### Assault carried-tag character isolation (v6.1.39)
- Rytaal stored count and regeneration timer remain account-wide.
- Carried Imperial Army I.D. Tag ownership is strictly per-character.
- A character whose carried state has not been verified now shows `Character ?`; HorizonCheck never assumes `1`.
- Direct `cannot issue ... while you have one in your possession` dialogue verifies carried=1 for that character.
- Obtaining a tag still verifies carried=1; Assault Order use still sets carried=0.
- Direct Rytaal packet count is stored independently from character carried ownership.


### Moritz ENM synchronization - phase 1 (v6.1.40)
- Adds exact Moritz Earth-time timer parsing.
- Adds capture-mapped Moritz selections for:
  - Spire of Holla / Promyvion - Holla
  - Spire of Dem / Promyvion - Dem
  - Spire of Mea / Promyvion - Mea
- Uses isolated capture 0x05C signatures:
  - Holla: 0x91
  - Dem: 0x96
  - Mea: 0x9B
- Moritz locked response updates the selected ENM to the exact reported Earth-time ready timestamp.
- Moritz ready response marks the selected mapped ENM `AVAILABLE | VERIFIED BY MORITZ`.
- Monarch Linn, Shrouded Maw, Mine Shaft #2716, Bearclaw Pinnacle, and Boneyard Gully ready captures are retained as evidence, but are not auto-assigned until a unique selection signature is verified.
- Unmapped Moritz responses are stored as observations and never guessed.


### Bastok Eco-War completion verification (v6.1.41)
- Adds capture-verified Raifa completion detection for Bastok Eco-War.
- Requires Raifa + Indigested Ore + committed-to-our-cause + reward-as-promised dialogue.
- Marks Bastok complete in the Eco-War rotation and marks the Dragon Chronicles Eco-War weekly source complete.
- Bastok row displays `COMPLETE | VERIFIED BY RAIFA`.
- The one-time HorizonXI `Achievement Unlocked` message is not required for repeatable weekly completion.


### Bastok Eco-War post-completion recovery (v6.1.42)
- Adds capture-verified Raifa post-completion recovery after addon reload/login.
- Requires Raifa + exact baked-popoto dialogue:
  `I can't believe there are people who throw away the skins of baked popotoes! They're so tasty and so good for you!`
- Reconciles Bastok as complete in the Eco-War rotation.
- Reconciles the Dragon Chronicles Eco-War weekly source complete.
- Row shows `COMPLETE | VERIFIED BY RAIFA POST-COMPLETION` when recovered this way.
- Original Indigested Ore turn-in remains the primary Bastok completion detector.


### Raifa post-completion chat debounce (v6.1.43)
- Prevents duplicate Bastok Eco-War completion messages when Ashita surfaces the same Raifa line multiple times.
- Duplicate baked-popoto lines within 3 seconds are ignored.
- Repeated later conversations still refresh verification state silently.
- Chat notification is only emitted when Bastok completion is newly recovered or corrected.
- Eco-War completion/recovery logic itself is unchanged.


### Raifa post-completion notification balance (v6.1.44)
- Keeps the 3-second duplicate-dialogue debounce from v6.1.43.
- Restores one AUTO verification message per actual Raifa interaction.
- Persistent already-verified state no longer suppresses the message entirely after reload.
- Result: one notification per conversation, not zero and not three-plus duplicates.


### Moritz ENM synchronization safety correction (v6.1.45)
- New timed Boneyard capture proved the changing 0x05C bytes previously used for Holla/Dem/Mea are timer-related data, not stable ENM-selection IDs.
- Removes the unsafe automatic Holla/Dem/Mea 0x05C signature assignment.
- Never guesses which ENM Moritz was asked about.
- Adds a `Moritz` button beside every ENM row:
  1. Click `Moritz` on the desired HorizonCheck row.
  2. Select that same ENM at Moritz within 20 seconds.
  3. Moritz's response updates that exact row.
- Exact Earth-time LOCKED responses are parsed and applied authoritatively.
- `sufficiently manifest` responses mark the armed ENM AVAILABLE.
- This works for Boneyard Gully and every existing ENM row.
- Adds a 3-second Moritz response debounce so duplicate Ashita text deliveries do not process the result repeatedly.
- 0x05C timer bytes are retained only as diagnostic evidence.


### Reliability + dashboard cleanup (v6.1.46)
- Upcoming now lists ALL locked ENMs sorted by soonest ready time, not only the first timer.
- Upcoming ENMs explicitly show `VERIFIED` for Moritz-synced timers or `ESTIMATED` for calculated timers.
- Assault Tags always render in Attention, including unresolved character ownership:
  `Character ? | Rytaal 2/3 | Total ?/4 | PARTIAL/ESTIMATED`.
- ENM rows use clearer status wording:
  `LOCKED ... | MORITZ VERIFIED`, `LOCKED ... | ESTIMATED`, or `AVAILABLE | MORITZ VERIFIED`.
- Moritz verification shows a compact age (`12m ago`, `2h ago`, etc.).
- Armed Moritz rows temporarily show `WAITING FOR MORITZ Ns` instead of an ambiguous button.
- Adds a global exact-message 2-second duplicate guard for HorizonCheck AUTO notifications.
- No new gameplay detector guesses were added.


### Digging rank safety + compact UI (v6.1.47)
- Successful-dig counters no longer auto-promote digging rank.
- Daily-cap/fatigue confirmation no longer infers rank from the observed count.
- Digging skill-up values no longer infer rank.
- Only explicit digging-rank text or manual rank selection changes rank.
- Rank changes persist as `verified_rank` going forward.
- Removed `Session finds` from the Digging UI.


### Digging stale Expert-state migration (v6.1.48)
- Rolls back Expert/200 only when older HorizonCheck state explicitly says that Expert was inferred from count/skill/daily-cap logic.
- Such stale inferred Expert state migrates to Veteran/190.
- Manual or explicitly verified Expert is preserved.
- `verified_rank` now controls the displayed digging cap when present.


### Digging unverified Expert rollback (v6.1.49)
- Fixes old Expert/200 state that survived after inference metadata was cleared by a reset.
- A saved Expert rank is now trusted only when `verified_rank` explicitly says Expert.
- Unverified legacy Expert migrates to Veteran/190.
- Explicitly verified Expert remains Expert/200.
- The displayed daily cap always prefers `verified_rank`.


### HAAP UI cleanup (v6.1.50)
- Removes the Capture button from `HAAP Weekly Scrolls`.
- Removes Capture buttons from the HAAP Dragon Chronicles and Miratete's Memoirs source rows.
- HAAP automatic point sync, reward detection, weekly scroll tracking, and status display are unchanged.
- The underlying HAAP learning/capture profile remains available internally for diagnostics if needed later.


### HAAP capture fallback fix (v6.1.51)
- Fixes HAAP Dragon Chronicles and Miratete rows falling through to the generic `dragon` capture profile.
- `dc_haap` and `mm_haap` now explicitly return no capture profile.
- HAAP Capture buttons are fully removed from those rows.


### Tabbed main UI experiment (v6.1.52)
- Attention remains permanently visible above the workspace.
- Main content is organized into tabs:
  Daily | Weekly | Dragon / EXP | ENM | Assault | Eco-War | Settings | Diagnostics.
- Weekly contains Conquest/Outposts, Black Coffin, and Chocobo Riding Game details.
- Assault contains Assault Tags and Assault Mission Progress.
- Settings contains Guild Points and HAAP details.
- Existing detector/state logic is unchanged.
- Includes a stacked-layout fallback if the local Ashita ImGui build lacks tab APIs.


### Dedicated Black Coffin + Chocobo tabs (v6.1.53)
- Removes the expanded Black Coffin Rotation panel from the Weekly tab.
- Removes the expanded Chocobo Riding Game panel from the Weekly tab.
- Adds a dedicated `Black Coffin` tab.
- Adds a dedicated `Chocobo Riding` tab.
- Weekly remains focused on the checklist plus Conquest / Outpost details.
- Tracking logic is unchanged.


### Missions tab (v6.1.54)
- Adds a dedicated `Missions` tab.
- Adds per-character manual checkboxes for:
  San d'Oria, Bastok, Windurst, Rise of the Zilart, Chains of Promathia, and Treasures of Aht Urhgan.
- Nation missions use mission-number checkboxes.
- Zilart and ToAU use numbered progression checkboxes.
- CoP is initially grouped by chapter to keep the first version compact.
- Mission checklist state persists per character through HorizonCheck state.
- This first pass is manual only; no mission auto-detection is added.


### Full mission-name table UI (v6.1.55)
- Replaces placeholder mission numbers with real mission names for:
  San d'Oria, Bastok, Windurst, Rise of the Zilart, Chains of Promathia, and Treasures of Aht Urhgan.
- Table layout mirrors a mission guide:
  Done | Rank/Chapter | Number | Mission Name | Type | Reward / Info.
- Each mission has an independent per-character checkbox.
- Each storyline header shows completed/total count.
- Uses ImGui tables when available, with a fixed-width fallback for older Ashita builds.
- Mission tracking remains manual; no mission auto-detection is introduced.


### Per-mission Assault capture buttons (v6.1.56)
- Adds a manual `Capture` button beside every standard Assault mission row.
- Uses the existing full-run `assault` capture profile.
- Capture IDs are mission-specific so evidence files can be tied back to the selected mission.
- Works for both completed and incomplete mission rows.
- Does not change Assault completion or acceptance detection logic.


### Mission Sync phase 1 (v6.1.57)
- Adds a `Mission Sync` button to the Missions tab.
- Reads the current character's authoritative Ashita player Nation and Rank.
- Safely auto-checks only nation mission gates that must have been completed to reach that rank.
- Does NOT auto-check optional/repeatable nation missions.
- Does NOT guess Rise of the Zilart, Chains of Promathia, or Treasures of Aht Urhgan history.
- Records checkbox source metadata (`PLAYER NATION RANK ...` or `MANUAL`).
- Hovering a checked mission checkbox shows its recorded source when available.
- Shows current nation/rank and a summary of the last sync.


### Mission Sync UI crash fix (v6.1.58)
- Fixes the v6.1.57 main-window runtime regression.
- Removes player nation/rank memory reads from the per-frame Missions render path.
- Nation/rank is now queried only when `Mission Sync` is clicked.
- Hardens the player-memory lookup with guarded alternate method names.
- Wraps Mission Sync execution so a sync API mismatch reports in chat instead of hiding the HorizonCheck window.
- Removes the new per-checkbox hover/source call from the hot render path.
- Mission tables and all existing tracking remain intact.


### Immediate Rytaal pickup reconciliation (v6.1.59)
- Fixes Rytaal stored-tag count remaining unchanged after obtaining a new Imperial Army I.D. tag.
- `Obtained key item: Imperial Army I.D. tag.` now immediately moves one tag from the cached Rytaal pool to the current character.
- Total account tags remain unchanged, as pickup transfers an existing tag rather than consuming one.
- Updates the cached Rytaal count immediately; another conversation with Rytaal is no longer required.
- Adds pickup debouncing to avoid double-decrementing from duplicate text events.
- Assault Orders pickup continues to handle actual tag consumption separately.


### Generalized Assault lifecycle tracker (v6.1.60)
- Implements the production Assault state flow:
  `ACCEPTED -> ORDERS RECEIVED -> ENTERING -> IN PROGRESS -> CLEARED -> VERIFIED`.
- `You have signed up for <mission>` remains the generic ACCEPTED detector.
- `Commencing <mission>! Objective: ...` now authoritatively sets the exact mission to IN PROGRESS.
- The generic Earth-time mission-limit line records an expiry timestamp (30 minutes in the current Requiem/Lamia captures).
- `You gain <N> assault points!` now marks the tracked mission CLEARED and checks its Assault mission checkbox.
- Rytaal's generic successful-completion message upgrades the lifecycle state to VERIFIED instead of being discarded as a duplicate clear.
- Assault lifecycle state/timestamps are persisted so a UI reload between phases can recover the tracked mission.
- Attention can show remaining mission time when an Assault is IN PROGRESS.
- No mission-specific Lamia/Requiem hard-coding is required.


### Rytaal estimated-regeneration authority fix (v6.1.61)
- Fixes estimated Assault Tag timer rollover incorrectly incrementing Rytaal's stored count.
- A directly observed Rytaal count is now authoritative until a later Rytaal menu confirms a change.
- When an estimated 24-hour timer expires, HorizonCheck marks regeneration as pending verification instead of adding a tag.
- Direct Rytaal packet/text observations clear the pending state and rebuild the estimate.
- UI indicates when regeneration is due but unverified.


### Cancellation -> re-accept tag consumption fix (v6.1.62)
- Fixes a returned Imperial Army I.D. tag remaining on the character after accepting a new Assault.
- Assault Orders pickup now authoritatively clears `carried=1 -> 0`.
- Consumption is driven by carried ownership instead of requiring a known positive account total.
- If the total is known, it decrements exactly once.
- Duplicate Assault Orders text is safe because subsequent calls see `carried=0` and do nothing.
- Adds a direct Assault Orders fallback in the tag module in addition to the automation detector.


### Authoritative signup tag-consumption fix (v6.1.63)
- Fixes `Character 1` remaining stuck after a new Assault application is successfully accepted.
- `You have signed up for <mission>.` now immediately consumes the carried Imperial Army I.D. tag.
- Assault Orders pickup remains as an idempotent backup detector.
- Both the Assault module and automation layer can trigger the same safe consumption path.
- Duplicate signup/orders events cannot double-consume because `auto_used()` exits once `carried=0`.


### Active Assault carried-tag reconciliation (v6.1.64)
- Repairs stale `Character 1` tag state left by older builds.
- ACCEPTED / ORDERS RECEIVED / COMMAND VERIFIED / STAGING / ENTERING / IN PROGRESS / OBJECTIVE COMPLETE / CLEARED / VERIFIED prove the I.D. tag is no longer on the character.
- The repair runs during normal Assault-tag status reconciliation, so an already-bad saved value fixes itself without another mission signup.
- When Rytaal stored count is directly known, total is reconciled to `Rytaal + carried`, preventing stale `Total 1/4` from surviving with `Rytaal 0/3` and an active Assault.
- CANCELLED is intentionally excluded because cancellation returns the tag.


### Missions checkbox crash fix (v6.1.65)
- Fixes the Missions tab UI crash when clicking a mission checkbox.
- `ensure_meta` and `source_key` are now correctly scoped before checkbox render handlers use them.
- Manual checkbox writes are wrapped in a protected save helper.
- A checkbox-save failure now reports to chat instead of propagating through the UI renderer and hiding the main window.
- Mission progress/source metadata behavior is otherwise unchanged.


### Mission Sync v2 (v6.1.66)
- Adds persistent historical nation ranks for San d'Oria, Bastok, and Windurst.
- Adds `All Nations Rank 10` for established characters that have reached Rank 10 in all three nations.
- Adds per-nation +/- historical-rank controls.
- `Mission Sync` observes the current nation's rank when available and remembers the highest observed rank.
- Every sync backfills mandatory mission prerequisites across all saved nation histories.
- Automatic observations never lower a previously known historical rank.
- Optional/repeatable rank-point missions are deliberately not inferred.
- Zilart / CoP / ToAU remain manual until an authoritative progression source is available.


### Mission Sync v3 - native Completed Missions (v6.1.67)
- Adds incoming 0x056 mission-log listener.
- Reads the native Completed Missions subtype (0x00D0) sent by the server.
- Auto-checks completed San d'Oria, Bastok, and Windurst mission rows from the native completion bitfield.
- Native packet evidence is stored as `NATIVE COMPLETED MISSIONS`.
- Rank-history inference remains as a fallback.
- Unknown/private-server bits are ignored.
- Expansion current-mission decoding remains conservative pending HorizonXI verification.


### Mission Packet Capture (v6.1.68)
- Adds Start Mission Capture / Stop Mission Capture controls to Missions.
- Captures every incoming 0x056 Quest/Mission Log packet while active.
- Logs timestamp, packet size, subtype, and complete raw hex.
- Diagnostic-decodes 0xFFFF current-mission fields (Nation, ROZ, COP, ToAU, WotG, ACP, MKD, ASA, SOA, ROV).
- Decoder is observation-only: expansion mission checkboxes are not changed from unverified current-mission values.
- Writes `horizoncheck_mission_packets_YYYYMMDD_HHMMSS.txt` to the addon folder.
- Capture summary lists every 0x056 subtype observed.


### Mission Packet Capture v2 (v6.1.69)
- Sequence-maps the entire incoming 0x056 zone-in burst.
- Adds packet ordinal, raw header bytes, sequence candidate, and observed byte-37 page marker.
- Logs a compact first-40-byte view plus non-zero byte positions.
- Logs byte-by-byte deltas against the previous 0x056 packet.
- Summarizes all observed type candidates and byte-37 page markers.
- Keeps 0xFFFF decoding diagnostic-only; no expansion checkbox is changed from unverified values.
- This build is intended to map HorizonXI's actual packet layout before Mission Sync v4 enables expansion backfill.


### Mission Storyline Capture rebuild (v6.1.73)
- Rebuilt from the structurally known-good v6.1.69 Missions module.
- Fixes v6.1.71/v6.1.72 regression where capture UI code replaced `M.draw()` and was accidentally inserted into `M.stop_packet_capture()`.
- Restores a valid `M.draw()` function.
- Adds simple standard-button storyline selection for San d'Oria, Bastok, Windurst, Zilart, CoP, and ToAU.
- Selected storyline is written into the capture header and each incoming 0x056 record.
- Capture workflow: select storyline -> Start Mission Capture -> zone once -> wait 5-10 seconds -> Stop.
- Fixes the latent `mission_key()` typo in native nation-mission packet handling.


### Native Mission Sync v4 (v6.1.74)
- Corrects incoming 0x056 layout: 32-byte variant payload at bytes 5..36, uint16 Type at bytes 37..38.
- Decodes 0x00D0 exactly:
  - San d'Oria completed missions (8 bytes)
  - Bastok completed missions (8 bytes)
  - Windurst completed missions (8 bytes)
  - Rise of the Zilart completed missions (8 bytes)
- Decodes 0x00D8 first 8 bytes for exact Treasures of Aht Urhgan mission completion.
- Uses actual DAT mission IDs for nation and Zilart rows, including the nation 2-3 branch gap.
- Decodes 0xFFFF Current Missions using correct 32-bit offsets.
- CoP earlier mandatory missions are backfilled when their progression IDs are below the current CoP value.
- Fixes the earlier false 0x00D0 detector that incorrectly read bytes 5..6 as the packet Type.
- Mission capture diagnostics now report the real 0x056 Type.


### Production cleanup + digging cap reconciliation (v6.1.75)
- Removes Mission Capture/storyline controls from the Missions UI now that Native Mission Sync v4 has been verified after zoning.
- Keeps the mission decoder and diagnostic capture backend intact.
- Treats HorizonXI's "You have maxed your player digging for today!" message as authoritative.
- On that message, the successful-dig count is reconciled to the verified rank's daily cap and remaining is forced to 0.
- Fixes the observed Veteran case where the server capped the player but HorizonCheck remained at 189/190.


### The Last Verse completion sentinel (v6.1.76)
- Special-cases CoP 8-5 / ZM18 "The Last Verse".
- The game leaves The Last Verse permanently in Current Missions after the shared Zilart/CoP epilogue is reached.
- When native 0xFFFF Current CoP equals the 8-5 progression value, HorizonCheck now marks The Last Verse complete instead of treating equality as an active unfinished mission.
- All other CoP rows retain the conservative rule: only progression values strictly below the current mission are auto-completed.


### Mission Sync user-facing chat cleanup (v6.1.77)
- Normal chat now says `Mission Sync: Updated 1 completed mission.` or `Mission Sync: Updated N completed missions.`
- Packet IDs remain stored only in mission metadata for diagnostics.


### Persisted digging cap reconciliation (v6.1.78)
- Fixes saved `CAPPED | 189/190` states from older builds.
- On load/ensure, any `server_cap_confirmed=true` state is normalized to the verified rank daily maximum.
- Daily UI stats also render the rank maximum whenever the server cap is confirmed.
- Existing Veteran capped state repairs itself to `190/190` without requiring another digging result.


### Missions production UI + HorizonXI reward audit (v6.1.79)
- Collapses historical nation-rank controls under Advanced / Historical Sync.
- Removes packet IDs, decoder version, last-added counts, and implementation notes from normal Missions UI.
- Normal UI now shows one Mission Sync status line, Resync Missions, and supported storylines.
- Reward text audited against the HorizonXI Wiki mission category tables.
- Adds Horizon-specific nation rings at 1-3, Mog Wardrobe rewards at nation 2-3/5-2/7-2, and Jeuno Outpost Teleport at nation 2-3.
- Adds Horizon Mog Wardrobe 2 rewards throughout Zilart and CoP milestones.
- Corrects Ancient Vows reward (Mog Wardrobe 2 +2; removes incorrect 1,000 EXP/LP).
- Corrects ToAU rewards including Supplies Package, Sanction access, Wardrobe 3 milestones, and the final 46/47/48 reward sequence.


### Mission table readability (v6.1.80)
- Adds horizontal divider lines between every mission row.
- Adds subtle vertical column dividers so checkbox, rank/chapter, number, mission, type, and reward fields line up more clearly.
- Fallback non-table rendering also receives a separator between each mission.


### Combined Daily / Weekly tab (v6.1.81)
- Replaces separate Daily and Weekly tabs with one `Daily / Weekly` tab.
- Daily objectives are grouped under a clear DAILY OBJECTIVES heading with daily reset wording.
- Weekly objectives are grouped separately under WEEKLY OBJECTIVES with Conquest-tally reset wording.
- Keeps all existing daily/weekly completion, reset, automation, and capture logic unchanged.
- Conquest / Outpost Details remain beneath the weekly section.


### Tab ordering (v6.1.82)
- Moves Dragon / EXP directly after the combined Daily / Weekly tab.


### Forced tab-order refresh (v6.1.83)
- Keeps Dragon / EXP directly after Daily / Weekly in source order.
- Changes the ImGui tab-bar identity so Ashita/ImGui cannot reuse persisted ordering from the previous tab layout.
- Changes the Dragon / EXP tab identity for the same reason.


### Tab ordering (v6.1.84)
- Moves Eco-War directly after Dragon / EXP.
- Refreshes the ImGui tab-bar identity so the new visible order is applied immediately.


### Compact Attention layout (v6.1.85)
- Splits Attention into two side-by-side columns on normal/wide windows.
- Left column: Current Status.
- Right column: Upcoming timers.
- Adds a vertical divider between the columns.
- Reduces Attention height substantially while preserving all existing status/timer information.
- Automatically falls back to the original stacked arrangement when the window is narrow or table APIs are unavailable.


### Black Coffin reward gallery (v6.1.86)
- Moves reward information out of the weekly progression rows into a separate Rewards section below the chain.
- Groups rewards beneath each of the three Halshaob battlefield names.
- Adds bundled 40x40 reward pictograms for Koga Shuriken, lockboxes, Yoichi's Sash, Barbarossa's Zerehs, Barbarossa's Moufles, and the Mog Wardrobe unlock.
- Uses image textures when supported by the installed Ashita ImGui build and safely falls back to reward text if texture helpers are unavailable.


### Black Coffin gear stats (v6.1.87)
- Adds compact stats beside equippable Black Coffin rewards.
- Koga Shuriken: DMG 88, Delay 192, Ranged Attack +10, Lv.75 NIN.
- Barbarossa's Zerehs: DEF 36, STR +4, VIT +4, Haste +3%, Lv.75.
- Barbarossa's Moufles: DEF 22, Ranged Accuracy +7, Ranged Attack +7, Lv.73.
- Yoichi's Sash is labeled as a crafting material rather than equipment.


### Black Coffin gear jobs (v6.1.88)
- Adds usable jobs beside each equippable reward.


### Black Coffin readability polish (v6.1.89)
- Highlights Scouting the Ashu Talif, Royal Painter Escort, and Targeting the Captain mission names.
- Applies alternating reward-row text tones to visually distinguish adjacent gear/reward lines.
- Adds separators between individual reward rows.
- Keeps the existing reward icons, stats, job restrictions, and completion logic unchanged.


### Black Coffin reload crash fix (v6.1.90)
- Fixes reward helper declaration order.
- Removes risky style-color APIs from the Black Coffin reward renderer.
- Mission headings remain visually distinguished with separators.
- Reward rows remain easy to follow with alternating safe markers and separators.
- Reward images remain optional and fall back to text if texture APIs are unavailable.


### Production polish + state reconciliation (v6.1.91)
- Adds Developer Mode under Settings; off by default.
- Hides Diagnostics tab, Automation Monitor shortcut, and learning/capture buttons from normal production UI unless Developer Mode is enabled.
- Adds State Health status with safe reconciliation of known impossible persisted states.
- Auto-repairs server-confirmed digging cap/count mismatches.
- Auto-repairs carried Assault tag state when an accepted/active/verified Assault proves the tag was consumed.
- Keeps `/hcheck diagnostics` available for troubleshooting even when Developer Mode is off.
- Black Coffin mission headings are more distinct and reward rows use alternating safe markers/separators without risky ImGui color APIs.


### v6.2 Production UI
- First-run setup guidance for Mission Sync, Rytaal Assault Tags, and Chocobo Digging.
- Attention prioritizes actionable READY / AVAILABLE items; timers stay in Upcoming.
- Mission tab adds compact storyline completion summaries.
- Scope labels distinguish CHARACTER, ACCOUNT, and MIXED SCOPE systems.
- Black Coffin rewards use readable vertical cards with separate Stats, Jobs, and Notes.
- State Health is expanded into a self-test for reset keys, Mission Sync, Digging, Assault, and Outpost state.


### v6.2.01 Usability Pass
- Assault Tags are always visible in Attention, including 0/4 and uninitialized states.
- Adds persistent Hide Completed filters for Daily/Weekly/Dragon objectives, Missions, and Assault progression.
- Completed mission storylines collapse by default; incomplete storylines remain open.
- Completed Assault rank groups collapse by default; incomplete ranks remain open.
- Black Coffin's completed weekly chain and completed reward groups collapse by default.
- Core tracking, reset, mission sync, and Assault tag logic are unchanged.


### v6.2.02 Timer Reliability + Upcoming Polish
- Assault Tag Upcoming timer never displays a dead 00:00:00 value.
- Estimated elapsed Assault regeneration switches to VERIFY and asks the player to talk to Rytaal instead of inventing a tag or restarting a timer.
- Assault timer states are explicit: COUNTING DOWN, VERIFY, CAPPED, or UNKNOWN.
- Rytaal status no longer exposes zero remaining as a valid countdown.
- Existing future `next_at` timestamps are preserved; only authoritative Rytaal observations may establish a replacement schedule.
- ENM Upcoming rows use the same COUNTING DOWN terminology while retaining VERIFIED / ESTIMATED confidence.


### v6.2.03 Attention visual consistency
- READY and AVAILABLE rows now use normal bright text consistently.
- Limbus, Dynamis, Assault Tags, and ENMs all stand out equally when actionable.
- Neutral informational rows such as 0/4 Assault Tags and Progress remain grey.


### v6.2.04 Outpost Filter + EXP Ring Restore
- Restores EXP Ring status to Attention.
- Adds a persistent `Hide completed outposts` toggle in Conquest / Outpost Details.
- When enabled, owned outposts are hidden and only missing outposts remain visible.
- If all 17 outposts are owned, the filtered list shows `All outposts are complete.`


### v6.3 Settings + Personalization
- Adds Display Settings with persistent tab visibility controls.
- Adds Normal / Dense UI preference (Dense reduces supported optional spacing).
- Adds per-category routine chat notification controls for Mission Sync, Assault/Rytaal, ENM, Digging, Black Coffin, Weekly/Lockouts, and general messages.
- Errors, load notices, self-test failures, and State Health messages always remain visible.
- Black Coffin gear rewards now detect the current main job and show whether it can equip each item.
- Adds Reset UI Settings, which resets presentation/preferences only and never touches tracker/progression data.
- Existing Hide Completed settings remain independent per section.


### v6.3.01 Assault Tag Pickup Transfer Fix
- Fixes a newly picked-up Imperial Army I.D. Tag being immediately reset to Character 0 by stale completed Assault state.
- A verified Rytaal stored-count transition such as 1/3 -> 0/3 now transfers that tag to Character 1/1 while preserving Total 1/4.
- The same transfer inference works from both Rytaal 0x034 packets and the `(N left)` menu text.
- Saved Assault activity may consume a carried tag only when its timestamp is newer than or equal to the latest tag pickup.
- Accepting/signing up for a new Assault remains authoritative and consumes Character 1 -> 0.
- State Health reconciliation now follows the same timestamp rule and cannot erase a newer tag pickup because of an older CLEARED/VERIFIED Assault record.


### v6.3.02 Independent Hide Completed Filters
- Daily, Weekly/Conquest, and Dragon/EXP now each have their own independent Hide Completed setting.
- Toggling Daily no longer toggles Weekly.
- Toggling Weekly no longer toggles Daily.
- Dragon/EXP also keeps its own preference.
- Existing users inherit the old shared setting once, then the three filters remain independent.


### v6.3.03 Daily Digging Hide-Completed Fix
- Capped/completed Chocobo Digging now obeys the Daily `Hide completed objectives` filter.
- Removes the previous Digging-specific visibility exemption.


### v6.3.04 Assault Tag Pickup Authority Fix
- A verified Rytaal stored-count transition of exactly one tag, such as 1/3 -> 0/3, now always records a pickup to Character 1/1.
- Old CLEARED / VERIFIED Assault history can no longer block detection of the new pickup before its pickup timestamp exists.
- After the pickup timestamp is recorded, the existing timestamp guard still prevents stale Assault history from erasing the new carried tag.
- Applies to both Rytaal 0x034 packet decoding and `(N left)` menu text.


### v6.3.05 Dynamis Attention Status
- Dynamis now always has a dedicated status line in Attention, similar to Limbus.
- If the current character is 2/2 but the account is only 2/3, Attention shows `Character CAPPED 2/2 | Account 2/3 | 1 account lockout remaining`.
- At 3/3 account-wide, the line shows `Account CAPPED`.
- When the current character can still run Dynamis, the line remains bright `AVAILABLE` and shows its remaining character lockouts.


### v6.4 Production UI Cleanup
- Assault Tags now render as one compact player-facing panel.
- Removes duplicate normal-mode Assault tag diagnostics and manual controls.
- Packet status, capture tools, reconciliation timestamps, and Repair +1 Stored are Developer Mode only.
- Assault mission rows are clean in Production Mode: completed entries show ✓ and incomplete entries are grey.
- Mark Complete and Capture controls are Developer Mode only.
- Adds compact Assault rank summary across PSC/PFC/SP/LC/C/SL/FL/CS/SM/FC.
- Adds PRODUCTION / DEVELOPER mode indicator in the main header.
- Keeps all tracking, auto-completion, tag sync, and timer logic unchanged.


### v6.4.01 Assault Pickup Same-Second Fix
- Fixes newly picked-up I.D. Tags being erased when an older Assault state has the same whole-second timestamp.
- Generic Assault-state reconciliation now requires activity to be strictly newer than the latest tag pickup.
- Adds a 3-second protection window around authoritative tag pickup packet/menu events.
- Explicit new Assault signup and Assault Orders still consume the carried tag immediately through `auto_used()`.
- Expected pickup state: `Character 1/1 | Rytaal 0/3 | Total 1/4`.


### v6.4.02 Character-Scoped Assault Pickup Fix
- Fixes the root data-model bug causing freshly picked-up I.D. Tags to revert to Character 0/1.
- Carried-tag pickup timestamps, pickup verification, transfer metadata, protection windows, and usage timestamps are now character-specific, just like `carried`.
- State Health can now see the correct character pickup timestamp and will not erase a newer carried tag because of stale Assault history.
- Adds migration recovery for pickup evidence accidentally stored account-wide by v6.3.01-v6.4.01.
- Explicit key-item pickup and verified Rytaal 1/3 -> 0/3 transfer both stamp character-local ownership evidence.


### v6.4.03 Assault Tag Ownership Authority Fix
- Removes `assault_activity` entirely as a source that can consume a carried I.D. Tag.
- Character 1 -> 0 now happens only from direct authoritative evidence: new Assault signup or Assault Orders obtained.
- Old/current Assault status refreshes can no longer erase a newly picked-up tag.
- Direct pickup immediately rebuilds total tags from Rytaal stored + Character 1.
- State Health no longer mutates carried-tag ownership from Assault status.


### v6.4.04 Assault Tag Split Invariant Fix
- Enforces the identity `Total Tags = Character + Rytaal`.
- If Total is known as 1 and Rytaal verifies 0, HorizonCheck now self-heals Character to 1/1.
- Rytaal packet sync reconciles carried ownership from the previous total before rebuilding Total, preventing `1/4 -> 0/4` collapse.
- Rytaal `(N left)` menu sync uses the same invariant.
- The 'cannot issue a new tag while you have one' possession message no longer requires the NPC name `Rytaal` to be present in the chat line.


### v6.4.05 Rytaal Possession Dialogue Authority
- Uses the captured HorizonXI Rytaal dialogue as direct authoritative evidence of a carried I.D. Tag.
- Matches the two stable fragments `cannot issue a new imperial army i.d. tag` and `while you have one in your possession`, making the detector tolerant of chat prefixes/control characters.
- That dialogue immediately forces Character = 1/1 and rebuilds Total = Rytaal stored + 1.
- The ownership state is written directly to the current character table and through the Assault proxy, then saved immediately.
- Explicit `Obtained Imperial Army I.D. Tag` pickup now reuses the same authoritative ownership helper.


### v6.5 Reliability + Status Consistency
- Adds carried-tag evidence metadata: VERIFIED / ESTIMATED / MANUAL / UNKNOWN, source, and verification time.
- Rytaal possession dialogue and explicit pickup mark ownership VERIFIED.
- Direct Assault signup / Assault Orders consumption marks Character 0 VERIFIED.
- Attention is priority sorted: READY first, then AVAILABLE, then neutral/capped information.
- Assault Tags in Attention show ownership confidence.
- Assault tab adds a compact Current Assault summary with mission, state, and remaining timer when available.
- Developer Mode shows carried ownership source and verification timestamp.
- State Health distinguishes NEEDS INITIALIZATION from actual errors.


### v6.6 State Reliability & Self-Diagnostics
- Adds formal carried-tag evidence hierarchy: UNKNOWN < ESTIMATED < MANUAL < INFERRED < PACKET < KEYITEM < DIALOGUE < ORDERS.
- Weaker Assault ownership evidence can no longer overwrite stronger evidence.
- Adds recent state audit history (last 30 events, 10 shown in Diagnostics).
- Adds per-event confidence/source logging for Assault carried-tag changes.
- Adds initialization summary with exact steps still needed for Mission Sync, Rytaal, and Digging.
- Adds `Hide complete/capped items in Attention`.
- Adds character schema version marker for future migrations.


### v6.6.01 Reload Runtime Fix
- Fixes reload failure introduced by v6.6 evidence hierarchy.
- Moves `EVIDENCE_RANK`, `evidence_rank`, `current_evidence_rank`, and `set_carried_evidence` above `split_counts`.
- Ensures Assault status/UI functions resolve the local evidence helpers correctly at runtime.
- No tracker data or evidence-priority behavior changed.


### v6.7 Smart Dashboard & Tracker Confidence
- Attention is now a prioritized activity planner with READY NOW / AVAILABLE / VERIFY / STATUS / COMPLETE-CAPPED grouping.
- Upcoming timers are sorted by time remaining.
- Adds Tracker Confidence for Assault Tags, Missions, Digging, Dynamis, Limbus, and EXP Ring.
- Selected VERIFIED sources become VERIFY when stale.
- Adds persistent routine-notification deduplication across reloads/zoning.
- Adds Global Incomplete Only to synchronize the main hide-completed filters.


### v6.7.01 Overview Header Move
- Moves Daily / Weekly / Dragon-EXP overview out of Attention.
- Displays the overview on the top character row beside the character name.
- Keeps the Attention panel focused on actionable activity/status rows.


### v6.7.02 Overview Completion Styling
- Completed top-row overview categories now use bright/white text.
- Incomplete Daily, Weekly, or Dragon/EXP categories remain grey.
- Each overview category is styled independently.
- Attention's generic `STATUS` group is renamed `CURRENT STATUS` for readability.
- No tracker or completion logic changed.


### v6.7.03 EXP Ring Status Styling
- `Recharge this week: YES` now renders bright/white to match the rest of the EXP Ring line.
- `Recharge this week: NO/UNKNOWN` remains dimmed so incomplete/uncertain state is visually distinct.
- Applies the same behavior in Attention and the detailed EXP Ring display.
- Main header now shows the exact v6.7.03 build number.
- No EXP Ring tracking or weekly completion logic changed.


### v6.7.04 Outpost Verification Consistency Fix
- Fixes `All outposts obtained` appearing when only part of the 17 outposts are actually verified.
- Top summary, checkbox ownership, and `Last verified` count now use the same authoritative `verified_owned` set.
- `All outposts obtained` is shown only at verified 17/17.
- If verification is 6/17, the summary now shows `Outposts obtained: 6/17`.
- Permanent 17/17 status no longer displays YES unless the verified set is actually 17/17.


### v6.8.00 San d'Oria Eco-War Lifecycle Automation
- Adds capture-derived San d'Oria Eco-War lifecycle states:
  - READY
  - IN PROGRESS / ACTIVE
  - KEY ITEM READY
  - RETURN TO NOREJAIE
  - COMPLETE
- Rojaireaut V.E.R.M.I.N. assignment dialogue verifies ACTIVE.
- `Obtained key item: Indigested Stalagmite` verifies KEY ITEM READY.
- Rojaireaut's proof dialogue verifies RETURN TO NOREJAIE.
- Norejaie's Indigested Stalagmite reward dialogue verifies repeatable completion.
- Norejaie's post-completion `run out of mulsum` dialogue reconstructs weekly completion after reload/login.
- Does not depend on HorizonXI's one-time Eco-Warrior achievement message.
- Duplicate dialogue copies within 3 seconds are debounced.
- Eco capture and manual Complete buttons are Developer Mode only.


### v6.8.01 Trusted Outpost Snapshot Replacement Fix
- Fixes the stale 17/17 Outpost state surviving a correct Conrad 6/17 Regional Teleport scan.
- Trusted Regional Teleport scans now REPLACE the durable ownership snapshot instead of merging only true flags.
- Corrected durable snapshot is committed before `sync_parent()` calls `ensure()`, preventing the old 17/17 set from being re-imported during the same scan.
- Durable replacement snapshots remain authoritative across reloads.
- Outpost summary and permanent-complete display use the verified ownership count directly.
- A verified 6/17 scan now displays `Outposts obtained: 6/17` and `Permanent 17/17 status: NO`.


### v6.9.00 Anniversary Guide
- Adds a dedicated Anniversary tab for HorizonXI custom anniversary content.
- 2023: 38-location scavenger-hunt route plus final 12 -> 17 -> 22 HorizonXI Shirt sequence.
- 2024: all 12 main scavenger-hunt zones with requested items, plus Aerec's 8 bonus items.
- 2025: all 30 Sehri monster hunts with target, location, and concise notes.
- Adds per-character saved completion checkboxes and per-year progress counters.
- Anniversary tab can be hidden from Display Settings.
- Guide content is informational/manual; it does not attempt to infer anniversary progress from packets yet.


### v6.9.01 2024 Anniversary Acquisition Guide
- Adds a `Get:` acquisition hint beneath every 2024 main scavenger-hunt item.
- Adds acquisition hints for all 8 Aerec bonus-riddle items.
- Calls out important special cases such as Exclusive items, Conquest restrictions, quest/key items, fishing locations, synthesis, and specific monster/NM sources.
- Existing per-character completion tracking is unchanged.

### v6.9.02 Eco-Warrior reconciliation
- Raifa's baked-popoto dialogue is generic and no longer marks Bastok complete.
- Only the actual Indigested Ore reward turn-in can auto-complete Bastok.
- Eeko-Weeko now removes stale Bastok completion when Bastok is reported available.
- A directly verified current-week completion is preserved while Eeko repairs rotation history.
- San d'Oria completed this week + Windurst already cleared + Bastok available now resolves to 2/3.

### v6.9.03 Eeko-Weeko Authoritative Availability Fix
- Eeko-Weeko current-week availability overrides stale Eco-Warrior cycle/lifecycle flags.
- When San d'Oria is completed this week and Eeko-Weeko says Bastok is available, Bastok is forcibly removed from the cleared set.
- Bastok stale completion timestamps/state are reset to READY.
- Rotation counter respects Eeko-Weeko's authoritative availability, preventing false 3/3.
- Bastok displays `AVAILABLE [VERIFIED BY EEKO-WEEKO]`.

### v6.9.04 Eco-Warrior Weekly Rollover Fix
- Eco-Warrior completions are now stamped with the conquest weekly key.
- Eeko-Weeko authoritative availability no longer preserves a stale Bastok `COMPLETED THIS WEEK` flag from a prior conquest week.
- Legacy unstamped completion state is discarded when Eeko verifies the current rotation.
- The rotation counter now follows current Eeko availability, so the reported Windurst-cleared / San d'Oria-or-Bastok-available state correctly displays 2/3 after one of those two is completed in the current cycle.


### v6.9.07 Eeko-Weeko San d'Oria + Windurst Parser Fix
- Added the captured Eeko-Weeko dialogue state where San d'Oria and Windurst are reported as cleared and Bastok is the next available nation.
- Eeko verification now clears stale Bastok completion/lifecycle state, forcing the display to 2/3 cleared with Bastok AVAILABLE.


### v6.9.08 ISNM battlefield entry + successful-clear automation
- Uses capture-verified `The secret imperial order breaks!` as the ISNM-specific entry gate.
- Pairs that event with the immediately following `Entering the battlefield for ...!` message and records the battlefield as `RUN IN PROGRESS`.
- Does not check the Daily / Regular ISNM row on battlefield entry.
- Checks the ISNM row only after a verified `Battlefield clear time: ...!` message for the tracked ISNM run.
- Generic battlefield clear messages are ignored unless HorizonCheck previously observed the Secret Imperial Order break + battlefield entry, preventing BCNM/ENM clears from being misclassified as ISNM.
- Secret Imperial Order possession remains visible as `ORDER HELD`, but possession alone no longer marks the run complete.
- Keeps v6.9.07 outpost and Eco-Warrior fixes unchanged.



### v6.9.10 ISNM stale ORDER HELD correction
- A verified Shajaf rejection now clears any persisted Secret Imperial Order / ORDER HELD state before recording NOT ELIGIBLE.
- Prevents old order ownership from taking precedence in the ISNM status line after the key item has already been consumed or is no longer held.
- Keeps v6.9.09 ISNM entry, battlefield clear, and Imperial Standing detection unchanged.

### v6.9.09 Shajaf ISNM eligibility rejection detection
- Added capture-verified detection for Shajaf's explicit "pretend you never met me ... when you're ready" rejection dialogue.
- Records the character as `ISNM | NOT ELIGIBLE [VERIFIED BY SHAJAF]` after that observed rejection.
- Keeps the Imperial Standing value Shajaf reports for context, but does **not** infer or hard-code an ISP requirement from the captured 1,705 balance.
- A later verified Secret Imperial Order acquisition clears the stale rejection state automatically.
- Existing v6.9.08 ISNM entry and successful-clear automation is unchanged.


### v6.9.11 ISNM Shajaf no-order verification
- A fresh Imperial Standing read from Shajaf now clears any stale persisted `Secret Imperial Order | ORDER HELD` state.
- This is based on the captured Shajaf eligibility path: Shajaf reports ISP when evaluating eligibility, while the separate active-job dialogue is used when an ISNM order/job is already active.
- Shajaf rejection matching is now tolerant of chat formatting/control-character differences by matching the stable rejection phrases rather than one exact full line.
- Existing ISNM order acquisition, order-break entry gate, and successful battlefield-clear automation remain unchanged.


### v6.9.12 ENM Venessa key-item state correction
- Venessa's "then you will need this censer" dialogue now identifies the selected Promyvion only and no longer marks the key item as held.
- Venessa's "no more censers / return later" dialogue clears stale KEY ITEM READY state for the selected Promyvion.
- Venessa's exact Earth-time line now stores the authoritative next-censer availability timestamp and displays NO KEY ITEM until that time.
- ENM battlefield entry clears stale KEY ITEM READY state by marking the entry key item consumed.


### v6.9.13 Anniversary auto-sync
- 2024 main riddles can now backfill earlier completed items from an event NPC's current requested item. Talk to each 2024 event NPC once to synchronize that NPC's ordered riddle progress.
- Aerec bonus riddles use the same conservative current-riddle backfill.
- 2025 Sehri hunts auto-check going forward after HorizonCheck observes the assigned target and the remains completion message (or a new assignment after turn-in).
- 2023 remains manual because no authoritative historical-progress signal has been captured yet.
- 2025 historical individual hunt identities are not guessed from reward milestones/counts because assignments are random.
- Existing manual checkboxes remain available as fallback/correction.


### v6.9.14 Boneyard Gully ENM definition
- Tracks the normal-item prerequisite chain: Flaxen Pouch -> Pouch of Parradamo Stones.
- `Obtained key item: Miasma filter.` remains the authoritative KEY ITEM READY signal and starts the ENM cooldown.
- Entering `Sheep in Antlion's Clothing` clears the held Miasma Filter state and starts the active battlefield tracker.
- A `Battlefield clear time:` line marks the verified active ENM CLEARED; the one-time Horizon achievement message is intentionally ignored for repeat-clear reliability.
- Preserves v6.9.13 Anniversary auto-sync and earlier ENM/ISNM fixes.




## v6.9.33

- Adds direct packet `0x055` Key Item Log bitmap diagnostics alongside Ashita `HasKeyItem()`.
- Decodes all seven 512-key-item bitmap tables when the server sends them on zone or KI updates.
- Compares packet ownership and `HasKeyItem()` side-by-side for Miasma Filter, Zephyr Fan, Secret Imperial Order, and Cosmo-Cleanse.
- Adds `/hcheck keyitems bitmap` and a `0x055 Bitmap Test` Diagnostics button.
- Diagnostic only: does not modify ENM / ISNM / Limbus state yet.

## v6.9.32
- Expanded the diagnostic-only Key Item probe into a Key Item API Test Lab.
- Adds a focused Cosmo-Cleanse mapping test (resolved resource ID, ID +/-1 checks, and nearby owned-ID scan).
- Adds a manual owned-ID range scan (`/hcheck keyitems scan 650 850`) that reports only IDs where Ashita returns `HasKeyItem=true`, together with the key-item resource name at that same ID when available.
- Adds `/hcheck keyitems test cosmo [radius]`.
- No Key Item test result changes ENM, ISNM, Limbus, or any other tracker state.

## v6.9.31
- Adds a non-invasive Key Item API probe under Developer Mode > Diagnostics.
- Uses Ashita v4 IPlayer:HasKeyItem(id) and the native key-item resource names to test Miasma Filter, Zephyr Fan, Secret Imperial Order, and Cosmo-Cleanse.
- Probe only reports ownership; it does not modify tracker state yet.
- Command: `/hcheck keyitems probe`.


## v6.9.38
- Adds a Quests tab immediately after Missions.
- Adds a native Quest Menu capture profile (`/hcheck learn questmenu`) that preserves full 0x056 packets for quest-log mapping.
- Adds a Hide completed quests preference scaffold and shows currently known quest automations while native regional quest mappings are being learned.

### Secrets of Ovens Lost authoritative completion fix (v6.9.45)
- Removes dialogue-only Jonette completion. Repeating normal Jonette dialogue can no longer mark the weekly quest complete.
- Adds Tavnazian Cookbook to the authoritative 0x055 key-item bitmap map.
- Completion now requires verified cookbook evidence plus either the actual Miratete reward or an authoritative native quest transition from ACTIVE to INACTIVE (0x056) in recent Jonette turn-in context.
- If 0x056 still reports Secrets of Ovens Lost ACTIVE, HorizonCheck repairs any older false COMPLETE state back to IN PROGRESS / COOKBOOK OBTAINED.


### v6.9.45
- Uninvited Guests now auto-detects the Monarch Linn Patrol Permit from the authoritative 0x055 key-item bitmap.
- Permit ownership shows KI VERIFIED / ready to enter. Permit loss never implies completion by itself.


### v6.9.48
- Quests tab adds case-insensitive quest/status search when supported by the local ImGui binding.
- Adds an Automated Only filter for quests with HorizonCheck-specific automation.
- Active tracked quests show contextual badges such as COOKBOOK OBTAINED, PERMIT READY, and Eco-War KI READY.
- Attention surfaces only actionable quest states instead of duplicating every active quest.
- Native 0x056 remains authoritative for ACTIVE state; completed history is still not inferred.


### v6.9.49
- Improves the Quests tab with per-character pinning, Ready/Pinned/Automated filters, status-first sorting, repeatable WEEKLY/CONQUEST tags for known automated quests, region/key-item-aware search, and a compact verified timestamp/count summary.
- Detects native 0x056 ACTIVE quest transitions live. Newly active quests are announced as accepted/active; quests leaving the ACTIVE bitmap are reported only as leaving the active log and are not falsely assumed complete.
- Keeps completed quest history conservative until an authoritative completion source is decoded.

### v6.9.52
- Removes quest pinning/favorites from the Quests tab.
- Removes the Pin/Unpin controls, Pinned count, Pinned-only filter, and pinned-first sort behavior.
- Keeps search, Automated Only, Ready Only, region expand/collapse, repeatable tags, actionable status sorting, and native 0x056 live quest transitions.
- Legacy per-character pin settings are ignored and no longer rendered.


## v6.9.52
- Adds Completed Quest Probe for all incoming 0x056 types.
- Separates known ACTIVE and COMPLETED quest-log bitmaps without changing player-facing completion state.
- Command: `/hcheck completedquests`. Zone once before running the probe.
- Unknown 0x056 types are reported rather than guessed.


### Rivernewort authoritative KI tracking (v6.9.62)
- Added Rivernewort to the native 0x055 key-item bitmap catalog.
- Spice Gals now advances immediately to `RIVERNEWORT OBTAINED | KI VERIFIED | Return to Rouva` when Rivernewort is obtained or restored from the bitmap after zoning.
- Losing Rivernewort alone never marks the weekly complete; the existing verified Rouva/Miratete completion evidence is still required.
- Quest metadata now identifies Spice Gals as a Chains of Promathia conquest-repeatable quest started by Rouva in Southern San d'Oria (I-8).


### Uninvited Guests battlefield clear state (v6.9.63)
- Capture-verified Mammet-800 defeat followed by `battlefield clear time:` now advances Uninvited Guests to `CLEARED | Return to Justinius`.
- Battlefield clear does not mark the weekly complete; the Justinius return/reward or lockout confirmation remains authoritative for weekly completion.
- Permit disappearance after entry no longer leaves a successful clear at `PERMIT NOT HELD`.

## v6.9.67
- Quests: adds Quest Chain previous/next relationships from mapped prerequisite metadata.
- Quests: adds Recently Unlocked detection when a new completed 0x056 bit causes a mapped quest to become AVAILABLE.
- Locked/Details: keeps explicit requirement reasons and shows dependent quest state in the chain panel.


## v6.9.69
- Expanded HorizonXI Outlands quest metadata for Kazham, Norg, Rabao, Zilart headstone quests, and Divine Might.
- Missionary Man now shows Rauteinot, Kazham (G-9), fame 3, Elshimo Marble/parcel/statue objective, Teleport-Yhoat reward, and next-step guidance.
- Quest Details now displays documented fame/job/mission requirements even when runtime verification is not yet available, plus Objective, Items, and Reward metadata.


## v6.9.71
- Removes the Recently Completed quest history section and its persistent tracking. Completed quest state remains available in the normal Completed view.

## v6.9.70
- Fixed Ashita ImGui BeginChild compatibility in the Quests split-pane layout by using ImGuiChildFlags_Borders instead of the legacy boolean border argument.


## v6.9.90
- Quests: reward tags in rows/details (Teleport, Map, Spell, Job, AF, Gil, Key Item, generic reward).
- Quests: SMART / NAME / ZONE / REWARD sorting controls.
- Quests: metadata confidence shown in persistent Details pane.
- Quest search now includes reward text/tags.
- Native 0x056 ACTIVE/COMPLETED decoder and persistence are unchanged from v6.9.89.


## v6.9.91
- Bulk quest catalog enrichment for Other Areas and Aht Urhgan.
- Adds NPC/zone, fame where documented, rewards, search keywords, and actionable next-step text for a large set of native DAT-mapped quest IDs.
- Quest-state 0x056 decode/persistence code is unchanged.


## v6.9.92
- Quests: added an Open HorizonXI Wiki button to the persistent Quest Details pane. The link is generated from the selected quest's mapped/native name and opens the matching HorizonXI Wiki quest page in the default browser.
- Quest packet/state handling is unchanged from the stable v6.9.88+ path.



## v6.9.95
- Adds 33 more quest catalog records through the bulk metadata overlay.
- Expands Jeuno coverage with missing early/general quests, Gobbiebag II-IV, Bard AF quests, Black Belt follow-up, Chocobo on the Loose, and Adventuring Fellow placeholders.
- Starts another Windurst catalog pass with eight Port Windurst quests including Making Amends, All at Sea, the Onion Brigade chain, Something Fishy, To Catch a Falling Star, and A Discerning Eye.
- Adventuring Fellow entries are deliberately marked unverified because the HorizonXI Wiki currently states that Fellow content is not yet available; they are informational only and do not affect quest availability.
- Native 0x056 Active/Completed quest-state decoding is unchanged.

## v6.9.94
- Quests: adds live catalog completeness totals (Complete / Partial / Basic) across HorizonXI-era quest logs.
- Quests: adds a Catalog gaps only filter to isolate entries still missing core catalog fields.
- Quest Details: shows completeness score, missing metadata fields, and catalog source.
- Quest search now also matches expansion, objective, required items, next-step text, documented requirements, source/status terms, NPC, zone, and rewards.
- Keeps the v6.9.92 HorizonXI Wiki button and leaves native 0x056 ACTIVE/COMPLETED packet decoding and persistence unchanged.


## v6.9.99
- Expands the quest catalog with 106 additional DAT-derived native quest records.
- Adds 65 Jeuno, 32 Other Areas, and 9 Outlands basic name/ID mappings that were not already covered by richer metadata.
- Preserves all existing rich NPC/zone/reward/prerequisite records and leaves native Active/Available/Completed quest-state decoding unchanged.
- Marks these new records as Horizon metadata pending so the catalog can distinguish verified Horizon details from name/ID coverage.

## v6.9.97
- Quests: major native-ID catalog expansion for San d'Oria and Windurst.
- Adds basic catalog records for previously unmapped native quest IDs so the Details panel can show the quest name and HorizonXI Wiki link immediately.
- Existing rich metadata continues to override these basic records; Active/Completed 0x056 decoding is unchanged.


## v6.9.99
- Quest catalog expansion: added the remaining 14 Aht Urhgan native DAT name/ID mappings from the bundled ToAU quest map.
- Completes name coverage for every quest ID currently present in `modules/questmaps/toau.lua`.
- Existing rich metadata records continue to take precedence; new entries are basic metadata pending Horizon-specific enrichment.
- Native Active / Available / Completed quest-state decoding is unchanged.


## v6.10.0
- Begins full rich quest-catalog enrichment for supported HorizonXI regions.
- Adds verified NPC, coordinates, fame, and reward metadata for 46 San d'Oria/Windurst quest records from HorizonXI Wiki city quest tables.
- Leaves native Active/Completed quest-state packet decoding unchanged.
- Crystal War / Wings of the Goddess remains excluded because it is not currently available on HorizonXI.


## v6.11.1

- Adds a bulk quest-catalog build pipeline under `tools/build_quest_catalog.py`.
- Adds JSON/CSV source ingestion with field-level source priority: manual overrides > HorizonXI > FFXIclopedia historical (September 2007 or earlier) > DAT identity/name.
- Enforces the September 30, 2007 FFXIclopedia cutoff during catalog builds. Post-cutoff historical records fail validation instead of silently entering the catalog.
- Adds generated runtime metadata overlay `data/quest_metadata_generated.lua`, loaded conservatively after the existing hand-curated catalog so historical imports fill gaps without erasing verified Horizon data.
- Adds manual per-field override support for corrections.
- Adds automatic provenance, conflict, gap, and regional coverage reports under `catalog/reports/`.
- Adds CSV/JSON templates and a documented source workflow under `catalog/`.
- Seeds the pipeline with the 10 latest Kazham/Outlands HorizonXI enrichments as a working example and regression test.
- Pipeline scope is San d'Oria, Bastok, Windurst, Jeuno, Other Areas, and Outlands; Crystal War/Wings of the Goddess remains excluded.
- Native 0x056 Active/Completed quest-state decoding is unchanged.


## v6.10.3

- Continues quest catalog enrichment with a Kazham/Outlands pass sourced from HorizonXI Wiki.
- Enriches 10 existing Outlands records with additional fame, rewards, required items, objectives, and search metadata where documented.
- Leaves native Active / Completed quest-state decoding unchanged.


## v6.10.2
- Added explicit **Can I start this?** status in Quest Details with readable blocked/unknown reasons.
- Added per-region catalog enrichment progress to quest-region headers.
- Added field-specific catalog gap filters for NPC, Zone, Objective, Reward, and Prerequisite data.
- Expanded overall catalog summary with enriched-record percentage.
- Available rows now distinguish **CAN START** from requirements that still need verification.
- Native 0x056 Active/Completed decoding is unchanged.


## v6.10.2
- Continued rich quest cataloging with additional San d'Oria records verified against HorizonXI Wiki quest pages/tables.
- Added item/objective detail for The Merchant's Bidding and Unexpected Treasure, plus NPC/location/fame/reward enrichment for Blackmail, The Setting Sun, and Warding Vampires.
- Catalog provenance remains explicit; FFXIclopedia is permitted only for information verified as September 2007 or earlier.
- Native 0x056 quest-state decoding is unchanged.

## v6.84.30
- Expanded 0x055 key-item bitmap handling beyond the old fixed 0-6 table range so higher permanent key-item tables are retained instead of discarded.
- Generic quest key-item requirements can now resolve ownership from those permanent-KI tables by name, while retaining the live `HasKeyItem()` fallback when a specific table has not arrived yet.
- Added an internal all-owned key-item enumerator over every received 0x055 table for future Character Info / diagnostics use.
- Updated key-item diagnostics to report the actual number of received tables instead of assuming exactly seven.


## v6.84.37
- Fixed permanent key-item prerequisite detection to mirror Ashita ItemWatch: HorizonCheck now queries `IPlayer:HasKeyItem(id)` directly for every exact resource-name candidate before falling back to the 0x055 bitmap.
- Handles duplicate/legacy key-item resource names instead of stopping at the first matching resource ID, preventing false `NOT OWNED` results for permanent key items such as Serpent Rumors.
- Builds and caches a normalized key-item name index once, improving repeated quest requirement checks.