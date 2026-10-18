# Native Settings and capture appearance checkpoint

Status: selected dark-mode phone/tablet journeys and mobile/Mac compilation pass. This is an interim checkpoint after the native sidebar/pane pass. Q98, the remaining feature work and final ticket 23 acceptance remain open.

## Context, starting state and goal

The recent native design pass qualified ordinary navigation, drafts and content panes, but did not inspect current Settings, Manage Labels or capture scenes. Those workflows must retain their saved-data behavior while following device appearance. The capture test still used phone tab queries on every iOS layout, even though regular iPad now uses the shared native sidebar.

Before: current-source dark-mode evidence for these scenes was missing, and the capture test could fail before reaching its editor on iPad. After: existing public native journeys exercise Settings/label identity, staged capture cancellation, saved capture content, and a saved Google Maps search-location card. Original captures distinguish native visual observations from behavior assertions. The capture controller uses the existing adaptive destination helper and records the actual staged editor before Cancel. Production code is unchanged.

## Readiness and test boundaries

Use the already agreed native UI seam and disposable local datasets. Existing domain commands create the data; assertions use actual controls and saved identities. No new production interface, fixture input, package, target or test-only option is introduced. Keep builds and runtimes serial, freeze Swift/configuration and compiled products during each run, and restore the Simulator appearance afterward.

Existing behavior assertions retain Cancel without saving, estimate shortcuts, notes and original link values, no invented schedule, source identity, and relaunch. The label journey retains canceled creation, shared identity across Settings/toolbar, rename and relaunch. These are compatibility/appearance checks, not new behavior TDD or physical sync evidence.

## Results and completion of this checkpoint

| Run | Executed outcome | Evidence |
| --- | --- | --- |
| Phone Settings/labels and capture baseline, dark | Both pass, 73.849 and 63.904 seconds | [Literal result](evidence/navigation/native-scene-appearance/phone-settings-capture-dark/exit.json) |
| iPad initial dark attempt | Capture fails before entering its editor, 6.938 seconds; Settings/labels passes, 67.978 seconds | [Aggregate remains failed](evidence/navigation/native-scene-appearance/tablet-settings-capture-dark/exit.json) |
| iPad adaptive capture and saved Google Maps card, dark | Both pass, 75.968 and 41.447 seconds | [Literal result](evidence/navigation/native-scene-appearance/tablet-capture-adaptive-dark/exit.json) |
| Phone adaptive capture and saved Google Maps card, dark | Both pass, 75.996 and 47.413 seconds | [Literal result](evidence/navigation/native-scene-appearance/phone-capture-adaptive-dark/exit.json) |
| Mobile test target compilation | Pass | [Compiler result](evidence/navigation/native-scene-appearance/capture-navigation-mobile-build/exit.json) |
| Mac test target compilation, local ad hoc signing | Pass, compiler evidence only | [Compiler result](evidence/navigation/native-scene-appearance/capture-navigation-mac-build/exit.json) |

The [controller review](evidence/navigation/native-scene-appearance/capture-navigation-review.json) retains the failing query, inspected recording limitation and adaptive correction. The original automatically attached hierarchy is a startup snapshot, not a failure-point hierarchy. No capture product-red credit is assigned to that attempt. The Settings function and production source are unchanged between their baseline and final capture epochs, so the passing Settings evidence is retained without rerunning it solely for a capture-test recorder change.

The [executed function record](evidence/navigation/native-scene-appearance/results.json), [source review](evidence/navigation/native-scene-appearance/source-review.json) and [inspected capture record](evidence/navigation/native-scene-appearance/visual-review.json) state their actual scopes. Both form factors restore and verify their initial light appearance after the dark-mode runs. Affected strict Swift and Markdown lint supply the checkpoint's remaining local checks. No signing-account or permission settings change.

## Inspected scene observations

- Settings and Manage Labels use native dark Form surfaces and readable actions. Labels retain separate Categories/Tags sections and an empty Category state. The iPad keeps its underlying native sidebar.
- Review Capture retains native Cancel/Add, staged text, estimate shortcuts, Toggle, unit Picker and Stepper. The selected 12-hour value is shown before cancellation; saved content separately retains the reviewed two-day estimate and exact notes/link.
- The saved Maps link shows an embedded native dark map with a search-location pin. This demonstrates the accepted temporary link preview, not a resolved business or saved provider coordinates. The original bookmark survives relaunch.
- The phone's ordinary website preview was unavailable in one inspected run. The owned link, notes, estimate and Retry action remained visible. This is an observed live fallback, not a controlled provider-error test.

## Remaining work

The Maps caption uses technical intent/resolution wording. Selected Item-row secondary metadata appears pale against the blue selection; automated contrast evidence is still needed before calling that a defect. At one phone scroll position, the floating bottom bar overlays part of the map caption. The journey separately reaches the original link, but whole-screen readability and large-text/scroll acceptance remain open.

This checkpoint does not qualify every scene/state, native Share execution, landscape/split widths, maximum text, quantitative contrast, hit targets, VoiceOver, keyboard use, Reduce Motion/Transparency, Mac runtime, physical devices or sync/recovery. Mac compilation supplies no runtime credit. It does not close the final [UI polish](../native-ui-polish.md) ticket or the overall map.
