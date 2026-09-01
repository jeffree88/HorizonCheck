# HorizonCheck Release Checklist

## Automated package gates

- [ ] Runtime version markers agree
- [ ] Lua structure audit passes
- [ ] Evidence-policy regression tests pass
- [ ] Workflow simulations pass
- [ ] Quest catalog schema and dependency audits pass
- [ ] Canonical HorizonXI content audit passes
- [ ] Production UI / release-hardening audit passes
- [ ] Performance contract audit passes
- [ ] State Integrity architecture audit passes
- [ ] Release tree contains no state, captures, reports, caches, or logs
- [ ] ZIP integrity check passes

## Fresh-install test

- [ ] Install with no state file
- [ ] Character is detected
- [ ] State path is writable
- [ ] Zone once
- [ ] Mission history synchronizes
- [ ] Permanent key-item tables synchronize
- [ ] Historical Assault clears synchronize
- [ ] Talk to Eeko-Weeko once; Eco-War initialization stays permanent
- [ ] Talk to Rytaal once; Assault Tag initialization stays permanent
- [ ] Talk to the current nation Outpost NPC and page through Regional Teleport; current Outpost ownership synchronizes and the setup milestone stays permanent
- [ ] Talk to all supported fame/reputation checkers once
- [ ] State Integrity reaches HEALTHY with 0 unresolved contradictions
- [ ] Zone Sync reaches phase 3/3
- [ ] Initial Synchronization shows the one-time reconstructed-history summary
- [ ] Finish Setup acknowledges the summary and permanently closes setup

## Upgrade test

- [ ] Upgrade a state from the previous schema
- [ ] Pre-migration backup is created
- [ ] Migration validation passes
- [ ] Progression remains intact
- [ ] User UI preferences remain intact
- [ ] Multi-character records remain separate
- [ ] Character Registry protects the current character and requires a second confirmation before removing an offline saved profile

## Long-session and UI test

- [ ] Main window open for 30–60 minutes
- [ ] No persistent Performance Profiler warnings
- [ ] Repeated tab switching remains smooth
- [ ] Multiple zone changes do not freeze the game
- [ ] Normal and Dense UI both render correctly
- [ ] Narrow window wrapping does not create vertical-letter columns
- [ ] Developer controls remain hidden with Developer Mode off
- [ ] One simulated module error does not break other tabs
- [ ] Repeated authoritative events batch integrity scans instead of scanning every frame
- [ ] Account Overview reads offline characters from compact saved summaries only

## Historical Assault test

- [ ] No-clear character imports 0/50
- [ ] Partial-clear character matches known unique clears
- [ ] Repeated Assault runs do not create false unique clears
- [ ] Existing manual/live proof is preserved
- [ ] Missing native bits never erase completion proof


## Anniversary automation safety

- [ ] A current riddle backfills only earlier items in the same NPC lane
- [ ] Talking to the second NPC in a paired group cannot mark the first NPC's lane complete
- [ ] Tracent/Drowsy counter dialogue remains the only capture-verified generic four-item turn-in completion proof
- [ ] Unverified 2024 NPCs do not invent successful turn-in completion
