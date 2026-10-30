# Private CKSyncEngine implementation checkpoint

30 October 2026. Implements the transport selected by Q164 A. The installed
application remains unchanged and production configuration still selects
`localOnly`. This is a bounded implementation checkpoint, not sync acceptance.

## Implementation

- Local SwiftData remains authoritative and explicitly uses `.none`.
  CKSyncEngine targets only `CKContainer.privateCloudDatabase`. There is no
  public/shared database or alternate backend, including on quota errors.
- Fourteen native model kinds map their scalar values to versioned CloudKit
  records. Stable record names include complete lifetime-bound identities.
  Saved source content, association order, contextual completion, owned links,
  bookings and existing deletion/provenance history use the same Core rules.
- Individual fields merge against the last acknowledged record. An upload
  acknowledgement preserves local edits made while the request was in flight.
  Received data is validated before its domain graph and transport state commit
  together. Existing canonical maintenance and independent recovery run afterward;
  an incomplete recovery is reported and blocks new mutations without inventing
  a successful user command.
- Private-bound stores add one local transport-state model: physical schema 20,
  writer gate 24. Device-only/unbound stores retain physical schema 19/gate 23.
  Portable format 5 is unchanged. Engine serialization, server records, pending
  incoming changes and local status stay outside portable backups. Local command
  receipts and maintenance evidence are not copied between devices.
- A file lease admits one main-app worker per account store. Share writes locally
  without starting CloudKit. A waiting main-app window can claim a released lease.
  Account/session generations reject obsolete callbacks. Apple's automatic
  scheduling and transient retry behavior remain enabled.
- Transport-only history does not invalidate data queries. Acknowledgements that
  change no domain values skip relationship rebuilding. Real incoming changes
  still invalidate canonical queries. Status distinguishes queued/active work,
  failures and local transactions acknowledged by the server.

## Passing evidence

The [signed native result](evidence/private-sync-engine/runtime.json) passes in
21.657 seconds using the actual public Core command/query/export interface and
real Development private CloudKit. Separate launched app processes have separate
local stores and use the approved team/container; no account setting changes.

The fixture creates five sources and includes Item address/pin, mixed duration,
notes, Item/Itinerary links, Category/Tag selections, List manual duration,
membership, direct and expanded route entries, contextual completion, a timed
Item booking and an inclusive all-day Itinerary booking. A fresh peer exports
the exact same complete represented graph, including public identities,
lifetimes, timestamps and history. After reviewed Item deletion, another fresh
store exports the exact post-deletion graph. The original query generation also
survives metadata-only upload acknowledgements.

The first complete-plan attempt reproduced unwanted query invalidation after
acknowledgement. Skipping unchanged domain updates corrects that case; the same
native scenario passes afterward. An earlier history predicate incorrectly
excluded nil-author transactions; the corrected predicate retains ordinary
local changes and the independent-writer regressions pass.

The affected real-Core cohort passes 22 tests across seven suites: private
configuration, recovery failures, change streams, dataset presentation scope,
Item creation in a List, Manual itinerary queries and archived progress.
Strict Swift formatting and the Mac app compilation also pass. The native
build/runtime wrapper verifies matching input hashes and Development signing.
The installed app's Info.plist, executable and signature resource hashes are
unchanged. Diagnostic source and bounded results are retained beside this file.

## Open outcomes and next steps

An already-open peer on this Mac did **not** observe a later deletion within
120 seconds. Direct private SDK readback confirmed the Item was absent on the
server; SDK logs reported no zones needing a fetch. Separate processes,
foreground activation, engine recreation and an explicit subscription experiment
did not establish live catch-up. The unsuccessful recreation/subscription
changes were removed. The passing fresh-store checks do not close this failure.
Actual two-device live delivery and explicit refresh remain required.

Further local work includes deployment/Share configuration, explicit attachment
of existing unbound plans, native status/retry qualification, genuine older-writer
rejection, interrupted/pending work and conflict/failure coverage. Quota/account
isolation, physical multi-device behavior and scale remain acceptance gates.
Synthetic fixtures still need scoped cleanup after their follow-up checks.

