## v7.9.33
- Prepares HorizonCheck for closed beta with a focused `BETA_TESTING.md` guide covering installation, smoke tests, high-risk scenarios, and consistent problem reporting.
- Adds a structured GitHub beta bug-report form for version, install type, UI conditions, reproduction steps, screenshots, and the exported release-health report.
- Adds **Open Reports Folder** to Release Health and Settings plus `/hcheck health folder`, available with Developer Mode off.
- Expands `/hcheck health export` with the detailed deduplicated Diagnostics error list so tester reports include actionable runtime failures.
- Adds release contracts protecting the new-user `Developer Mode = off` default and the beta support workflow.
- Marks tag-built GitHub releases as pre-releases for the closed-beta period.

## v7.9.32
- Fixes the Daily / Weekly **Recipe / Item Wiki** button still being clipped after the Guild Point status wrapped at narrow window widths.
- Anchors the action to the left edge of the Status column on its own responsive line, allowing the complete button and the table row to resize together.

## v7.9.31
- Makes the Guild Point **Recipe / Item Wiki** action resize-safe in Daily / Weekly: it now flows onto its own line inside the Status cell instead of being clipped when the window or table column is narrowed.
- Keeps the full GP status text wrapped to the current table-column edge while allowing the row height to expand naturally.
- Applies the same responsive layout to the detailed Guild Points requested-item actions so the Recipe button stays visible at narrow window widths.

## v7.9.30
- Fixes a false EXP Ring weekly-complete notification that could fire while logging into or switching to another character.
- Reusable-item inventory caches are now explicitly character-owned and are cleared whenever the active character changes.
- The first live charge observation for each reusable item after login/character switch is treated as a baseline only, so an older saved charge count cannot be mistaken for a recharge.
- Genuine same-session charge increases and capture-verified NPC recharge dialogue still update EXP Ring tracking normally.
- Changes the completion notification wording from `fully recharged` to the more accurate `recharge confirmed`, avoiding misleading messages for non-max charge increases.

## v7.9.29
- Adds a daily Guild Point item-count helper for **Goldsmithing** using HorizonXI's server-specific Guild Points/Items values.
- After the Guild Union NPC reveals today's request, the compact status now shows the number of NQ items needed to reach the daily GP cap (for example `Need 2 NQ`).
- Uses the NPC's live `GP remaining` value when available, so the count automatically decreases after partial turn-ins; otherwise it derives the starting target from the item's HorizonXI daily cap.
- Adds a detailed `Daily item target` line with GP per NQ item and the daily cap, while unknown/unverified requests fall back safely instead of guessing.

## v7.9.28
- Polishes **Overview** with dynamic status wording so cards read `COMPLETE`, `READY`, `NO ENTRY`, `RESET`, or `x LEFT` instead of forcing every state into a fraction.
- Keeps the exact counts as subdued secondary notes and adds richer hover details for Daily, Avatars, Weekly, Dynamis, Limbus, Outposts, current-job progression, and collection cards.
- Adds lightweight in-memory **session change indicators** such as `+1 objective this session`, `+1 piece this session`, and earned EXP since the addon/session baseline; these reset on reload and never write to saved state.
- Replaces long free-form Other Character headers with an aligned six-column comparison (`Character | Job | Daily | Weekly | Dynamis | Seen`) while keeping each character collapsed by default.
- Expanding an offline character exposes a second aligned detail row for Jobs at 75, Avatars, Limbus, Outposts, Last Seen, and reset-scoped data freshness.
- Adds subtle separators between Current Character, Other Characters, and Shared Account so the dashboard reads as distinct sections without adding large visual blocks.
- Preserves the v7.9.26 performance baseline: all new Overview behavior is read-only, cached/in-memory, and performs no new inventory or ownership scans.

## v7.9.27
- Redesigns **Overview** into a more visual character command center while keeping it a true status overview rather than a planner.
- Adds a bordered identity panel for the logged-in character with live job/level, EXP toward Lv.75, Overall %, mapped quests, Maat, and capped combat-skill summary.
- Replaces the old label/value grid with responsive dashboard cards for Jobs at 75, Outposts, Daily, Avatars, Weekly, Dynamis, and Limbus.
- Adds a dedicated **Current Job** card group with level, Overall %, Maat, mapped quests, skills, and last-known AF / AF+1 / Relic / Relic -1 collection totals.
- AF / Relic summaries are persisted only when Character Info or another collection screen has already performed the full ownership scan; Overview never starts a new 17-container inventory scan, preserving the v7.9.26 performance baseline.
- Keeps other account characters collapsed by default with compact reset/entry/last-seen information and a cleaner expanded card layout.
- Simplifies **Shared Account** to Characters, Assault Tags, and the shared Dynamis pool.
- Keeps progress bars, Missions, Anniversary, Seasonal rewards, and What-to-Do-Next content out of normal Overview.

## v7.9.26
- Backend performance cleanup aimed at reducing intermittent in-game hitches.
- Coalesced legacy `state.save()` calls into deferred writes; unload still flushes state immediately.
- Reusable-item/EXP-ring tracking now handles normal `0x020` updates by re-reading only the changed slot instead of scanning all inventory/storage/wardrobe containers.
- Removed noisy reusable-item invalidation from generic `0x01D/0x01E/0x01F` packet traffic.
- Global Attention urgency is evaluated on a small cache instead of sorting planner rows every rendered frame.
- Overview no longer recomputes hidden Missions/Anniversary/Seasonal summaries that were removed from the visible dashboard.
- Increased read-only Overview cache windows while preserving event/zone invalidation.

## v7.9.25

- Fixes a likely rhythmic ~10-second stutter while HorizonCheck is open by making the shared collection scan token depend only on the native inventory update counter instead of the five-second cache timestamp.
- Account Item Locator no longer rebuilds its saved 17-container inventory snapshot merely because another tracker refreshed the shared collection cache.
- Clients without `GetContainerUpdateCounter()` now use a two-minute Account Item Locator safety refresh rather than a ten-second full-scan cadence.
- Keeps manual `Refresh Items` behavior unchanged for immediate on-demand snapshot refreshes.

## v7.9.24

- Redesigns **Overview** as a compact character/account dashboard without progress bars.
- Gives the logged-in character a focused live summary with EXP-weighted current-job progression, jobs at 75, Outposts, Daily, Avatars, Weekly, Dynamis, and Limbus.
- Replaces the wide saved-character table with compact collapsed character cards; expanding a character shows Jobs at 75, Avatars, Limbus availability, Outposts, and last-seen age.
- Keeps a dedicated **Shared Account** block for Assault Tags and the shared Dynamis pool.
- Makes current-character Overview values act as navigation links when the ImGui click API is available, including deep links to Job Progression, Daily / Weekly sections, Dynamis, Limbus, and Outposts.
- Adds the missing Outposts navigation focus so Overview can open **Conquest / Outpost Details** directly.
- Keeps Missions, Anniversary, Seasonal rewards, planner suggestions, timestamps, evidence labels, and progress bars out of the normal Overview.

## v7.9.23

- Simplifies the true Overview by removing Missions, Anniversary, and Seasonal reward progress from the current-character summary.
- Removes Missions and Events from the saved-character comparison; the comparison now keeps Outposts as the permanent progression field alongside reset/entry status.
- Keeps those trackers fully available in their dedicated tabs; this change only reduces Overview density.

## v7.9.22

- Adds the logged-in main job's EXP-weighted progression line directly to Overview: `Lv.x/75 | EXP earned/801,350 | Mapped quests x/y | Overall z%`.
- Reuses Character Info's existing live EXP curve and mapped-job-quest planner so Overview and Job Progression always report the same numbers.
- The equipped job continues to include live current-level EXP, so Overall progress moves as EXP is earned.

## v7.9.21

- Rebuilds the normal **Overview** as a true character/account status page instead of another **What to Do Next** planner.
- Adds a dedicated **Current Character** summary with live job/level, jobs at 75, missions, Daily Objectives, avatar fights, full 13-part Weekly Objectives progress, Dynamis/Limbus entries, Outposts, Anniversary, and Seasonal reward progress.
- Adds an always-visible **Other Characters** comparison for saved account characters, including last-known job/level, jobs at 75, reset progress, Dynamis/Limbus, missions, outposts/events, and data freshness.
- Adds a compact **Shared Account** summary for saved character count, Assault Tags, and the shared Dynamis entry pool.
- Uses live `weekly.progress()` and avatar status for the logged-in character while keeping offline reset-scoped values explicitly expired after their reset.
- Keeps the detailed action planner only in Developer Mode because the global Attention / Next Up strip already owns action-oriented guidance.

## v7.9.20

- Simplifies the normal Overview by removing the **More Suggestions** section.
- Removes **Things to Prepare** from the normal Overview so lower-priority readiness information no longer overwhelms the dashboard.
- Keeps **What to Do Next** as the focused action list; detailed planning remains available in Developer Mode.

## v7.9.19
- Changes the **2023 - 1st Anniversary Scavenger Hunt** year section to start **collapsed** after addon load/reload, matching the 2024 and 2025 Anniversary sections.
- The section still stays open or closed for the current session after the player explicitly toggles it.
- Adds a regression contract so the 2023 Anniversary section does not accidentally return to default-open behavior.

## v7.9.18
- Changes Character Info job **Overall** progress from the old `level / 75` ratio to the actual classic/HorizonXI EXP curve from Lv.1 to Lv.75.
- Uses **801,350 total EXP** as 100%, so later levels correctly account for much more progression than early levels.
- Includes current-level EXP for the actively equipped main job through Ashita's live `GetExpCurrent()` value; other jobs use the cumulative EXP required to reach their saved level.
- Expanded job rows now show cumulative EXP explicitly, for example `EXP 441,850/801,350`, alongside mapped quest progress.
- Adds regression coverage that locks the Lv.75 total at 801,350 EXP and prevents a return to the old level-count percentage.

## v7.9.17
- Adds a shared **Reusable Item** framework for charge-based gear so item modules can use one inventory-Extra parser, cached scanner, event stream, and state record instead of maintaining separate charge logic.
- Moves EXP-ring charge scanning onto that shared framework while preserving the existing low-cost `rings.scan()` compatibility cache.
- Automatically records EXP-ring uses when inventory charge data decreases, so the displayed charge count follows actual ring use without a manual checkbox.
- Uses the capture-verified Emitt recharge dialogue to set **Empress Band** to **10/10**, record the Conquest Point cost, and mark the weekly EXP-ring recharge complete immediately.
- Protects NPC recharge dialogue from packet-order races so an older inventory update cannot briefly look like a ring use immediately after a full recharge.
- Upgrades the Daily / Weekly EXP Ring row to show the live ring name, charge count, charge state, and whether this week's recharge has been used.
- Integrates EXP-ring charge state into **What to Do Next**: empty or low-charge rechargeable rings surface automatically when the weekly recharge is still available, while full or already-recharged rings stay out of the way.

## v7.9.16
- Merges **Account Item Locator** into the global **Find anything** search so HorizonCheck has one search box instead of two.
- Global search now counts both tracker matches and saved-character item-location matches in one result total.
- Adds **Refresh Items** beside the global search to refresh the current character's saved account inventory snapshot without visiting Character Info.
- Removes the redundant Account Item Locator panel from Character Info while keeping its saved snapshots, background refresh, and account-wide location results intact.
- Improves the empty-result wording so item-only matches no longer appear underneath a misleading "no tracker records" message.

