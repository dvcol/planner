# Native itinerary presentation-window contract

Status: proposed for Q98. No tests or implementation at the expanded interface are authorized by this proposal alone. Q95 and Q97 remain accepted for their existing Item, Inbox and standalone List behavior.

## Context and starting state

Standalone Lists now use `SavedItemWindow`. It retains complete typed identities and full List metadata while loading only first-page, visible and neighboring row presentations. Its native integration has qualified phone and iPad multi-page traversal and selected ordinary actions. The standalone List and itinerary Item pickers now also adopt this unchanged loader; their separate List-choice catalogs remain eager.

Itineraries still use `SavedPlannerStore.readItineraryContents`. That reader hydrates every filtered appearance to discover matching identities, then every unfiltered appearance to assemble entries. It also hydrates the matching List catalog for header matching. A nested List's children are built together inside one outer native row. Lazy outer List rendering therefore does not establish individual child-row laziness.

Core already provides complete typed appearance identities, ordered Manual queries, generation-bound pages, full itinerary progress/estimates and contextual summaries for each repeated List entry. No new Core or agent query is needed. List header matching remains native composition under Q57: retain a branch when its header or a child matches, and show neither when both fail.

The current loader projects each row to one UUID and validates UUID uniqueness. An expanded itinerary appearance needs its List-entry identity and membership identity together. Reusing the membership UUID alone would collapse repeated appearances of the same List.

## Goal and resulting state

Open an itinerary without hydrating every child presentation. Keep its complete ordered entry and appearance identities, full source metadata and contextual List summaries independently of its presentation pages. Load the first 64 matching child rows, then visible pages and at most one neighboring page on each side. Render expanded children as individually lazy native rows.

Repeated direct Items and repeated Lists retain independent local completion, full typed selection and saved route order. Global Item Done still takes precedence. Archive, full progress, estimate and remaining-time rules stay unchanged. Filters do not change full progress or duration totals. Collapsing a branch releases its child presentations when they are no longer visible or neighboring; it does not remove its contents or completion.

This is a native presentation-retention change. Complete Core identity sequences/captures, entry descriptors and source metadata remain resident under Q84. It establishes no total-memory, physical latency or hitch budget.

## Recommended production interface

Extend the existing app-internal `SavedItemWindow`, without another package, target, Core/wire contract or test-only control. Keep its real Planner/session initializer, typed query, namespace/revision identity, `reload`, visible-index requests, `cancel` and ready/loading/failure states.

The proposed view-facing interface is:

- Complete ordered matching `PlannerRowIdentity` values and matching count.
- A loaded presentation containing its actual `PlannerRowRead` and shared `PlannerRowPresentationContext`, or an explicit loading/failure state. The window no longer assigns a single UUID to a loaded row. Existing Item/List callers derive their current native identity from the validated typed row; itinerary callers keep `SavedItineraryRowSelection` with both expanded-appearance components.
- The existing optional standalone List source.
- Optional itinerary metadata containing its source, complete ordered entry descriptors and full child appearance identities/counts per entry. A List descriptor includes its live source header, contextual summary and header-match result. Descriptors contain no complete child-presentation arrays.
- Presentation lookup and visible requests use the complete matching appearance sequence. Entry descriptors map their children to that sequence without treating a page-relative index as saved route order.

Items/Inbox, standalone List contents and both Item picker callers must migrate to the typed loaded-row output. Their existing real-Core and native UI tests must retain their behavior assertions. Query defaults, row identities, selection, retention and action scopes remain unchanged. The itinerary picker must retain its complete String selection identities while deriving the saved Item UUID from the typed source. The separate List-choice catalogs remain outside this proposal.

## Coherence and failure rules

