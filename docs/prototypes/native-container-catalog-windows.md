# Native container catalog windows

Status: Q103 A implementation checkpoint. All catalog and picker consumers are migrated. Represented phone/iPad picker flows and 20 real-Core loader functions pass. Rich creation, deletion replacement and import callers pass; the complete remembered Capture/archive journey now passes. Final affected compiler/lint outcomes are recorded in the packet. All four broader caller regressions now have passing phone invocations; unavailable Mac runtime and broader acceptance remain open. Q106/Q107 original-association Undo is implemented in its linked checkpoint.

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

The evidence packet retains exact source epochs, commands, product hashes and results.

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

- Mac UI runtime remains unavailable before tests start; represented phone/iPad results do not establish Mac interaction or resizing.
- Retain the final strict affected lint and both platform compiler results in this checkpoint. All five picker migrations have represented phone/iPad identity/selection evidence, and the complete remembered Capture/archive caller journey passes.
- All four named broader callers pass in the continuation below. The ordered-entry journey also covers the final Add-task guard's ordinary path; deterministic race pausing is outside the approved seam. Keep their recorded source epochs separate from Mac and physical acceptance.
- Keep physical scale, broader accessibility/keyboard/scene inventory and feature-complete whole-app polish on their owning map gates.

Mac UI automation currently times out before tests start. Signing, protected Agent Control storage, physical performance, CloudKit/account transitions and cross-process Share retain separate gates. No Q103, Navigation or whole-app polish gate is closed by this checkpoint.

## Destination and filter picker continuation

All five remaining catalog consumers use the accepted overload. Filter choices retain archive All; Capture, Add, Move and Itinerary choices retain archive Active and omitted sorting. Move excludes its source at original query indices. Selected IDs remain separate from cached presentations. Move reads its selected List once before the command for truthful feedback, rechecks namespace/revision/selection, and never reports a saved move as failed because of a later metadata read.

Capture initializes the originating or remembered subset once per prepared draft. A remembered set with any unavailable identity clears the whole set, preserving the accepted initial policy. Later refreshes retain user choices. An unavailable selected destination blocks Save and offers explicit removal of unavailable selections. Dataset replacement blocks the old capture; preference reads/writes stay bound to its originating namespace. Provider preview content remains temporary.

The eager `SavedPlannerStore.lists` array and complete `readLists`/`readItineraries` methods are removed. Creation, archive and import rely on their existing saved-change revision refresh. Core/MCP/backup contracts remain unchanged.

`container-picker-mobile-build` compiles the migrated production views and focused fixture tests. Native qualification is in progress; compilation is not completion.

The first long-destination journey, `phone-container-picker-add-move`, fails its controller's fully-visible assertion after 168.399 s. An original Simulator diagnostic shows List 193 clearly visible in the Add sheet with Add enabled. The controller was using the obscured background TabBar as the sheet's bottom boundary. It now uses only hittable native bars. No Add/Move save or relaunch credit is claimed from that attempt.

A bounded read-only source review confirms the five migrated callers preserve their query defaults, complete-ID selection and remembered-subset behavior. It also finds an adjacent Item-side retention gap in the mixed Itinerary picker: empty visibility sets were skipped after scrolling into Lists. The picker now submits empty requests after first display to release those Item pages. This preserves selected source IDs and introduces no new test boundary.

`phone-container-picker-qualified-add-move` passes in 247.990 s with the corrected controller. The selected first destination remains usable after reaching List 193. Move excludes its source List, retains a selected final destination after returning to the first page, and saves a new local Todo appearance. Relaunch retains the destination identity, original shared source/notes and one global source row. This is light-phone evidence; it does not establish every picker, tablet/Mac layout or physical performance.

