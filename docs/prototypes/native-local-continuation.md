# Local continuation, 19 October 2026

The user requests continued local implementation, deferring signing until it is required. The initial checkpoint qualifies existing native Undo and diagnoses remaining native interactions without changing production behavior, Core schema or portable data. Later local results are recorded below.

## Context, readiness and intended result

The starting revision is `c49db7b0`. Grouped link/label Undo already passes on simulators; actual Mac window/text Undo remains open. The approved native UI seam, Q108 controller boundary and Q111 compound restoration contract carry forward. The goal is actual native evidence, with test-driver corrections based on observed accessibility traits rather than added production hooks.

## Executed results

| Journey | Surface | Outcome |
| --- | --- | --- |
| Membership Undo, separate windows and ordinary text Undo | Mac, local ad hoc | Pass, 69.255 s |
| Whole Move Undo | Mac, local ad hoc | Pass, 94.714 s |
| Grouped itinerary links/labels, notes retained, relaunch | Mac, local ad hoc | Pass, 70.830 s |
| List creation/cancellation and relaunch | Dark iPhone Simulator | Pass, 28.932 s |
| Filtered Manual reorder with hidden Done membership and relaunch | Dark iPhone Simulator | Pass, 138.383 s |
| Same filtered Manual reorder | Light iPad Simulator | Pass, 152.308 s |

The Mac window query now compares the generated identifier through a predicate. XCTest rejects `matching(identifier:)` for this observed identifier exceeding 128 characters. Native Mac source choices expose text through value; saved labels are Buttons rather than StaticText. Queries now match those actual traits. Grouped editor scrolling targets the active sheet and checks that the control fits inside its viewport before clicking. The previous Add Link failure clicked below the visible Form clip.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains source/product hashes, commands, exit status, actual logs, failing attempts and selected original captures. Inspected passing captures show restored checked membership, grouped itinerary links and notes, and before/after filtered reorder on phone plus the reordered tablet. They also retain the crowded inline phone toolbar title; this is still a local polish issue.

## Initial remaining local outcomes

The final Mac batch has three functions, one pass and two failures. Repeated-entry setup fails opening the catalog Add menu; grouped Item setup fails an XCTest automatic scroll to its label selector. An exported native recording shows display/window geometry changing during the failed Add interaction. These outcomes do not establish a Core mutation defect, signing failure or successful journey. They remain open; no automatic retry is counted as a fix.

An earlier unchanged filtered drag failed on iPhone. The added before/after captures preserve its gesture unchanged; the diagnostic run passes on both simulators. This is evidence of intermittent behavior, not proof of its cause or permanent test stability.

## Initial implementation audit

At the starting revision `c49db7b0`, the project has no Share extension targets/controllers and no App Intents implementation. Storage supports only `localOnly`, and its SwiftData configuration disables CloudKit. These are implementation gaps as well as future qualification gates. Signing alone cannot complete them.

Unsigned Share source/targets and ordinary app-target Intents can proceed against the accepted Core/provider/native seams. Installed extension access, real App Groups, physical CloudKit/account transitions, native Agent Control under Q100 B, selected desktop clients and physical performance retain their separate gates. Existing local data must not silently move to a new directory. No provisioned group, team or cloud identifier is invented. Final whole-app polish follows feature completion.

## Later local implementation and native checks

[Native Item Intents](native-item-intents.md) and [Share recovery outcomes](native-share-recovery.md) now provide the implemented tracers and their scoped evidence. They retain separate installed/system/physical gates. [The device readiness report](local-device-readiness.md) records a successful signing-disabled iPhone/iPad SDK build and the current access inventory.

Both previously failing Mac Undo journeys now pass. Grouped Item link/label removal Undo, saved notes and relaunch pass in 87.359 seconds. Repeated Itinerary-entry removal/Undo passes in 113.334 seconds, retaining original public identity, independent completion, filters, progress and order through relaunch. These are local ad hoc native results.

The scoped Mac recapture also passes in 138.390 seconds. The repeated-entry regression passes on dark iPhone in 144.870 seconds and light iPad in 125.661 seconds, both with Increase Contrast enabled and the original settings restored. These are focused behavior checks across their recorded source revisions, not complete appearance/accessibility acceptance.

The scoped drivers place those single-window journeys through the observed native Window Fill action. New Item waits for its actual menu entry. The existing Item editor scrolls its label selector inside the real sheet before opening the popover. Mac's repeated-List header is a combined group/progress element, so the removal targets the containing entry identity rather than a missing StaticText. Filter choices use actual MenuItem titles; ordinary Button captions fall back to their labels. Progress is checked through the actual ProgressView accessibility label. No production command or data model changes for these corrections.

The iPad regression first fails in 42.771 seconds before Item creation and reproduces unchanged in isolation in 18.924 seconds. The helper caches a missing sidebar destination before revealing it, then takes the fallback path and toggles the sidebar again after selecting Items. Rechecking the actual destination after revealing the sidebar avoids that redundant navigation. The production Add menu then opens and the entire journey passes. Both failed attempts remain failures; no production menu workaround or test-only application hook is added.

Failed iterations remain in the [compatibility evidence](evidence/navigation/native-itinerary-window-compatibility/). The first preparation build precedes the actual driver edits and receives no Undo-runtime credit. Group/header, menu-title and progress-text diagnostics are retained separately. Unrelated system Apple-menu branches are omitted from committed hierarchy copies, with original hashes and local originals recorded. Three whole-display Mac captures are also omitted because they contain unrelated system menu-bar content. Their original hashes and local paths remain in the audit records; pixels are not modified. The repeated-entry screenshot helper now captures the actual Planner window. Original scoped Mac, dark-phone and light-tablet captures were inspected; final toolbar/scroll-edge polish remains open.

[Q113's toolbar review](../native-list-toolbar-review.md) is pending. Its ineffective priority trial is reverted; the inline-title diagnostic is retained outside default test targets in `docs/prototypes/experiments/ListToolbarTitleProbe.swift`. It is not an accepted UI requirement or a completed fix. Final whole-app polish still follows feature completion.
