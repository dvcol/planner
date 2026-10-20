# Native Mac checks after session refresh

Status: Mac execution is restored. Original-association Undo, filtered-selection Undo and the corrected draft-resizing journey pass at their recorded source epochs. This does not close the Navigation prototype or whole-app acceptance.

## Context, starting state and goal

Mac app-hosted XCTest repeatedly stopped in IDE-session setup before entering a test, while the native UI runner also had automation-startup failures. A narrowly scoped user-broker restart was denied by macOS. The user then confirms a refreshed Mac session and Xcode open. Signing and account setup remain deferred.

The approved existing public boundaries are production Intent invocation with real storage under Q112 A and actual native UI journeys. Retry the unchanged startup control, then qualify the previously unavailable native Undo/window/text behavior and represented draft resizing. Use disposable local datasets, existing shared schemes and the existing local ad hoc build configuration. No test hooks, replacement services, team, entitlement or security changes are added.

## Environment and results

Observed environment is macOS 27.0.1 on arm64 and Xcode 27.1, build 27A9275. Source snapshots, commands, original logs and exits are retained in each linked packet.

| Check | Outcome | Evidence |
| --- | --- | --- |
| Unchanged Archive and invalid-creation/missing-read startup control | Both pass, 0.133 and 0.017 s | [Prebuilt session-refresh retry](evidence/navigation/native-itinerary-window-compatibility/app-intent-archive-session-refresh/) |
| Mac association Undo, ordinary text Undo, other-window isolation and relaunch | Pass, 70.244 s | [Native Undo journey](evidence/navigation/native-itinerary-window-compatibility/mac-association-undo-after-session-refresh/) |
| Undo while Todo filtering hides the restored Done row, preserving another selected appearance | Pass, 93.324 s | [Two-function batch](evidence/navigation/native-itinerary-window-compatibility/mac-filter-selection-layout-after-session-refresh/) |
| Original draft-resizing caller in that batch | Fails, 74.684 s, at its duration Picker label assertion | Same batch; the overall batch remains failed |
| Focused Picker observation | Fails, 65.503 s, recording an empty label and selected value Hours | [Actual accessibility observation](evidence/navigation/native-itinerary-window-compatibility/mac-draft-unit-accessibility-observation/) |
| Corrected full draft-resizing journey | Pass, 146.413 s, zero failures or skips | [Mac resize qualification](evidence/navigation/native-itinerary-window-compatibility/mac-draft-resize-picker-correction/) |

The [text Undo report](native-association-text-undo.md#mac-qualification-after-session-refresh) describes the passing window/text/restoration sequence. The filtered journey retains the original restored membership identity and local Done after clearing the filter and relaunching. Its original named own-app capture was inspected and shows 1 of 2 progress, Showing 1 of 2 items and the selected Hotel's retained notes. This does not turn the failed two-function invocation into a passing batch.

## Resize diagnosis and correction

The original caller reads the duration Picker's label and requires Hours. A diagnostic invocation records its actual native label as empty and its value as Hours. The local recording independently shows Hours and quantity 12 after narrowing. The existing capture controller already uses the selected native value on Mac and the label on mobile.

Apply that same platform distinction in the existing `assertNewItemFields` UI helper. Keep the unchanged exact 12-hour, source identity, rich-field, destination, Save, other-List and relaunch expectations. No production duration editor, persistence or draft-navigation behavior is changed. The temporary diagnostic message is removed from the current test source; its original failed-run evidence remains retained.

The corrected journey reaches actual 860-point and 1200-point window widths, toggles the sidebar, verifies all draft fields and the exact 12-hour estimate, then saves into the original List. Relaunch retains the original List and new membership identities, source content, owned location, bookmark identity and estimate. The other List stays empty and the global catalog contains one shared Item. Both original resize captures were inspected; the draft fields remain readable on native dark surfaces, with truncated sidebar summaries. Four named originals across these Mac journeys were inspected in total.

Only named own-app screenshots are published. Full-display diagnostic recordings remain local, rather than publishing unrelated applications visible behind a narrow Planner window.

## Limits and remaining gates

Session refresh is followed by successful test execution; these runs do not establish the underlying cause of the earlier startup waits. Durations are XCTest journey timings, not application latency or physical-device measurements. Every result retains its actual source epoch.

Other native scenes, Mac keyboard/accessibility coverage, physical devices, installed Share, shared/account-bound storage, managed CloudKit, system Intents and Q100 B's signed Agent Control/reader/client qualification retain their separate map gates. The user defers whole-app UI polish until features are complete. No overall Navigation or map completion is claimed.
