# Restore deleted data through reviewed import

## Context and goal

At `ab24fd2`, native Overwrite reconciles source/reference deletion but rejects restoration. A pre-deletion backup cannot restore its Item, container or labels and included references. Existing closure metadata must continue suppressing obsolete lifetimes.

An explicitly confirmed restoration must keep public identities and portable values, assign new authorized lifetimes to closed records, preserve old closure/history data and save the complete selected graph with independent recovery. Ordinary Overwrite remains unable to restore deleted data. Deleting a restored record closes its entire family; another explicit restoration starts a new family.

## Definition of ready

- A14/A20, minimal restoration-family metadata, whole-owner modes and independent recovery are accepted.
- Source/reference deletion and full export/reopen already have qualified native boundaries.
- Use the existing portable family grammar and native lineage storage; no new schema fields or agent administration endpoint.

## Definition of done and required /tdd

- Reproduce the public deleted-source review gate, then verify new lifetimes under retained public IDs and original content.
- Keep separate restoration authorization in the reviewed command. Default Overwrite rejects restoration; a token for that default cannot authorize the changed command. Skip with restoration authorization is invalid.
- Exercise all five source kinds with a complete planning graph. Preserve included reference identities, local/global completion, archive state, order, fields, closed history and surviving shared data. Report restored sources/references in the applied result.
- Compare full independent recovery, reopen and original-operation replay. Reimport the restored export without duplicates and faithfully copy it into an empty planner.
- Reproduce restored-family Delete failures for all five kinds under native Delete and import deletion. Persist valid family closures through ordinary builders and supplied/generated import markers; retain existing model fields and older marker compatibility.
- Restore again after deletion with a new family descended from the last closed candidate.
- Skip a supplied restored-candidate backup without adding its skipped source or family. Reject source/owned candidate reconciliation and conflicting known-family metadata before any partial import, receipt or content update.
- Reproduce normalized-marker reimport failures. Freshly reimport the identical deletion payload without graph changes; retain rejection of actual operation/target/explicit-family collisions. Replay cannot change restoration authorization.
- Requalify affected import, deletion, recovery, migration and HTTP tests, native compilation and strict lint.

## Proof and limits

The initial native Item tracer reproduces the review gate. The complete five-kind matrix then exposes unordered family readback; sorting the projected families fixes native equality. Broader closure checks expose that the first pass incorrectly allows ordinary Overwrite restoration. Separate authorization now retains the default rejection and binds a fresh review and replay digest.

Spec review identifies family closure after restored Delete. The matrix reproduces all five failures, then passes after every ordinary native marker builder closes matching families. A subsequent restore initially fails by reusing the old predecessor; following closed family ancestry gives a fresh family while retaining the closed ancestors. Standards review identifies candidate/family metadata from skipped owners; selected-owner filtering and exact-binding gates preserve the graph, including a reproduced owned-membership bypass.

Review then identifies missing family closure in supplied/generated import markers. The matrix now covers native/import deletion for each source kind, asserts every affected family closes and restores again successfully. Fresh deletion reimport exposes a comparison made before normalization. Normalizing before both collision comparison and insertion fixes the five failures while preserving genuine collision rejection. Final rechecks have no remaining confirmed findings.

Final qualification passes 119 Core functions in 54 suites on Mac and iOS Simulator, with 340 invocations on each. Native HTTP passes 16 functions in four suites, with 22 invocations. Strict lint passes for ten changed Swift files; the Mac app/navigation test-host build passes. Commands, final source hashes, native results, logs and fixture cleanup retain the evidence.

Incoming candidate/family consolidation, broader rebinding, source origin/provider persistence, complete summaries/native forms and direct database-save failure proof remain open. No physical convergence, account-transition, Share or native UI runtime proof is claimed here.
