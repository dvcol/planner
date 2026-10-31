# Native container estimate shortcuts

Status: the represented List shortcut lifecycle passes on both simulators. Mac compilation passes; Mac runtime and Q94 label-picker presentation remain separate gates. Signing remains deferred.

## Context and starting state

The shared editor already implements the accepted Half-day, Full-day and Weekend conversions. [Item qualification](native-estimate-shortcuts.md) does not qualify the List and Itinerary callers. This slice starts with the ordinary List editor and an empty local dataset.

## Goal and expected end state

Use Half-day to save a manual List estimate of 720 minutes. Stage Full-day and Cancel without changing it. Save Weekend as 2,880 minutes and retain the same List and two-day display after relaunch. Clear explicitly back to calculation, save and relaunch; the same empty List shows zero calculated minutes and No items.

## Definition of ready

The accepted conversions, manual-override lifecycle and production native UI boundary already define the behavior. The existing shared component supplies the feature. This is qualification of an existing implementation, so it does not invent a missing-feature red. No public command, schema, wire contract or test-only seam changes.

## Required tests and definition of done

- Select native shortcuts and assert literal saved minutes, selected quantities and Manual versus calculated presentation.
- Verify Cancel retains the saved estimate and relaunch retains the List identity and display unit.
- Verify clearing survives a second relaunch without completing the empty List.
- Compile the affected app/UI targets on both platforms, lint changed Swift and report files, and record actual platform outcomes and individually inspected named Planner-window captures.

Itinerary/Capture callers, Mac runtime, physical sync/account/Share, accessibility, performance and whole-app polish retain their separate gates.

## Qualified results

| Platform | Final function result | Scope |
| --- | --- | --- |
| iPhone 18 Pro Simulator, iOS 27.0 | Pass, 101.080 s | Complete List shortcut lifecycle and two relaunches |
| iPad Air 11-inch M4 Simulator, iOS 27.0 | Pass, 128.726 s | Same lifecycle through native sidebar/toolbar overflow |
| Native Mac | Compiler-only pass | Affected app/UI targets with local ad hoc settings |

Both final-source invocations execute one function with zero failures or skips. An earlier iPhone invocation passes in 104.123 seconds on its original source epoch. These durations include XCTest and fixture work; they do not measure physical responsiveness.

The journey saves Half-day as exactly 720 minutes, stages Full-day and cancels, then saves Weekend as exactly 2,880 minutes. After relaunch it verifies the same List identity, the exact saved minutes and the two-day unit display. Clearing the manual estimate and saving returns the empty List to zero calculated minutes. A second relaunch retains that identity and calculated state, with No items rather than completed progress. This qualifies existing production behavior; the slice changes the native test/controller only.

## Native toolbar compatibility

The first iPad invocation fails before List creation after 26.213 seconds. Its retained own-app hierarchies show that revealing the sidebar exposes a native More control. The next controller opens that menu but fails after 29.468 seconds because iPadOS exposes its CollectionView button as New List without the custom identifier.

The final controller opens a hittable native overflow only if the target is still absent after revealing the sidebar. Only for the New List overflow action, it then uses the exact observed menu label when the identifier is absent. The ordinary identifier path remains intact. The Mac estimate editor uses the existing platform-aware menu-item query. Neither failed invocation supplies shortcut-lifecycle pass credit, and neither finding requires a production change.

## Evidence and review

The run index separates the three passing function invocations, two failed iPad setup invocations and eight compiler-only attempts. The two final builds archive 945 source inputs each. Both final runtime invocations verify 469 source/configuration hashes and six product hashes before and after execution. These exact products match the final compiler epochs at this report's audit; later builds may replace the live products.

All six retained named Planner-window PNGs were individually inspected. Four belong to final-source invocations; two preserve the initial passing iPhone epoch. They show readable two-day Manual estimates and cleared zero-minute calculated estimates. Strict affected Swift lint, report Markdown lint and whitespace checks pass. Standards and Spec reviews have no remaining source/controller findings; their earlier menu-role and relaunch-precision findings are resolved.

[Measured draft resizing and creation compatibility](native-layout-compatibility.md) retains its own source epochs and represented platform outcomes. This List check supplies no new resize, Mac runtime, Item/Capture/Itinerary, signed account/CloudKit/Share, accessibility or performance qualification. Whole-app native SwiftUI polish follows feature completion. No Navigation prototype or map gate is closed.
