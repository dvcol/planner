# Import additions into an existing planner

## Context and goal

At `54e0401`, a complete independent backup restores into an empty native dataset. Every nonempty dataset still rejects import execution, even when review has already classified new owners and protected current owners. The accepted Skip rule keeps conflicting and omitted owners, including all their owned records, while adding independent new content.

This stage applies those additions through the same native transaction. New Lists can reference current Items without copying them. Current source and reference models retain their identities and values. Reimporting the file with fresh operation identities creates no duplicates.

## Definition of ready

- Whole-owner Skip/Overwrite classification, Q73 omitted-owner preservation and exact reference lifetimes are accepted.
- Public native decode/review/execute/export/recovery/reopen and actual storage I/O remain approved test boundaries.
- The complete empty-restore fixture, replay, independent recovery and schema-16 lineage have passing evidence.

## Definition of done and required /tdd

- Execute a reviewed Skip import with conflicting Item content/global completion and List order/local history, an omitted shared Tag, and independent new Item/List content.
- Run both represented-conflict and omitted-owner variants. Retain all current content, metadata, references, order and completion history.
- Exercise source identities that interleave across Item and List kinds, instead of relying on fixture IDs that happen to sort in kind order.
- Preserve explicit imported identities, lifetimes, timestamps and saved ranks. Resolve new List memberships against existing Items and report only newly generated sources.
- Verify the complete graph through native export, its acknowledged recovery checkpoint and reopen. Fresh repeated imports generate nothing and leave the graph unchanged.
- Keep empty restore, unsupported-field rejection, preparation failure, ordinary completion history and exact external-binding review behavior passing.
- Run affected native/HTTP checks, strict lint and app/test-host compilation; retain failed fixture admission, functional reds and final source epochs.

## Implementation and proof

The first fixture omitted a required null List global-completion field. Public decoding rejected it before execution; that failure is excluded from functional red. The corrected fixture reaches the nonempty execution gate. The writer now selects only reviewed additions and their owned data, retains current owners and history, and resolves references through existing native models.

An intermediate guard incorrectly rejected non-live deletion history and regressed empty restore. The corrected guard keeps destructive live-data execution gated while retaining ordinary deletion metadata. Another failure exposed array ordering in the fidelity comparison. Projected data now uses native storage order; saved manual ranks remain unchanged.

Spec review found that globally sorting source UUIDs still differed from native kind grouping. The interleaved-ID variant reproduced the fidelity rejection through public execution. The corrected projection groups sources by kind and sorts identities within each kind. All four represented/omitted and ordinary/interleaved cases pass. Review and execution now share their completion-context owner lookup.

Final qualification: 46 Core functions in 22 suites, 86 invocations, pass on both the Mac package and native iPhone simulator. The Mac HTTP checks pass 16 functions in four suites, 22 invocations. No failures or skips. Five affected Swift files pass strict lint; the Mac app and navigation test host compile. No new UI journey ran for this Core change. Standards and spec review have no remaining confirmed findings.

Replacement execution, live deletions, restoration, recorded import summaries, unsupported origins/provider values, native forms and direct local-save failure proof remain open. This stage does not complete the import ticket.

Commands, counts, source hashes and retained failures are recorded in [execution evidence](evidence/navigation/core-native-import-additions/execution.json). Earlier [empty restore proof](core-native-import-apply.md), [preview proof](native-delayed-link-result.md) and [loading proof](native-loading-fixture.md) remain applicable.