1. Capture unfiltered Manual appearance identities and the filtered Manual query using the same presentation context. Query matching List identities without hydrating their catalog presentations. Read the itinerary source and each distinct referenced List source.
2. Validate every contributing snapshot against its saved history before publishing the metadata and initial matching page together. Generation-bound positive-limit reads must also validate empty results. Validation reads need only a small slice; they must not hydrate the complete unfiltered or List-catalog result.
3. A stale history restarts the composition and first page together. Cancellation, a new itinerary, query, dataset or revision prevents obsolete work from publishing. Unsupported identities, inconsistent entry ownership/counts or missing summaries fail visibly rather than inventing an action scope.
4. Use complete typed appearance identities for uniqueness and page validation. Validate each page's exact identities and count. Repeated List memberships are distinct through their List-entry identities.
5. Preserve the existing first-page, visible-plus-neighbor, duplicate-request, release/revisit and page-failure behavior. Loading or failed placeholders expose no checkbox, drag payload or navigation action pretending that content loaded.
6. Selected details load independently through their existing typed appearance. Releasing a page, collapsing a branch or filtering a valid appearance out does not clear that detail or change a local action into a global action. Deleted/removed selections follow their accepted replacement/navigation behavior.
7. Reorder, filtered drag/drop and beginning/end anchors use complete saved entry identities. Full progress and estimates come from the coherent source metadata. Matching counts describe the complete filtered query, including unloaded pages.
8. Keep native branch disclosure, contextual actions and the existing roomy List headers. Individual child rows must be lazy within the native List; do not put an arbitrarily large branch into one eagerly constructed `VStack`. Mobile and Mac layouts require actual runtime qualification.

## Definition of ready and required TDD

The pending decision confirms this expanded production interface and its existing real-Core app-hosted seam before any new tests. Use the existing `PlannerMCPTests` target with a disposable real local-only dataset. Native UI and public Core remain the other accepted seams. No private page/task inspection, database side channel, test-only delay, callback or initializer is added.

After confirmation, work one failing behavior at a time:

- Migrate existing Item/Inbox/List tests to the typed presentation output without dropping behavior assertions, and requalify both Item pickers with offscreen selection and the existing mixed Item/List journey.
- Open a repeated-entry itinerary with more than 64 children. Verify complete literal identities and route order, first-page hydration, full metadata and independent contextual summaries.
- Cross, release and revisit pages, preserving composite appearance identity and local/global completion precedence across repeated direct and List entries.
- Cover empty itineraries, empty Lists, header-only matches, child-only matches and cumulative filters. Full progress/estimates must stay independent of the matching pages.
- Reload after real completion, archive, membership, entry-order and source changes. Check stale generation refresh, replacement and cancellation through observable outcomes.
- Qualify native intermediate boundaries, collapse/reopen, selected detail, local checkboxes, filtered drag anchors, counts, relaunch and phone/tablet resizing. Retain failed attempts and inspect original own-window captures.

Expected state, order and identities come from literal fixtures created through public commands/imports. Real Core cannot deterministically pause every internal await. Keep the Q95/Q97 limit, review publication guards, and do not claim exhaustive race coverage. Propose a different controllable production boundary only if a critical remaining case actually requires it.

## Definition of done and remaining gates

Itinerary views no longer retain complete child-presentation arrays. Approved loader behaviors, existing Item/Inbox/List regressions, affected strict Swift lint and mobile/Mac compiler checks pass. Source and specification review distinguish this integration from earlier checkpoints. Record exact source/product hashes, runtime outcomes and inspected captures.

Native runtime evidence must identify its actual platform. Mac compilation supplies no Mac runtime credit. Signing, physical-device performance, the existing Mac UI automation startup issue, broader collection/picker windowing and final whole-app acceptance remain open. This slice alone cannot close the overall map.

## Review alternatives

A extends the shared loader and changes its loaded-row output as described above. It centralizes paging and coherence but requires requalifying the existing Item/Inbox/List clients and both Item pickers.

B keeps those clients unchanged and adds a dedicated app-internal itinerary window with the same typed output, hierarchy/coherence rules and real-Core/native test boundaries. It limits changes to existing clients but duplicates paging, cancellation and retention behavior that must remain consistent.

C revises the proposed interface or test boundary before implementation. Existing List compatibility qualification can continue while that review is pending.
