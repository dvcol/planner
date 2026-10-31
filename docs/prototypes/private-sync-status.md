# Native private-sync status and retry

30 October 2026 status-only checkpoint. The
[deployment follow-up](private-sync-deployment.md) now wires private configuration
in source; the installed Planner Development app remains unchanged.

`SavedPlannerStore` consumes account/cloud invalidations through the existing
native status read. A private-configured store exposes a native Settings section
with sync state, a useful failure message and Sync now. Device-only configurations
keep their existing Settings presentation. Local recovery and cloud acknowledgement
remain separate; a local save is not described as uploaded.

Sync now reuses the existing guarded bootstrap/reconnect workflow. It accepts only
the same public dataset and ownership binding; a different account/data selection
requires quitting and reopening Planner. Concurrent writes and duplicate reconnect requests
are guarded. A stale-session notification attempts this same reconnect after its
outstanding status read, preserving the existing draft destination protection.
An unavailable iCloud account is described as local editing with paused sync.

Mac and iOS Simulator app builds and strict formatting pass. The
build summary records the two UI source
hashes and compile scope. The separate signed Core runs qualify private transport,
pending Share edits and independent-field merging; compilation does not prove
these Settings controls, draft interaction or account-transition UI journeys.

Deployment/Share configuration and explicit existing-plan attachment remain the
next implementation slice. Qualify the native controls with that active slice,
then combine Planner-only off/on with final integrated multi-device sync checks.
No new signing setup, account switch or standalone off/on cycle is requested.

The [deployment follow-up](private-sync-deployment.md) now wires the normal app
and Share configurations and adds a reviewed copy of existing device-only plans.
Its own evidence and remaining integrated checks supersede the implementation
to-do above; the installed app is still unchanged.