`phone-container-capture-filter-itinerary` reaches List 193 in the dark Capture Form and saves the first offscreen destination, then fails at 84.235 s while asserting a List-filter control. The controller's eager element helper fixed its query to Button before the asynchronously loaded Toggle existed. Exported debug descriptions retain that Button query. The controller now uses the established type-independent label/identifier query and waits for the real row; production views are unchanged for this correction. The failed combined invocation is not credited as wholly passing.

A read-only sub-agent inspected all three passing Add/Move originals. The Add sheet shows readable Lists 181–193 and its full explanatory footer. The Move sheet shows its source, origin and readable early destinations after scrolling back. Saved details show To do, the correct destination, retained notes and five-minute duration, with all bottom tabs visible. No concrete clipping/obscuring defect was found in these frames. Exact paths, hashes and attribution are in `visual-review-delegated.json`; pixels alone do not establish identity, interaction, memory or accessibility results.

The next combined run, `phone-container-choice-queries-qualified`, passes Capture and List filtering but fails at 182.266 s because Itinerary Add is disabled. This remains a product failure, not a controller pass. A minimized native reproduction, `phone-itinerary-minimal-selection-red`, fails in 21.202 s immediately after choosing a loaded List. Its original image/hierarchy shows ready content, no loading overlay and disabled Add before eviction.

The helper's outer ForEach identity was UUID, while the mixed Itinerary picker requires String selection values. Its explicit String tag was nested inside loaded content. The correction gives every caller an explicitly typed outer-row selection tag and keeps that tag across presentation states; unloaded rows remain disabled. Main sidebar tags use their existing sidebar enum, catalog and ordinary destination tags use UUIDs, and mixed Itinerary tags use their existing Item/List strings. This is a native UI correction, with no Core query, persistence or backup change. The minimized native test supplies the red/green boundary; the complete Capture/filter/Itinerary and UUID callers still require requalification.

`phone-itinerary-stable-selection-tags-green` is named for the intended check but fails in 21.620 s at the same immediate-selection assertion. Moving only the explicit tag therefore does not establish a fix. The next candidate also aligns the outer ForEach identity with the caller's selection value, matching the existing mixed Item row pattern. No successful Itinerary List-selection result is claimed from the failed candidate.

`phone-itinerary-matching-selection-identities` passes the before/after-eviction enabled checks and submits Add, then fails at 79.197 s because its exact-label query cannot locate the containing saved List group. The group identifier is separate from its child title; the controller now queries that containing group. `container-saved-branch-controller-build` then fails compilation because a local Add element shadows XCTest's attachment method. The call is qualified as `self.add`; neither controller issue is credited as a product failure or a completed journey.

## Final picker qualification in progress

The final production selection correction passes all three dark-phone functions in `phone-final-container-picker-regressions`: Capture/filter/Itinerary choices 202.561 s, offscreen Add/Move 252.542 s, and the minimized Itinerary selection/save/exact-entry relaunch regression 77.306 s. Total 532.409 s, zero failures/skips. The stable outer row's ForEach identity and explicit tag both match the caller's selection type. The source's complete IDs remain independent of retained presentations.

`tablet-final-container-picker-and-contrast` passes current wide catalog estimate/selection in 105.163 s and the actual native List contrast audit/local completion in 21.108 s with dark mode and Increase Contrast. Both new large-picker functions stop at their phone-specific initial Lists-button check, in 65.539/65.404 s, before reaching their workflows. The invocation is failed overall. The controller now accepts the sidebar's existing Show Sidebar/section controls as well as phone navigation and captures initial navigation; no production change accompanies that correction. Their iPad workflow rerun remains in progress.

The final phone source has nine inspected originals across the primary agent and a read-only sub-agent. All five picker types have readable represented controls and rows. Saved Move details remain clear. The full saved itinerary image places its final child title beneath bottom tabs at that initial scroll position; that frame does not establish full reachability. The isolated empty-branch image shows its No items text above the tabs. Header-edge clipping/blur and complete scroll reachability remain final-polish work, separate from the passing identity/completion assertions and the later scoped iPad contrast audit.

