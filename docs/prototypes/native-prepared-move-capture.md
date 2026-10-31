# Prepared Move and Capture replay

## Qualified behavior

Extend the existing public-operation and recovery-file preparation test with
Move and Capture reuse. Each has three environments: missing current targets,
newer replacement relationships, and committed maintenance awaiting recovery.
The proposal is produced by an actual successful command, then supplied without
its receipt to an independently initialized store with the same dataset binding.

Retry returns that original preparation as unverified before resolving missing
or newer targets or demanding the original review. Changing Move's placement or
Capture's choice rejects with `operationPayloadMismatch`. Complete saved exports
and recovery-file bytes stay unchanged. A fresh Core instance reports the same
proposal after reopen. Pending maintenance continues to block new mutations.

Capture additionally creates and edits a separate current draft. The old retry
and mismatched request leave its generation, edited title and links unchanged.
Its original producer draft is unavailable in the independent/current and
reopened instances. This qualifies missing-draft handling, not restoration of
unsaved drafts across launches.

The new cases use the existing version-two proposal and membership execution
evidence with payload-v3 fingerprints. The original 54 completion/reorder/bulk
cases, including unversioned preparations, retain their expectations. No new
legacy Move/Capture literal is claimed.

## Trials and final evidence

The first Move cohort passes all 57 preparation cases. The initial Capture
fixture fails before establishing replay because its reused Item has no matching
saved link. The production reuse rule requires that match. Adding the link
through ordinary hash-guarded Item editing makes the fixture valid; the corrected
60-case preparation cohort passes. This is a fixture correction and supplies no
production bug/fix claim. Failed inputs/results remain retained.

The final validation
records five functions and 66 invocations passing on each of Mac and iPhone
Simulator. Alongside the 60 preparation cases, affected Move, Capture reuse and
two Overwrite paths pass. There are no failures, skips, timeouts or SQLite-unlink
diagnostics. Actual products and all 813 shared Core inputs match. Of 1160 native
inputs, only the existing test file changes; all 90 Core production inputs,
514 frozen fixtures and schema declarations remain unchanged. Strict Swift,
Markdown and whitespace checks pass.

The change adds no production code, test hook, target, package, public interface,
schema, format or writer gate. No HTTP or UI rerun is needed for this test-only
change. Verified cleanup removes 249 closed marked stores from passing runs;
failed-run stores remain. Manifests and overlays are losslessly compressed.

This is genuine preparation/replay input qualification, not an actual Move or
Capture process-death test. Existing shared maintenance termination evidence
keeps its own scope. Native/system/physical behavior, Q161 payload-specific fault
checks, Q163 and whole-app polish remain separate map work. Signing stays
deferred.