## v7.9.15
- Adds a **Universal Ownership Engine** that becomes the shared item-ownership path for Assault rewards, Limbus, HENM, Seasonal Events, Sea/Sky, Anniversary items, and Account Item Locator ID resolution. It reuses the existing cached inventory/wardrobe scan and includes Porter Moogle proof plus saved offline-character snapshots.
- Adds account-wide ownership queries that distinguish **live current-character** ownership from **saved offline-character** locations instead of treating old snapshots as live data.
- Expands the self-healing engine to repair case-insensitive duplicate saved character profiles, safely prune retired presentation/cache fields across every saved character, and normalize impossible Black Coffin chain/lockout/mirror combinations.
- Adds shared UI table primitives and begins migrating large collection tables onto the same widths/header/status treatment, including Assault Point rewards, Limbus boss armor, and HENM reward tables.
- Routes collection-heavy modules through the ownership facade rather than each module calling the low-level skills inventory helpers directly, reducing duplicated ownership logic and future Wardrobe/Porter detection inconsistencies.
- Extends release regressions to enforce the universal ownership path, self-healing repairs, and shared table primitives.

## v7.9.14
- Adds a central low-cadence **present scheduler** so HorizonCheck no longer guarded/profiled-calls every background subsystem on every rendered frame. Time-sensitive capture/KI work stays responsive while saves, integrity, zone sync, automation, Currency refresh, and other background polls run only as often as needed.
- Skips the entire protected UI draw boundary while the HorizonCheck window is closed, reducing idle addon overhead without changing the Shift+C hotkey or event-driven tracking.
- Moves **Account Item Locator** refresh out of the per-frame UI path and into a one-second visible-window scheduler; its existing inventory update token still prevents unnecessary container scans.
- Converts the central **Progression** engine from a forced five-second rebuild/save loop to batched event-driven invalidation with a 60-second safety reconcile. Systems snapshots are reused from cache and state is saved only when a progression state actually changes.
- Removes render-time Currency refresh calls from Assault rewards, ISNM status, and Limbus; the shared Currency scheduler remains the single refresh owner for ISP, AP, HAAP, and Ancient Beastcoins.
- Reduces zone-transition work: Seasonal collection ownership is invalidated and rebuilt lazily instead of force-scanning inventory during zone reconciliation, while permanent historical backfill runs once per character each session and then at most every ten minutes.
- Expands release performance contracts/regressions to protect the scheduler, lazy zone work, event-driven progression, and no-duplicate Currency behavior from future regressions.

## v7.9.13
- Adds an **Account Intelligence** layer to Overview: current Black Coffin state/entry cost, affordable Assault rewards from live AP balances, and clear Limbus entry readiness can now compete directly in **What to Do Next**.
- Makes **What to Do Next** rank signals from current zone, weekly state, held entry items, currencies, and collection ownership instead of relying only on isolated activity rows.
- Adds reset-safe account freshness semantics: expired daily/avatar/weekly values from offline characters now render as unavailable instead of misleading `0/x` progress, while permanent job/progression data remains saved.
- Adds a shared UI status vocabulary (`OWNED`, `COMPLETE`, `AVAILABLE`, `AFFORDABLE`, `ACTIVE`, `READY`, `NOT NEEDED`, `LOCKED`, `MISSING`, `CHECKING`) plus shared freshness badges for live/saved/reset data.
- Migrates Assault reward, Limbus boss-gear, and HENM reward collection rendering onto the shared status framework as the first unified-table pass.

## v7.9.12
- Turns **Assault Point Rewards** into a purchase planner: affordable unowned rewards sort to the top, insufficient rewards show exactly how many AP are still needed, and owned rewards move to the bottom.
- Adds per-area reward summaries with affordable, owned, and remaining counts while preserving the aligned live-AP collapsible headers.
- Simplifies the normal **Black Coffin** view around the current/next mission, entry cost, live state, and time until the next Conquest tally. Manual Complete/Fail and no-time-limit Capture controls now stay in Developer Mode.
- Adds GitHub Actions validation on main/PRs and automatic tagged releases. Pushing a matching `vX.Y.Z` tag runs the complete `prepare_release.py` audit suite and publishes the validated ZIP with release notes from `CHANGELOG.md`.
- Adds repository-wide LF line-ending rules and a shipped `.gitignore` so Windows GitHub Desktop updates stay clean and user/capture files are not committed accidentally.

## v7.9.11
- Aligns all **Assault Point Rewards** collapsible headers into fixed-width columns so area, progress, AP balance, vendor, and location line up vertically.
- Right-aligns the live AP balance column for faster scanning while keeping the existing collapsible behavior and automatic Currency refresh.

## v7.9.10
- Shows the current Assault Point balance directly on each area collapsible header in **Assault Point Rewards**.
- Reads all five standard area-specific AP pools automatically from the shared native `0x113` Currency payload: Leujaoam, Mamool Ja, Lebros, Periqia, and Ilrusi.
- Reuses HorizonCheck's globally throttled Currency refresh, so opening the Assault tab does not add duplicate packet requests.

## v7.9.9
- Updates ISNM Imperial Standing automatically from HorizonXI's native `0x113` Currency payload instead of requiring another Shajaf visit.
- Uses the capture-verified little-endian ISP field at byte offset `0x7C`; the known sample maps `19 05 00 00` to 1,305 ISP.
- Adds one shared, throttled Currency refresh for HAAP, Ancient Beastcoins, ISP, and other `0x113` listeners so HorizonCheck does not send duplicate refresh requests.
- Refreshes Currency data on load and approximately once per minute while HorizonCheck is running; ISNM status now shows `ISP: <value>` instead of the stale `ISP seen` label.
- Keeps Shajaf eligibility/order evidence separate from numeric ISP, so an automatic balance refresh cannot falsely rewrite ISNM eligibility.

## v7.9.8
- Automates the full successful Black Coffin weekly chain using the supplied HorizonXI captures.
- Halshaob's verified payment/acceptance dialogue now moves each stage from **NEXT** to **ACTIVE**, and Ashu Talif entry moves it to **IN PROGRESS**.
- The verified `Objective complete. You may return on the lifeboat.` system message now completes the active stage automatically and advances the next mission; finishing Targeting the Captain marks the weekly chain **3/3 COMPLETE**.
- Keeps manual Complete/Fail buttons as fallback controls and keeps Black Coffin Capture in manual-stop, no-time-limit mode.
- Adds release regression checks so the generic objective-complete line can only advance Black Coffin while a tracked Ashu Talif run is already in progress.

## v7.9.7
- Changes Black Coffin **Capture** to manual-stop mode with no automatic timeout.
- A Black Coffin capture now keeps running until **Stop** is pressed (or `/hcheck learn stop` is used), so long battlefield runs can be captured in one report.
- Updates the Black Coffin capture tooltip to make the no-time-limit behavior explicit.

## v7.9.6
- Combines the two **Account / Characters** tables into one compact account-status table.
- Keeps **Jobs at 75**, **Daily**, **Avatars**, **Weekly**, **Dynamis**, **Limbus**, and **Last Seen** on one row per character.
- Removes the **Missions**, **Events**, and **Overview** columns from the account panel to reduce clutter.

## v7.9.5
- Adds a compact **Daily / Weekly Status** table to Overview → Account / Characters for every saved character.
- Shows Daily Objectives, Daily Avatar fights, Weekly Objectives, Dynamis entries, and Limbus entries side by side.
- Ignores stale prior-reset daily/weekly flags on offline characters.
- Moves long-term character data into a separate cleaner Progression table and removes duplicated Dynamis/Limbus columns there.
- Weekly sorting now includes unfinished weekly objectives in addition to open Dynamis/Limbus entries.

## v7.9.4
- Fixes garbled/binary item names appearing in the Account Item Locator on some Ashita resource layouts.
- Validates resource display strings before saving them and rejects unreadable fixed-buffer data instead of showing it as an item name.
- Filters bad names already saved by v7.9.2/v7.9.3, so old corrupted-looking rows disappear without requiring manual state cleanup.
- Current-character inventory snapshots automatically rebuild once on v7.9.4; known tracked items on other characters can still be identified from their saved item IDs.

## v7.9.3
- Moves **Account Item Locator** to the very top of Character Info so it is immediately accessible instead of appearing below the long character/progression sections.
- Keeps a clean separator between the locator and the rest of Character Info.

## v7.9.2
- Fixes Account Item Locator searches returning no results after character inventories were saved.
- Stores multiple Ashita resource-name aliases for each inventory item and supports fixed-char-array / FFI resource names used by some HorizonXI clients.
- Existing v7.9.0/v7.9.1 saved snapshots are now searchable by their item IDs through HorizonCheck's universal tracked-item catalog, so known gear such as Homam can work without re-logging every character.
- Adds `Saved inventories: X characters | Y item entries` to the locator so it is obvious whether account snapshots were actually populated.

## v7.9.1
- Fixes Daily Avatar fights incorrectly showing COMPLETE while their entry key item is still held.
- A currently held Tuning Fork / Vial of Dream Incense now overrides and clears any false inferred completion for that avatar.
- Requires the key item to remain absent for several seconds after previously being observed HELD before marking the fight complete, preventing brief key-item loading gaps from creating false completions.
- Existing false Titan / Diabolos completions self-repair as soon as HorizonCheck sees their key items are still held.

## v7.9.0
- Expands the universal **Find anything** search to cover Assault Point rewards, Limbus areas/materials, HENM fights/rewards, and Seasonal event rewards, with GO navigation into the matching tracker.
- Adds an **Account Item Locator** at the bottom of Character Info and directly beneath global search results. Each character saves a compact inventory/storage/Wardrobe snapshot while HorizonCheck is open, allowing item-location searches across saved characters.
- Adds a shared collection-table style and applies it to Assault Point rewards, Limbus Homam/Nashira collection, and HENM reward tables: owned items stay bright, missing items stay quiet, status uses a compact check, and location gets its own column.
- Adds exact-section navigation for Assault Point reward areas, Limbus sections, HENM fight details, and Seasonal event groups.
- Account item snapshots refresh only when the game's inventory update token changes, reusing HorizonCheck's existing cached container scan.

## v7.8.35
- Hides the Black Coffin **Capture** buttons for normal users.
- Capture controls remain available in Developer Mode for route/reward troubleshooting.
- Complete and Fail controls are unchanged.

## v7.8.34
- Aggressively simplifies Overview for normal/new users.
- Replaces the old filter bar, counts, five-column action table, duplicated current-zone list, and always-visible readiness detail with one compact **What to Do Next** list.
- Shows only the six best `BEST / HERE / NOW / READY` actions with a simple GO button; reasons move to hover help instead of taking another column.
- Moves lower-priority prep, soon, and blocked items into a collapsed **More Suggestions** section.
- Replaces Content Readiness with a collapsed **Things to Prepare** section using simple `Content / What it needs / Go` wording.
- The old full planner and zone-intelligence views remain available under **Advanced Planner** in Developer Mode only.

## v7.8.33
- Tightens the Events → Seasonal reward table columns so the layout holds up better when the addon window is narrower.
- Renames `How to Obtain` to `Source` and slightly reduces all three column widths.
- Shortens long status tags such as `WARDROBE 8` to `W8`, `HISTORICAL 2025` to `Older 2025`, and `NOT AVAILABLE THIS YEAR` to `Not this year` to prevent ugly wrapping.

