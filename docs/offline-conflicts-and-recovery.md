# Offline conflicts and recovery

Decision record in progress for [Offline conflicts and recovery](https://github.com/dvcol/planner/issues/10). The proposed outcomes below are questions for the human, not accepted policy. This record contains no application code, approved Swift interfaces or executed persistence/CloudKit tests.

## Context and starting state

The private multi-device planner must preserve usable local data offline and after relaunch. CloudKit synchronization is asynchronous. The [Apple capabilities resolution](https://github.com/dvcol/planner/issues/4#issuecomment-6038241318) establishes that automatic mirroring does not supply Planner's uniqueness, ordering, conflict or recovery semantics. It does not prove a particular merge winner, bulk transaction or account-change outcome.

The [Planner vocabulary](planner-vocabulary.md) establishes stable shared identities and live references. [Completion scopes](completion-scopes.md) settles the completion model. Q8 governs every recovery scenario: List/Itinerary completion actions affect only their contextual children, and native global controls belong in the Item view. Global Done OR local Done determines effective completion. Global Reopen retains local values; new local states start Todo; itineraries do not inherit a source list's local completion; progress counts unique reachable items. Archive remains separate.

No deletion/trash lifetime, removed-context retention, import merge rule, conflicting-write winner or account-switch behavior has been accepted. Those are this ticket's remaining decisions. The source tree currently contains planning documents rather than an app or store.

## Goal and expected end state

Produce human-confirmed before/action/after recovery and convergence tables, plus a JSON portability contract. Each outcome must identify retained identities/content, references, global/local completion, archive state, visibility, progress and a user remedy where needed. Describe permitted temporary sync states separately from the eventual required state.

Assign exact future /tdd fixtures to [Core architecture](https://github.com/dvcol/planner/issues/12), [Shared command contracts](https://github.com/dvcol/planner/issues/13), [Navigation prototype](https://github.com/dvcol/planner/issues/14) and [Sync and share prototype](https://github.com/dvcol/planner/issues/15). Framework behavior remains a prototype gate until observed. A planning decision cannot establish cross-device atomicity or turn a sync-status guess into a guarantee.

## Definition of ready

- [x] Planner vocabulary, Apple capabilities and Completion scopes and derived progress have accepted resolutions.
- [x] The ticket is claimed by dvcolomban before work.
- [x] Existing source content and identities stay shared rather than becoming copies.
- [x] Concrete shared-item fixtures distinguish container, membership, source and contextual operations.
- [x] Proposals are explicitly pending; the human chooses consequential recovery rules.

Public command/query, persistence and import/export interfaces require human confirmation in the architecture/contracts work before executable /tdd tests. They are future implementation gates, not prerequisites for discussing this document.

## Shared fixture

Use stable identities X and Y for two items, List A and List B for two lists, Itinerary A for a plan, and S1/S2 for schedules. The runnable fixtures must assign distinct persistent UUIDs; these names are readable aliases rather than proposed Swift interfaces.

- X is globally Todo + Active. List A contains X/Y; List B contains X. List A's local X is Done, and List B's local X is Todo.
- Y is globally Todo + Archived and locally Todo in List A. Archived Y still contributes to progress.
- Itinerary A references List A and X directly. Its local X/Y are Todo. X's two appearances share one contextual state; itinerary progress is 0 of 2.
- S1 directly schedules X. S2 schedules Itinerary A. No recovery action silently alters schedule dates or supplies a missing end.
- X and Itinerary A reference the same Category C and Tag T. Their current metadata is shared.

Each scenario resets to its stated fixture. Completion changes do not alter archive state, source content or schedule identity unless another explicitly accepted operation requests that change.

## First decision round

These independent questions establish operation scope, recoverability and portability. Recommendations remain unaccepted until the human answers. A later round uses those answers to decide trash visibility/retention, permanent deletion, concurrent edits, ordering, account changes and invalid-import handling.

| Question | Before and action | Recommended outcome to confirm | Alternative requiring different fixtures |
| --- | --- | --- | --- |
| R1: Container Archive/Delete scope | X is shared by List A, List B, Itinerary A and S1. Archive or Delete List A; separately consider Itinerary A. | Affect only the selected container. Referenced Items and Lists retain their source/global states, content and identities; X remains available through List B and S1. Container-reference visibility/restoration follows the later chosen deletion policy. Completion bulk actions still obey Q8. | Also archive/delete referenced source items, affecting their other uses. |
| R2: Recoverable deletion | Delete Item X, List A or Itinerary A in separate runs. | Move the selected entity to recoverable Trash first. Restore keeps its identity, content, saved ordering, reference associations and contextual completion. Permanent deletion is a separate explicit Trash action and remains unavailable in default MCP sessions. Exact reference visibility while trashed is a later decision. | Delete immediately, with only short-lived undo or an external backup for recovery. |
| R3: Remove and re-add context | Remove locally Done X from List A, then ordinarily add it again. Separately remove every path to locally Done X in an itinerary, then ordinarily reintroduce it. | A genuinely reintroduced context starts Todo. Removing one path while another still reaches X retains that itinerary's current state. Undo or restoration of the original association restores its prior local state. Global completion and other contexts do not change. | Ordinary re-addition also restores old local completion after the item was no longer reachable. |
| R4: Complete JSON backup | Export the shared fixture, including different global/local states and retained schedules. | Export a versioned full backup of user-owned content, stable IDs, labels, links/location, estimates, global/local states, archive states, memberships, saved order, itineraries and schedules. Include recoverable Trash if adopted. Exclude credentials and transient provider caches. A later round defines exact version/validation and restore behavior. | Export only active source items, omitting contextual/order/recovery state. |
| R5: Default JSON import | A valid supported backup contains matching X with a different title and missing item Z. Import it into a nonempty planner, then import it again. | Preview, add missing IDs and retain current records for matching IDs. Report differing existing records rather than silently overwrite them. X keeps its current title; Z keeps its backup identity; repeating the same file creates no duplicates. Restore into an empty dataset can faithfully recreate backed-up state. | Use backup values to update matching IDs as part of the default import. |
| R6: Local bulk completion failure | List A reaches X/Y, but current filters show only X. Confirm Mark all Done/Undone; separately inject a local validation/save failure or change the target set before saving. | Confirm the unique current-context target set including Y, then save the local bulk action together. Failure leaves that local action unapplied and visibly reports failure. If the target set changes before saving, refresh confirmation. Cancellation changes nothing. Cross-device delivery remains asynchronous; this does not promise atomic CloudKit changes. | Permit partial local completion, explicitly listing successful and failed targets. |
| R7: Delete a referenced label | X and Itinerary A both reference Tag T or Category C. Remove that shared label. | Remove the label associations from every owner without deleting, completing or archiving the owners or changing their other labels/references. Recoverability and concurrent rename/delete outcomes follow the later deletion/conflict decisions. | Prevent deletion while the label is referenced and require manual detachment first. |

## Dependent questions after that round

- If Trash is adopted, define whether trashed sources/containers remain visible as placeholders in retained references, whether they count toward progress/scheduled filters, retention and purge behavior, and exact restored state. Apply the same identity rules to deleted labels and schedule entries where supported.
- Given container/source deletion scopes, decide delete versus offline edit, restore versus remote delete, permanent deletion of a shared source and treatment of dangling references. Do not guess that an offline device has seen a deletion.
- Given context-retention rules, decide same-membership duplicate creation, remove versus add/move, independent reorder and membership changes during bulk actions. Specify final identity sets/order/local states and allowed temporary observations.
- Decide same-field versus independent-field edits, global/contextual completion conflicts, archive conflicts and shared-label rename/duplicate creation. Distinct operations must not silently change unrelated state. Determine which results automatic mirroring actually demonstrates and which need additional design.
- Given the JSON backup/import choice, define schema version validation, duplicate/type-conflicting IDs, missing references, preflight/partial failure, archived/trash restoration, migration and fresh-device recovery. Restoring retained context records is distinct from manually creating a new planning association with local Todo.
- Define truthful locally saved/pending/failure presentation, retry, iCloud unavailability and account switches. Local data must not disappear because a sync attempt fails. No sync latency or upload-completion claim is assumed.

## Required later tests and validation

The final resolution must replace proposed outcomes with accepted exact observations before tests. No fixture title alone satisfies this requirement.

| Level and public boundary | Input/action | Evidence required by resolution or implementation |
| --- | --- | --- |
| Domain unit/query | Container Archive/Delete and source Delete using X shared across List A/B, Itinerary A and S1/S2. | Exact retained entity IDs, memberships/entries/schedules, effective states, visibility/progress and restore result. No implicit global completion in container flows. |
| Domain unit/query | Ordinary remove/re-add, undo/restore and loss of only one versus every itinerary path to X. | Exact local/global states and unique-item progress, preserving states where the item remains reachable. |
| Real-store integration | Save offline edits and local bulk completion; inject a genuine persistence-boundary failure; reopen the store. | Successful local data survives relaunch. Accepted all-or-partial failure state is verified through queries, without test-only production seams. No failed save is reported as success. |
| JSON public import/export | Export/reopen/restore X/Y, C/T, A/B, contexts, order and S1/S2; import conflicting X and new Z twice. | Exact accepted record values/IDs/counts, preserved associations, repeat-import outcome, scoped completion and no fabricated provider data. Invalid-file expectations are supplied after the validation decision. |
| Two physical devices | Offline independent/same-field edits, completion/archive changes, membership duplication/removal/reorder, deletion/restoration and interrupted bulk sync. | The human-approved converged states, allowed temporary states and any remedy, with recorded device/OS/container evidence. Documentary availability is insufficient. |
| Native UI and integration parity | Invoke the accepted actions on iPhone, iPad and Mac, and through allowed App Intents/MCP commands. | Scope, confirmation, cancellation, truthful failure/status presentation and global/contextual effects match the accepted tables. Global completion controls remain confined to the Item view in native container flows. |
| Documentation | Update only affected records and ticket assets. | Markdown lint, local links, final newlines and whitespace checks. These checks do not count as Swift unit, integration or runtime proof. |

Use /tdd at confirmed public interfaces, one failing behavior followed by its minimum passing implementation. Architecture/contracts own those interfaces; the sync/share prototype owns physical-device convergence evidence.

## Definition of done

- [ ] The human confirms deletion, retention, import, conflict and recovery rules with exact before/action/after outcomes.
- [ ] Every scenario above has accepted expectations or an explicit named downstream owner; no consequential policy is silently assumed.
- [ ] The JSON contract covers identifiers/references, scoped states, ordering, version validation, migration and supported restore/import modes.
- [ ] Future unit/query/store/UI/physical-device checks name their public boundary, fixtures and required observations.
- [ ] The resolution links committed source and evidence, the ticket closes only after its planning criteria pass, and the map receives its named resolution pointer.
