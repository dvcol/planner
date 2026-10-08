# Offline conflicts and recovery

Decision record in progress for [Offline conflicts and recovery](https://github.com/dvcol/planner/issues/10). The human confirmed the first round on 2026-10-08, including the referenced-label confirmation requirement. The remaining policies below are still open. This record contains no application code, approved Swift interfaces or executed persistence/CloudKit tests.

## Context and starting state

The private multi-device planner must preserve usable local data offline and after relaunch. CloudKit synchronization is asynchronous. The [Apple capabilities resolution](https://github.com/dvcol/planner/issues/4#issuecomment-6038241318) establishes that automatic mirroring does not supply Planner's uniqueness, ordering, conflict or recovery semantics. It does not prove a particular merge winner, bulk transaction or account-change outcome.

The [Planner vocabulary](planner-vocabulary.md) establishes stable shared identities and live references. [Completion scopes](completion-scopes.md) settles the completion model. Q8 governs every recovery scenario: List/Itinerary completion actions affect only their contextual children, and native global controls belong in the Item view. Global Done OR local Done determines effective completion. Global Reopen retains local values; new local states start Todo; itineraries do not inherit a source list's local completion; progress counts unique reachable items. Archive remains separate.

Container-only Archive/Delete, recoverable Trash, ordinary re-addition with local Todo, a full JSON backup, add-missing/keep-current default import, locally atomic bulk completion and confirmed referenced-label deletion are now accepted. Trash visibility/retention, permanent-delete reference handling, conflicting-write outcomes, detailed JSON validation and account-switch behavior remain open. The source tree contains planning documents rather than an app or store.

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

- X is titled Nezu Museum and globally Todo + Active. List A contains X/Y; List B contains X. List A's local X is Done, and List B's local X is Todo.
- Y is globally Todo + Archived and locally Todo in List A. Archived Y still contributes to progress.
- Itinerary A references List A and X directly. Its local X/Y are Todo. X's two appearances share one contextual state; itinerary progress is 0 of 2.
- S1 directly schedules X. S2 schedules Itinerary A. No recovery action silently alters schedule dates or supplies a missing end.
- X and Itinerary A reference the same Category C and Tag T. Their current metadata is shared.

Each scenario resets to its stated fixture. Completion changes do not alter archive state, source content or schedule identity unless another explicitly accepted operation requests that change.

## Accepted first-round choices

These choices establish operation scope, recoverability and portability. They do not choose the remaining trash visibility/retention, permanent-delete, convergence, account-change or invalid-import policies.

| Decision | Before and action | Accepted outcome |
| --- | --- | --- |
| R1: Container Archive/Delete scope | X is shared by List A, List B, Itinerary A and S1. Archive or Delete List A; separately consider Itinerary A. | Affect only the selected container. Referenced Items and Lists retain their source/global states, content and identities; X remains available through List B and S1. Container-reference visibility/restoration follows the later chosen deletion policy. Completion bulk actions still obey Q8. |
| R2: Recoverable deletion | Delete Item X, List A or Itinerary A in separate runs. | Move the selected entity to recoverable Trash first. Restore keeps its identity, content, saved ordering, reference associations and contextual completion. Permanent deletion is a separate explicit Trash action and remains unavailable in default MCP sessions. Exact reference visibility while trashed remains open. |
| R3: Remove and re-add context | Remove locally Done X from List A, then ordinarily add it again. Separately remove every path to locally Done X in an itinerary, then ordinarily reintroduce it. | A genuinely reintroduced context starts Todo. Removing one path while another still reaches X retains that itinerary's current state. Undo or restoration of the original association restores its prior local state. Global completion and other contexts do not change. |
| R4: Complete JSON backup | Export the shared fixture, including different global/local states, Trash and retained schedules. | Export a versioned full backup of user-owned content, stable IDs, labels, links/location, estimates, global/local states, archive/Trash states, memberships, saved order, itineraries and schedules. Exclude credentials and transient provider caches. Exact version/validation and restore behavior remain open. |
| R5: Default JSON import | A valid supported backup contains matching X with a different title and missing item Z. Import it into a nonempty planner, then import it again. | Preview, add missing IDs and retain current records for matching IDs. Report differing existing records rather than silently overwrite them. X keeps its current title; Z keeps its backup identity; repeating the same file creates no duplicates. Restore into an empty dataset faithfully recreates backed-up state. |
| R6: Local bulk completion failure | List A reaches X/Y, but current filters show only X. Confirm Mark all Done/Undone; separately inject a local validation/save failure or change the target set before saving. | Confirm the unique current-context target set including Y, then save the local bulk action together. Failure leaves that local action unapplied and visibly reports failure. If the target set changes before saving, refresh confirmation. Cancellation changes nothing. Cross-device delivery remains asynchronous; this does not promise atomic CloudKit changes. |
| R7: Delete a referenced label | X and Itinerary A both reference Tag T or Category C. Remove that shared label. | Require confirmation when at least one Item uses the label. After confirmation, remove its associations from every owner without deleting, completing or archiving owners or changing their other labels/references. Cancellation changes nothing. Exact Trash/undo and concurrent rename/delete behavior remain open. |

## Exact first-round observations for later /tdd

- Archive List A: only its container archive state changes. X remains globally Todo + Active, Y Todo + Archived, List B's local X Todo, and Itinerary A's local X/Y Todo. Memberships, source identities and S1/S2 dates remain. List A retains its local Done/Todo values and 1-of-2 progress; Itinerary A retains 0 of 2. Archiving Itinerary A similarly changes only that itinerary's archive state.
- Trash and restore List A without intervening edits: restore the same List identity, X/Y memberships and original saved order, local Done/Todo values and prior archive state. Do not create new Items, change List B's local X or alter S1/S2. Visibility and counts while trashed need the next decision.
- Ordinary remove/re-add X to List A: after re-add, its local state is Todo. Global X and other contexts are unchanged. Undo of the original removal instead restores local Done. Explicitly supply the requested placement so this fixture does not choose the native insertion default.
- Override the fixture with Itinerary A's local X Done. Remove its direct X entry while List A still reaches X: every remaining X appearance stays Done, progress 1 of 2. Remove the List entry too: the itinerary becomes empty, No items and not completed. Ordinary addition of direct X then starts local Todo, progress 0 of 1. Undo/restore of an original association restores its prior local state.
- Valid import: the nonempty store has sources X/Y. The backup contains X titled Nezu Museum lunch and new Z titled Travel Adapter, with all required references valid. Preview/merge preserves current X titled Nezu Museum, adds Z with its supplied ID, and reports the X difference. Source count becomes three. Repeating the file adds zero sources and keeps the same three IDs.
- Bulk Done from List A's local X Done/Y Todo: target both unique Items even when filters hide archived Y. Success yields 2 of 2; Y remains Archived. Bulk Undone yields 0 of 2. Injected local failure or cancellation retains the pre-action 1 of 2 and original states/identities. Globals, List B and Itinerary A never change from this action.
- Delete Tag T used by X and Itinerary A: confirmation precedes the write. Cancel retains T and both associations. Confirm removes both T associations while Category C, X/Y identities and states, context values, memberships and S1/S2 remain. Deleting C similarly retains T and all unrelated data. The navigation prototype must demonstrate the minimum one-Item confirmation threshold and settle presentation for itinerary-only label uses.

## Verified Apple facts and remaining runtime evidence

Checked against Apple primary sources on 2026-10-08. These facts constrain the choices; they are not accepted conflict or account-recovery policy.

| Area | Primary evidence | Consequence for this map |
| --- | --- | --- |
| One local save | The [WWDC26 SwiftData Group Lab, chapter 41:09](https://developer.apple.com/videos/play/wwdc2026/8017/?time=2469) explains that a ModelContext saves its accumulated changes together in one transaction. [transaction(block:)](https://developer.apple.com/documentation/swiftdata/modelcontext/transaction(block:)) runs the block and persists pending changes. | Local all-or-nothing bulk behavior is a valid implementation target. The transaction wrapper does not document automatic restoration after every thrown block/save. Real-store failure and reopen checks remain required. |
| Rollback scope and autosave | [rollback()](https://developer.apple.com/documentation/swiftdata/modelcontext/rollback()) restores committed model state and discards pending work. [autosaveEnabled](https://developer.apple.com/documentation/swiftdata/modelcontext/autosaveenabled) defaults false for manually created contexts and is enabled on mainContext. | Architecture must keep unrelated pending edits and autosaves outside the failed bulk action's rollback scope. This requirement does not select a context/actor design or approve Swift interfaces. |
| Cross-device delivery | The [SwiftData synchronization guide](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices) uses NSPersistentCloudKitContainer and says relationship changes lack atomic server processing. [TN3164](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer) assigns timing to the system. | A single local save does not imply all children arrive together remotely or that the app can force synchronization. Optional relationships, temporary states and convergence need explicit policy and device evidence. |
| Conflict resolution | [Using Core Data with CloudKit](https://developer.apple.com/videos/play/wwdc2019/202/?time=1281) describes automatic last-writer-wins resolution and a competing-content example retaining one value. | This does not specify an application-edit timestamp winner or prove preservation of independent fields on one record. Delete/edit races, context-state reconciliation and duplicate memberships need chosen outcomes and physical-device checks. |
| Account transitions | In an [Apple Frameworks Engineer reply from December 2025](https://developer.apple.com/forums/thread/811294?answerId=870541022#870541022), disabling per-app iCloud is treated as sign-out, including the reported clearing of saved but unuploaded local changes. In a [SwiftData-specific DTS reply from January 2026](https://developer.apple.com/forums/thread/813340?answerId=873267022#873267022), account switching may erase existing local data. | The automatic mirrored store alone cannot justify unconditional preservation across sign-out or account switches. This is device-local clearing, not proof that private-cloud records are deleted. Ordinary offline/throttling failures are a separate condition. The human must choose an account-recovery requirement, architecture must support it, and the prototype must verify it using disposable data. |

No Planner OS 27 store, account transition, injected failure, remote merge or device run has been executed. Engineer guidance and documented APIs are evidence for test design rather than runtime completion.

## Second decision round, still pending

The first-round answers and Apple evidence make the following questions concrete. These recommendations remain pending until the human answers; they are not part of the accepted state model yet.

| Question | Before and action | Recommended outcome to confirm |
| --- | --- | --- |
| R8: Trash references and counts | Trash X, List A or Itinerary A in separate runs while their references and schedules exist. | Keep recoverable reference data and show In Trash placeholders where needed. Exclude trashed sources and paths through trashed containers from ordinary search, parent progress, local bulk completion and effective scheduled filters. Restore reactivates retained associations without resetting locals. Retained schedule records can expose recovery placeholders. |
| R9: Trash retention | A trashed entity remains unrecovered while another device is offline. | Retain it until explicit permanent deletion or Empty Trash. No automatic expiry. |
| R10: Permanent deletion of a referenced entity | X is in Trash and referenced by both Lists, Itinerary A and S1; separately purge a trashed List/Itinerary. | Preview reference impact and confirm. Purging X removes its associations/contextual states, itinerary references and direct schedules, retaining other sources/containers. Purging a container removes that container and its references without purging source Items/Lists. Cancel changes nothing. Default MCP sessions cannot purge. Exact remote deletion races remain a later question. |
| R11: Competing field edits | Two disconnected devices rename X to Cafe A and Cafe B; separately one changes its title while the other changes notes. | Accept the native same-field winner without a conflict dialog: both devices converge on one of Cafe A/Cafe B with one X identity. Require both independent-field edits to survive; prove this on devices rather than assuming the framework does it. Do not choose a winner from device clocks. |
| R12: Invalid or failed import | A file is malformed, unsupported, internally repeats IDs, has unresolvable references, or fails while saving. | Reject the whole invalid import before changes, or leave a failed local import unapplied, with an actionable error. Repeating a valid file remains supported and creates no duplicates. Exact version/schema rules remain architecture/contracts work. |
| R13: Account transitions | A locally saved edit has not uploaded when per-app iCloud is disabled, the user signs out or the account changes. | Require an independent recoverable local copy of saved data, without automatically uploading the old account's data to a different account. Architecture and disposable physical-device tests must prove the chosen design. Accepting mirrored-store reset with only a prior manual export is the alternative. |

## Remaining policy owners and later cases

- Given adopted Trash, finish source/container visibility, progress/scheduled filters, retention/purge and exact restored state. Decide deleted-label/schedule recoverability and itinerary-only label-confirmation presentation with their native interaction owners.
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