## v7.8.32
- Simplifies player-facing wording inside the addon UI so normal tabs read more naturally.
- Replaces technical labels such as `AUTO`, `VERIFIED`, `KI VERIFIED`, `native`, and `synchronize` in standard gameplay views with friendlier wording.
- Cleans up Weekly, Chocobo Riding, Assault, Mission History, Seasonal Events, HAAP, and Character Info helper text while keeping technical details available in Developer Mode and Diagnostics.

## v7.8.31
- Rewrites normal in-game chat notifications in plain, player-friendly language.
- Removes developer labels such as `AUTO`, packet terminology, verification-source tags, native/evidence wording, and similar implementation details from normal chat.
- Developer Mode still shows the original technical messages for troubleshooting.
- Simplifies `/hcheck` help for normal users while keeping the full command list in Developer Mode.

## v7.8.30
- Consolidates the standalone **Anniversary** and **Seasonal** tabs into one cleaner **Events** tab.
- Events contains separate collapsible **Anniversary** and **Seasonal Events** sections with compact progress totals.
- Preserves all existing Anniversary year trackers and Seasonal reward collection data without changing completion state.
- Old Anniversary / Seasonal navigation automatically opens the matching Events subsection.
- Removes the old Anniversary and Seasonal visibility toggles and replaces them with one **Events** toggle.

## v7.8.29
- Moves each HENM fight's editable Notes field out of the compact tier table and into that fight's detailed panel.
- Notes now appear between Strategy/Hard Mode information and Rewards, keeping the top Tier 1 / Tier 2 tables cleaner and easier to scan.
- Existing saved HENM notes are preserved because the same per-fight note keys are reused.

## v7.8.28
- Adds a dedicated **HENM** tab directly after Limbus for HorizonXI's currently available Tier 1 and Tier 2 Hyper Empty Notorious Monsters.
- Adds compact fight tables with zone, all known ??? spawn coordinates, pop-item readiness/location, weekly EXP/Cerulean Shard rewards, personal notes, and HorizonXI Wiki GO links.
- Adds fight-detail panels with enemies, key mechanics, strategy notes, Tier 2 Hard Mode triggers/cosmetics, and per-fight reward ownership/location tracking.
- Adds an aggregate HENM reward collection view using the same inventory/storage/Wardrobe detection as other collection trackers.

## v7.8.27
- Adds a persistent **Notes** column to every Apollyon and Temenos route in the Limbus tab.
- Rebalances/shrinks the existing Area, Status, Entry, Reward, AF+1 focus, and Time columns so Notes fits cleanly before the GO button.
- Notes save immediately per character and per Limbus route and survive reload/logout.

## v7.8.26
- Adds a **GO** button to every job row in Limbus -> AF+1 Upgrade Materials.
- GO opens **Character Info -> Job Progression**, expands the selected job, and scrolls directly to its AF / AF+1 progression details so the obtained +1 pieces can be reviewed immediately.

## v7.8.25
- Fixes Limbus Entry-column wrapping on Central Apollyon / Central Temenos rows.
- Cards and chips now render as clean stacked requirement lines instead of inline fragments that could collapse to one character per line.
- Held cards/chips remain white; missing requirements remain grey.
- Gives the Entry column a little more width for multi-chip routes.

## v7.8.24
- Limbus entry requirements now render held cards and chips in white text instead of all-grey text.
- Required cards show white when the key item is owned, and required chips show white when they are present in inventory, storage, or wardrobes.
- Mixed entries now make it much easier to see which Central Apollyon / Central Temenos prerequisites are already ready.

## v7.8.23
- Corrects Limbus Ancient Beastcoin tracking: Beastcoins are stored in the native Currency menu, not physical inventory.
- Reads Ancient Beastcoins from the native 0x113 Currency packet and displays `Ancient Beastcoins Stored`.
- Requests a fresh Currency sync when Limbus data is missing or stale instead of scanning inventory/Wardrobes for a nonexistent physical stack.

## v7.8.22
- Adds a dedicated **Limbus** tab after Dynamis with every current Apollyon and Temenos battlefield, dynamic entry readiness, card/chip requirements, completion-chip chains, time limits, and HorizonXI Wiki guide buttons.
- Adds an **AF+1 Upgrade Materials** collection table for all 18 HorizonXI jobs, pairing each job's Apollyon and Temenos material with live inventory/storage/Wardrobe locations and existing AF+1 completion progress.
- Adds **Proto-Omega / Proto-Ultima armor** tracking for Homam and Nashira pieces, including the required boss part and obtained/storage location.
- Shows weekly Limbus usage (0/2 through 2/2), Cosmo-Cleanse state, reset countdown, and Ancient Beastcoin count in one compact header.
- Keeps Wings-era DNC/SCH materials out of the main HorizonXI job tables while preserving current HorizonXI Limbus zone structure.

## v7.8.21
- Adds a sleek **Assault Point Rewards** collection section to the bottom of the Assault tab.
- Lists all 55 standard vendor rewards across Leujaoam Sanctum, Mamool Ja Training Grounds, Lebros Cavern, Periqia, and Ilrusi Atoll with Assault Point costs.
- Shows **OBTAINED / MISSING** and live Inventory / Storage / Locker / Satchel / Sack / Case / Wardrobe 1-8 location information, with Porter Moogle fallback when known.
- Excludes Nyzul Isle because its reward currency is Tokens rather than standard area-specific Assault Points.

## v7.8.17 — Level-Only Job Progress

- Removes aggregate AF/Relic gear counts from the compact Job Progression rows and section summary in Character Info.
- Simplifies each job's `overall` percentage to level progress only: current job level divided by the Lv.75 cap.
- Keeps AF/Relic ownership, missing-gear tools, mapped quests, and Maat status available inside each expanded job without letting them change the displayed level percentage.
- Removes the redundant `[75]` suffix from Lv.75 job headers; Lv.75 now naturally reads as `100% overall`.

## v7.8.15 — Black Coffin UI & Reward Refresh

- Replaces the tall Black Coffin mission/reward stack with a compact table-based layout matching the cleaner Chocobo Riding presentation.
- Keeps Complete / Fail / Capture actions directly on each weekly chain row while consolidating NPC and entry-cost information.
- Replaces three expanded reward panels with one compact reward table covering lockbox counts, notable rewards, and bonus conditions.
- Cross-checks rewards against the current HorizonXI Wiki: Scouting 1-2 lockboxes with Swiftwinged Gekko bonus appraisals; Royal Painter up to 3 lockboxes with Koga Shuriken (100%), Yoichi's Sash, headpiece/box appraisals; Targeting up to 3 lockboxes with first-clear Mog Wardrobe 3 +5 slots, Koga Shuriken, Barbarossa gear, and box appraisals.
- Keeps the UI explicit that complete Horizon-specific reward pools and drop rates still require live verification where the wiki says so.

## v7.8.14 — Weekly EXP Scrolls Deduplication

- Removes **Chocobo Riding Game** from the **Weekly EXP Scrolls** section because the activity is already tracked under **Weekly Objectives**.
- Weekly EXP Scrolls progress totals now count only the remaining five scroll-source objectives.
- Chocobo Riding Game tracking, rewards, run history, and Weekly Objective completion behavior are unchanged.

## v7.8.13 — Weekly EXP Scrolls Cleanup

- Removes the redundant **HAAP Weekly Scrolls** aggregate row from Weekly Objectives; the two HAAP scrolls remain tracked individually under **Weekly EXP Scrolls**.
- Adds **resets with Conquest tally** to the Weekly EXP Scrolls section header, matching the Weekly Objectives reset wording.
- Weekly Objectives progress totals now exclude the removed HAAP aggregate row automatically.

## v7.8.12 — Weekly EXP Scrolls Label

- Renames the **Dragon Chronicles / EXP Scroll Sources** section to **Weekly EXP Scrolls** for a shorter, clearer Daily / Weekly label.
- Tracking behavior and all six EXP-scroll sources are unchanged.

## v7.8.11 — Outpost Setup Step

- Adds a fifth beginner-friendly Initial Synchronization step for current Outpost ownership.
- New users are told to talk to their nation Outpost NPC, open Regional Teleport, and page through the menu once so HorizonCheck can learn the character's currently unlocked outposts.
- The step completes only from a trusted Regional Teleport menu synchronization and then remains a permanent first-run milestone, just like the Eeko-Weeko, Rytaal, and fame-checker setup steps.
- Existing trusted Outpost menu evidence is promoted automatically, so characters that already synchronized their outposts do not have to repeat the step.
- The setup panel refreshes immediately after a successful trusted Outpost scan.

## v7.8.10 — Beginner-Friendly Initial Synchronization

- Replaces the technical first-run synchronization wall with four plain-language steps: change zones once, talk to Eeko-Weeko once, talk to Rytaal once, and visit each supported fame/reputation checker once.
- Groups mission history, permanent key items, historical Assault clears, historical progression, zone reconciliation, and progression reconciliation under the single action the player actually needs to take: change zones once.
- Hides schema, release-manifest, storage, inventory, and other technical setup rows from normal users while preserving the complete row list under Developer Details.
- Keeps critical automatic setup failures visible as one simple attention message that points the user to Diagnostics.
- Simplifies the completion report and renames the actions to Check Again, Hide for Now, and Finish Setup.

## v7.8.9 — Chocobo Route Verification Cleanup

- Removes the Kazham-only `Chocobo Ticket`, `Requirements`, and `Reference` rows from the normal Chocobo Riding display.
- Shows `NPC/route phase` only while Developer Mode is enabled.
- Makes capture verification strictly route-specific: `CAPTURE VERIFIED` is shown only for exact routes backed by a user-supplied HorizonCheck capture.
- Current verified route set is Quelle -> Southern San d'Oria and Orlaine -> Port Jeuno; all other city rotations remain predicted/reference until their own capture is supplied.
- Removes the old city-wide verification shortcut so one captured route can no longer mark sibling routes as verified.

## v7.8.8 — Kazham Chocobo Riding Reference

- Adds a dedicated **Kazham (F-9)** Chocobo Riding Game section directly after Windurst and before Run History / Reward Learning.
- Uses the supplied FFXIclopedia reference data: Tielleque -> Norg, Page from Miratete's Memoirs at <= 2:29, and Chocobo Ticket at 2:30-3:59.
- Shows the Chocobo License + Airship pass for Kazham requirements and the source-noted availability rule that Kazham follows the Bastok Mines -> Windurst Woods schedule.
- Adds Kazham zone ID 250 to live route detection so a future accepted Kazham run is recorded as Tielleque -> Norg instead of falling back to Bastok.
- Kazham personal best, completed runs, latest result, and Run History automatically participate in the existing account-wide Chocobo statistics.
- Keeps the source-derived Kazham route marked as needing HorizonXI capture validation rather than presenting it as capture-verified.

## v7.8.7 — Account-Wide Chocobo Run History

- Aggregates Chocobo Riding route statistics across every character profile stored in the shared HorizonCheck account state.
- Run History is merged newest-first across characters and displays the character name beside each Earth-time/reward result.
- Personal best times now include the character that owns the record.
- Completed-runs counters are summed across all characters for each route.
- Current-route observed reward results are likewise merged account-wide and retain character provenance.
- Weekly Riding Game completion remains character-specific; only permanent run-learning/statistics are shared in the UI.

## v7.8.6 — Post-Feed Re-Examine Tracking

- Separates flowerpot examine credit from crystal-feeding interactions even though both use the same HorizonXI `0x0FA` flowerpot packet family.
- Uses the Moogle `Use this crystal, kupo?` prompt to mark the following pot interaction as a feed action so it cannot increment the daily checked-pot counter.
- On the authoritative successful-feed confirmation, removes that pot's existing daily examine credit and clears **Check Plant Pots** completion until the pot is examined again.
- Reconciles daily completion from the current post-feed examined-pot set on reload, preventing a stale completed checkbox from surviving after a feed.
- Keeps crystal-feed counts independent and informational.

