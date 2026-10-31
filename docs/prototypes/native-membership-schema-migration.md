# Membership schema migration

Q155 A approves native schema 19, portable version 3 and separate membership-maintenance recovery. This checkpoint implements the structural migration first. Canonical membership resolution, strict removal provenance and maintenance recovery remain open.

## Genuine schema-18 input

The unchanged production schema-18 code ran the existing V15 migration journey, edited the Museum's notes and replayed its original creation. Its native host exited and no process held its SQLite files before freezing the new `Fixtures/SchemaV18` resource. Native metadata reports `18.0.0`. The producer record retains every original file hash and the executed source packet.

The frozen graph has a locally Done membership and live List/Itinerary references. Its seven acknowledged checkpoints retain the original creation receipt at generation 1. The expected graph comes from the digest-verified schema-18 checkpoint. Only the new fixture's manifest and expected graph are updated to describe that actual closed store. Existing fixture resources stay unchanged.

## Structural implementation

`PlannerSchemaV19` reuses the unchanged V18 models and adds the approved optional/defaulted MembershipProvenance and MaintenanceCommit models. The main app owns the lightweight migration. Share requires the main app while the control file describes an older schema. Current sessions, recovery namespace discovery and new checkpoint validation recognize schema 19.

The new public-interface migration test verifies Share refusal without changing control bytes, full graph preservation, the Item lifetime, exact original command result and checkpoint, and unchanged historical recovery files. A new global completion save advances generation 7 to 8, publishes schema 19 and keeps original replay at generation 1. Reopening retains the saved completion and lifetime.

Migration tests use the established marked fixture lifecycle. Disposable stores remain until their native hosts and SQLite handles close, then the existing verifier removes them.

## Executed evidence

The qualified baseline fails because schema-18 Share currently accepts the store instead of requiring migration. Earlier compiler and temporary-path comparison failures remain separately recorded. Both sides of the final file comparison resolve macOS temporary-directory aliases.

The final Mac cohort passes 18 functions across 14 migration suites, including genuine V18 and skipped earlier versions. All 789 Core inputs remain unchanged during execution; the log has zero SQLite unlink diagnostics. Strict formatting passes for every affected Swift file. The validation compares all frozen V1–V18 declarations and original tracked fixtures against the prior checkpoint. Twenty disposable stores from passing Mac runs and eighteen from the passing simulator run are removed only after verified closure; their logs, results and frozen input remain retained.

The schema-19 duplicate diagnostic still fails at the shared List query. Its exact source is retained in that packet, outside the shipping test target. No consolidation pass is claimed.

The final iPhone simulator cohort also passes the same 18 functions across 14 suites, with no failures, skips or SQLite unlink diagnostics. Its 1,126 staged inputs and both actual test products match the workspace; all 789 Core inputs match the Mac run. The initial simulator attempt stopped before test execution because an old dependency-cache path was empty. The retry reuses seven existing clean checkouts at the exact repository-pinned revisions. Portable-v3 bytes, command fingerprint compatibility and separate automatic-maintenance recovery are subsequent implementation work. Actual signed/shared storage, CloudKit convergence, physical interruption/performance, external Mac UI and final whole-app polish retain their existing gates. Signing stays deferred.

## Frozen wire inputs and next failing read

The approved contract requires independent wire fixtures before their implementation tests. `Fixtures/MembershipConsolidation` now contains a literal portable-v3 graph, a maintenance preparation, a recovery-v2 envelope and operation fingerprints for legacy versions 1/2 and the new version 3. An independent Python tagged-value encoder produces the fingerprint bytes without executing Planner code. The producer and hashes retain their exact provenance.

The worked graph keeps M401/841 closed under D891 and represents an informed ordinary re-add M405/845 that observes D891 and starts Todo. It retains the original Item/List lifetimes and leaves global completion Todo. The maintenance envelope's data/preparation digests bind its exact literal bytes.

The first bytes-only decoder tracer executes the existing public `decodeImport` interface and fails with `invalidInput` at `/membershipProvenance`: the property is not supported yet. It opens no native dataset. Its exact source and failed execution remain retained outside the shipping target while dependent implementation continues. The wire fixtures have no passing import, maintenance or fingerprint execution claim. At the wire-freeze checkpoint e145eb4b, production export remained version 2 and recovery publication version 1. The [portable-v3 follow-up](native-membership-portable-provenance.md#final-local-checkpoint) now preserves native provenance and passes matching 97-function Mac/iPhone cohorts. Separate maintenance recovery remains unimplemented; Q155 work stays unblocked.
