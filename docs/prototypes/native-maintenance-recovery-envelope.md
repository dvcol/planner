# Maintenance recovery envelope compatibility

This Q155 checkpoint implements version-2 recovery envelope reads and preserves already acknowledged maintenance through ordinary saves. It does not create automatic maintenance attempts, native maintenance commits or maintenance-retry outcomes.

## Implemented behavior

Recovery envelope version 2 requires a separate maintenanceReceipts array. A receipt retains its flat maintenance identity, namespace, dataset, epoch, ownership, rule and preparation digest, plus applied state and original checkpoint generation. Unknown or missing receipt fields, malformed values, duplicate identities, mismatched ownership/epoch, unsupported rules and invalid generations reject inspection. Version 1 retains its existing fields and has no maintenance array. Explicit maintenance evidence cannot be silently interpreted as version 1.

Public namespace inspection and snapshot selection validate the independent checkpoint without opening the native store or creating control metadata. Inspection reports the portable version actually present in the validated payload. This corrects the earlier hardcoded version-1 summary.

When an ordinary command publishes after a version-2 checkpoint, it carries all acknowledged maintenance receipts forward unchanged and retains the version-2 envelope. Command receipts remain separate and retain their original checkpoint generations. Maintenance IDs do not produce applied user-command status. Earlier acknowledged files remain byte-identical. A real recovery-filesystem failure after native save and subsequent command retry preserves the same evidence.

## Executed evidence

The first public inspection rejects the previously frozen version-2 envelope. The corrected reader selects its exact portable bytes without mutating recovery or opening native storage.

The publication failure then demonstrates an actual ordinary save dropping maintenance acknowledgement and reverting the envelope to version 1. The publisher is corrected to preserve the prior version and complete acknowledgement array. The first publication success verifies retained evidence, original command replay, native/recovery graph agreement and reopen. Native export uses pretty-printed JSON while recovery uses compact JSON, so the test compares their complete parsed graphs. It separately checks exact bytes for the earlier acknowledged file.

The integrity/retry matrix rejects 23 malformed acknowledgement cases through both namespace inspection and snapshot selection. The final cases also exercise legacy and empty version-2 envelopes. The ordinary-save fixture adapts the frozen acknowledgement to a disposable real dataset; it is input evidence for carry-forward tests, not proof that Planner created a maintenance commit.

## Fixture lifetime diagnosis

The first affected phone run passes its assertions but records 48 SQLite lifetime warnings, so it is not accepted as clean qualification. The original diagnosis verifies that the warnings name 16 unmarked temporary roots in NativeStatusAdmissionTests and RecoveryCheckpointRetryAdmissionTests. The run's exact inputs and actual products are verified before the baseline trial replaces the staged build.

An isolated run of unchanged commit 6559feee reproduces all 48 warnings in those two suites. The fixture helpers' hashes match the original run, and every baseline input matches the committed archive. This establishes the old fixture lifetime problem before changing it.

Both helpers now use the existing owned fixture mechanism, with deletion deferred until verified host/SQLite closure. The missing-store case moves its directory aside, preserving the absent-path test without unlinking an open database. No behavioral assertion is removed. Earlier warning runs retain their original logs and incomplete-qualification status.

## Final local checkpoint

The corrected Mac cohort and iPhone simulator cohort each pass 137 functions in 62 suites, comprising 481 invocations. Final logs have no failure, skip or SQLite lifetime diagnostic. The common cohort excludes the macOS-only separate-process notification test; that test already passes in the earlier 138-function Mac cohort.

The reconciliation verifies identical test signatures and argument counts, 802 matching Core inputs, 1,139 phone project inputs and both actual test products per platform. Strict formatting passes for all affected Swift files. Frozen schemas V1–V18, original portable/migration fixtures and wire literals remain unchanged. This report explicitly leaves canonical consolidation, native maintenance recovery and new fingerprint-vector execution unqualified.

After verified host and SQLite closure, 2,267 disposable fixture directories are removed across passing phases and the final runs. This includes 441 marked, unaffected roots from the warning run, removed only after exact-base diagnosis and corrected qualification. Their separate cleanup report proves that none contains a warning path and keeps that original run unqualified. Original logs, frozen inputs and failed behavior fixtures remain retained. Reclaimed physical bytes are not measured.

## Remaining integration

Canonical duplicate resolution, durable maintenance preparation, native commit verification, maintenance status/admission/retry, prepared-maintenance inspection and native recovery controls remain open local work. New membership observations, versioned operation evidence and the legacy receipt baseline also remain on the approved contract. Physical/shared storage, CloudKit convergence and actual Mac UI retain separate gates. Signing stays deferred.