## v7.8.5 — Crystal Feed Detection + Sea Location Separator

- Adds capture-verified Mog House crystal-feed detection from the authoritative `your moogle uses the <element> crystal on the plant.` success message.
- Daily / Weekly now shows the number of successful crystal feeds alongside the existing duplicate-safe unique-pot check count; feed tracking resets with the normal daily plant-pot state.
- Records the crystal element and associates the feed with the most recent verified `0x0FA` flowerpot ID when available, without making feeding a requirement for the existing Check Plant Pots objective.
- Changes Sea / Sky material container formatting from `@ Inv(3), Satchel(5)` to `- Inv(3), Satchel(5)`.

## v7.8.4 — Sea Material Container Locations

- Adds live container locations beside every **In the Name of Science** Obi/Gorget material count in **Sea / Sky**.
- A material in one container shows its location and stack count (for example `@ Satchel(8)`); split stacks show each contributing container (for example `@ Inv(3), Satchel(5)`).
- Supports Inventory, Safe, Storage, Locker, Satchel, Sack, Case, Temp, and all scanned Wardrobes.
- Extends the shared cached collection scan with per-container stack totals, avoiding an extra inventory scan when the Sea / Sky UI renders.
- Completed Obi/Gorget entries continue to show materials as `used` because the quest consumes those materials.

## v7.8.3 — Mission Guide GO Buttons

- Adds a compact **GO** button directly beside each current/next mission name in **Missions → Current Story / Next Mission**.
- Clicking **GO** opens that mission's HorizonXI Wiki guide in the default browser; HorizonCheck performs no background web requests.
- Nation missions use numbered mission pages so names that collide with zones/articles (such as **Full Moon Fountain**) still open the mission guide.
- Zilart and Chains of Promathia use their numbered mission pages; Treasures of Aht Urhgan uses the mission article with explicit overrides for ambiguous titles.
- The action is retained in both the shared responsive table and compact/fallback mission layouts.

## v7.8.2 — Legacy Addon-Folder Cleanup

- After the config-backed state loads and passes state migration/validation, HorizonCheck automatically removes migrated user-generated files from `Game\addons\horizoncheck\`.
- State, state backups, Outpost persistence, captures, guided/mission captures, learning/audit logs, release-health reports, and quest-state reports are copied and byte-verified before their legacy source is deleted.
- If a config destination already exists with different contents, the legacy source is preserved as a `legacy_addon_*` collision archive in config storage before removal from the addon folder.
- Abandoned `horizoncheck_state.lua.tmp`, `.migrate_tmp`, `.write_test`, and write-probe files are removed only after the config state validates.
- Cleanup never runs while HorizonCheck is in addon-folder fallback mode or after a failed state migration; in those cases all legacy sources remain untouched.
- Settings and Diagnostics now report legacy-cleanup completion, removal count, collision archives, and any cleanup failures.

## v7.8.1 — Diagnostics Load Fix

- Fixes the Diagnostics module failing to load after the v7.8.0 external user-data update.
- Correctly escapes the displayed `backups\horizoncheck_state.lua...` and `logs\horizoncheck_audit_<character>.log` Windows paths so Lua no longer treats `\h` as an invalid string escape.
- Restores the full Diagnostics tab so startup self-test details can be inspected normally.

## v7.8.0 — External User Data Storage

- Moves HorizonCheck-generated user data out of `Game\addons\horizoncheck` and into `Game\config\addons\horizoncheck\` on first load when the config path is writable.
- Creates dedicated `backups`, `captures`, `logs`, and `reports` subfolders so addon updates can replace the addon code folder without replacing character state, settings, notes, capture evidence, or diagnostic exports.
- Safely migrates the existing `horizoncheck_state.lua` only after validating the copied state, retains the original addon-folder file as a rollback copy, and copies existing state backups plus legacy Outpost persistence into the new storage area when present.
- Routes future Developer captures, guided captures, mission packet captures, learning/audit logs, quest-state reports, release-health reports, and Outpost persistence to the new config storage tree.
- Falls back to the legacy addon-folder storage automatically if the config path cannot be resolved/written or a legacy state file cannot be safely migrated.
- Adds the active User Data path and storage mode to Settings / Diagnostics.

## v7.7.15 — Windurst Eco-War End-to-End Completion

- Finishes authoritative Windurst Eco-Warrior tracking from the 2026-08-30 capture sequence.
- Correlates Lumomo's captured `Indigested Meat` reward dialogue with the immediately following **Page from the Dragon Chronicles** reward before marking Windurst complete.
- Marks Windurst **COMPLETED THIS WEEK**, clears the active state, updates the 3-nation Eco rotation, and persists the completion through reloads until the normal Conquest-cycle logic advances it.
- Records final completion evidence on the Windurst lifecycle record and keeps stale native ACTIVE bits from overriding the verified completion.

## v7.7.14 — Guild Point Recipe Links

- Adds a contextual **Recipe** button beside the currently detected Guild Point request in Daily / Weekly and in the detailed Guild Points view.
- Opens the requested item's HorizonXI Wiki result in the default browser; Fishing requests use an **Item Wiki** label because fish do not have synthesis recipes.
- Adds a **GP Item List** button linking to HorizonXI's server-specific `Guild Points/Items` master table for all guilds and A-H assignment cycles.
- Recipe linking is offline-safe inside HorizonCheck: no in-game web scraping or network lookup is performed; the exact NPC-detected item name is encoded into the wiki link only when the user clicks it.

## v7.7.13 — Requiem of Sin Completion Tracking

- Adds authoritative weekly completion tracking for **Requiem of Sin (X's Knife)** using the newly captured Boneyard Gully clear behavior.
- Remembers when either Requiem entry key item is held during the current Conquest cycle, then marks the weekly objective complete when that key item is no longer held and HorizonXI reports a successful **Boneyard Gully battlefield clear**.
- Persists the consumed-key-item / clear evidence so the row remains complete through reloads until the next Conquest reset.
- Adds a dedicated Developer Mode **Requiem** capture profile/button so future Requiem evidence no longer needs to be recorded under Eco-Warrior.
- Changes the intermediate status to `KEY ITEM USED | Waiting for verified battlefield clear` when the weekly entry item has been consumed but completion evidence has not yet been observed.

## v7.7.12 — Persistent Attention on Overview

- Keeps the global **Attention / Next Up** section visible when switching to the Overview tab whenever the planner has an urgent `DO NOW` activity.
- Preserves the v7.6.4 empty-state cleanup: if nothing is urgent, the global Attention section remains hidden and consumes no space.
- No planner ranking, objective state, or Overview content was changed.

## v7.7.11 — Sea / Sky Header Polish

- Removes the extra horizontal divider between the main **Sky Gods** and **Sea Bosses** collapsible headers so the three collection sections read as one consistent stack.
- Gives **Elemental Obis / Gorgets** a HorizonCheck-owned open state while retaining the normal collapsible-header appearance.
- Checking or unchecking an Obi/Gorget no longer collapses the section when the live `X/16` total changes; it remains open until the player explicitly closes it.

## v7.7.10 — Obi/Gorget Manual Checkbox Fix

- Fixes the one-frame runtime error that could appear when manually checking an Elemental Obi or Gorget.
- Makes the manual ownership mutation happen before cache invalidation/save work, so a secondary helper cannot cancel the checkbox update.
- Updates the current Sea / Sky ownership snapshot immediately after a manual click so the checkbox latches visually in the same frame.
- Wraps cache invalidation and state-save requests defensively while preserving persistent per-character manual ownership.

## v7.7.9 — Obi/Gorget Material Readability

- Makes each Elemental Obi/Gorget material line turn bright/white once the live owned count meets or exceeds the required amount; unmet and unknown requirements remain dimmed.
- Keeps the explicit `owned/required` quantity on every material so readiness is visible at a glance.
- Groups each left/right Obi/Gorget pair into its own bordered section with a center divider and subtle alternating dark backgrounds for easier scanning.
- Preserves the table-free compatibility renderer introduced in v7.7.8, finished-item manual checks, READY/OWNED/CHECKING states, and live cached material counts.

## v7.7.8 — Obi/Gorget Expansion Runtime Fix

- Fixes the remaining runtime error that occurred only when expanding **Elemental Obis / Gorgets**.
- Removes ImGui table/column usage from the expanded Obi/Gorget body entirely; the section now uses only basic Checkbox / SameLine / Text rendering for maximum HorizonXI Ashita compatibility.
- Keeps Obis visually paired on the left with Gorgets on the right and lists every required material beneath each pair with live owned/required counts.
- Preserves READY/OWNED/CHECKING states and manual finished-item confirmation.
- Isolates each Obi/Gorget pair so one unexpected row-level rendering issue cannot close the entire Sea / Sky tab.

## v7.7.7 — Sea / Sky Obi/Gorget Compatibility Fix

- Replaces the Obi/Gorget four-column renderer with HorizonCheck's existing shared responsive two-column helper that is already used successfully elsewhere in the addon.
- Keeps Obis on the left and Gorgets on the right, but renders each reward/material block as simple text rows instead of a custom multi-column table stack.
- Makes Elemental Obis / Gorgets collapsed by default so simply opening Sea / Sky never executes the organ/material UI path automatically.
- Wraps finished-item and material-state lookups defensively so a failed collection lookup degrades to CHECKING instead of closing the Sea / Sky tab.
- Removes duplicate/obsolete science-render helper code left over from the first two implementations.

## v7.7.6 — Sea / Sky Runtime Fix

- Fixes a runtime error that could close the Sea / Sky tab after the new Obi/Gorget material tracker was added.
- Reworks the Obi/Gorget display into one flat four-column table instead of nested ImGui tables, keeping Obis on the left and Gorgets on the right while avoiding table-stack issues on some Ashita builds.
- Hardens organ/material quantity lookups so a failed inventory-count call cannot take down the whole Sea / Sky tab.
- Keeps live owned/required counts, READY status, finished-item ownership, and manual confirmation behavior unchanged.

## v7.7.5 — Sea Obi / Gorget Material Tracker

- Adds a new collapsible **Elemental Obis / Gorgets** section directly beneath Sea Bosses in the Sea / Sky tab.
- Places all eight Elemental Obis on the left and all eight Elemental Gorgets on the right to keep the section compact.
- Lists the exact `In the Name of Science` base item, chip, organ, and tissue requirements for every reward and shows live owned quantity versus required quantity.
- Finished Obis/Gorgets automatically count as complete and their consumed materials display as already used; unfinished rewards show `READY` when every required material is currently held.
- Extends the shared cached inventory collection scan with per-item counts so organ/material readiness does not require a second independent inventory walk.
- Finished rewards support the same persistent manual ownership confirmation used by the rest of Sea / Sky and are included in Universal Search.

## v7.7.4 — Tighter Assault Notes Alignment

- Moves the Assault **Notes** divider/editor start point left so it sits closer to the mission location instead of splitting the row exactly 50/50.
- Uses a 38% mission/location column and 62% Notes column, keeping the vertical divider consistent while leaving enough room for standard Assault mission/location labels without overlap.
- Notes editors still fill the full right-hand column and retain the same persistent per-character save behavior.

## v7.7.3 — Aligned Assault Notes Layout

- Reworks each Assault rank into a consistent two-column table with **Assault / Location** on the left and **Notes** on the right.
- Adds a fixed vertical divider between mission information and notes so every note editor starts at the same position.
- Notes inputs now fill the available Notes column instead of using different inline starting points based on mission-name length.
- Preserves completion marks, Developer Mode manual completion/capture controls, saved per-character notes, and the fallback renderer for older ImGui bindings.

## v7.7.2 — Requiem of Sin Weekly Objective

- Adds **Requiem of Sin (X's Knife)** directly beneath Uninvited Guests in Weekly Objectives.
- Shows Despachiaire at Tavnazian Safehold (K-10), Boneyard Gully as the battlefield destination, and the once-per-Conquest-cycle cadence.
- Detects either **Letter from Shikaree Y** or **Letter from the Mithran Trackers** as readiness evidence and points the player to Boneyard Gully when held.
- Adds a `Go` button that opens Requiem of Sin directly in Quest Details.

## v7.7.1 — Dragon / EXP Section Table Cleanup

- Reformats the **Weekly EXP Scrolls** subsection inside Daily / Weekly to match the clean table-first presentation used by Daily Objectives and Weekly Objectives.
- Adds aligned **Objective / Status / Notes** columns while preserving the existing hide-completed toggle, automatic source statuses, manual checkboxes, and Developer capture controls.
- Keeps the old line-by-line renderer only as a compatibility fallback for clients without ImGui table support.

## v7.7.0 — Mission / Readiness / Zone Intelligence Upgrade

- Overhauls **Missions** with an action-first `Current Story / Next Mission` summary for the active nation, Rise of the Zilart, Chains of Promathia, and current HorizonXI Treasures of Aht Urhgan content. Native current-mission pointers are preferred when available; ToAU falls back to authoritative completed-mission history and skips future-capped rows.
- Adds current mission objectives to the Overview planner as low-priority progression work with direct `Go` navigation into the relevant Missions section.
- Adds a centralized **Content Readiness** engine covering Dynamis, Limbus, Assault tags, ISNM, ENM, Daily Avatar fights, Eco-Warrior, Black Coffin, and Chocobo Riding using each tracker's existing authoritative state instead of duplicating lockout logic.
- Adds a compact, collapsed-by-default Content Readiness panel to Overview with direct navigation and an optional Show Completed view.
- Upgrades **Zone Intelligence** into a `While You're Here` planner that hides completed content, ranks DO NOW / READY / PREP work, converts incomplete Sea/Sky bosses into gear targets rather than pretending the boss itself is entry-ready, and adds current-zone Outpost and Assault opportunities when supported by tracked evidence.
- Zone Intelligence now suppresses fully completed Sea/Sky bosses and completed Daily Avatar fights and keeps exact NPC/location/key-item details where the underlying tracker already knows them.
- Nation mission fallback is deliberately conservative: if HorizonCheck has not synchronized the native current-nation mission pointer, it shows VERIFY instead of guessing from old unchecked repeatable missions.

