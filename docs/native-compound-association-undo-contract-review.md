# Compound association Undo contract

Status: Q111 A approved by the human on 19 October 2026. Q109 A and Q110 A settle atomic Move reversal and one removal group per Save. This document makes issuance, validation, link placement and literal expected outcomes concrete before implementation. Approval alone establishes no implementation or runtime result.

## Context, goal and starting state

Core currently issues one native-only `PlannerAssociationUndoSnapshot` for explicit membership or Itinerary-entry removal. `restoreAssociation` preserves original public identities under fresh lifetimes and validates current-run issuance. Native history deduplicates by the closing operation identity. Move and Item/Itinerary editor removals do not issue this companion yet.

Extend that same interface to restore a whole Move or the associations removed by one Save. Preserve unrelated source edits and newer work. Keep all-or-nothing local persistence, truthful applied/recovery outcomes and original-association lineage.

## Core interface and issuance

Keep `PlannerOperationResult.associationUndoSnapshot` and `PlannerCommand.restoreAssociation(snapshot:)`. Extend the snapshot's `OriginalRecord` enum with two cases whose read-only record values are constructed only by Core:

- `membershipMove(PlannerMembershipMoveUndoRecord)` contains the original membership, any destination membership created by this Move, and its post-Move contextual bindings/state. The snapshot's existing `identity` and `originalExpandedStates` describe the removed origin.
- `ownedAssociationGroup(PlannerOwnedAssociationUndoGroup)` contains the bound Item/Itinerary owner, every removed portable bookmark and label association, and the original ordered bookmark identities needed for placement. Its snapshot `identity` is the first removed bound identity in stable kind/UUID order. Each member retains its own predecessor identity; the first identity does not represent the whole group's lineage.

An applied Move issues one companion. An applied Item/Itinerary Save issues one companion only when at least one bookmark or label association was removed. Edited surviving bookmarks, added associations and changed notes are not removals. A mixed Save can change them without making them part of the inverse.

Capture the actual removed records inside the coordinated writer and issue only after successful local commit. An applied operation with incomplete recovery retains its companion, but Undo waits for ordinary recovery repair. Exact operation replay returns the same current-run companion. Rejected/unverified actions issue none. A failed restoration never consumes its issued capability.

Keep companions outside portable backups, applied-result/receipt encodings and agent interfaces. Preserve existing operation digests for unchanged commands. A compound restoration digest binds its complete inverse, owner/source lifetimes, removed predecessors and Move destination guards. No schema, backup/receipt format, package or target change is proposed.

## Atomic Move reversal

Restore the origin's original public membership identity, saved rank, local completion and captured expanded contexts under fresh authorized lifetimes. Existing Q106 guards still require the original Item/List and captured Itinerary entries to survive under their bound lifetimes, with no newer replacement origin membership or superseded history.

If this Move created the destination membership, remove exactly that membership and its contextual states in the same local transaction. Require its identity/lifetime, Item/List bindings, rank and local state to match the post-Move record. Require the set of Itinerary entry identities/lifetimes referencing that destination List and the membership's explicit expanded completion states to match the captured post-Move state. A later contextual edit, reorder, remove/re-add or changed referencing branch rejects the whole inverse. A global Item completion or notes edit does not alter those local guards.

If the destination membership predated the Move, do not remove, restore or overwrite it. Its subsequent independent changes remain intact. Undo restores only the origin in this case, which reverses the Move's actual association changes.

A new destination closure gets the normal deletion marker. Restored origin predecessors get fresh restoration-family candidates; never reopen an old lifetime. Preserve unrelated memberships, source content and ordering. Rank rebalancing that left other destination members in the same logical order need not be reversed numerically.

## Atomic owned-association restoration

Validate the entire group before writing. The owner and every target label must retain their bound lifetimes. Each removed predecessor must still be closed by this Save and have no newer restoration family. Reject a currently occupied public identity or a recreated owner/label pair. A shared label rename with the same identity/lifetime remains valid and displays its current name. Label deletion or deletion/restoration into another lifetime rejects the whole group.

Restore every removed bookmark's original public identity, original URL, label, kind and provider reference under a fresh lifetime. Restore label association identities and bindings similarly. Identical bookmark URLs are allowed and remain separate identities. Do not merge by URL or label name.

Preserve current source fields, surviving bookmark fields and independent additions. Restoring label associations and bookmarks updates the owner's own Last updated timestamp through the usual content rule. It never restores old notes or changes global/local completion, archive state or bookings.

### Bookmark placement

Reinsert removed runs in their original relative order using surviving original bookmark identities as anchors. Preserve the current relative order of every existing bookmark, including new additions.

