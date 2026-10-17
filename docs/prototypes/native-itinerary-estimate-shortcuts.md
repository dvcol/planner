# Native Itinerary estimate shortcuts

Status: simulator qualification passes on iPhone and iPad. Mac app/UI compilation passes; Mac runtime, Q94 label presentation and signing remain open.

## Context and starting state

The accepted fixed conversions are already implemented by the shared native editor. [Item](native-estimate-shortcuts.md) and [List](native-container-estimate-shortcuts.md) qualification does not qualify the Itinerary caller. The existing Itinerary estimate journey covers quantity changes, Cancel and clearing, without selecting the named shortcuts.

## Goal and expected end state

Create one empty Itinerary with Half-day as exactly 720 manual minutes and retained notes. Stage Full-day and Cancel without changing that saved value. Save Weekend as exactly 2,880 minutes; relaunch retains the Itinerary identity and two-day representation. Explicitly clear the manual value, Save and relaunch. The same Itinerary has zero calculated full/remaining time, the same notes and No items rather than completed progress.

## Definition of ready

The accepted conversions and container estimate lifecycle define literal outcomes. The existing approved production native UI boundary, disposable local dataset and relaunch provide the test seam. No public command, persistence schema, wire contract or production testing injection is introduced. This qualifies existing behavior, so it does not invent a missing-feature red. Q94 does not affect these estimate controls.

## Required tests and definition of done

- Select Half-day, Full-day and Weekend through the actual native menu. Verify 12 Hours, 1 Day and 2 Days in the editor.
- Verify 720 saved minutes survives Cancel; 2,880 saved full/remaining minutes survive relaunch with the same Itinerary identity and representation.
- Clear explicitly, Save and relaunch; verify zero calculated full/remaining minutes, retained notes and the empty progress state.
- Compile affected app/UI targets on both platforms, run strict affected Swift/report lint and native simulator journeys, inspect named Planner-window captures and retain literal source/product-bound outcomes.

The test helper shares the existing shortcut selector with its List caller using the same default List identifier prefix. Existing List results retain their original source epochs. Capture shortcuts, Mac runtime, physical/account/CloudKit/Share, accessibility, performance and whole-app polish remain separate gates.

## Recorded results

| Boundary | Result | Scope |
| --- | --- | --- |
| iPhone native journey | Pass, 107.400 seconds | One function, zero failures or skips; Half-day, staged Full-day cancellation, Weekend persistence and calculated reset through two relaunches. |
| iPad native journey | Pass, 110.220 seconds | The same function and literal expectations; zero failures or skips. |
| iOS Simulator app/UI compiler | Pass | The affected native app and UI target, selected Itinerary function. |
| Mac app/UI compiler | Pass | Compilation only; no new Mac runtime result. |

The frozen source and products match the builds for both native invocations. The packet records 945 compiler inputs per platform, 469 runtime inputs per invocation and six products per platform. The test change shares the existing shortcut selector without changing its List default. No production code changed in this slice. Unit and HTTP behavior did not change, so this slice adds no unit or HTTP test and claims no new result at either boundary.

All four named original Planner-window captures were opened individually. Both platforms show the saved two-day Manual estimate, then zero calculated full/remaining time with retained notes and No items. The iPad captures also show its separate detail column. These are functional observations, not whole-app visual acceptance, accessibility qualification or performance measurements.

## Evidence and remaining gates

[The evidence packet](evidence/navigation/native-itinerary-estimate-shortcuts/) contains literal run exits, compressed logs, input/product hashes, original named captures, source reviews and the bounded audit. Source reviews found no confirmed Standards or Spec issue; runtime credit comes only from the two completed native invocations. The audit verifies the exact current source and products before commit. Historical packets retain their own source epochs.

The earlier [rich draft resizing report](native-rich-draft-layout.md) retains the phone/tablet rotation, Save and relaunch qualification and its links to prior layout evidence. [Item shortcuts](native-estimate-shortcuts.md) and [List shortcuts](native-container-estimate-shortcuts.md) retain their separately qualified callers. This Itinerary result does not requalify those historical invocations against changed test source.

Capture shortcuts still need their own native journey. Q94 label navigation remains a separate pending presentation choice. Mac UI automation previously stopped before test discovery; a compiler pass does not close that gate. Physical devices, accounts, CloudKit convergence, Share, signing, accessibility and large-catalog retention/performance remain open. Whole-app native SwiftUI polish follows feature completion.