## v7.6.8 — Windurst Eco Evidence + Cleanup Pass

- Adds capture-verified Windurst Eco-Warrior lifecycle tracking from Lumomo acceptance through Ahko Mhalijikhari field instructions, level-20 kill phase, Indigested Meat acquisition, and return-to-Lumomo proof confirmation.
- Prevents a stale Windurst native 0x056 ACTIVE bit from promoting a fresh weekly READY state unless HorizonCheck has current-week Lumomo/Ahko or proof-key-item evidence.
- Deduplicates normalized `q[HH:MM:SS]` mirrors in Developer Capture reports so repeated copies of the same dialogue no longer bloat evidence files.
- Removes the retired Dragon / EXP top-level tab visibility state while preserving compatibility navigation into its Daily / Weekly subsection.
- Consolidates EXP Ring reconciliation into one path and caches inventory scans until relevant inventory packets mark the cache dirty.
- Corrects the Notifications help text now that routine HorizonCheck addon-load chat output is intentionally suppressed.
- Fixes a duplicate increment in the Eco-War rotation-count helper.

## v7.6.7 — Runtime Cleanup / Quiet UI

- Reduces normal-play chat noise: low-value automatic state transitions such as ACTIVE / IN PROGRESS / synchronized / packet-confirmed messages are hidden unless Developer Mode is enabled. Meaningful completions, obtained rewards, unlocks, warnings, failures, and errors still announce normally.
- Suppresses the empty **Zone Intelligence** block on Overview when the current zone has no tracked actionable content.
- Prunes obsolete Overview snapshot work that continued scanning weekly, ENM, quest, unlock, and Sea / Sky summaries even though those panels were removed in the recent action-first Overview cleanup.
- Consolidates shared section-header/action rendering into `uikit.lua` and reuses it in Eco-War and Chocobo Riding.
- Consolidates Chocobo and Sea / Sky table flag handling onto the shared UI helper instead of maintaining local copies.
- Package/runtime audit confirms every shipped Lua module is part of the active HorizonCheck load graph; no orphan module was retained.

## v7.6.6 — Quiet Reload Startup

- Removes HorizonCheck's normal startup chat line (`vX.X.X loaded. Quest catalog and runtime trackers initialized.`) on addon load/reload.
- Ashita's own `Loaded addon: horizoncheck version ...` line remains unchanged.
- Self-test failures still print a concise warning and automatically open Diagnostics, so important startup problems are not hidden.

## v7.6.5 — Ovens Lost Post-Reset Zone Guard

- Fixes **Secrets of Ovens Lost** incorrectly changing from fresh-week `READY` to `IN PROGRESS` just from zoning after the weekly reset.
- HorizonXI can resend the quest's stale native `0x056 ACTIVE` bit from the prior completed cycle; HorizonCheck now remembers that the previous cycle was complete and treats that first post-reset ACTIVE observation as diagnostic-only evidence.
- Fresh Jonette request dialogue or verified ownership of the new Tavnazian Cookbook releases the guard and advances the current week's quest normally.
- Suppresses the misleading `AUTO: Secrets of Ovens Lost - IN PROGRESS [0x056 confirms quest ACTIVE]` chat line when the only evidence is that stale post-reset zone packet.

## v7.6.4 — UI Bloat Reduction / Consolidation

- Removes the permanent `Dragon/EXP` counter from the top status line now that Weekly EXP Scrolls lives inside Daily / Weekly; the header now stays focused on Daily and Weekly totals.
- Hides the global **Attention / Next Up** area while Overview is selected and suppresses it completely on other tabs unless an urgent `DO NOW` activity actually exists.
- Makes **Conquest / Outpost Details** collapsible and closed by default; navigation to the Conquest objective opens it automatically.
- Compacts Weekly Objectives to **Objective / Status / Open**. Long explanatory notes are retained as hover help instead of occupying a permanent wide column, and dedicated trackers get `Go` buttons.
- Makes **Account / Characters** on Overview collapsible and closed by default. Expensive profile-summary work is deferred until that optional panel is opened.
- Removes dead Overview renderers for the retired Character, Current Activity, Progression, Events & Collections, and Current Job Gear panels.
- Removes the retired `dashboard.lua` and obsolete standalone `collections.lua` UI modules from the runtime/package.
- Shortens Overview's filter row and removes the ranking-explanation prose so the dashboard remains action-first.

## v7.6.3 — Aggressive Overview Simplification

- Removes the large **Character**, **Current Activity**, **Progression**, **Events & Collections**, and **Current Job Gear** blocks from Overview.
- Overview now stays focused on **What Should I Do?**, **Zone Intelligence**, and the existing **Account / Characters** comparison.
- No underlying tracking data is removed; the deleted summaries remain available in their authoritative tabs such as Daily / Weekly, Missions, Quests, Sea / Sky, Character Info, and Job Progression.

## v7.6.2 — Dragon / EXP Consolidation

- Removes the standalone **Dragon / EXP** tab and moves its full tracker into **Daily / Weekly**.
- Adds a new collapsible **Weekly EXP Scrolls** section directly beneath Weekly Objectives, preserving all six source rows, status details, capture controls, and the independent Hide Completed preference.
- Existing navigation requests for `Dragon / EXP` are redirected to Daily / Weekly and automatically open the new section.
- Removes Dragon / EXP from the Visible Tabs settings because it is no longer a separate tab.

## v7.6.1 — Quest Go Opens Details

- Fixes Overview, Universal Search, and Zone Intelligence `Go` navigation so opening the Quests tab also selects and opens the requested quest in **Quest Details**.
- Quests now consumes the navigation focus payload after the tab is selected instead of only switching tabs.
- Zone Intelligence now carries exact quest log/quest IDs into navigation, with name resolution retained as a fallback for older callers.

## v7.6.0 — Progression Blockers + Sea / Sky QoL

- Adds a dedicated **Progression Blocker Engine** that turns mapped quest requirements into concise player-facing explanations and follows the quest dependency graph to the next actionable prerequisite.
- Locked quest rows, quest details, Job Progression quest blockers, and Universal Search now surface clearer guidance such as `Need <prerequisite> → do <earlier quest> next` instead of stopping at a generic LOCKED state.
- Overview gains a **Blocked** filter so high-impact progression blockers can be reviewed without competing with the normal Best Next actionable recommendations.
- Sea / Sky adds independent **Missing gear only** and **Hide completed bosses** controls for Sky Gods and Sea Bosses.
- Completed boss panels collapse to a compact completion message when Missing gear only is enabled, and fully completed bosses can be removed from the grid entirely.
- Sea / Sky boss completion counts and Zone Intelligence now use the same consolidated Sky NQ/HQ collection-slot totals as the main tracker.

## v7.5.2 — Combined Sky NQ / HQ Collection Rows

- Combines Sky abjuration NQ/HQ variants into a single collection row, for example `Zenith Mitts / Zenith Mitts +1`, because either quality represents the same underlying gear slot.
- Applies the same treatment to differently named NQ/HQ pairs such as Koenig/Kaiser, Crimson/Blood, and Adaman/Armada equipment.
- A combined row is considered obtained when either variant is detected or historically/manual-confirmed, and its location reflects the detected/saved variant.
- Updates Sky completion totals to count one collection slot per NQ/HQ pair instead of requiring both qualities. Direct boss drops remain separate.
- Universal Search receives the combined Sky names as single entries, eliminating duplicate NQ/HQ search results.

## v7.5.1 — Overview Activity Cleanup

- Removes the player-facing **Recent Activity** section from Overview to keep the dashboard focused on current actionable progression.
- Keeps HorizonCheck's underlying timeline/history engine intact for diagnostics, automation evidence, and future tooling; only the Overview rendering was removed.

## v7.5.0 — Actionable Navigation + Job Progression 3.0

- Adds **clickable navigation** from Overview recommendations and Zone Intelligence. `Go` buttons jump directly to the relevant HorizonCheck tab, including Quests, Daily / Weekly, Assault, ENM, Dynamis, Eco-War, and Dragon / EXP.
- Makes Universal Search results actionable with a new **Go** control; Job Gear searches can open the matching job directly, Daily Avatar searches open the avatar section, and Sea/Sky searches open the matching main collection section.
- Upgrades **Job Progression to 3.0** with shorter per-job headers and an action-first `Next Progression` line that prioritizes Maat, actionable mapped job quests, missing AF/Relic gear, blockers, or the remaining level target.
- Removes redundant expanded-job summary lines and replaces them with one compact status line for level, mapped quests, AF/Relic gear, and overall progress.
- Adds a compact **Recent Activity** feed to Overview using the existing persistent timeline, filtered to normal-player automatic changes and progression transitions rather than diagnostics noise.
- Navigation automatically re-enables a destination tab if the player intentionally clicks a link to content whose tab was hidden.

