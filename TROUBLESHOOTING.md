# HorizonCheck Troubleshooting

## Initial Synchronization remains incomplete

Zone once and wait for Zone Sync to reach phase `3/3`. The setup panel reports exactly which native history is still missing.

- Mission history waiting: zone once.
- Permanent key items waiting: zone once and allow the `0x055` tables to arrive.
- Assault history waiting: zone once; then check Diagnostics → Assault History Validation.
- Progression waiting: wait for Zone Sync phase 3.

## Addon becomes slow while open

Open Diagnostics → Performance Profiler. Persistent `SLOW` entries identify the remaining operation. HorizonCheck v6.91.1 and later cache Planner, Dashboard, quest, weekly, and canonical work; report any persistent regression with a release-health export.

## One tab errors but the rest still works

HorizonCheck isolates major tab/module draws. The failing section displays a retry control while other tabs remain available. Open Diagnostics → Runtime Errors or Module Error Isolation.

Repeated identical errors are collapsed instead of being logged every frame. After three failures in one minute, only that operation is paused for 30 seconds.

## User data folder / storage fallback

Open Settings → Maintenance & Advanced or Diagnostics → System Health to see the active **User Data** path. A normal v7.8.0+ install reports `config\addons\horizoncheck` as writable.

If HorizonCheck reports **ADDON FOLDER FALLBACK**, it could not safely use the config storage path. The displayed reason indicates whether the Ashita install path was unavailable, the config folder was not writable, or the legacy state could not be copied/validated. HorizonCheck intentionally keeps using the old addon-folder state in that case so existing data is not lost.

In v7.8.2+, a successful config-backed state migration automatically cleans the old addon-folder user files. Cleanup runs only after the config state has loaded and validated. A differing legacy file is preserved under config storage as a `legacy_addon_*` archive before its addon-folder copy is removed. If cleanup reports ATTENTION, leave the remaining source file in place and review Diagnostics → System Health for the exact failure.

## Saved-state migration problem

Open Settings → Maintenance & Advanced or Diagnostics → Release Health Check. HorizonCheck reports:

- current and required state schema
- migration result
- pre-migration backup path
- validation result

A failed migration automatically rolls back. Do not manually delete the original state or migration backup before collecting a release-health report.

## Historical Assault clears did not import

Open Diagnostics → Assault History Validation.

Expected healthy output:

- Packet received: YES
- Packet: `0x056/0x00C0`
- Mapping coverage: `50/50`
- Native bits set: the number of unique clears in the server history

Use `/hcheck assaultprogress sync` after zoning to re-read the cached table. Missing native bits never erase other verified proof.

## Exporting one report for support

Use `/hcheck health export`. The report includes synchronization, schema migration, detailed runtime errors, performance health, and Assault history diagnostics.

After exporting, select **Open Reports Folder** in Diagnostics or run `/hcheck health folder`. Attach the newest `horizoncheck_release_health_*.txt` file to the beta issue report. The report includes the character name but never includes account passwords or login credentials; it can be reviewed or redacted before sharing.