`tablet-container-picker-adaptive-navigation` reaches both workflows after the startup correction. Capture saves, then the filter controller fails to reveal the offscreen In Lists field, stopping that function at 83.335 s. Add/Move reaches the correct saved destination/source/Todo details after relaunch, then fails at 261.240 s when navigation tries to find Items in the sidebar still scrolled to List193. The whole invocation remains failed. The controllers now use the existing filter-reveal helper and scroll a long iPad sidebar back to its navigation rows. Production code is unchanged in these corrections.

`tablet-container-picker-controls-qualified` passes both complete workflows with dark mode and Increase Contrast: Capture/filter/Itinerary choices in 219.125 s and Add/Move in 332.602 s, zero failures/skips. Exact identities, retained notes, local Todo after Move and one global source survive relaunch. The primary agent inspected its original saved itinerary and moved-source detail captures: represented rows, nested branch, progress, warnings and detail content are readable and unobscured. This is scoped iPad evidence, not Mac runtime or physical-performance qualification.

`container-picker-final-loader-regressions` reruns all 20 app-hosted real-Core loader functions successfully on the final picker source. Summed function time is 120.194 s; the 193-List durable fixture accounts for 102.265 s, rather than measuring query latency. Existing Item/Inbox/List/Itinerary windows, catalog defaults, stale refresh, cancellation and release/revisit remain covered.

`container-picker-current-native-mac-build` and `container-picker-current-navigation-mobile-build` compile the actual app and native test targets. `tablet-container-caller-regressions-current` passes first-survivor List/Item selection in 135.477 s, rich List-origin creation in 144.302 s and real Skip/Overwrite import in 101.303 s. Its Capture function fails at 36.029 s before Capture opens: a phone-specific Items Button query cannot match the hidden iPad sidebar. The captured hierarchy includes Show Sidebar. Both Capture section transitions now use the existing adaptive navigation helper; no Capture production behavior changes for that controller correction. The whole four-function invocation remains failed.

Final source review also adds the mixed Itinerary Add task’s cancellation, load-identity and selected-source recheck before mutation, matching the migrated Add/Move forms. Exact race interleavings are not deterministically paused at the approved boundary. Affected native regression and both platform compiler checks follow this guard.

The primary agent inspected the original iPad first-survivor and rich-New-Item captures from that mixed invocation. The surviving source/context and authored native fields are readable in dark mode with Increase Contrast. The already-scrolled originating-List field extends behind the New Item toolbar; no complete scroll-reachability claim follows from that frame.

`tablet-capture-memory-adaptive-current` passes the remembered global/North/South subset assertions and relaunch, then fails at 227.314 s when its controller directly queries the archive filter now held in the narrow sidebar toolbar’s native overflow menu. The exported hierarchy identifies that Planner overflow control. The controller now opens that native menu before selecting the existing archive filter. Production Capture code is unchanged; the entire failed invocation retains no pass credit.

`tablet-capture-memory-toolbar-qualified` reaches the native overflow but fails at 233.149 s because its fallback incorrectly expects the direct control’s accessibility label Active Lists. The exported overflow hierarchy instead contains the Button Active and New List. The controller is corrected to that observed native title. No product change or successful whole journey is credited to this failed attempt.

`tablet-capture-native-overflow-label-qualified` selects All Lists and reopens the archived List, then fails at 243.803 s because the disabled Add menu is also inside content-toolbar overflow. It does not fail the disabled-state assertion; the direct identifier lookup finds no control. The established menu-reveal helper now returns its native control separately from activation, so the same helper can inspect disabled Add without tapping it. Capture behavior remains unchanged.

`container-picker-archived-add-controller-mobile-build` exits 74 before compilation because the temporary Swift MCP SDK and SwiftNIO checkouts have no Package.swift. Their Git metadata is incomplete too, and the pinned-only resolver cannot repair them. The repair packet records fresh checkouts of exactly Swift MCP SDK 0.12.1 at a0ae212ebf6eab5f754c3129608bc5557637e605 and SwiftNIO 2.104.0 at 6db9d9abd92ad7399b8a564cafbb87d3507245fa. Original damaged directories are retained outside the repository. Package.resolved is hash-verified unchanged. This is build-cache repair, with no compiler/runtime success claimed from the failed attempt.

