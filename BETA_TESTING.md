# HorizonCheck Closed Beta Guide

HorizonCheck v7.9.33 is a closed beta candidate for HorizonXI. Testers should use the normal interface with **Developer Mode off** unless a developer specifically asks for a capture.

## Install or upgrade

### New installation

1. Unzip the download.
2. Copy the complete `horizoncheck` folder into `HorizonXI\Game\addons\`.
3. In game, run `/addon load horizoncheck`.
4. Complete the five steps shown under **Initial Synchronization**.

### Upgrade

1. Run `/addon unload horizoncheck`.
2. Replace the existing `Game\addons\horizoncheck\` code folder with the new one.
3. Do not delete `Game\config\addons\horizoncheck\`; it contains saved character data and backups.
4. Run `/addon load horizoncheck`, then change zones once.

## First ten-minute smoke test

- Confirm the header shows `v7.9.33` and does not show `[DEVELOPER]`.
- Open Overview, Daily / Weekly, Missions, Quests, Character Info, and Diagnostics.
- Narrow and widen the window; text and action buttons should remain readable.
- On Daily / Weekly, confirm the Guild Point **Recipe / Item Wiki** button remains fully visible after the status wraps.
- Change zones two or three times and confirm the game does not freeze for several seconds.
- Run `/hcheck selftest`; it should report that the self-test passed.
- Open Diagnostics and confirm **Release Health**, **State Integrity**, and **Runtime Errors** do not show unexpected attention items.

## High-value beta scenarios

- Fresh character with no HorizonCheck state.
- Upgrade from an earlier HorizonCheck version.
- Two or more saved characters on the same account.
- Daily reset and Conquest-week reset behavior.
- Dynamis shared-entry limits and Limbus lockouts.
- Eco-Warrior progression from 0/3 through 3/3 without losing same-week completion.
- A 30–60 minute session with repeated zoning and tab switching.
- Normal and Dense UI at both narrow and wide window sizes.

## Reporting a problem

Please include:

1. HorizonCheck version.
2. Whether this was a fresh installation or an upgrade.
3. The tab or tracker involved.
4. What you expected and what happened instead.
5. Exact steps that reproduce the problem.
6. Screen resolution, window size, and whether Normal or Dense UI was selected for layout problems.
7. A screenshot when the issue is visual.
8. A release-health report.

Create the report with `/hcheck health export`, then select **Open Reports Folder** in Diagnostics or run `/hcheck health folder`. Attach the newest `horizoncheck_release_health_*.txt` file to the bug report.

The report contains the HorizonCheck version, character name, synchronization health, migration status, runtime errors, performance health, and Assault history diagnostics. It does not contain account passwords or login credentials. Testers may review or redact the character name before sharing it.

## Expected limitations

Some quest prerequisites and server mappings intentionally remain `VERIFY`, `CHECK`, or `UNKNOWN` until HorizonCheck observes authoritative evidence. That conservative result is not a bug by itself. Report cases where HorizonCheck shows an incorrect definite result, loses saved proof, produces a runtime error, freezes the game, or makes an action unreadable.