Per the user's latest direction, combine one attended Planner-only iCloud off/on
cycle with final integrated sync checks. It must prove local read/edit/relaunch,
same-account resume and no alternate cloud storage. No standalone switch test is
waiting and no manual account action blocks continuing implementation.

## Durable Share edits and independent fields

The [follow-up native run](evidence/private-sync-pending-edit/runtime.json)
passes on final source in 37.334 seconds. After a peer imports the plan and
exits, its Share-role process saves new notes without starting a sync worker.
Core reports pending cloud work, rather than falsely acknowledging that save.
The other store independently saves and uploads a new title. Reopening the
original peer's main-app worker preserves both edits and acknowledges the merged
record. Complete-plan and fresh-store deletion readback also pass again.

The [first attempt](evidence/private-sync-pending-edit/before-resume.json)
preserved both content edits but replaced the later title-edit timestamp with
the older queued notes timestamp. Record merging now retains the later saved
`updatedAt` from either side. The production-interface check verifies the exact
later timestamp after synchronization. The affected local cohort passes 32 tests
across nine suites, adding Item editing and container catalog sorting.

This proves durable pending work and independent-field merging across process
exit/reopen. It does not qualify a network outage, account removal, quota failure,
or two-device live delivery; those gates remain open.

## Genuine older-writer refusal

A separate signed diagnostic links the unchanged Core sources from `f3efee75`,
before private transport and writer gate 24. It opens the upgraded synthetic
writer's actual account-bound paths using the existing public private
configuration. Bootstrap rejects with `unsupportedVersion`; all 32 fixture file
contents remain unchanged. The [native result](evidence/private-sync-older-writer/runtime.json)
passes in 1.037 seconds. This qualifies the older-writer refusal, not every
historical data migration. It requires no account setting or signing-resource
change.

## Retry after rejected incoming staging

The [new regression](evidence/private-sync-staging-retry/before-peer.json)
reproduces a missed download after a temporary local binding failure. A test-owned
peer invalidates only its disposable writer-control epoch during the initial
fetch, observes the actual staging error, then restores the original bytes.
Previously, retry reused the engine's advanced in-memory fetch state and did not
recover the expected graph. No iCloud account setting changes in this test.

The worker now pauses after an inbox/state write fails, ignores subsequent
transport updates and reloads the last durable state when retry is requested.
Account invalidation still works while paused. New incoming conflict/deletion
knowledge also receives this protection. An already durable inbox remains
available when graph validation rejects its application. Repeated identical
cloud errors coalesce instead of creating further metadata writes.

The [final signed run](evidence/private-sync-staging-retry/runtime.json) passes
in 77.189 seconds, including observed failure, repaired retry, exact complete-plan
readback, pending Share edits, field/timestamp merging and fresh-store deletion.
The affected Core cohort passes 22 tests in seven suites. Mac/mobile compilation
and strict formatting pass. This is a local staging/retry check; actual disk-full,
quota, permanent server rejection and two-device live/account behavior still
need their separate qualification. No domain, portable or recovery format changes.

## Permanent upload rejection and correction

The [signed follow-up](evidence/private-sync-permanent-error/runtime.json) passes
in 126.598 seconds. CloudKit rejects a synthetic Item with 1.1 million characters
of notes. The Item remains readable locally, the error stays visible, and an
explicit retry after shortening its notes sends the corrected graph to a fresh
peer. The complete-plan, staging-retry, queued Share edit, concurrent-field and
deletion checks pass in the same run.

The [earlier attempt](evidence/private-sync-permanent-error/before-runtime.json)
left synchronization in progress with no lasting error; direct SDK inspection
confirmed the large Item was absent remotely. Permanent errors now stay paused
instead of being cleared by a later fetch. Only handled conflicts request an
immediate follow-up; Apple's scheduler owns transient network retries. Local
editing is not paused by an upload rejection. The affected Core cohort passes
22 tests across seven suites, and strict formatting passes. This checks a real
permanent record rejection, not quota exhaustion or every request-size limit.
