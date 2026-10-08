# Completion scopes

Decision record in progress for [Completion scopes and derived progress](https://github.com/dvcol/planner/issues/22), following the human's 2026-10-08 clarification. This ticket revises the earlier global-only completion and explicit itinerary-status assumptions in [Planner vocabulary](planner-vocabulary.md). It remains open for the cases below; no production interfaces or tests have been approved or written.

## Current behavior and the revision

Content, identities, list membership and itinerary sources remain live references. Completion has a global source meaning and local planning-context meaning; contextual completion does not create another item or copy its content.

The human clarified these behaviors:

- Completing an item in a list or itinerary affects only that context. Editing its content still updates every use.
- Within one itinerary, all appearances of an item share its contextual completion, including appearances reached through different lists.
- Global Done makes the item appear Done everywhere. Global Reopen reveals the retained contextual states rather than rewriting them. The human proposed the effective rule global Done OR contextual Done; it matches the requested override/restore behavior. Storage representation remains an architecture choice.
- List and itinerary completion derives from their contextual child items. Mark Done/Undone is a bulk child operation, not an independent parent completion override.
- Archived child items still count and are included by bulk completion. UI filters do not reduce bulk targets; completion does not unarchive anything.
- An empty list or itinerary shows No items, has no completion percentage and is not completed.

The earlier proposal for global Complete/Reopen to overwrite all stored local states is superseded. The earlier proposal for a manually completed itinerary independent of its children is also superseded. These revisions are recorded explicitly rather than changing the old accepted resolution silently.

## Effective item completion

For an existing contextual reference, the clarified override/restore behavior has this table:

| Global source | Retained contextual state | Effective state |
| --- | --- | --- |
| Todo | Todo | Todo |
| Todo | Done | Done |
| Done | Todo | Done |
| Done | Done | Done |

This table describes behavior, not a Swift signature, storage schema or write fan-out strategy. A local Todo state cannot make an item effectively Todo while its global source is Done. The native Undone action must explain this rather than silently affecting other contexts.

## Concrete existing-reference examples

Use two existing items X and Y, each globally Todo + Active. List A contains X/Y; List B contains X. Itineraries A and B each directly reference X. All supplied contextual states initially are Todo. These are fixture inputs for existing references, not a chosen initialization rule for newly created references. Each row resets to its stated fixture unless it explicitly follows the preceding row.

| Action | Before | Required current observation |
| --- | --- | --- |
| Complete X in List A | All global/contextual states are Todo. | Only List A's local X becomes Done. Global X, List B's X and both itinerary contexts remain Todo. List A remains unfinished because Y is Todo. Source count remains two. |
| Complete X in Itinerary A | All global/contextual states are Todo. | Only Itinerary A's local X becomes Done; that nonempty itinerary is complete. Global X, both list contexts and Itinerary B remain Todo. |
| Complete X globally | List A's X is locally Done; every other X context is locally Todo. | Global X becomes Done. Every effective X appearance becomes Done. Retained contextual values stay as before. List A still has unfinished Y; List B and both one-item itineraries are complete. |
| Reopen X globally | Continue from the preceding row. | Global X becomes Todo. List A's X remains effectively Done; List B's X and both itinerary X contexts return to Todo. Retained contextual states are unchanged. |
| Mark List A Done | Reset global X/Y and all local states to Todo. | Bulk-complete X/Y in List A's context. List A becomes complete; global X/Y and other contexts remain Todo. Archive states and source count are unchanged. |
| Mark List A Undone | Global X/Y are Todo; List A's X/Y are locally Done. | Clear List A's local child completion. List A is unfinished; no other context or archive state changes. Global-Done override cases still require the chosen native action behavior. |
| Finish the last contextual child | A nonempty list/itinerary has only one effectively unfinished child. | Complete that child in this context or globally. The container derives completion from its children. It has no separate completion override to toggle. |
| Edit X's title | X has different local completion values in the existing contexts. | Every reference reads X's current title. Global, local and effective completion retain their values. There is still one source X. |

For a scheduled item, source/reference identity remains stable through these operations. Scheduling and archive state are separate decisions; local completion does not create visit history or another schedule occurrence.

## Remaining cases

- A new reference to a globally Done item must initially appear Done, as the human accepted. It is still being clarified whether its local state starts Todo and inherits that display, or copies the current source completion. The result after a later Global Reopen distinguishes them.
- A list completed in its own context is referenced by itineraries with independent local item states. Whether source-list completion contributes to those itinerary uses is still being clarified.
- One itinerary shares a contextual item state across appearances. Its progress denominator still needs a choice between unique identities and occurrences.
- A local bulk Undone operation may leave globally Done items effectively Done. Its explanation and any separate explicit Global Reopen action remain under discussion.
- Confirmation/cancellation and native labels must reflect bulk contextual completion, not the superseded independent parent-status proposal.

Removal/re-addition of contextual associations, duplicates during sync, deleted sources, bulk failures and concurrent changes belong to [Offline conflicts and recovery](https://github.com/dvcol/planner/issues/10). No retention lifetime, conflict winner or atomic cross-device bulk transaction is assumed.

## Future test and interface obligations

Before /tdd code, [Core architecture](https://github.com/dvcol/planner/issues/12) and [Shared command contracts](https://github.com/dvcol/planner/issues/13) must propose and confirm public global/contextual completion, effective queries and bulk commands. One failing behavior and minimum passing implementation follow each approved fixture.

- Unit/query tests exercise all four effective-state rows and the exact existing-reference examples. Global queries and contextual queries must not conflate their completion meaning.
- New-reference, list-in-itinerary, overlap and Global-Done bulk Undone tests receive exact observations once the remaining choices are accepted.
- Parent progress tests include partial/all completion, archived/hidden children and an empty container. Empty is not completed and has no percentage.
- Integration tests use a real temporary store to save/reopen source identities and retained contextual states, including Global Done followed by Global Reopen. The sync prototype verifies the approved remote-update outcomes.
- UI tests demonstrate contextual completion, global completion, override/restore display and bulk completion on native iPhone/iPad/Mac layouts. Confirmations expose their scope and counts; shared source content remains live.
- Recovery fixtures cover a shared item, overlapping itinerary references and membership changes during a bulk action. The recovery resolution must supply exact targets, failure outcomes and converged states before tests.

The record has no runtime evidence. Markdown lint, local links and whitespace checks validate documentation only.
