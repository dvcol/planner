# Native List presentation windows

Status: the Q97 A shared loader is implemented and its 13 real-Core tests pass. Native standalone List/Table adoption is implemented in `3489c26`, with full phone/iPad traversal and selected ordinary action compatibility qualified against the integrated source. Mac runtime remains open. The accepted interface and test boundary are in the [List-window contract](../native-list-window-contract-review.md).

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

Independent Standards and Spec review found no confirmed findings in this loader checkpoint. These results establish the app-internal loader only. At that loader-only checkpoint, native List/Table views still used eager reads. Their adoption, scroll/selection/action checks and performance qualification remain separate requirements before Q97 is complete.

### Native adoption cycle

The existing native UI seam now has an isolated `list-windows` fixture with 193 ordered Item memberships, enough for four presentation pages, plus a separate List referencing the final Item. Seed data is imported through public reviewed Core commands, outside production targets. The initial journey traverses rows 65, 129 and 193, changes local completion, revisits the first/final membership and relaunches. Its eager-reader baseline qualifies observable compatibility; it cannot establish presentation-page retention. The earlier real-Core loader red/green establishes that requirement. Native adoption will be checked against both sources of evidence rather than calling an already compatible UI journey a failing retention test.

The integration will render headers directly from the loader's generation-validated ready source. A retained same-List header supports valid details while loading; it will not supply rows from another generation. Native complete membership identities drive matching counts and reorder anchors. No second row-presentation cache is added to the view.

The qualified native iPad baseline passes in 303.057 seconds. It reaches Items 65, 129 and 193, locally completes the last membership, revisits both ends with their original identities, preserves full 193-item progress and rereads the completed membership after relaunch. The first two attempts are explicitly controller failures: a collapsed sidebar hid the initial Lists button, and the CollectionView container reported noninteractive despite tappable child rows. Their failure hierarchies are retained. These baseline results use the eager native reader and establish compatibility only, not moving-window retention or a performance measurement.

### Native refresh regression

Native adoption replaces the eager row array with complete lightweight membership identities plus presentations supplied by the shared loader. List headers read the generation-validated source; manual anchors and filtered counts use the complete identities. Selected details remain independent from page retention. The Mac Table uses the same typed rows, loading/failure states and guarded actions.

The initial native integration exposed a real viewport regression after completing Item 193. The save succeeded and the full header reported one completed item, but the checked control moved out of view. The exact post-click hierarchy and [capture](evidence/navigation/native-list-windows/list-native-interaction-visible/5940F726-00ED-4A4F-B4E1-1367CA114E0A.png) establish the failure. Automatic startup hierarchy attachments from earlier attempts do not describe the failure point and must not be interpreted as a deselected List.

Retaining the clicked identity alone did not fix the regression. The target page must finish loading before restoring its variable-height native rows. Viewport-driven page requests wait during that restoration; no second presentation cache is introduced. The focused [green journey](evidence/navigation/native-list-windows/list-native-hydrated-anchor/exit.json) passes in 59.871 seconds and explicitly checks both Completed and native hittability. Its [inspected capture](evidence/navigation/native-list-windows/list-native-hydrated-anchor/045C3380-14B3-4809-9C97-54E2705A3EBF.png) shows the same completed final membership within the viewport and full 193-item progress. The complete traversal, ordinary action regressions and platform qualification remain separate checks.

The complete iPad integration journey passes in 298.909 seconds. It traverses all four pages, reopens Item 193 details, revisits the first membership while retaining those details and full progress, and rereads completion after relaunch. The inspected [first-page revisit](evidence/navigation/native-list-windows/list-native-tablet-hydrated-traversal/418F8E7A-D650-4833-816C-1C59FAC73F4A.png) and [relaunch capture](evidence/navigation/native-list-windows/list-native-tablet-hydrated-traversal/E4E51EBA-EC33-4C05-921E-599B2BB8FA48.png) show those states. These timings qualify the journey, not performance. The [final Mac compiler check](evidence/navigation/native-list-windows/list-native-platform-guard-mac-build/exit.json) passes with local ad hoc signing. Source review separates the mobile restoration guard from Mac Table visibility requests. Mac UI runtime, phone traversal and ordinary List action compatibility remain open at this checkpoint.

The subsequent [UI consistency follow-up](native-design-refinement.md#native-pane-consistency-follow-up) adds passing ordinary native compatibility checks through the integrated List window: filtered Manual drag/drop and independent Itinerary checks on iPad, cumulative List search/archive filters on phone, and rich New Item creation into its original List at maximum iPad text size. These preserve local completion, identities, full progress and relaunch state. They do not close phone multi-page traversal, first-survivor deletion, Mac runtime or physical performance qualification.

### Phone traversal and action compatibility

The [full iPhone traversal](evidence/navigation/native-list-windows/list-native-phone-final-traversal/exit.json) passes in 224.911 seconds against the exact committed Swift/configuration source in `5c5febb`. It reaches intermediate memberships 65 and 129, locally completes membership 193, returns to the first membership and rereads the completed final membership after relaunch. The [first-page revisit](evidence/navigation/native-list-windows/list-native-phone-final-traversal/98A9A840-DD9C-431E-961F-174DE36259E2.png) and [relaunch capture](evidence/navigation/native-list-windows/list-native-phone-final-traversal/AD920795-B59F-4A03-A84E-ED1575988B2F.png) were inspected directly. Full progress remains one of 193 items done, with the full estimate and remaining time retained. Native bottom tabs and contextual completion remain visible.

The [selected ordinary iPad action run](evidence/navigation/native-list-windows/list-native-tablet-adoption-regressions/exit.json) passes all four functions in 678.727 seconds. Item deletion respects cancellation and then chooses the first visible survivor in the current sort. List deletion respects cancellation and then selects the first surviving List and its first sorted Item. Sort choices retain Manual order, per-List ascending/descending preferences, membership identities and contextual progress through switching and relaunch. The edited New Item draft retains its title, subtitle, notes, duration, owned location, bookmark and original List through portrait/landscape rotation, explicit Save and relaunch. This run qualifies iPad behavior; it supplies no Mac resize or cross-window credit.

These checks reuse the exact app Swift/configuration source qualified in `5c5febb`. The fresh phone compiler check and both native runtime runners retain source/product hashes and assert that those inputs stay frozen. The iPad runner uses the existing final mobile build; the final Mac compiler check is also reused against unchanged source. No signing account or permission setting changes are needed. The [compatibility record](evidence/navigation/native-list-windows/native-compatibility-validation.json) links the exact results, compiler references, lint and inspected captures. Native journey durations are execution timings, not performance acceptance measurements.

The [itinerary window proposal](../native-itinerary-window-contract-review.md) is pending as Q98. It identifies the current eager itinerary reads and proposes typed loaded rows and coherent hierarchy metadata at the existing real-Core/native test boundaries. Itinerary/picker retention is not qualified by these standalone List results. Mac native UI, physical performance, signing and full visual/accessibility acceptance remain open.