## v7.4.3 — Always-Visible Job Progression

- Removes the redundant outer **Show Job Progression** collapsible header from the Job Progression tab.
- The Job Progression Planner now renders immediately when the tab is opened.
- Individual job sections remain collapsible so the detailed AF/Relic/Maat information can still be folded as needed.

## v7.4.2 — Job Progression Summary Removal

- Removes the large all-job **Progression Summary** table from Job Progression.
- Job level, Maat, AF/Relic ownership, overall progress, and missing gear remain available inside each individual job's progression section.
- Keeps the Job Progression Planner as the primary interface, reducing duplicate information and vertical clutter.

## v7.4.1 — Job Progression Cleanup

- Removes the redundant **Jobs / Levels** roster from the Job Progression tab.
- Keeps live job levels in the Progression Summary table, where they are already combined with Maat and AF/Relic progression.
- Removes the extra explanatory/cached-scan lines that belonged to the duplicate roster so the tab starts directly with the useful progression summary.

## v7.4.0 — Progression Workflow Upgrade

- Upgrades **Job Progression** into a more complete per-job workspace with an all-job progression summary covering level, Maat, AF, AF +1, Relic, Relic +1, Relic -1, and a transparent overall progress score.
- Adds a persistent **Missing gear only** filter inside Job Progression, per-job gear totals in each header, mapped-job-quest completion counts, and a `Next missing gear` callout.
- Upgrades **Overview** to **Progression Dashboard 3.0** with a prominent Best Next action, expanded views for In This Zone, Do Now, Ready Now, Ending Soon, Prep / Verify, Quests, and Activities, plus a current-job missing-gear shortlist.
- Expands the global search into a broader **Universal Search** covering quests, missions, permanent unlocks, ENMs, Daily Avatar fights, AF/Relic job gear, Sea/Sky gear, and tracked systems.
- Search results now show live state, where the objective/item is located, and the HorizonCheck tab that contains the full tracker; exact-name matches are ranked first.
- Search indexing is now character-aware so switching characters cannot temporarily reuse another character's gear/avatar result state.

## v7.3.1 — Remove Redundant Collections Tab

- Removes the standalone **Collections** tab because AF / Relic job gear progression is already covered by **Job Progression**, while Sea/Sky gear remains available in **Sea / Sky**.
- Removes Collections from the Settings > Visible Tabs list so there is no redundant toggle.
- Keeps the internal collection summary engine available for Overview progress totals; this is a UI cleanup only and does not discard saved ownership data.

## v7.3.0 — Progression Intelligence

- Upgrades the Overview into a **Progression Dashboard** with ranked Next Actions based on verified activity state, current-zone quest evidence, key-item readiness, and reset urgency.
- Adds Overview filters for **All**, **Current Zone**, **Activities**, and **Quests**, with compact In Progress/Urgent, Ready Now, and Prep/Verify counts.
- Adds **Zone Intelligence** to the Overview. It automatically surfaces tracked quests, Daily Avatar fights, ENMs, and Sea/Sky bosses relevant to the zone the character is currently in.
- Adds a new **Collections** tab after Sea / Sky. It combines AF, AF +1, Relic, Relic +1, Relic -1, Dreamworld Relic accessories, and Sea/Sky progress into one collection workspace.
- Collections reuses the existing live inventory/wardrobe/Porter-slip scanner, understands irreversible upgrades, and treats Relic +1 as satisfying consumed Relic -1 progression where appropriate.
- Adds a compact all-job gear summary plus a selectable per-job detail view with item locations and a Missing Only filter.
- Adds Sea/Sky and AF/Relic collection totals to the Progression Dashboard's Events & Collections summary.

## v7.2.37 — Compact Diagnostics Workspace

- Reorganizes the Diagnostics tab from dozens of top-level headers into six purpose-based sections: **Health & Errors**, **State & Recovery**, **Detection & Evidence**, **Progression & Sync**, **Performance**, and **Advanced / Developer**.
- Keeps all existing diagnostic capabilities, repair tools, packet/evidence inspectors, history views, and self-tests; only the presentation is consolidated.
- Adds a compact status summary at the top showing Release, Sync, Runtime Errors, State Integrity, and Performance Watchdog state.
- Moves normal troubleshooting actions into Health & Errors and buries low-level catalog/native-ID/system-engine tools under Advanced / Developer.
- All six groups are collapsed by default unless current runtime errors or unresolved state-integrity issues need attention.

## v7.2.36 — Sea / Sky Item Locations

- Shows each boss zone directly in the compact boss header instead of hiding it behind a tooltip.
- Adds a visible **Location** column to every Sky/Sea gear table showing where an owned item was detected (Inventory, Safe, Storage, Locker, Satchel, Sack, Case, or Wardrobe).
- Historical/manual ownership that is no longer physically detected is labeled `SAVED` so it stays distinct from a live container location.
- Keeps the two-boss-per-row layout and compact ownership checkbox/status column.

## v7.2.35 — Sea / Sky Header Cleanup

- Cleans up the Sea / Sky tab header so it reads more clearly and no longer crams the title and totals onto one line.
- Renames the header display to `Sea / Sky Collection` and moves the totals to a dedicated summary line: `Obtained: Sky Gods X/Y | Sea Bosses X/Y`.
- Shortens the explanatory auto-scan note while keeping the same behavior.

## v7.2.34 — Two-Column Sea / Sky Boss Layout

- Removes the individual collapsible headers from every Sky god and Sea boss; only the main **Sky Gods** and **Sea Bosses** sections remain collapsible.
- Places boss gear panels side by side in a two-column grid to substantially reduce the vertical length of the Sea / Sky tab.
- Uses compact `Boss | obtained/total` headings; the boss location is available as a hover tooltip.
- Simplifies each boss table to **Gear / Owned** columns; source details remain available as gear-name hover tooltips while manual and automatic ownership tracking are unchanged.

## v7.2.33 — Compact Sea / Sky Layout

- Tightens the Sea / Sky tab so more collection information fits on screen without losing the boss/source/status details.
- Replaces the two-line introductory explanation with a compact Sky/Sea obtained summary and one concise ownership note.
- Shortens Sky/Sea and individual boss headers to compact `Boss | Zone | obtained/total` rows and removes extra spacing between every boss.
- Uses proportional Gear / Source / Owned columns and a compact checkbox + status treatment for each item.
- Keeps the clear divider between Sky Gods and Sea Bosses while reducing the oversized blank gap.

## v7.2.32 — Sea / Sky Section Separation

- Adds a clear divider and extra vertical spacing between the Sky Gods collection and Sea Bosses collection.
- Keeps the existing collapsible Sky/Sea headers and individual boss sections unchanged.

## v7.2.31 — Sea / Sky Collection Tab

- Adds a new **Sea / Sky** tab directly after Seasonal.
- Sky tracks Genbu, Suzaku, Seiryu, Byakko, and Kirin named drops plus the wearable NQ/HQ gear produced from their abjurations.
- Sea tracks all seven Jailers, the three Ix'aern cape rewards, Jailer of Love's Novio/Novia earrings, and Absolute Virtue equipment rewards.
- Ownership is auto-detected from the shared inventory/storage/wardrobe collection scan and is saved per character once observed.
- Every item also has a manual obtained checkbox so existing Porter-stored or historical pieces can be reconciled without withdrawing them.
- Bosses and the Sky/Sea groups are collapsible and show obtained/total collection counts.

## v7.2.30 — Chocobo Tab Eco-Style Refresh

- Restyles the Chocobo Riding tab to match the cleaner Eco-War look and feel.
- Replaces the custom blue-gray Chocobo header bars with the shared HorizonCheck section styling used by Eco-War and other table-first tabs.
- Converts Chocobo detail, history, observed-result, reward, and riding-time sections to the shared bordered table layout with visible column headers for easier scanning.
- Moves the Developer Capture control onto the main Chocobo header line so the tab layout stays consistent with Eco-War.

## v7.2.29 — Collapsible Daily / Weekly Sections

- Makes **Daily Objectives**, **Daily Avatar Fights**, and **Weekly Objectives** collapsible sections using the same ImGui collapsing-header behavior used by Black Coffin.
- Keeps each section open by default so the tab initially looks the same, while allowing players to fold away sections they do not need.
- Preserves the existing progress/reset text directly in each collapsible header and keeps all table layouts, hide-completed controls, and automatic tracking unchanged.
- Daily Avatar Developer Capture remains available inside the expanded avatar section.

## v7.2.28 — Daily Avatar Developer Capture

- Adds a Developer Mode Capture / Stop Capture control directly after the Daily Avatar Fights `repeatable after Japanese midnight` status text.
- The Daily Avatar capture is manual-stop so a tester can include the full NPC/key-item/battlefield interaction without racing a short timeout.
- The capture control remains hidden when Developer Mode is off.

## v7.2.27 — Daily Avatar Hide-Completed + HAAP Label Cleanup

- Adds a **Hide completed objectives** toggle directly to the Daily Avatar Fights section.
- Daily avatar completion is recorded only after HorizonCheck has observed that fight's required key item held during the current daily window and later observes it no longer held; the completion state resets with the normal Japanese-midnight daily reset.
- The held-seen state is stored in daily character data so the completion correlation survives `/addon reload` during the same day.
- Removes the `verified ... ago` / `not verified` suffix from the HAAP Weekly Scrolls status row while keeping the underlying automatic HAAP verification and synchronization logic unchanged.

## v7.2.26 — Daily / Weekly Eco-Style Layout

- Reformats the Daily / Weekly tab to match the cleaner Eco-War presentation with fixed table columns and separated status/notes fields.
- Daily Objectives now use Objective / Status / Notes columns while preserving checkboxes, auto-detection, Relearn Pots, and Developer capture controls.
- Daily Avatar Fights now use Avatar / NPC & Location / Key Item / Status columns for easier scanning.
- Weekly Objectives now use Objective / Status / Notes columns and include Dynamis and Limbus as table rows.
- Simplifies the section headers to title + compact progress/reset text while preserving all existing tracking logic.

## v7.2.25 — Daily Avatar Fight Readiness

- Adds a new **Daily Avatar Fights** section between Daily Objectives and Weekly Objectives.
- Lists Titan, Ifrit, Leviathan, Ramuh, Garuda, Shiva, Fenrir, and Diabolos with each starting NPC and NPC location.
- Shows the required key item for every fight and live ownership state as `[HELD]`, `[NOT HELD]`, or `[CHECKING]` using HorizonCheck's existing authoritative key-item tracker.
- Shows a held-key-item count and notes that these repeatable avatar quests become available again after Japanese midnight once the prior reward has been claimed.
- Keeps avatar readiness separate from the normal Daily Objectives completion count; holding a tuning fork / Moon Bauble / Dream Incense is readiness evidence, not proof that today's fight was completed.

## v7.2.24 — Wider Assault Notes

- Adds a `- Notes:` separator after each Assault mission location so the editable note field is visually distinct from the zone name.
- Triples the inline Assault note box width from 240 to 720 pixels.
- Raises the note input capacity from 160 to 480 characters while preserving the existing per-character persistent save behavior.

## v7.2.23 — Persistent Assault Mission Notes

- Adds an inline `Notes:` text field after the Assault location on every mission row.
- Notes are stored per character in permanent Assault state and save as they are edited, so they survive `/addon reload`, logout/login, zoning, and normal addon updates.
- Notes remain available for both complete and incomplete Assault missions and are independent of native completion-history synchronization.
- `/hcheck assaultprogress clear` now clears mission completion progress without deleting saved notes.
- Adds a release-hardening contract protecting persistent Assault note storage and rendering.

