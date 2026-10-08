# Completion scopes

Decision record for [Completion scopes and derived progress](https://github.com/dvcol/planner/issues/22), amended by accepted [Scheduling Q12](itineraries-and-scheduling.md#accepted-repeated-references-scheduling-q12). Q8 still governs action scope and global precedence. Q12 replaces the earlier shared local state across all appearances in one itinerary with independent local completion per appearance. Accepted Scheduling Q14 replaces the earlier unique-item counting choice with completed item appearances out of all item appearances. This also retains the revision of global-only completion and explicit itinerary-status assumptions in [Planner vocabulary](planner-vocabulary.md). Production interfaces and executable tests remain future work.

## Current behavior and the revision

Content, identities, list membership and itinerary sources remain live references. Completion has a global source meaning and local planning-context meaning; contextual completion does not create another item or copy its content.

The human clarified these behaviors:

- Completing an item in a list or itinerary affects only that context. Editing its content still updates every use.
- Within one itinerary, each item appearance has independent local completion, including direct repeats and appearances reached through different or repeated list entries. All of them reference the same source content.
- Global Done makes the item appear Done everywhere. Global Reopen reveals the retained contextual states rather than rewriting them. Effective completion is global Done OR contextual Done. Storage representation remains an architecture choice.
- List and itinerary completion derives from their contextual child items. Mark Done/Undone is a bulk child operation, not an independent parent completion override.
- Archived child items still count and are included by bulk completion. UI filters do not reduce bulk targets; completion does not unarchive anything.
- An empty list or itinerary shows No items, has no completion percentage and is not completed.
- List/itinerary actions affect only their contextual children. They do not offer global completion actions; native global actions belong in the item view. Clearing local completion can leave an item effectively Done while its global source is Done, without any automatic global reopen.
- A new contextual state starts Todo. Its effective display inherits global Done without copying global completion into the local state. A later Global Reopen makes it effectively Todo unless it has since been completed locally.
- A source list's local completion does not contribute to an itinerary's completion. Each itinerary uses its own contextual item states plus the items' global states. A list shown inside an itinerary derives its displayed completion from those itinerary-context items.
- Progress counts every item appearance separately, including repeats and live List expansion; the List container contributes no extra count. A nonempty container completes only when every child appearance is effectively Done. This supersedes the earlier unique-item progress example under accepted Scheduling Q14.

The earlier proposals for global operations to overwrite local states, a manually completed itinerary independent of its children, and one local state per Item within an itinerary are superseded. The original issue resolution remains historical; the Scheduling Q12 amendment records the new scope explicitly. Q8's OR precedence and Item-view-only global actions are unchanged.

## Effective item completion

For an existing contextual reference, the clarified override/restore behavior has this table:

| Global source | Retained contextual state | Effective state |
| --- | --- | --- |
| Todo | Todo | Todo |
| Todo | Done | Done |
| Done | Todo | Done |
| Done | Done | Done |

This table describes behavior, not a Swift signature, storage schema or write fan-out strategy. A local Todo state cannot make an item effectively Todo while its global source is Done. Local Undone does not change the global source or offer a global action in a list/itinerary view.

## Concrete existing-reference examples

Use two existing items X and Y, each globally Todo + Active. List A contains X/Y; List B contains X. Itineraries A and B each directly reference X. All supplied contextual states initially are Todo, consistent with the accepted initialization rule. Each row resets to its stated fixture unless it explicitly follows the preceding row.

| Action | Before | Required current observation |
| --- | --- | --- |
| Complete X in List A | All global/contextual states are Todo. | Only List A's local X becomes Done. Global X, List B's X and both itinerary contexts remain Todo. List A remains unfinished because Y is Todo. Source count remains two. |
| Complete X in Itinerary A | All global/contextual states are Todo. | Only Itinerary A's local X becomes Done; that nonempty itinerary is complete. Global X, both list contexts and Itinerary B remain Todo. |
| Complete X globally | List A's X is locally Done; every other X context is locally Todo. | Global X becomes Done. Every effective X appearance becomes Done. Retained contextual values stay as before. List A still has unfinished Y; List B and both one-item itineraries are complete. |
| Reopen X globally | Continue from the preceding row. | Global X becomes Todo. List A's X remains effectively Done; List B's X and both itinerary X contexts return to Todo. Retained contextual states are unchanged. |
| Mark List A Done | Reset global X/Y and all local states to Todo. | Bulk-complete X/Y in List A's context. List A becomes complete; global X/Y and other contexts remain Todo. Archive states and source count are unchanged. |
| Mark List A Undone | Global X/Y are Todo; List A's X/Y are locally Done. | Clear List A's local child completion. List A is unfinished; no global, other-context or archive state changes. |
| Mark Undone with a global override | Global X is Done and Y is Todo; List A's X/Y are locally Done. | Clear both local states to Todo. X remains effectively Done; Y becomes effectively Todo. List A shows 1 of 2 and is unfinished. Global states stay unchanged. The list offers no global-action option. |
| Mark Undone while every source is globally Done | Global X/Y and List A's local X/Y are Done. | Clear both local states to Todo. Both effective states remain Done and List A remains complete at 2 of 2. Global states stay unchanged; no automatic reopen or global-action option appears. |
| Finish the last contextual child | A nonempty list/itinerary has only one effectively unfinished child. | Complete that child in this context or globally. The container derives completion from its children. It has no separate completion override to toggle. |
| Edit X's title | X has different local completion values in the existing contexts. | Every reference reads X's current title. Global, local and effective completion retain their values. There is still one source X. |

For a scheduled item, source/reference identity remains stable through these operations. Scheduling and archive state are separate decisions; local completion does not create visit history or another schedule occurrence.

## Initialization, list references and progress examples

Each row supplies its own fixture. Local state is separate from shared item content; there is still only one source per item identity.

| Action | Before | Required observation |
| --- | --- | --- |
| Add a globally Done item to a new context | X is globally Done. It has no association with the target List or Itinerary. | The new local state is Todo and its effective state is Done. Global Reopen then shows Todo in that new context. A local Complete before Global Reopen instead preserves effective Done. |
| Reference a completed source list | X/Y are globally Todo. List A's local X/Y are Done, so List A is complete. Itineraries A/B newly reference List A. | Both itineraries' X/Y local states start Todo. Each itinerary is unfinished at 0 of 2, including its displayed List A entry. Source List A remains complete at 2 of 2. |
| Complete an overlapping item in one itinerary | X/Y are globally Todo. Itinerary A references X directly, List A containing X/Y, and List B containing X. Its four item appearances are locally Todo. Itinerary B references List A. | Complete only the direct X appearance in A. That appearance becomes Done; A's other two X appearances and Y stay Todo. A shows 1 of 4 and is unfinished. Source lists and global states remain Todo; Itinerary B shows 0 of 2. |
| Bulk-complete that itinerary | Continue from the overlapping-item row. | Set all four child appearance states in A to Done. A shows 4 of 4 and is complete. Itinerary B remains 0 of 2; both source-list contexts and globals remain Todo. The bulk target is four distinct local contexts, not two source identities. |
| Add a new live list member | List A contains only globally Todo X, locally Done. An itinerary references List A and also has X locally Done. Y is globally Todo and has no existing context in either container. | Add Y to List A. Both containers include Y with new local Todo state; each now shows 1 of 2 and is unfinished. There are still only sources X/Y. |
| Remove a child from the reachable set | List A contains globally Todo X/Y, locally Done/Todo. An itinerary reaches them only through List A, with X locally Done and Y locally Todo. | Remove Y from List A. Each container now reaches only X and shows 1 of 1, complete. Source Y remains. Retention of Y's removed local associations is owned by recovery. |
| Reorder references | An itinerary reaches X/Y with X effectively Done and Y Todo. | Reorder itinerary entries or source-list Manual order. Progress remains 1 of 2; identities and completion states do not change. |
| Complete archived and hidden children | List A reaches globally Todo X/Y; Y is Archived. Both local states are Todo, and filters display only X. | Mark all Done sets both local states Done. Progress is 2 of 2, complete. Y remains Archived. Mark all Undone clears both local states and progress returns to 0 of 2. |
| Query local completion | X/Y are globally Todo + Active. List A's local X/Y are Done/Todo. List B and Itineraries A/B contain only X with local Todo. | Global Todo returns X/Y; global Done excludes both. List A Todo returns Y and List A Done returns X. List B and Itineraries A/B Todo each return X. Queries change no states or references. |
| Inspect an empty container | No item is reachable from the List or Itinerary, including an itinerary whose referenced lists are empty. | Show No items, no completion percentage and not completed. Bulk completion has no child state to change and cannot create a parent override. |

## Downstream decisions

The [Navigation prototype](https://github.com/dvcol/planner/issues/14) owns simple native labels and confirmation/cancellation presentation. Its completion prompt stays within local bulk scope, exposes all targeted children including hidden/archived ones, and proposes no global actions. Global completion controls belong only in the Item view. Canceling the prompt changes no state.

The later [Offline conflicts and recovery](offline-conflicts-and-recovery.md) answers confirm that ordinary re-addition starts a new local Todo state; Undo or restoration of an original association preserves its prior state. Scheduling Q12 makes that lifetime appearance-specific: removing one appearance does not transfer its completion to another appearance of the same Item. Surviving appearances retain their own states. Local bulk completion is all-or-nothing, with cancellation/failure leaving the action unapplied. R14 establishes Archive plus confirmed Delete, with no Trash. Delete removes the selected source and its references; containers never delete their source children. R15-R17 retain deletion precedence, one membership/local context per standalone Item/List pair and converged order retaining independent additions. Architecture/prototypes own reconciliation and runtime proof. R11 accepts a native same-field winner while requiring independent edits to survive; no atomic cross-device bulk transaction is assumed.

## Future test and interface obligations

Before /tdd code, [Core architecture](https://github.com/dvcol/planner/issues/12) and [Shared command contracts](https://github.com/dvcol/planner/issues/13) must propose and confirm public global/contextual completion, effective queries and bulk commands. One failing behavior and minimum passing implementation follow each approved fixture.

- Unit/query tests exercise all four effective-state rows and the exact existing-reference examples. Global queries and contextual queries must not conflate their completion meaning.
- New-reference, repeated-entry, list-in-itinerary, overlap, live membership and Global-Done bulk Undone tests use the exact observations above and Scheduling Q12. No appearance inherits a source list's local completion. Accepted Q14 supplies exact repeated-item counts; each independently completed appearance contributes once.
- Parent progress tests include partial/all completion, archived/hidden children and an empty container. Empty is not completed and has no percentage.
- Integration tests use a real temporary store to save/reopen source identities and retained contextual states, including Global Done followed by Global Reopen. The sync prototype verifies the approved remote-update outcomes.
- UI tests demonstrate contextual completion, Item-view global completion, override/restore display and local bulk completion on native iPhone/iPad/Mac layouts. Confirmations expose their scope and counts; cancellation changes nothing. Lists/itineraries must not offer global completion actions. Shared source content remains live.
- Recovery fixtures cover a shared item, independent overlapping/repeated itinerary appearances and membership changes during a bulk action. Bulk targets every local child appearance once, including hidden/archived ones. The recovery resolution and Q12 amendment supply exact targets, failure outcomes and converged states before tests.

The record has no runtime evidence. Markdown lint, local links and whitespace checks validate documentation only.
