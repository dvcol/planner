# Atomic Move Undo in Core

Status: the approved Q111 whole-Move inverse passes the affected local Core tests. Native Move registration and its UI journey are the next slice. Grouped bookmark/label restoration remains separate approved work. This report does not close Navigation or physical sync acceptance.

## Context, goal and starting state

Q109 A and the [Q111 concrete contract](../native-compound-association-undo-contract-review.md) require Undo to reverse the entire Move atomically. The original membership must return with its identity, saved order and local completion. A destination membership created by the Move must disappear only when it is safe to reverse; an existing destination must remain intact.

Before this slice, Move saves its normal association changes but issues no native Undo companion. The existing `restoreAssociation` command supports only explicit membership/Itinerary-entry removal. Original source content must remain live, and Undo must preserve subsequent notes/global-state edits and unrelated relationships.

## Readiness and implementation

Q111 approves the concrete values, guards, replay/recovery rules and existing real-store/native test interfaces. Extend the existing snapshot with `membershipMove(PlannerMembershipMoveUndoRecord)`; construction remains internal to Core. Its original membership, optional created destination and destination context bindings are captured in the coordinated writer and issued after successful local commit. Exact Move replay retains the same current-run companion.

Restoration reuses the original-membership path and fresh lifetime/lineage handling. Before staging the inverse, validate the created destination's exact identity/lifetime, bindings, rank, local flags, referencing entry set and explicit expanded states. Preserve a preexisting destination, including its later local changes. A newer origin membership or changed created destination rejects the entire action. Close the removed destination's lifetime through ordinary deletion metadata and include both Lists and affected contexts in the result. Source content, archive/global state and unrelated memberships remain untouched.

The same restoration transaction and receipt cover both halves. The snapshot remains outside backup/receipt encodings and agent interfaces. No schema, target or package is added.

## Executed red and green observations

The initial test compile fails on an optional Boolean assertion. After correcting that test declaration, the actual behavior test fails in 0.116 seconds because a successful Move supplies no Undo snapshot. The first implementation passes in 0.163 seconds, restoring the original Done membership, preserving edited notes/unrelated destination data and replaying both operations without repeating changes.

The preexisting-destination case passes in 0.148 seconds. Its original destination identity and later reopened local Todo state survive Undo. Six newer-relationship cases pass together in 0.254 seconds: completion, order, a newly referencing branch, expanded completion, destination remove/re-add and origin replacement. Every rejection preserves the complete public backup byte-for-byte. Independent repeated origin contexts pass in 0.184 seconds, restoring one Done and two Todo appearances with progress 1 of 3.

The genuine isolated native save-failure test first fails in 0.188 seconds. Move rolls back the data but leaves prepared recovery evidence, so its operation status remains unverified rather than allowing a clean unchanged retry. The fix retains the proposal identity and discards only that known failed save's preparation, matching the existing restoration failure path. The whole failure test then passes in 0.348 seconds, exercising both Move and its inverse, reopening the store after each failure, comparing unchanged exports and retrying the same operation identity.

Applied-but-recovery-incomplete Move and inverse cases pass together in 0.128 seconds. The applied action remains present, later mutations stay blocked, and repair publishes only its checkpoint. Exact replay returns the original result; it does not repeat removal/restoration. The repaired Move's issued snapshot remains usable.

## Final local qualification

The final affected invocation passes **27 test functions in nine suites**, zero failures, in 1.514 seconds. It includes Move, original membership/entry restoration, expanded contexts, issuance/replay, stale lifetimes, native save failure, recovery and originating-List creation failure. Parameterized cases retain their exact per-input observations in the log. The earlier 16-function intermediate invocation also passes and remains recorded.

The execution index retains all eleven Core epochs, including both initial diagnostics and the actual save-failure red. The validation record binds the final package inputs to current source and records affected strict Swift/Markdown lint, whitespace and local links. Its manifest covers the evidence and source snapshots. The bounded credential-pattern scan has no findings.

The native caller still returns only a Boolean, so its Undo registration must be implemented and exercised separately. Native compiler/runtime evidence belongs to that next slice; no interaction credit is claimed here.

## Definition of done and remaining gates

Core now implements the represented atomic inverse, validation, original/independent contexts, truthful save failure, recovery and replay at the approved public seam. Native Move result propagation, named window/mobile history, native failure presentation and agent admission regressions remain part of the next slice. Grouped owned-association restoration is approved but not implemented by this change.

Local Core and compiler results do not establish CloudKit convergence, physical account/Share behavior, actual Mac window/text-field UI, signing, scale or final whole-app polish. Those owning-map gates remain open.

The later [native whole-Move Undo checkpoint](native-move-undo.md) supplies its own caller, controller, HTTP and represented phone/iPad qualification. This Core report retains the scope and source epochs above.
