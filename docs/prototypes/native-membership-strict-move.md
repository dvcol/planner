# Strict membership Move history

This Q155 A follow-up extends the qualified ordinary Add/Remove mechanism to Move. It adds no schema, public command, target or production test hook. Signing stays deferred.

Move records the source membership's original pair and observation basis, its closure and its strict removal declaration atomically. A newly created destination membership observes that destination pair's known removals and starts Todo. An existing destination keeps its identity, rank, local completion and original observation basis. Shared Item content/global state and unrelated appearances remain independent.

New Move operations use sha256-payload-v3 and retain both original membership bindings/bases in the existing version-two stored/prepared evidence wrappers. Receipt and versioned preparation lookup precede current target resolution. Applied replay returns the original result/checkpoint even after the destination was removed and ordinarily re-added; it cannot resolve the old action against that replacement. The unversioned preparation and receipt paths keep the frozen payload-v1 encoding.

## Recorded tracers

The initial public-interface test reproduced a failed Move into a previously removed destination. With an existing destination, it also exposed the missing strict source declaration and old evidence format. The production change records both causal inputs and stages them with the closure before the existing durable preparation/native save.

The corrected test covers both destination cases. It retains an informed origin's exact basis, verifies the new source barrier and destination observations, reads the actual acknowledged digest/prepared wrapper, then removes/re-adds the destination and replays the original Move without changing current data.

A separate literal encodes an old new-destination Move independently from Swift, first checking the encoder against the already frozen legacy-Remove payload. The test constructs the corresponding historical native receipt input, then uses only public execution/export/recovery observations. Its original source membership is already absent. Replay retains the old result and digest; independent recovery repair retains the graph and the original checkpoint returned by subsequent replay. No old closure is promoted into a strict pair barrier. This qualifies a test-owned legacy receipt, rather than claiming execution by an old installed app.

The literal producer and test evidence are retained with this checkpoint. Existing frozen fixture files are preserved.

## Qualification and remaining scope

The [matched Core checkpoint](evidence/native-membership-consolidation/strict-move-validation.json) passes 198 functions in 79 suites and 575 invocations per platform. The Mac/iPhone cohorts include the existing atomic Move Undo, repeated expanded-state, failure and recovery cases. All 807 Core inputs match across Mac, phone and the adapter build; the full phone manifest has 1,146 inputs. Both actual Core products per platform are verified. All 512 earlier frozen fixture inputs and nineteen model source files remain unchanged, with one additional independent legacy literal. No skipped tests or SQLite lifetime diagnostics occur. Strict formatting passes for the three changed Swift files.

The actual Mac app, Share extension and fixture app compile. The real MCP/status cohort passes six functions; captured executable hashes match the final products. Its existing routing tests emit no owned-directory markers, so no additional deletion is attempted and no new directory-lifecycle claim is made. The system linkd diagnostics do not qualify system App Intent invocation.

[Six completed phases](evidence/native-membership-consolidation/strict-move-attempts.json) retain the initial failing tracer separately from successful runs. After host/file-closure checks, 1,113 distinct marked disposable stores from passing Core runs are removed; failed fixtures and evidence remain retained. This follow-up claims no new native UI journey or physical-device execution. Reviewed Overwrite and Capture reuse still need their affected observation/evidence paths. Exact eligible aliases, broader lifetime/family reconciliation, prepared-only interruption and remaining native recovery controls stay open. Actual Mac UI, protected signed/shared storage, CloudKit convergence, physical performance and system invocation remain separate gates. Q155 and the implementation map remain open.