The next dependency graph also identifies missing manifests in EventSource, Swift Atomics, Collections, Log and System. The transitive repair packet retains every exact pinned revision and preserved old checkout. No dependency version changes. The subsequent compiler attempt uses that complete repaired cache.

A further inspected original from the passing rich-creation function visibly retains its selected originating-List appearance and a painted native Apple Maps address card with pin/attribution in details. The link card shows Preview unavailable and Retry; no website-image provider success is inferred from that capture.

`tablet-capture-archived-add-controller-qualified` reaches the overflow Add group but fails its parent-enabled assertion at 244.204 s. A focused native journey now inspects the actual New Item, Add existing Item and Capture actions before classifying this as an actionable product failure or a native menu-group accessibility difference. The failed full journey is retained without success credit.

The minimized `tablet-archived-creation-actions-diagnostic` passes in 49.221 s. Its retained native hierarchy and assertions show the enabled overflow group contains disabled New Item, Add existing Item and Capture actions. This is a parent-group accessibility difference, with no production behavior change needed. The complete journey now uses the same actual-action check rather than asserting the group itself must be disabled.

`tablet-capture-native-action-policy-qualified` passes the complete remembered global/North/South destination and archive workflow in 280.573 s with dark mode and Increase Contrast. It verifies all three archived-List creation actions are unavailable, then relaunches and verifies the invalid remembered subset clears without selecting another List. The final draft is cancelled without creating its Item. The primary agent inspected the original final sheet: North is the sole available destination, its Toggle is off, and the Inbox explanation plus Add/Cancel controls are visible.

`container-picker-final-native-mac-build` compiles the final Mac app/test targets with the existing local ad hoc signature and repaired exact pinned dependencies. The final Simulator source compiles in `container-native-disabled-action-controller-mobile-build`; the passing focused/full action checks retain their own source epochs. Strict affected Swift/Markdown lint and diff checks are recorded under `picker-checkpoint-validation`. Actual xcodebuild exits and function results determine runtime credit; older diagnostic wrappers printed failure results without propagating their exit, and subsequent wrappers now propagate it. No failed invocation is counted as passing here.

## Broader caller continuation

`association-undo-phone-catalog-caller-regressions` runs the four outstanding callers against the same production source as the Undo checkpoint. Inbox passes in 315.397 s, cumulative List search in 140.579 s, and ordered Itinerary Item/List entries in 96.922 s, including independent completion and relaunch. The invocation fails overall because the fourth fixture misses New List in compact navigation. Reusing the shared native creation helper gets it past that setup.

A subsequent observation expects three native rows while the third child is below the phone's visible lazy-list window. Its actual capture retains all three entries in full progress and shows the second List branch continuing below the tab bar. The controller now scrolls the real native collection before reading the fixture's appearance identities. The corrected `phone-itinerary-filter-visible-rows-qualified` invocation passes in 328.991 s, including cumulative text/state/label filters, independent repeated completion, full progress and relaunch. Neither failed controller observation establishes a product defect.

The original passing List-search, ordered-route and final itinerary-filter captures were inspected. Full progress, separate filtered counts, independent checks and system bottom tabs remain visible in dark mode. Faint composition captions and floating-bar edge readability remain final UI review findings. These represented results do not close Mac runtime, accessibility or physical acceptance.

The caller/draft checkpoint index preserves individual passing functions, failed attempts and compiler-only epochs. Final mobile and Mac app/UI targets compile; strict lint passes both affected Swift files and both reports. Recorded production Swift inputs match this checkpoint. This continuation changes native test observations and adds qualification; production behavior remains unchanged.
