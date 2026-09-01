# HorizonCheck Known Limitations

- HorizonXI may omit, reuse, or remap retail native quest IDs. Unverified mappings are quarantined and cannot independently activate or complete a quest.
- Historical Assault import depends on HorizonXI sending the native `0x056 / 0x00C0` Completed Assaults table after zoning.
- Passive ENM timer starts require HorizonCheck to observe the authoritative `0x055` ownership transition during the current addon session. If the first snapshot already shows the entry KI held, the timer origin remains unknown until `Verify Timer` is used or a future acquisition is observed.
- Ashita's `HasKeyItem(false)` is not authoritative on HorizonXI. HorizonCheck prefers the server `0x055` bitmap and permanent saved proof.
- Inventory and Porter-slip availability depends on the APIs exposed by the installed Ashita/HorizonXI build.
- Some quest requirements, rewards, waits, and completion methods remain catalog verification work. Unverified data is not silently promoted to HorizonXI-confirmed information.
- ToAU missions beyond the current HorizonXI cap remain visible as reference content but are non-actionable.
- Mission `Current Story / Next Mission` uses native current pointers for the active nation/Zilart/CoP when HorizonXI supplies them. Nation history contains optional/repeatable missions, so HorizonCheck intentionally shows VERIFY rather than guessing the active nation mission when that pointer has not synchronized.
- Zone Intelligence only shows NPC coordinates/locations and mission-zone guidance when an existing tracker/catalog entry actually provides them; it does not invent missing mission routing data.
- Developer captures can confirm server behavior only when the relevant packet, dialogue, or before/after state is observed during the capture.
- The performance profiler measures addon-side Lua work; it cannot attribute unrelated game, driver, network, or other-addon stutter.

## Anniversary Tracent / Drowsy

- The capture-verified tracker distinguishes riddle-only request dialogue from post-turn-in counter dialogue.
- Riddles record the requested items but do not prove completion.
- The `Bug #... down` and `Quest #... down` signatures confirm the corresponding four-item NPC turn-in.
- Other 2024 Anniversary NPCs can use current-riddle dialogue to backfill only earlier riddles in that same NPC's lane. HorizonCheck does not claim a successful turn-in for those NPCs until a separate completion signature is captured and verified.



## State Integrity

- State Integrity repairs derived/reconstructable state only. It intentionally preserves stronger raw/native/account-wide evidence when exact attribution is incomplete, which can leave a Diagnostics item marked for review instead of guessing.
- The integrity engine is event-driven with batched invalidation plus a low-frequency safety audit; it is not intended to make every external HorizonXI value continuously current without an authoritative server/NPC observation.

- Seasonal year availability is evidence-scoped: the bundled recurring-event catalog is verified against the documented 2025 HorizonXI guides. A later calendar year is shown as unverified/historical until its reward availability is confirmed; HorizonCheck does not guess that a reward returned or disappeared.