## v7.2.22 — Chocobo Destination Reward Mapping Fix

- Uses the full Orlaine -> Port Jeuno capture to confirm Narsha as the destination NPC, a 15:34 Earth-time finish, and Gysahl Greens as the reward.
- Corrects Orlaine's best-reward target to the destination-specific Windurst Woods Glyph cutoff of 15:29; the captured 15:34 result independently lands just beyond that boundary.
- Corrects Sariale -> Southern San d'Oria to Miratete's Memoirs <= 28:36.
- Corrects the three San d'Oria routes so reward/cutoff metadata follows the verified destination instead of the old phase index: Camereine -> Bastok = Dragon Chronicles <= 19:59, Emoussine -> Windurst = Miratete's Memoirs <= 28:19, Meuneille -> Upper Jeuno = East San d'Oria Glyph <= 13:15.
- Uses the exact Bastok Mines Glyph name for Eulaphe -> Lower Jeuno.
- Adds a release-hardening contract protecting these destination-specific route mappings.

## v7.2.21 — Windurst Chocobo NPC Rotation Fix

- Corrects the Windurst Woods Riding Game rotation to the actual left-to-right NPC order: Orlaine -> Sariale -> Amimi.
- Fixes phase 0 incorrectly showing Amimi when Orlaine is the active NPC.
- Keeps each NPC's verified destination, reward target, cutoff, and riding-time gear requirement attached to the correct renter.

## v7.2.20 — Chocobo Server-Time Calibration

- Learns a full capture-verified Quelle -> Southern San d'Oria Riding Game run ending at Camereine.
- Confirms the destination completion dialogue reports an authoritative 19:25 Earth-time result followed by Page from the Dragon Chronicles.
- Uses the capture-verified `Time elapsed: ... (Earth time)` zone messages to recalibrate the active Riding Game timer after each zone transition.
- This removes the several-second offset caused by the acceptance acknowledgement arriving after the server has already started the run.
- Keeps final completion time and reward parsing unchanged and authoritative.

## v7.2.19 — New-User Developer Mode Default

- Explicitly seeds Developer Mode OFF when a character loads HorizonCheck for the first time.
- New users now always start in the normal player-facing UI without developer-only tabs or capture controls enabled.
- Existing characters keep their saved Developer Mode preference; this only changes brand-new character profiles.
- Adds a release contract protecting the new-profile default.

## v7.2.18 — Boyahda Full Turn-In Completion Dialogue

- Learns the capture-verified dialogue that Kipling and Ah Puch use after all four requested items for their lane have been turned in.
- Kipling completion signatures include the observed post-turn-in lines about the unexpected combo / nerfing Aerec's favorite job.
- Ah Puch completion signatures include the observed post-turn-in anti-cheater / fair-play lines.
- These post-turn-in signatures are authoritative full-lane evidence and can reconcile all four items if an earlier individual trade packet was missed.
- Keeps the normal per-item `Ah! Yes this is one of the items I was looking for.` acknowledgement strict: it still requires the matching `0x020` inventory decrease/removal before one item is checked.
- Stores the following post-completion clue for diagnostics when observed.

## v7.2.17 — Anniversary Year Section Spacing

- Adds the same visual separation between the top-level Anniversary year sections (2023, 2024, and 2025).
- Keeps the extra spacing previously added between the 2024 NPC/location sections and before the Aerec Bonus section.
- Preserves the sticky open-state behavior so trading items still does not collapse the year section or active NPC lane.

## v7.2.16 — Anniversary Section Spacing

- Adds vertical spacing between each 2024 Anniversary NPC/location section so collapsed rows are easier to scan.
- Applies the same extra separation before the Aerec Bonus section for clearer visual grouping.
- Keeps the v7.2.15 sticky open-state behavior intact, so trades still do not collapse the parent 2024 section or the active NPC lane.

## v7.2.15 — Anniversary Sticky Open-State Fix

- Replaces Anniversary year, 2024 NPC-group, and Aerec Bonus `CollapsingHeader` state with HorizonCheck-owned open/closed booleans.
- The 2024 section and an open NPC group now remain open when an NPC trade auto-checks an item, even on HorizonXI/Ashita ImGui builds that reset collapsing-header state after live content changes.
- Only an explicit click on the Anniversary header row changes its open/collapsed state.
- Restores live progress/COMPLETE text in the header rows because progress changes can no longer alter the stored open state.

## v7.2.14 — Anniversary Menu State Stability

- Keeps Anniversary collapsing sections open when progress changes after an item trade.
- Uses stable visible labels for the 2023/2024/2025 year headers so automatic completion no longer recreates the 2024 header state.
- Uses stable 2024 NPC-group and Aerec Bonus header labels; progress and COMPLETE state are now rendered inside the open section instead of mutating the header label.
- Preserves the user's manual open/collapsed state while Boyahda turn-in detection updates checkboxes in real time.

## v7.2.13 — Kipling Item Turn-In Verification

- Adds capture-verified successful turn-in detection for **Kipling** in The Boyahda Tree.
- Confirms Kipling uses the same `Ah! Yes this is one of the items I was looking for.` acknowledgement observed from Ah Puch.
- Confirms the same interaction pattern: generic `0x017` success dialogue plus the `0x020` Inventory item update/clear and `0x01D` inventory refresh packets.
- Extends the strict Boyahda correlation path to both NPC lanes, so HorizonCheck marks only the exact requested item whose inventory count decreased or whose slot cleared within the verification window.
- Adds Kipling to the verified turn-in coverage metric and expands regression/release-hardening checks to require both Boyahda lanes.

## v7.2.12 — Ah Puch Item Turn-In Verification

- Adds capture-verified successful turn-in detection for **Ah Puch** in The Boyahda Tree.
- Recognizes Ah Puch's generic `Yes this is one of the items I was looking for` acknowledgement only when it is correlated within five seconds to an incoming `0x020` Inventory item decrease/removal for one of Ah Puch's exact requested item IDs.
- Maintains a tiny Inventory-only slot cache so a `0x020` packet that clears a slot can still be tied back to the item that occupied that slot immediately before the update.
- Marks only the exact correlated item complete; a generic success line without a matching requested-item inventory delta records no completion.
- Shows partially confirmed Boyahda hand-ins as `TURN-IN PARTIAL` with a `Turned in:` list. Four verified items promote the NPC lane to `TURN-IN COMPLETE`.
- Keeps Kipling completion request-only until a successful Kipling hand-in capture verifies his acknowledgement pattern.
- Adds regression and release-hardening contracts that prevent generic Ah Puch dialogue from directly completing an Anniversary item.

## v7.2.11 — Boyahda Anniversary Riddle Capture Mapping

- Adds capture-verified 2024 Anniversary request-riddle signatures for **Kipling** and **Ah Puch** in The Boyahda Tree.
- Maps Kipling's four observed clues to Ancient Papyrus, Smooth Velvet, Silver Obi +1, and Raxa, and Ah Puch's four observed clues to Phoenix Feather, Chocobo Bedding, Luminicloth, and Black Chocobo Feather x3.
- Records these clues as **requested items only**. The captured interaction emits all four riddles for each NPC in one batch, so later clues are deliberately not treated as proof that earlier items were turned in.
- Shows the captured requested-item set inside the Kipling + Ah Puch 2024 section and clears stale unmapped-dialogue evidence once a known signature is recognized.
- Adds a regression contract preventing these batch riddles from being routed through current-riddle completion backfill.

## v7.2.10 — HorizonXI Sugar Math Reload Compatibility

- Fixed the reload-time UI crash reporting `libs\sugar\math.lua:572: Math namespace does not contain a definition for: x`.
- Removed `.x` / `.y` access from main-window geometry code and switched recovery/layout checks to scalar ImGui width/height APIs.
- Removed the remaining `.x` access from shared UI width detection so the same Ashita bridge issue cannot surface from responsive panels.
- Keeps the v7.2.7 first-run window sizing repair and the v7.2.9 Anniversary developer capture behavior.

## v7.2.9 — Anniversary Capture Reload Fix

- Fixes the UI-module failure that could occur after adding the Developer Mode Anniversary Capture control.
- Hardens the shared learning Capture button against Ashita ImGui builds where optional hover/tooltip helpers are unavailable or throw.
- Wraps the Anniversary developer capture control so a capture-widget failure cannot abort the Anniversary tab or parent HorizonCheck UI frame.
- Keeps the Developer Mode-only **Capture / Stop Capture** button beside **HorizonXI Anniversary Quest Guide**.
- UI-frame failures now also print the underlying runtime error after the existing generic recovery message, making future field-only binding errors diagnosable without opening a separate window.

## v7.2.8 — Anniversary Developer Capture

- Adds a Developer Mode-only **Capture** button directly to the right of **HorizonXI Anniversary Quest Guide** on the Anniversary tab.
- The button starts a manual-stop Anniversary evidence capture for NPC riddle, counter, turn-in, assignment, and completion dialogue; while active it changes to **Stop Capture**.
- Shows a small `CAPTURE ARMED` reminder only while the Anniversary capture is active.
- Keeps the control completely hidden when Developer Mode is off and does not change Anniversary completion or automation logic.

## v7.2.7 — First-Run Window Layout Fix

- Gives the main HorizonCheck window a usable 1180x820 first-use size instead of allowing Dear ImGui to initialize it as a very narrow, near-full-height column.
- Uses `ImGuiCond_FirstUseEver`, so existing users' established window geometry is preserved.
- Adds a one-time safety recovery for clearly broken tiny saved geometry (under 640px wide or 420px tall), allowing users affected by the old first-run behavior to recover automatically.
- First-use sizing adapts down to the current display instead of extending off-screen on smaller game windows.

## v7.2.6 — Chocobo Riding Column Fix

- Fixed the v7.2.5 Chocobo Riding layout regression that squeezed route values into a one-character-wide column and caused extremely tall rows.
- Route detail cards now use an explicit 22% / 78% stretch-column layout, preserving the alternating row shading while keeping values readable across the tab.
- No Chocobo tracking, completion, capture, reward-learning, or route logic changed.

## v7.2.5 — Chocobo Riding Visual Cleanup

- Reworked the Chocobo Riding tab into clearly separated dark header sections inspired by the approved mockup.
- Each Bastok, San d'Oria, and Windurst route now renders as a bordered two-column card with alternating row shading for easier scanning.
- Current NPC, destination, reward target, personal best, riding-time gear, next route, and route verification are aligned into label/value rows.
- Run History, Observed Results, Possible Rewards, and Riding Time Reference now have stronger section separation and cleaner zebra-striped lists where appropriate.
- Kept all Chocobo tracking, capture, completion, reward-learning, and route logic unchanged; this release is presentation-only.

## v7.2.4 — Anniversary Full Item-ID Registry

- Converts all 96 Anniversary 2024 main-riddle items plus all 8 Aerec bonus items to ID-first ownership/location matching.
- Resolves human-friendly catalog labels through Ashita's local item resources once per session, caches the resulting exact item IDs, and uses names only as compatibility fallback.
- Normalizes quantity suffixes and guide-only parentheticals before resource lookup.
- Generates safe FFXI-style abbreviation candidates for middle words and keeps explicit aliases for known resource-name differences such as `Black C. Feather`, `H.Q. Bugard Skin`, `H.Q. Scorpion Shell`, `Linkshell`, and `Tree Sapling`.
- Keeps Black Chocobo Feather pinned to verified item ID 845 and adds Diagnostics coverage for resolved vs fallback Anniversary item entries.
- Reuses the existing cached collection scan; the ID-registry warmup is a bounded one-time resource lookup and does not add per-frame inventory scanning.

