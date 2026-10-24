# Known-applied checkpoint retry

## Context, before and goal

At `e605569`, a complete database commit followed by independent recovery failure reports applied/incomplete and blocks subsequent mutations. Core exposes operation evidence and separate proposal inspection, but the approved native checkpoint-retry method is missing. Reexecuting the original command cannot repair the checkpoint and must not be used to infer an uncertain outcome.

The goal is the declared `retryRecovery(session:operationId:)` through the same Core facade. Only known applied evidence authorizes checkpoint work. Return the existing applied result with complete/incomplete recovery, retain the original operation identity and never repeat its mutation. An already acknowledged operation returns its existing result/generation without publishing another checkpoint. Unknown/unverified evidence rejects this path. MCP and App Intents do not expose recovery administration.

## Definition of ready

- A15/A18 and accepted A21/Q33 declare checkpoint-only retry, truthful recovery acknowledgement and the shared native facade. [Portable recovery forms](../portable-data-contract.md#native-import-delete-and-recovery-forms) already specify its behavior.
- The approved tests observe public bootstrap, commands, query/read, operation status and independent recovery. Controlled configured-file obstruction uses the existing native save I/O boundary, without database queries or production test-only hooks.
- Existing schema 14 snapshots/receipts already cover the supported graph and can publish independent recovery under the shared writer gate.

## Definition of done

- A known applied operation repairs its independent checkpoint after reopening without changing content, timestamps, identities, completion, order or query-row validity.
- The original result and checkpoint are observable through status and independently decoded recovery; the next ordinary mutation becomes available.
- Repeating retry after a later edit returns the original acknowledgement and never restores an earlier value or publishes another checkpoint.
- Continued recovery failure keeps the complete applied action, useful incomplete outcome and mutation block. Unknown, prepared-only and invalid-session attempts do not mutate or acknowledge data.
- Retry retains every supported graph group and prior deletion markers, and applies no data from an uncertain proposal.
- Focused real-store tests, affected strict lint, native host/app compilation and authenticated administration-boundary checks pass with exact execution/source records. Native administration UI, lineage, coherent account cutoffs and physical sync/Share remain separate gates.

## Required /tdd

Create Hotel with Original notes and a complete checkpoint. Obstruct recovery at native save while setting global completion Done; its exact applied result survives, independent recovery is incomplete and the next notes edit is blocked. Restore recovery access, reopen Core, capture current content/timestamp/hash and a canonical Item query, then retry the known operation. Require complete independent recovery, the same global Done Item, valid original row generation and the original applied result in status/backup. An ordinary Friday booking notes edit now succeeds. Repeating retry retains Friday booking, the original completion checkpoint and the newer latest checkpoint.

After this tracer passes unchanged, add graph preservation, continued I/O failure, unknown/session/prepared-only admission and concurrent facade retry cases at the same approved seams. Counts must distinguish functions from parameterized invocations. Missing declarations or compilation faults are setup failures, not functional red.

## Qualification

The [execution record](evidence/navigation/core-recovery-checkpoint-retry.json) retains commands, source epochs, package logs and native result summaries/test trees. The declared interface's unavailable body supplies the executable red; the same tracer bytes pass after implementing checkpoint work. Production remains fixed after that first green.

| Qualified surface | Functions | Suites | Invocations | Failures/skips |
| --- | ---: | ---: | ---: | ---: |
| Mac Core package | 24 | 9 | 37 | 0/0 |
| iOS 27 native Core host | 24 | 9 | 37 | 0/0 |
| Mac authenticated HTTP command routing | 12 | 1 | 15 | 0/0 |

Five new Core functions cover eight invocations. The original completion action remains known applied when file recovery fails. Its retry retains content, timestamps, hashes and query-row validity, publishes checkpoint 2, and unblocks the next notes edit at checkpoint 3. Repeating the completion retry returns its original result/checkpoint 2 while Friday booking and latest checkpoint 3 remain intact. A continued file obstruction retains the applied/incomplete result and write block, then succeeds when access is restored.

Two separately bootstrapped facades in one process concurrently retry the same operation and both observe one checkpoint. This does not qualify a host-closed Share extension, separate processes or physical synchronization. Unknown operation, prepared-only archive input, a foreign facade session and a separate dataset reject without changing current/acknowledged data. Prepared-only admission uses a declared external recovery-file input and verifies its unverified status; actual interrupted/account-reset evidence remains required.

The graph fixture preserves six sources, two memberships, three ordered itinerary entries, one expanded completion, four label associations, two schedules and a prior deletion marker. It retains owned bookmarks/location/estimate, archived Park, fixed timed instants and inclusive all-day dates. Standalone List completion becomes 2 of 2 while the independent itinerary remains 1 of 4. Normalized proposed/recovered data match. The first graph assertion incorrectly compared portable array position with saved route order; it now compares the same entry IDs by their declared ranks. The observation correction changes no production code, fixture values or expected completion.

The native repair path uses the same writer gate and validates the session and committed evidence before publishing the current supported graph with its original receipts. It inserts/saves no domain record and never executes a command. Missing/unreadable committed evidence cannot authorize recovery from a proposal. Already acknowledged evidence returns without another publication. Known committed evidence plus a failed archive read/publication retains the applied result and incomplete recovery.

The actual authenticated `retryRecovery` command attempt returns unavailable at `/command/type`, leaving Hotel and its prior recovery intact. Native source Delete/import/restore command attempts remain forbidden. Production MCP decoding/registration and App Intents are unchanged; this native method has no agent endpoint. Four affected Swift files pass strict lint. The Mac app compiles and its HTTP tests execute, with native Mac UI runtime still zero. All 292 native qualification source/configuration hashes stay fixed. Schema 14, portable format 1 and local-only mode remain unchanged.

Manual restore/import/export, native status/recovery forms and controlled native failure presentation remain open, as do lineage/convergence, interruption/process evidence and signed physical sync/account/Share. Calendar/estimate choices await Q59-Q61; groups/loading await Q57/Q58. Accessibility, responsiveness, native Mac runtime and whole-app polish remain required. Checkpoint repair is not a cloud-upload or all-devices-current claim.

## Later native qualification

The [native retry/status flow](native-recovery-checkpoint-retry.md) now qualifies the represented readable-store success, publication-failure and unavailable-checkpoint journeys, with their own phone/tablet evidence. The earlier pending-choice statements describe the historical Core slice; the [decision register](../open-decisions.md) records current choices. Unverified/interrupted outcomes, unavailable-store recovery, physical sync/account/Share, Mac runtime, scale and whole-app polish retain their separate gates.

The [canonical-copy follow-up](native-canonical-recovery-copy.md) handles later duplicate memberships or expanded rows while keeping Retry read-only. It preserves applied evidence through unproven input, separates recovery acknowledgement from the next native maintenance transaction, and qualifies matching Mac/iPhone coverage. Concurrent mid-read changes, interruption and native presentation remain separate gates.
