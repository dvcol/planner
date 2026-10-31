# Native estimate shortcuts

Status: implemented; iPhone/iPad qualification passes. Mac app/UI compilation passes, but Mac runtime remains open after two automation-startup failures. Developer-account signing remains deferred.

## Context and starting state

The accepted [duration record](../duration-and-search.md) defines Half-day as 720 minutes, Full-day as 1,440 minutes and Weekend as 2,880 minutes. The shared native estimate editor exposes positive quantity/unit controls and explicit clearing, but none of these named shortcuts. New Item, Edit Item, List, Itinerary and Capture all use that editor.

## Goal and expected end state

Choose a named estimate through a native menu without typing a duration. Half-day displays 12 hours, Full-day displays 1 day and Weekend displays 2 days. The selected estimate remains a draft until Save. Cancel retains the previous saved value. Clearing removes the estimate only after Save, and relaunch preserves the source identity and saved result. Estimates never create schedules.

## Definition of ready

The map's accepted fixed conversions and the existing approved production native UI boundary supply the inputs and observable outcomes. No new public Core command, storage schema, wire contract or test-only production seam is required. Local simulator datasets and local ad hoc Mac tests need no developer-account signing.

## Required tests and definition of done

- Through the real New Item editor, choose Half-day and save exactly 720 minutes.
- Stage Full-day in Edit Item, then Cancel. Retain 720 minutes.
- Save Full-day as exactly 1,440 minutes and Weekend as exactly 2,880 minutes, using native quantity/unit controls for their displayed representation.
- Relaunch and retain the one Item, its identity and 2-day estimate. Clear explicitly, save, relaunch and retain No estimate without a Schedule.
- Run the affected native journey on iPhone, iPad and Mac, plus the existing remainder/unit-change compatibility checks where affected. Inspect named Planner-window images, compile both platform app/UI targets and lint changed Swift and report files.

The first test run must witness the missing native shortcut control before adding it. Record literal attempts and results here. This slice supplies no physical-device, CloudKit, accessibility, latency or whole-app polish qualification. The separate creation-destination and labels gates remain open.

## Execution so far

The iPhone red invocation fails in 22.399 seconds at the absent `saved.item.estimate.shortcuts` control. The initial implementation then compiles for both platforms. Its first iPhone invocation fails in 21.734 seconds after tapping the new menu: the own-app hierarchy contains Quick estimate, no shortcut choices and a still-focused title field. This does not establish why the menu closed or failed to open.

The next controller submits the single-line title with native Return on iOS before opening the menu and verifies its exact text. It queries Toggle, Stepper and summary elements through their actual accessibility types rather than treating them as Buttons. Review also finds that the old shared navigation helper targets prototype identifiers on Mac; the estimate journeys now use the existing saved-data sidebar identity there. These controller corrections supply no pass credit by themselves.

Return alone does not fix menu activation: that attempt fails in 22.026 seconds. The own-app hierarchy no longer contains the focused keyboard, but ordinary center activation still produces no choices. A StaticText-child probe fails before activation in 22.939 seconds because that child is not independently hittable. Activating the measured leading label then opens the menu, saves 720 minutes, preserves it after cancelling a Full-day edit, and saves Full-day. Its whole function still fails in 55.352 seconds because the test expects `1440 minutes` while the native accessibility value is `1 440 minutes`. The saved detail explicitly shows 1 day; this is a grouping mismatch, not a different duration.

The native Menu now uses a Label that fills the row with a rectangular hit area. The final test returns to ordinary Button activation, without coordinate workarounds. Literal 1,440/2,880-minute assertions permit an optional native whitespace/comma grouping separator. The unit-change handler reads the current bound estimate when changing representation so a shortcut's new minutes are preserved. No Core or wire behavior changes.

## Qualified results and remaining gates

| Platform | Shortcuts, Cancel, clear and relaunch | Remainder/unit compatibility | Year/month compatibility | Whole invocation |
| --- | --- | --- | --- | --- |
| iPhone 18 Pro Simulator, iOS 27.0 | 106.989 s | 105.269 s | 77.886 s | Pass, 3 functions, 0 failures/skips |
| iPad Air 11-inch (M4) Simulator, iOS 27.0 | 113.483 s | 105.602 s | 80.095 s | Pass, 3 functions, 0 failures/skips |
| Native Mac, local ad hoc signing | Not started | Not started | Not started | Two runner initialization failures, 0 executed functions |

Both final app/UI-target compiler checks pass using Xcode 27.1. Each archives 945 source/configuration/resource inputs. The two passing runtime invocations use identical current source, freeze 469 source/configuration inputs and verify six product hashes before and after execution. Strict lint passes the two affected Swift files. Independent Standards and Spec reviews report no remaining confirmed source findings after correcting Mac saved-data navigation. These source reviews do not replace missing Mac runtime.

All eleven retained named Planner-window PNGs were individually inspected. Ten belong to the passing phone/tablet functions. The earlier leading-label probe contributes one diagnostic image without function-pass credit. They show readable native controls, the exact displayed remainder and the saved 2-day Weekend estimate. The iPad year image retains the keyboard while its tested controls remain visible. These observations do not qualify accessibility or whole-app polish.

Both Mac attempts fail with `Timed out while enabling automation mode` before any function starts. Unchanged app/test-runner signatures verify locally. The read-only console registry reports an on-console, logged-in session but no lock-state field; it does not prove an unlocked screen. No automation permission, security setting or developer-account signing change is made. Mac runtime remains required, with no application assertion or pass inferred from these setup failures.

The evidence packet retains literal commands, results, source/product hashes, original named images and failed attempts. Its run index keeps compiler success, individual results and whole-invocation outcomes separate.

List, Itinerary and Capture compile with the same shared editor, but this slice adds no runtime credit for their estimate controls. No new Core unit or HTTP test is needed for this view-only change; their public contracts and persistence behavior are unchanged. Other native field/destination scenarios, Mac runtime, physical/account/CloudKit/Share, accessibility, performance and whole-app polish retain their gates. No feature-wide or map gate is closed.