## v7.2.3 — Anniversary Black Chocobo Feather Ownership Fix

- Fixes Anniversary 2024 ownership detection for `Black Chocobo Feather x3`.
- Maps the full HorizonXI guide name and the FFXI client abbreviation `Black C. Feather` to exact item ID 845.
- Keeps quantity suffixes display-only and continues to reuse the cached collection scan.

## v7.2.2 — Anniversary 2024 Inventory Locations

- Shows live current-character ownership beside every 2024 Anniversary main-riddle item as `[OWNED - LOCATION]`.
- Includes Aerec bonus-riddle items in the same ownership/location display.
- Reuses the shared cached inventory/storage/Wardrobe scan and invalidates from the existing inventory update token instead of adding a per-frame bag scan.
- Strips quantity suffixes such as `x12` for inventory matching and includes aliases for known abbreviated resource names.
- Ownership display is informational only and never auto-checks an Anniversary completion checkbox.

## v7.2.1 — Single Diagnostics Workspace

- Removes the separate floating HorizonCheck Diagnostics window and its Open Diagnostics Window control.
- Makes the Diagnostics tab inside the main HorizonCheck window the single canonical troubleshooting/maintenance workspace.
- Consolidates all diagnostics sections into that tab, including Recent State Audit, Key Item Diagnostics, State Cleanup, Historical Progression Import, and Self-Healing.
- Routes `/hcheck diagnostics`, migration failures, self-test failures, and UI-error recovery back to the main HorizonCheck window instead of spawning a second window.
- Preserves Developer Mode gating while allowing explicit diagnostics/error requests to expose the Diagnostics tab for the current session.
- Does not change tracker state, evidence rules, cache behavior, or gameplay automation.

## v7.2.0 — Integrity Expansion / Seasonal Year Awareness / Performance Watchdog / Catalog Score

- Expanded State Integrity with reset-scope, fame/reputation bounds, outpost mirrors, Anniversary automation metrics, Seasonal metadata, and conservative mission/quest chain audits.
- Added year-aware Seasonal availability metadata. Existing event catalogs are verified against the documented 2025 guides; later years remain explicitly unverified until confirmed.
- Added a low-cadence Performance Watchdog that evaluates existing profiler telemetry for scan/cache/save/invalidation churn without performing its own gameplay scans.
- Added a HorizonXI Catalog Verification Score with category scores for native IDs, availability, NPC/zone, prerequisites, rewards, wait conditions, and completion evidence.
- Added save-request/write telemetry so excessive persistence activity can be detected during long sessions.

## v7.1.0 — Anniversary Automation / Character Registry / Initial Sync Report

- Expands Anniversary automation with safe same-NPC advancement evidence for every 2024 lane, while keeping successful turn-in counters restricted to capture-verified signatures.
- Stores one bounded unmapped dialogue observation per 2024 NPC lane in Diagnostics so future riddle signatures can be mapped without changing completion state.
- Adds Diagnostics Character Registry with last-seen, job/level, Jobs-at-75, sync initialization, schema, and two-step removal of non-current saved HorizonCheck profiles.
- Adds a one-time Initial Synchronization completion report showing reconstructed quests, missions, Assault clears, permanent unlocks, advanced jobs, Limit Breaks, key-item bitmap coverage, and fame-checker initialization before the setup wizard permanently closes.
- Makes Synchronization Health actionable with a dedicated resolution/action for every STALE or NEEDS SYNC state.
- Adds Weekly Availability sorting to the Account / Characters section at the bottom of Overview.
- Preserves permanent Eeko-Weeko, Rytaal, and Fame initialization milestones and the event-driven/cached performance architecture.

## v7.0.0 — State Integrity / Anniversary Automation / Account Overview Refinement

- Adds a centralized, event-driven State Integrity engine that audits contradictory derived state and automatically repairs only safe/reconstructable values while preserving raw packet/native evidence.
- Adds integrity checks for Assault Tag bounds/timers, Dynamis account-vs-character usage, Limbus sequence state, saved Overview summaries, transient Anniversary pointers, Seasonal ownership, plus the existing canonical/self-heal provider checks.
- Routes authoritative state changes through the dependency graph into batched integrity reconciliation, with a 10-minute low-frequency safety audit instead of a second frequent whole-state poller.
- Expands 2024 Anniversary automation with per-NPC riddle lanes. Current-riddle evidence can backfill only earlier riddles for that same NPC, preventing a paired NPC from falsely completing the other NPC's items.
- Keeps Tracent/Drowsy successful turn-ins capture-verified by their post-turn-in counters; no unverified generic turn-in completion signature is invented for other 2024 NPCs.
- Refines the Account / Characters section at the bottom of Overview with compact saved-summary v2 profiles, Name/Progress/Last Seen sorting, mission/event percentages, clearer Dynamis/Limbus availability states, shared pool totals, and last-seen age.
- Adds Diagnostics State Integrity status and Anniversary automation coverage while keeping normal gameplay tabs free of developer evidence details.
- Preserves permanent Initial Synchronization milestones: Eeko-Weeko, Rytaal, and Fame initialization never reopen due to weekly freshness changes.

## v6.99.0 — Synchronization Health / Account Overview / Dependency Reconciliation

- Separates permanent Initial Synchronization milestones from live/current-cycle freshness. Eeko-Weeko, Rytaal, and Fame initialization never reopen after weekly resets once completed.
- Adds Diagnostics Synchronization Health with HEALTHY / STALE / NEEDS SYNC states for mission history, key-item bitmaps, zone reconciliation, Assault history, historical import, Eco-War, Assault Tags, Fame, and normalized progression.
- Strengthens the Account / Characters section at the bottom of Overview with saved Jobs-at-75 progress, clear Dynamis/Limbus availability states, shared account resources, event totals, and a lightweight Overview percentage.
- Persists a small per-character Overview profile so offline characters can be summarized without live scans.
- Adds dependency-driven cache invalidation so mission, key-item, fame, Eco-War, Assault, historical, weekly, and zone changes dirty only dependent caches and rebuild lazily.
- Removes eager Search rebuilding from self-healing repairs and preserves the v6.91.1 open-window performance architecture.

## v6.98.0 — Release Readiness / Maintenance

- Adds Historical Import Coverage with observed/imported/skipped native-state reporting.
- Adds filtered Catalog Verification Work Queue views for collisions, native IDs, availability, and incomplete fields.
- Advances saved-state schema to 24 and safely prunes retired UI/cache fields with backup/rollback protection.
- Adds State Cleanup diagnostics and a manual safe cleanup action.
- Adds runtime cache-hit/miss and expensive-scan counters to the Performance Profiler.
- Preserves event-driven/cached open-window performance behavior.

## 6.96.0

- Added safe historical progression import for native completed quests, missions, permanent unlocks, advanced jobs, and Limit Breaks.
- Added historical import to initial synchronization and zone reconciliation.
- Expanded self-healing to Seasonal ownership and historical normalization.
- Expanded the shared responsive UI framework and migrated major remaining tracker summaries to it.
- Preserved event-driven/cached performance behavior.

# HorizonCheck Changelog

## v6.97.1 — Why Inspector Removal

- Removes the Why inspector module, popup, and all normal UI `?` controls.
- Renames Quest Details' technical section to **Advanced Details**.



## v6.93.4 — Relic -1 Upgrade Satisfaction

- Displays a Relic -1 slot in bright text as `[NOT NEEDED]` when the matching Relic +1 is already owned or stored.
- Preserves a physically held/stored Relic -1 in the actual `found` count and labels it `[OBTAINED | NOT NEEDED]` or `[STORED | NOT NEEDED]`.
- Keeps the Relic +1 column and physical Relic -1 ownership counts accurate.



## v6.93.3 — Upgraded AF and Relic Progress Credit

- Treats AF +1 as historical proof of the matching base AF piece.
- Treats Relic +1 as historical proof of the matching base Relic piece.
- Shows proved base rows as `[UPGRADED]` in bright text and includes them in base-set totals.



## v6.93.2 — Confirmed Fame Requirement Display

- Replaces technical fame diagnostics in normal Quest Details with a concise `current / required` status.
- Renders directly confirmed fame and reputation profiles in bright text.
- Keeps inferred-only floors visually subdued and labels their evidence level clearly.

## v6.93.1 — Adaptive Smart Dashboard Layout

- Hides More in This Zone when all local recommendations are already shown under Best Next.
- Expands Best Next to the full Dashboard width when there is no unique second-column content.
- Restores the two-column layout automatically when additional current-zone objectives exist.

## v6.93.0 — Production UX and Anniversary Tracking

- Hides the empty Attention column automatically while keeping Next Up visible.
- Adds Critical and Expiring Soon urgency groups for genuinely time-sensitive activities.
- Simplifies normal Quest Details and moves native IDs, catalog quality, evidence, and state reports into a collapsed Advanced / Why This State section.
- Adds capture-verified Tracent and Drowsy request/turn-in tracking: riddles record requested items, while NPC counter dialogue confirms the four-item turn-in and stores the next clue.
- Shows ENM Verify Timer only for unknown/estimated timers in normal mode; Developer Mode can still show it on every row.

## v6.92.6 — Production Information Cleanup

- Keeps Attention urgent-only and moves ordinary ready recommendations to the Dashboard.
- Deduplicates Best Next and More in This Zone.
- Removes healthy synchronization, catalog-audit, and verification implementation details from normal tabs.
- Makes Fame and ENM help conditional and keeps Dynamis explanations in a tooltip.
- Removes the redundant PRODUCTION header label.


## v6.92.5 — Attention Focus Cleanup

- Removes the redundant Focus row from What Should I Do?.
- Keeps DO NOW, READY, and Next Up as the normal activity summary.
- Keeps richer ranked recommendations on the Dashboard.


## v6.92.4 — Main UI Simplification

- Removes Compact Mode and its `/hcheck compact` command entirely.
- Removes the redundant Activity Snapshot from the normal Planner/Attention area.
- Keeps technical progression details available in Diagnostics.


## v6.92.3 — Passive ENM Timer Tracking

- Starts ENM timers only from a session-observed authoritative `0x055` false-to-true key-item transition.
- Does not infer a new timer when the first snapshot already shows the KI owned.
- Corroborates transitions with acquisition dialogue without letting chat move the timer.
- Renames the ENM `Moritz` action to `Verify Timer` for unknown/estimated timer recovery.

## v6.92.2 — ENM Consumed-State Cleanup

- Prevents stale `KEY ITEM CONSUMED` evidence from being appended to an available ENM.
- Clears the transient marker after battlefield completion, Moritz synchronization, or timer expiry.


The complete historical changelog remains in `README.md`.

## v6.92.0 — Release Candidate Hardening

- Adds a full Initial Synchronization wizard and unified Release Health Check.
- Adds formal saved-state schema migration with pre-migration backup, validation, save verification, and automatic rollback.
- Adds per-operation runtime isolation, temporary quarantine, retry controls, and duplicate error suppression.
- Adds detailed historical Assault import validation diagnostics.
- Adds static production-UI and performance release gates to the packaging process.
- Adds installation, upgrade, troubleshooting, known-limitations, and release-checklist documentation.
- Preserves the v6.91.1 open-window performance optimizations and all later hotfixes.
