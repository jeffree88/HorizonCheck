# HorizonCheck Regression Fixtures

`evidence_cases.json` captures the resolver policies that previously caused live
HorizonXI false-negatives: authoritative packet evidence vs client API results,
reload-safe saved state, permanent proof, tri-state UNKNOWN, and recency among
equal-strength sources.

The same policies are exercised in-game by `modules/regression.lua` and can be
run from the addon with `/hcheck regression` or from Developer Diagnostics.
`tools/run_regression_tests.py` is the offline release check for these fixtures
and for required runtime integration points.


`workflow_scenarios.json` now exercises end-to-end contracts for key-item
ownership, permanent proof, weekly resets, HorizonXI era gating, staged zone
synchronization, planner/search behavior, canonical native-ID blocking and
quarantine, guided capture analysis, idempotent self-healing repairs, migration rollback, runtime isolation, duplicate-error collapse, and first-run synchronization health.
`tools/run_workflow_simulations.py` runs these scenarios and validates the
required runtime integration contracts during every release build.

`tools/audit_canonical_content.py` separately verifies the server-specific
canonical authority profile, the explicit HorizonXI collision safeguards, and
the runtime modules that enforce them.
