# HorizonCheck Installation and Upgrade Guide

## Fresh installation

1. Close or unload HorizonCheck with `/addon unload horizoncheck` if it is already running.
2. Copy the complete `horizoncheck` folder into `HorizonXI\Game\addons\`.
3. Keep the folder name exactly `horizoncheck`.
4. Load it with `/addon load horizoncheck`.
5. Follow the five simple steps in **Initial Synchronization**:
   - Change zones once.
   - Talk to Eeko-Weeko once.
   - Talk to Rytaal once.
   - Talk to your nation Outpost NPC once, open **Regional Teleport**, and page through the list.
   - Talk to each listed fame/reputation checker once.
6. A checked step is finished permanently. Click **Check Again** after doing a step if the panel has not refreshed yet.

Technical synchronization details stay out of the beginner view; Developer Mode and Diagnostics still show the full health information.

## Upgrading an existing installation

1. Unload HorizonCheck.
2. Replace the existing addon files with the new `horizoncheck` folder.
3. Load HorizonCheck and zone once.

Beginning with v7.8.0, HorizonCheck stores user data outside the addon code folder. It creates `Game\config\addons\horizoncheck\`, copies and validates an existing `Game\addons\horizoncheck\horizoncheck_state.lua`, and then uses the config copy. Beginning with v7.8.2, after that config-backed state has loaded and passed migration/validation, HorizonCheck copies and byte-verifies remaining legacy user files and removes their addon-folder copies. If a same-name config file differs, the legacy copy is preserved as a `legacy_addon_*` archive before removal. If safe migration, validation, or config-folder writing fails, HorizonCheck keeps the legacy addon-folder files untouched and continues using the proven fallback location instead of silently starting over.

HorizonCheck also creates a pre-migration backup before changing an older saved-state schema. If schema validation or save verification fails, the addon automatically restores the previous state.

## Persistent files

Normal v7.8.0+ storage layout:

```text
Game\config\addons\horizoncheck\
├─ horizoncheck_state.lua
├─ horizoncheck_outposts_persistent.lua
├─ backups\
│  ├─ horizoncheck_state.lua.bak1
│  ├─ horizoncheck_state.lua.bak2
│  └─ horizoncheck_state.lua.bak3
├─ captures\
├─ logs\
└─ reports\
```

The `Game\addons\horizoncheck\` folder should contain addon code/data only after migration. Developer captures, learning/audit logs, quest-state reports, release-health exports, and mission captures are written to the matching config subfolder.

## Basic commands

- `/hcheck` — show or hide the main window
- `/hcheck diagnostics` — open Diagnostics
- `/hcheck health` — summarize release health
- `/hcheck health export` — write a release-health report
- `/hcheck health folder` — open the folder containing release-health reports
- `/hcheck setup` — reopen Initial Synchronization
- `/hcheck selftest` — run module self-test

Closed-beta testers should also read `BETA_TESTING.md` for the smoke-test checklist and bug-report instructions.