1. Insert a removed run immediately before its nearest surviving original successor.
2. If there is no such successor, insert immediately after its nearest surviving original predecessor.
3. If no original anchor survives, append the removed run after current bookmarks.

If the surviving original anchors have changed relative order so the removed bookmarks cannot retain their original relative order without reordering existing bookmarks, reject the whole group. Missing anchors alone do not reject. Resolve ranks with the existing checked gapped-rank/tie rules, rebalancing when necessary. No retained bookmark fields or current relative order are overwritten.

## Literal fixtures

Fixture names below stand for distinct fixed UUIDs in executable tests. Each original public identity is restored with a fresh lifetime and a restoration-family link to its closed predecessor.

| Before / intervening change | Required result |
| --- | --- |
| A has Museum `mA`, rank 1024, local Done; B has none. Move creates `mB`, local Todo. | Undo restores `mA` at rank 1024/local Done, removes `mB`, and preserves Museum's current notes/global state. |
| B already has `mB`, local Done. Move removes `mA`. B is later locally reopened. | Undo restores `mA`; the same existing `mB` remains locally Todo. |
| Move created `mB`; B later completes or reorders `mB`. | Reject all. A remains without `mA`; current `mB` and its state/order survive. |
| Move created `mB`; another Itinerary later references B. | Reject all, preserving that newer branch and `mB`. |
| Original A branch had local Done; another repeated branch had Todo. | Restore captured origin contexts independently; preserve the other branch and global Item state. |
| Links `[a, b, c, d]`; Save removes `a,c` and a Tag association, changes notes. Later links are `[x,b,d]`. | Undo gives `[x,a,b,c,d]`, restores the Tag association, and keeps the new notes and all current bookmark fields. |
| Links `[a,b,c]`; Save removes `c`; later links `[a,b,x]`. | Undo gives `[a,b,c,x]`. |
| Save removes `[a,b]`; no original bookmark survives; current links `[x,y]`. | Undo gives `[x,y,a,b]`. |
| Links `[a,b,c,d]`; remove `a,c`; later retained original anchors reorder to `[d,b]`. | Reject the whole removal group, including its label associations. Preserve `[d,b]` and current notes. |
| Removed bookmarks `a,b` have the same URL. | Restore both original identities and their order. |
| One of two removed label associations was ordinarily recreated under a new identity. | Reject all; retain the newer pair, current links and notes. |
| One removed label is renamed, retaining lifetime. | Restore its association; show the current shared name. |
| One removed label is deleted or restored under a new lifetime. | Reject all; do not restore any other member of that group. |

## Native callers and failure behavior

Move and Item/Itinerary Save return the truthful operation response to their existing native caller, so it can register the issued companion after an applied result. Keep callers' current success/validation/recovery handling. Use one history action named Move Item or Remove Links and Labels, with a more specific Links/Labels name when only one kind was removed. Content edits stay outside these removal actions.

Use the existing per-window native UndoManager/history and explicit mobile Undo. One closing operation registers once, even if replayed. Existing Q108 controller qualification applies to the extended history without adding another test seam. Retain valid selection and current filters. No association Redo, persistent history, source-Delete recovery or agent restore command is added.

Validate before mutation. Rejected stale/cross-dataset/wrong-lifetime actions return `associationUndoUnavailable` and change nothing. Genuine local save failure rolls back every part and retains Retry Undo. Applied/incomplete recovery stays applied, blocks further mutations and repairs only its checkpoint. Exact restoration replay resolves the same receipt without duplicating associations or repeating destination removal. Mismatched operation payloads reject normally.

## Definition of ready

- Q109 A and Q110 A are accepted. Q111 approves this concrete interface, Move guards, bookmark placement and literal outcomes.
- Test through existing real-store operations/reads/exports, actual MCP admission, native UI, and the separately approved Q108 controller interface.
- No fabricated snapshot, test-only production parameter, private database assertion, new target or unchecked signed-device claim is needed.

## Required tests and definition of done

Work one behavior at a time. First obtain a failing public operation test for absent issuance/restoration, then implement the minimum corresponding behavior. Cover each literal fixture, fresh lineage, current-run issuance, exact replay, superseded history, wrong dataset/lifetimes, genuine save failure, and applied/incomplete recovery with checkpoint-only retry. Compare public exports to prove whole-action rejection and preserved unrelated data.

Verify agent admission remains forbidden and backup/receipt formats remain unchanged. Qualify native grouped naming, real editing Save/Move results, ordinary text Undo, selection/filters and relaunch expiry on applicable local destinations. Run affected lint/compiler tests and retain exact source/results. Mac UI startup, signed storage, physical CloudKit/account/Share scenarios, scale and final whole-app polish remain their separate gates.
