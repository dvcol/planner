# Native container catalog windows

Status: Q103 A implementation checkpoint. The shared catalog overload and main catalog views are implemented. Destination/filter picker migrations and final qualification remain open.

## Context and goal

Lists, Itineraries and List-choice pickers previously used complete row-presentation reads. SwiftUI rendered lazily, but the app retained every matching presentation. The accepted [contract](../native-container-window-contract-review.md) extends the existing Item/List/Itinerary loader rather than adding another paging implementation.

Before: each catalog hydrates its complete result. After: retain complete typed source identities/counts, publish a validated first 64-row page, then retain visible pages and at most one neighbor on either side. Selection, sorts, archive filters and destinations keep their existing meaning. Core identity sequences and query captures remain resident; bounded total memory and physical performance are not established.

## Definition of ready and required checks

Q103 A approves `reload(catalogQuery:identity:)` and the existing real-Core app-hosted/native UI boundaries. Disposable tests use actual public queries, commands, reads and imports. No new package, target, persistence field, MCP schema or test-only production parameter is introduced.

The contract defines required tests and completion criteria: both kinds beyond 64 rows, release/revisit, complete metadata, sort/filter preservation, stale refresh, query/namespace replacement, cancellation and every native catalog/picker consumer. Existing Item/Inbox/List/Itinerary regressions remain required. A successful compiler check alone is not a native journey.

## Implemented behavior

`SavedItemWindow` retains the actual typed query request through paging and stale refresh. Catalog reads admit Lists and Itineraries, validate complete source identities/counts and required estimate/archive fields, and clear unrelated List/Itinerary-content metadata. The existing paging, cancellation and recovery from stale generations remain shared.

The main native Lists and Itineraries catalogs use the new overload. `SavedContainerWindowRows` renders loaded native rows, disables selection on loading/failure placeholders, and reports visibility at original query indices. Complete identities determine the first List replacement after deletion. Presentation release does not remove an offscreen selection's identity.

## Evidence recorded so far

The [evidence packet](evidence/navigation/native-itinerary-window-compatibility/) retains exact source epochs, commands, product hashes and results.

| Epoch | Result |
| --- | --- |
| `container-catalog-first-page-red` | The new real-Core test fails compilation because the approved catalog overload does not exist. |
| `container-catalog-first-page-green` | Initial 65-List first-page/identity/estimate case passes in 4.955 s. |
| `container-catalog-loader-regressions` | Test compiler error from `.minutes` instead of the existing `.minute` display-unit case. No product red or runtime credit. |
| `container-catalog-loader-regressions-qualified` | All 20 loader functions pass. Includes a 193-List release/revisit case, 65-Itinerary stale refresh, sort/archive/text checks and earlier Item/Inbox/List/Itinerary cases. |
| `phone-main-catalogs-and-corrected-collapse` | Native separate catalog sorts/relaunch/dataset choices pass in 113.176 s; itinerary collapse/rotation passes in 55.457 s. Live-estimate test stops at a controller readiness check before its workflow starts. Whole invocation fails. |
| `container-main-catalog-mac-build` | Current-source Mac fixture app/test targets compile with the existing local ad hoc signature. |
| `mac-current-itinerary-and-catalog-retry` | Runner times out enabling automation before either test starts. Exit 65 after 71.335 s; no Mac runtime credit. |
| `phone-container-window-stable-catalog` | Both 193-source catalogs cross 65/129/193, revisit their first source and reopen exact final identities after relaunch. Pass, 460.562 s. |

The failed readiness query expects the Lists tab's icon identifier on a Button. Its captured hierarchy instead contains a usable Button labeled Lists with that identifier on its child Image. The controller now accepts the actual native navigation alternatives. No product change is credited for that correction.

The corrected live-estimate function subsequently passes in 99.608 s in `phone-container-window-traversal-and-estimate-refresh`. That invocation still fails overall: the new traversal controller identifies its scroll container through the first row, which disappears when scrolled offscreen. Stable native catalog identifiers replace that query. Phone execution skips the function's simultaneous wide-pane selection assertions; those need tablet/Mac evidence.

The 20-function class takes 116.796 s of summed function time. Its 193-List fixture performs separate durable public create commands and accounts for 99.243 s; this is not a catalog-query latency measurement.

A read-only sub-agent inspected four original captures from the passing traversal. Intermediate List rows and final Itinerary rows show readable estimates and Manual captions. Relaunched List 193 shows its manual estimate and empty state; Itinerary 193 shows its notes, totals and one source row. These frames contain no loading/error state. Scrolled edge content extends under the native floating bars. Pixel review establishes no memory bound or formal accessibility result.

A bounded read-only source review found two lifecycle defects in the catalog migration. Canceled caller tasks could replace a newer window before returning, and an automatic Itinerary refresh failure could clear rows without showing Retry. Entry cancellation guards now precede mutation, and catalog overlays observe the loader's current loading/failure state. Exact interleavings are not deterministically paused at the approved boundary; the review does not establish exhaustive race coverage.

Current-source review corrections compile for Simulator and Mac in `container-refresh-guards-mobile-build` and `container-refresh-guards-mac-build`. `tablet-catalog-refresh-and-collapse-current` passes both wide iPad functions: live catalog estimate/selection in 104.952 s and collapse/rotation in 52.994 s. The primary agent inspected its original portrait and landscape collapse captures: selected Completed details, full 1-of-132 progress and independent List branches remain readable. This is scoped evidence, not final scene acceptance.

## Remaining definition of done

- Qualify tablet and available Mac layouts, including simultaneous selected details and lifecycle behavior. Phone traversal and live-estimate results above do not establish those layouts.
- Migrate Filter Lists, Capture destinations, both Add/Move-to-List forms and the Itinerary List-choice section. Preserve offscreen selected IDs, lifecycle readiness, live names and Capture's remembered-subset rules.
- Remove the eager shared destination array, obsolete complete-presentation readers and their refresh calls only after all consumers migrate.
- Requalify affected native creation, filtering, deletion, ordering, destination and selection workflows. Complete strict affected lint and both platform compiler checks; record inspected original captures and unavailable runtime checks.

Mac UI automation currently times out before tests start. Signing, protected Agent Control storage, physical performance, CloudKit/account transitions and cross-process Share retain separate gates. No Q103, Navigation or whole-app polish gate is closed by this checkpoint.
