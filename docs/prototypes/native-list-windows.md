# Native List presentation windows

Status: the Q97 A shared loader is implemented and its 13 real-Core tests pass. Native standalone List/Table adoption remains open while the requested UI review proceeds. The accepted interface and test boundary are in the [List-window contract](../native-list-window-contract-review.md). The navigation/appearance checkpoint is committed separately as `b1b8d3b`.

## Context and outcome

Before this slice, Items and Inbox open through the existing first-page loader. Standalone Lists read their header and eagerly accumulate every matching row presentation. Their complete arrays also supply matching counts, native membership identities, reorder anchors and replacement selection. Native lazy rendering alone does not release those presentations.

After this slice, the shared loader should return complete typed identities and a generation-validated List header with only the first page hydrated. Visible pages and one adjacent page on either side should be retained. Full progress, estimates, filtered counts, local completion scope, saved order and valid selected details must survive page release and query changes. Native List and Mac Table adoption and their compatibility checks are part of the outcome, not implied by a loader test.

## Readiness and TDD boundary

Q97 A approves the expanded app-internal loader interface and its existing real-Core `PlannerMCPTests` seam. The same native UI/large-fixture boundaries qualify integration. No Core/MCP contract, package, target or production test hook changes.

The first test uses a real local-only Planner, imports 65 Items and memberships through the public reviewed import path, and checks List readiness, complete typed membership identities, full header progress/estimates/references and first-page presentations. The row at index 64 must remain unhydrated. Initial output declarations contain no List behavior so the test can observe a runtime failure before implementation.

Subsequent vertical cycles cover empty/filtered results, page release/revisit, contextual state across Lists, Core filter/sort/manual ordering, stale saved-history refresh, replacement/cancellation and existing Item/Inbox behavior. Expected identities and values come from the fixture's public commands/imports. Tests never read database or private task/page state.

## Completion requirements

- Implement and qualify the shared loader's approved typed identity and coherent List-header behavior, migrating the seven existing Item/Inbox tests and callers.
- Adopt it in standalone native List and Mac Table contents. Keep full matching identity sequences and header references for counts and manual-order actions; loading placeholders expose no invented Item action.
- Preserve independent selected detail, first-survivor deletion selection, contextual completion, Add/New Item, archive filters and navigation/draft guards.
- Qualify native intermediate boundaries, release/revisit, selected detail, filtered/manual reorder anchors and phone/tablet layout compatibility through existing seams.
- Run affected strict Swift lint, mobile/Mac compiler checks and focused regressions; inspect original native captures and review Standards/Spec separately.
- Record literal red/green, source/product hashes, source freeze checks, source reviews, captures actually inspected and remaining limits before claiming completion.

## Evidence and limits

The [evidence directory](evidence/navigation/native-list-windows/) retains each compiler/runtime epoch separately. Current compiler activity is not runtime proof. This report will record executed outcomes as they arrive.

Core's retained identities/captures and full List metadata remain resident under Q84/Q97. Page retention alone proves neither bounded total memory nor latency. Itinerary hierarchy, picker adoption, physical performance, Mac UI startup, signing and final whole-app polish retain their existing gates. This slice cannot close the overall map or Navigation ticket.

### Shared loader checkpoint

The loader now retains full typed source/membership identities and an optional List header. It publishes a List header only after the query's first generation-bound row read, including empty results. First display hydrates 64 rows; page traversal releases distant presentations and retains full progress, estimates, references and matching identities. Items/Inbox callers retain source-based selection.

The qualified [first List red](evidence/navigation/native-list-windows/q97-first-list-qualified-red/exit.json) observed the old loader reject List membership identities. Two earlier fixture setup failures are retained and carry no behavior-red credit. The [final loader suite](evidence/navigation/native-list-windows/q97-loader-suite/exit.json) passes all 13 functions in 4.463 seconds, covering original Item/Inbox behavior, List page traversal/revisit, empty/filtered headers, independent completion across Lists, cumulative filtering/sort and stale manual-order/removal refresh. The final selected compiler check succeeds. Strict Swift formatting and whitespace checks pass.

Independent Standards and Spec review found no confirmed findings in this loader checkpoint. These results establish the app-internal loader only. Native List/Table views still use eager reads; their adoption, scroll/selection/action checks and performance qualification remain required before Q97 is complete.
