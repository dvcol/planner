# Native List row-window contract

Status: approved by the human as Q97 A. Implementation and qualification remain required. The navigation/appearance review requested on 18 October is the current slice.

## Context and starting state

Items and Inbox use the qualified first-slice `SavedItemWindow`. It accepts only Item source identities. A standalone List instead has one identity per membership, with its own completion and ordering. The current List workflow reads the List source and then accumulates every matching row presentation before displaying the result. Native lazy rendering does not remove that accumulation.

The complete array also drives matching counts, manual reorder anchors, first-survivor selection and the Mac membership Table. Replacing that array with the currently loaded page would lose those meanings. List source data already contains the full progress, estimates and membership references separately from row previews.

Core supplies typed source/appearance identities and generation-bound row pages. `PlannerListSourceRead` has no generation token. Core validates row history before and after hydration, including a positive-limit read of an empty result. The existing Itinerary reader uses query, header reads and a final generation-bound row read to detect intervening changes. These existing capabilities can establish a coherent List header and initial page without changing Core.

## Goal and resulting state

Show the first up-to-64 List rows without hydrating every matching Item presentation. Load visible pages and at most one neighboring page on each side. Keep complete typed membership identities and List metadata while releasing offscreen presentations. Scrolling, filters, sort, full-scope counts/progress/estimates, local completion, selection, Add/New Item, deletion and manual drag/drop retain their accepted behavior.

This proposal changes native row retention. Core still retains its complete identities and captures under Q84. List metadata and references remain retained for valid selection and ordering. Page counts alone establish neither bounded total RAM nor measured latency.

## Proposed production interface

Extend the existing app-internal `SavedItemWindow`, used by Items, Inbox and standalone List contents. Keep its real Planner/session initializer, typed `PlannerItemQuery`, lifecycle identity, `reload`, `requestRows`, `cancel`, loading/failure state and `presentation(at:)` operations. No package, target, public Core/wire change or test-only option is added.

Replace the source-only `sourceIdentifiers` output with `rowIdentities: [PlannerRowIdentity]`. It contains the complete ordered result supplied by Core. Existing catalog clients require Item source identities. List clients require Item appearances whose `listId` matches their selected List and whose `membershipId` remains their native row identity. The same Item can have different memberships in different Lists. Their identities and contextual state must remain separate when switching Lists; windowing changes no rule about adding the same Item to one List. A loaded `SavedPlannerItem` keeps the existing native convention: Item ID for a catalog row, membership ID for a List row, with the full typed identity retained in its row read.

Add a read-only `listSource: PlannerListSourceRead?`, populated for a List query. It supplies the full List header, progress, estimates and references. Items/Inbox leave it nil. Matching count remains the full filtered result count, independent of loaded or retained pages.

The complete proposed view-facing interface is therefore:

- Initialize with the real Planner and dataset session.
- Reload with the existing typed query and namespace/revision lifecycle identity.
- Request visible row indices or cancel the inactive view.
- Read `rowIdentities`, `matchingCount`, `state` and optional `listSource`.
- Read each index's loaded presentation or loading/failure placeholder through `presentation(at:)`.

This is the expanded production interface proposed for the real-Core app-hosted test seam. Cache keys, tasks, page storage and native identity projection stay implementation details. Itinerary hierarchy and both Item picker clients remain follow-up adoption work; this proposal does not classify their current eager reads as windowed.

## Coherence, retention and action rules

1. For a List, capture the typed query snapshot, read its List source, then validate the first row page against that captured generation before publishing ready content. Do this even for an empty result. A stale generation refreshes the query and header together. Do not publish a header from one history state with rows from another.
2. Validate complete count, supported identity kind, owning List, membership identity uniqueness and every page's exact ordered typed identities. Reject unexpected data with a usable failure state rather than guessing a source ID or action scope.
3. Preserve Q95's first-page, visible-plus-neighbor, duplicate-request, cancellation, supersession and stale-refresh rules. Released pages can be reread without changing their identities. Source/header metadata does not become a presentation page and is not evicted with one.
4. Use the complete ordered identities and retained source references for manual reorder anchors, beginning/end actions, drag/drop, filtered matching counts and first-visible-survivor replacement. Never interpret a loaded-page index as the complete result order. Keep all existing filtered/manual-order semantics.
5. Keep selected detail attached to its typed appearance and load it independently of its row cache. A page release or a filter hiding its row does not clear a valid detail or change completion scope. Deletion/removal keeps the established replacement/navigation rules.
6. Native placeholders are visibly loading or failed, with Retry where applicable. They must not pretend to have an Item's content/completion or expose an action with an invented identity. Preserve a surviving visible row as the scroll anchor where possible.
7. Full List progress and estimates remain based on the retained full-scope metadata; filtering and page eviction do not change their denominators. Displayed matching counts use the complete query count, including when only the first page is loaded. Archive and completion continue to obey the accepted current rules.

## Definition of ready and required TDD

Q97 A would confirm this expanded interface before its tests. Reuse the existing `PlannerMCPTests` app-hosted target with real local-only Core data, along with the existing public Core and native UI seams. No test reaches private page/task state or introduces a suspended-request mock into production.

Migrate the seven existing Item-window tests to the typed identity output, retaining their actual behaviors. Then implement one failing List behavior at a time through the production interface:

- First page, empty List and filtered empty results, complete membership identities/count, and correct full List metadata.
- Crossing/releasing/revisiting pages, then switching between two Lists sharing an Item, while their memberships retain identity, source and independent contextual state.
- Cumulative filters and ascending/descending/Manual results from Core, with full progress/estimates unchanged by the visible page or filter.
- Replacement List, dataset/revision, query and cancellation outcomes, plus stale-generation refresh after real membership/completion/order changes. Old results must not publish into a new List.
- Existing Item/Inbox behavior through the expanded loader, preserving their source identities, cancellation and query defaults.

Expected IDs, order, state and counts come from literal fixtures created through public commands/imports. Real Core cannot deterministically pause every internal await; retain that Q95 limit, review publication/coherence guards and qualify live changes at the native UI seam. Propose another controllable production seam separately if a critical uncovered race actually requires it.

## Native qualification and definition of done

Use the existing large fixture and ordinary native List/Table scrolling. Verify intermediate page boundaries, release/revisit, selected detail, complete matching/full-scope counts, local checkbox targeting, filtered/manual drag/drop anchors and first-survivor replacement. Exercise New Item creation into its original List, Add existing, archive visibility, rotation and narrow/expanded layouts. A row unavailable in the current presentation window must never redirect an action to another membership or the global Item.

Run affected strict Swift lint, mobile/Mac compiler checks and focused Item/Inbox/List regressions. Inspect original captures and review Standards/Spec separately. Mac UI runtime, physical performance, signing and final whole-app native polish retain their existing gates. A passing first List slice does not close Itinerary/picker windows or the Navigation map ticket.

## Choices for Q97

A. Extend the existing loader as proposed. One implementation handles the shared paging lifecycle, typed identities and guarded List metadata. Existing Item/Inbox callers and tests migrate to the typed output, so their regressions must be rerun.

B. Keep the Item/Inbox loader unchanged and build a dedicated List loader with the same behavior and tests. This isolates the first implementation from List changes, but leaves another native loading implementation to maintain and qualify.

C. Retain eager List reads for now. Native rendering remains lazy, but List content still waits for complete presentation hydration and retains it. The List moving-window requirement stays open on the map.

Recommendation: A. It reuses the established paging behavior while making the List's actual identities and metadata explicit. Implementation waits for the interface/test-seam choice; independent qualification can continue.
