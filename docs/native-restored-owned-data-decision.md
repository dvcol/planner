# Remaining restored-data choices for the MVP

Status: Q161 A and Q162 A approved on 25 October 2026. Q160 is complete for its approved independent target references. These choices concern data that Q160 explicitly preserves without reconciling. Their implementation remains open; signing is unrelated.

## Existing behavior and implementation limits

A20 already chooses one deterministic source version. Independent owners and their authorized inbound references survive. Q160 implements that target rebinding, but rejects a losing source that still owns collections, or label rebinding that creates two association identities for one owner/label pair. The complete projection rejects before native changes or recovery preparation.

Manual import already resolves collection owner/target lifetimes and reviews complete owners. It does not decide how two native candidates' owned collections combine. Existing source maintenance, deletion markers, graph validation and atomic persistence are the implementation starting points. No new reconciliation framework, record field, portable format or writer gate is proposed by this decision document. Any concrete compatibility requirement must be established before changing those declarations.

## Q161: contents owned by a losing restored version

Example: winning Museum814 owns Guide A and Booking A; losing Museum815 owns Guide B and Booking B. An independent Tour references Museum815. A restored List can similarly own different memberships, and a restored Itinerary can own different ordered stops.

- **A, recommended:** keep the winning version and its complete owned contents. Retire the losing version's bookmarks, bookings, label selections, memberships or stops with the existing truthful closure rules. Guide B and Booking B are no longer live. Independent Tour survives and follows Museum814. Removing a losing List's membership never deletes its shared Item. Do not redirect discarded relationship identities to different relationships. A current guide or Undo action must follow its existing invalid-context rules when its exact relationship disappears. This preserves one consistent version and avoids collection merging.
- **B:** retain unique losing-owned records and combine them into the winner. Guide A and Guide B both survive. This requires further conflict, ordering, duplicate identity and completion rules for each owned collection before implementation.
- **C:** defer these cases beyond the MVP. Keep the current atomic rejection and preserve all records. A dataset containing this conflict still cannot supply a canonical read/export until reconciliation is implemented. This explicitly leaves part of A20 unfinished.

The same policy applies to every source kind. Expanded completion belonging to a discarded itinerary or List relationship must not transfer to an unrelated surviving appearance. Independent sources, their owned state, history and exact old-command replay remain protected. Unknown, closed or unproven families retain their existing rejection rules.

## Q162: duplicate label selections after target rebinding

Example: surviving Item Museum has association701 selecting Tag601/815 and association702 selecting winning Tag601/814. Rebinding produces two selections of the same shared Tag. Existing uniqueness permits one selection per owner/label pair.

- **A, recommended:** keep the association with the smallest public UUID, rebind it to the winning label and close the other association with existing history. Museum shows the Tag once through association701. Keep Museum's content and edit timestamp unchanged. Old association702 identifiers do not alias to701, so stale actions and Undo retain their existing rejection behavior. Deterministic identity selection does not depend on delivery order.
- **B:** keep the association already selecting the winning label, here702. This favors the existing winner binding, but needs an additional rule when several colliding records have already been rebound before another delivery.
- **C:** defer automatic collision reconciliation beyond the MVP. Preserve both records and the current atomic projection rejection. Reads/export remain unavailable for this conflicting graph until reconciliation exists.

Q162 is independent of Q161: its owner already survives, and the competing records differ only in their association identity and label binding.

## Implementation and qualification

Use the existing Core/native-input, recovery-filesystem, process, native UI and HTTP boundaries. Start with one literal owned-collection conflict and one literal Category/Tag collision. Reuse complete-graph projection and current maintenance rather than building a parallel path. Confirm discarded identities stay closed after redelivery, surviving references keep their exact scope, failed saves change nothing, Retry/replay remain truthful, and unchanged independent data survives reopening. Review any concrete declaration changes that the implementation actually requires before introducing them.

Physical/cloud convergence, actual Mac interaction, installed Share, signed storage and whole-app acceptance remain separate map gates.
