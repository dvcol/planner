# Remaining original-association Undo decisions

Status: proposed Q109/Q110 frontier. No implementation or new tests are authorized by this proposal. Q106/Q107's membership/Itinerary-entry slice and Q108's separate controller-test choice retain their existing status.

## Context and goal

[Q33](https://github.com/dvcol/planner/issues/13#issuecomment-6070841289) and the [portable contract](portable-data-contract.md) accept original-association restoration for memberships, entries and owned associations. The first concrete slice deliberately covers explicit membership/entry removal only. Owned bookmarks and label associations remain current-map work. The generic declaration does not settle the inverse of a compound Move or the grouping of several removals in one editor Save.

Before this follow-up, Move removes an origin membership and creates or retains a destination membership. Guarded Item/Itinerary edits can remove several bookmarks, Categories or Tags while also changing content. Those operations have no original-association native Undo. The goal is a truthful native history action that preserves unrelated edits and newer relationships, with explicit compound-action semantics.

## Q109: Move

Worked example: Museum is locally Done in List A. Moving it to List B closes A's membership and creates a new local Todo membership in B. If B already contained Museum, that existing membership and its state are retained instead.

Recommended A reverses the Move atomically. Restore A's original membership identity, order and local/expanded state under a fresh authorized lifetime. Remove B's membership only when this Move created it and it remains safe to reverse. An already-existing B membership stays intact. If later association changes make reversal unsafe, reject the whole Undo and explain; do not overwrite that newer work. Shared Item content edits survive. This matches an action named Undo Move, but needs a compound inverse and destination guards.

Alternative B restores the removed A association only. B keeps its membership, including one created by the Move. The history action must say Undo Remove from A rather than imply full Move reversal. This is smaller and fits the first slice's restoration model, but Undo can leave Museum in both Lists.

Alternative C explicitly defers Move Undo beyond this map. Ordinary Move stays available and its existing transactional rules remain. This reduces current scope but leaves a deliberate editing-history gap. It does not defer bookmark/label restoration already required by Q33.

## Q110: Several removals in one Save

Worked example: one Item editor Save changes notes, removes two bookmarks and removes one Tag association. The Item, Tag and bookmark source URLs are otherwise retained according to the ordinary edit rules.

Recommended A creates one named association-removal history action for that Save. Undo restores the whole removed-association group atomically with original identities, link order and other owned record fields under fresh authorized lifetimes. It preserves the new notes and independent additions. If any removal cannot be safely restored, reject the whole history action without partial restoration. This needs grouped issuance/validation, but avoids several Undo presses for one Save.

Alternative B gives each removed association a separate named history action. Each can succeed or reject independently, and several Undo presses can restore only part of the Save's removals. This makes an individual restoration smaller but adds several history entries and requires explicit capability ordering/deduplication.

Neither choice restores deleted shared Items, Lists, Itineraries, Categories or Tags. Removing a label association is distinct from deleting the shared label. Repeated authored bookmark URLs remain distinct identities; URL equality alone is not a restoration conflict or merge rule.

## Next contract and definition of ready

After Q109/Q110, write the concrete snapshot/result/restore contract and literal fixtures before tests or implementation. The current companion/history deduplicates one snapshot per closing operation and has only membership/entry record variants. A grouped design must define one operation's issued capability, replay, namespace/lifetime guards, native naming and failure outcomes without persistent history or adapter/backup exposure.

The next review must settle bookmark order alongside retained/new links and the exact guards on a newly created Move destination. Keep original public identities and closed predecessor lifetimes separate from fresh authorized restoration lifetimes. Define the effect on contextual children before writing its tests.

## Required tests and definition of done

Use the existing real-store operation and native UI boundaries after the concrete contract is accepted. Do not add a direct history-controller seam through this proposal.

- Move into an empty destination and an existing destination; original Done/order/expanded state; later destination changes; unrelated Item edits; all-or-nothing rejection and preservation of newer associations.
- Item and Itinerary edits removing several bookmarks and labels, with literal original/retained/new identities and link order. Test duplicate URLs without name-based merging and a deleted/changed label binding.
- Current-run issuance, exact replay, superseded history, wrong dataset/ownership, genuine local save failure and applied/incomplete recovery with checkpoint-only retry.
- Native action grouping/naming, explicit mobile Undo, filters/valid selection, relaunch expiry and preserved ordinary text Undo. Keep unavailable actual Mac runtime separate.
- No source-Delete recovery, association Redo, persistent history, MCP/Intent administration or backup/receipt-format change is implied. Publish affected lint/build checks and exact executed evidence; physical sync and full UI review retain their own gates.
