# Native loading fixture

## Context and starting state

Q58 accepts a native forty-Item/four-List journey before the separate 5,000-Item/200-List performance gate. Existing native checks use small datasets. Catalogs currently request all matching rows; this slice cannot prove bounded paging, memory or the physical 300 ms target.

## Goal and expected end state

Create every Item and List through the ordinary native forms in a fresh local-only dataset. Traverse all forty Items forward and backward with stable unique identities and expected order. Add one existing Item to each List through the native picker, preserving live references. Search for the final Item, complete it while a Todo filter is active and retain its valid detail selection after its row leaves the results. Reopen the dataset and verify all forty identities, all four Lists and memberships, and saved completion.

## Definition of ready

- Q58 B approves forty Items/four Lists created through native controls.
- Use the existing ordinary local prototype dataset and public UI; no seeded fixture store or production injection is needed.
- Existing creation, selection and filter controls have smaller passing journeys. This is a broader qualification of those paths; do not invent an artificial red. Any real failure must be diagnosed, corrected and rerun at the affected scope.

## Definition of done and required /tdd

- Run the focused native journey on phone and tablet, preserving failed/setup runs and actual result counts.
- Verify every expected identity and order during traversal, then saved data after relaunch. Capture final traversal, selected-detail refresh and reopened state.
- Inspect original captures, run strict affected Swift/Markdown lint and Mac native-test-host compilation, and record commands/source hashes.
- Retain the separate large-dataset/paging/300 ms device gate, broad Mac runtime, import/recovery, Calendar, signed sync/account/Share and whole-app polish.

## Execution

The first run completed forward and reverse traversal, then failed when an immediate Add-control probe preceded asynchronous List loading. Its final native snapshot already contains No items and the Add control. The test now awaits the loaded List detail/control. The second run also passed all four membership additions, then failed because Search Items remained collapsed. Its snapshot shows the catalog rows without the search field. Pulling down the scoped native catalog reveals search. Both failed bundles, logs and snapshots remain retained; these were observed native test-interaction failures.

The corrected phone and tablet journeys each pass one function with zero failures or skips. Each creates forty Items, four Lists and four memberships through ordinary native controls. Forward/reverse traversal checks all expected titles, visual order and stable unique identities. Completing the final search result removes its row from Todo while retaining the selected detail; switching to all completion states returns the same row. Relaunch verifies all four List identities/memberships, every Item identity and the saved global completion. The retained identity text contains forty expected ordered titles and forty distinct source IDs on each device.

Tablet uses the same built test artifact with test-without-building and its own simulator/dataset. The two final runtimes overlap, so their timings serve only as functional execution records. The forty-Item check does not establish the separate 5,000-Item/200-List/300 ms target, smooth scrolling or bounded row loading/memory. Production catalogs still request all matching rows.

Standards and Spec reviews find no actionable issues. Strict lint passes for the affected Swift file; Markdown and whitespace checks pass. The corrected Mac app/test host compiles, with zero qualified Mac UI runtime functions. Production UI, Core and storage code are unchanged. [Machine-readable evidence](evidence/navigation/native-loading-fixture/execution.json) records commands, source hashes, failed epochs and actual counts. Previous [Q52 delayed-preview evidence](native-delayed-link-result.md) remains separate.

Original [phone traversal](evidence/navigation/native-loading-fixture/phone-traversal.png), [selected detail](evidence/navigation/native-loading-fixture/phone-selection.png) and [reopened completion](evidence/navigation/native-loading-fixture/phone-reopened.png), plus [tablet traversal](evidence/navigation/native-loading-fixture/tablet-traversal.png), [selected detail](evidence/navigation/native-loading-fixture/tablet-selection.png) and [reopened completion](evidence/navigation/native-loading-fixture/tablet-reopened.png), are inspected and retained. Identity records are [phone](evidence/navigation/native-loading-fixture/phone-identities.txt) and [tablet](evidence/navigation/native-loading-fixture/tablet-identities.txt). Broader map gates and whole-app polish remain open.
