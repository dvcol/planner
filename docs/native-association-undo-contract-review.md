# Native original-association Undo

Status: approved under Q106 A and Q107 A on 18 October 2026. Native UndoManager integration and explicit mobile Undo are accepted; Redo remains outside this slice. Q104 A accepts current-app-run history. Q105 A accepts preserving a newer relationship and rejecting conflicting old Undo. Q33 already declares native-only association restoration and the snapshot's data fields.

## Context, goal and starting state

Removing a List membership or Itinerary entry currently saves the removal but offers no original-association Undo. Ordinary re-add correctly creates a new local Todo association. The removal writer has the original record and expanded completion states, but the native store currently returns only a Boolean.

The goal is to restore a removed membership or entry with its original public identity, rank and contextual completion, under a fresh authorized lifetime. Preserve live source content and unrelated changes. Reject restoration when a newer relationship, superseded history or invalid source/owner lifetime makes it unsafe. No Trash, source-Delete restoration, persistent Undo archive or automatic resurrection is introduced.

This first implementation covers the explicit `removeMembership` and `removeItineraryEntry` commands. Whole-field bookmark/label edits and Move do not silently acquire Undo through this slice. Their broader association-history behavior remains separate map work.

## Proposed Core interface

```swift
public struct PlannerAssociationUndoSnapshot: Sendable {
  // Public read-only Q33 fields; construction remains internal to Core.
}

// Optional native-only companion, separate from the applied receipt value.
PlannerOperationResult.associationUndoSnapshot: PlannerAssociationUndoSnapshot?

PlannerCommand.restoreAssociation(snapshot: PlannerAssociationUndoSnapshot)
```

The snapshot retains the accepted `datasetId`, `ownershipBinding`, bound `identity`, `closingOperationId`, `originalRecord` and `originalExpandedStates`. Reuse the existing immutable portable membership, entry, bound-identity and expanded-completion values. No public decoder or initializer fabricates an issued snapshot.

- Core captures actual removed records within its coordinated writer and issues the companion only after the local save succeeds. Rejected or unverified removals issue none.
- A private current-run issuance record validates the snapshot and can return the same companion for an exact removal replay. Native registration deduplicates by closing operation ID.
- Applied removal with incomplete recovery remains applied and retains its companion. Further changes, including Undo, stay blocked until checkpoint repair. Missing companion never changes an applied outcome into failure.
- Restoration uses the ordinary operation envelope, authorization, receipt and recovery handling. Identical operation replay resolves its existing receipt before fresh restoration eligibility checks.
- A new restoration validates current-run issuance, dataset/ownership binding, predecessor closure, surviving source/owner lifetimes and relevant association history. Unrelated source title/notes changes do not invalidate it.
- Restore the original public association ID, rank and local flags under a fresh restoration family/lifetime. Remap explicitly captured expanded contexts without restoring source content or reopening the closed predecessor lifetime.
- Reject a newer recreated membership, superseded restoration history or invalid bindings without replacing anything. Preserve unrelated independent changes. A local validation/save failure applies nothing; a post-save recovery failure preserves the applied result and uses checkpoint-only retry.
- Keep the companion outside `PlannerAppliedResult`, receipt encodings, portable backups, MCP and App Intents. No store schema or backup/receipt-format change follows from keeping history in memory.

## Native presentation proposal

Keep history per window in the `SavedPlannerView` lifecycle, rather than in the shared store. Register named removal actions only after an applied result supplies its snapshot. Scope history to its originating dataset/ownership binding, and clear invalid history on a namespace change or window destruction. Quit clears every window's history.

Q107 A selects the affordance. The accepted first slice uses the window's native UndoManager, retains normal text-field Undo, and adds an explicit native Undo action after removal on mobile. Association restoration supplies Undo only; it does not advertise an unimplemented Redo. While restoration runs, prevent another association-history action in that window. A retryable local failure retains the action for Retry; an ineligible stale action explains why it cannot restore and leaves current data intact. Recovery-incomplete outcomes follow the existing checkpoint workflow.

Apple's [closure registration method](https://developer.apple.com/documentation/foundation/undomanager/registerundo%28withtarget%3Ahandler%3A%29) uses a MainActor handler returning `Void`. Core operations await durable persistence and recovery. Native integration must therefore qualify the asynchronous completion/failure behavior explicitly; registering a closure alone does not establish correct Undo or Redo.

Restoration preserves any current valid selection. Restored rows return according to the current filters and sort; Undo does not clear filters or force a new detail selection.

## Definition of ready and required tests

Q106 A approves the concrete companion/command contract and existing public Core/native UI boundaries. Q107 A approves native UndoManager integration, explicit mobile Undo and no association Redo for this slice. The Core operation, removal, lineage and recovery seams already exist. No injected production callback, fabricated snapshot or private database inspection is added for testing.

Extend the real disposable-store operation tests one behavior at a time:

- Remove a locally Done membership, retain its source, then restore its exact public identity/rank/local state under a new lifetime. Ordinary re-add remains a new local Todo association.
- Remove one repeated direct/expanded Itinerary entry, restore its captured contextual states, and preserve the other repeated entry and source List state.
- Reject newer recreated/superseded relationships, wrong dataset/ownership, invalid owners/sources and stale lifetimes. Unrelated source edits survive valid Undo.
- Qualify failed save, recovery obstruction, applied/incomplete recovery, checkpoint retry, exact operation replay and same-run snapshot issuance. Reopening Core after relaunch supplies no previous Undo capability.
- Confirm forbidden MCP/Intent admission and unchanged data-only export/receipt encodings.

Extend existing native removal journeys for exact identity/local state after Undo, ordinary re-add conflict, filters, selected details, multi-window isolation, retry/in-flight feedback and current-run lifetime. Qualify the selected platform affordances without interfering with text-field Undo. Existing Core lineage fixtures supply literal identity/flag expectations.

## Definition of done

Supported removal commands return truthful applied outcomes and issued companions; restoration and replay pass their public-store tests. Native history and affordances pass represented Mac and Simulator journeys, strict lint and affected builds. Publish exact evidence and limitations. Unimplemented association kinds, Redo, signed storage and physical sync remain explicit owning-map work rather than implied completion.
