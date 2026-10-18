# Native text Undo beside association history

Status: the represented phone/iPad text-Undo and explicit removal-Undo journey passes. Q108's direct history-controller test proposal remains unanswered and is not used here. Production behavior is unchanged.

## Context, goal and starting state

Q107 accepts native removal Undo while preserving ordinary text-field Undo. Existing phone/iPad journeys restore associations through the explicit native action. The existing Mac journey also declares text/window checks, but its current automation-startup failure supplies no executed text-Undo proof.

This slice uses the already approved public native UI seam. It exercises an unsaved Item title while a completed membership's removal remains available for Undo. The goal is to prove that text Undo changes the draft text, leaves the relationship removed, and keeps the separate association action usable afterward.

## Readiness and required outcomes

Create a shared Item and a List membership through ordinary controls, complete the membership locally, then remove it. Retain its original appearance identity and require No items plus the explicit association Undo action.

Open New Item from that List, type one word as a single typing action, invoke the system text-editing Undo control, and require an empty title. Cancel the unsaved editor, require the List still empty, then use its explicit Undo removal action. It must restore the original membership identity and local Done state. The canceled draft creates no row. Relaunch retains the restored identity/state and expires the old removal history.

Apple's [text-editing guide](https://support.apple.com/guide/iphone/select-edit-and-move-text-iph1a9cae52c/27/ios/27) describes system Undo. XCTest exposes a [multiple-touch tap](https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap(withnumberoftaps:numberoftouches:)) in the installed SDK. The actual run must establish the available native editing control; these API references alone do not prove that its gesture or action works in Planner.

## Definition of done and limits

Run on phone and iPad with disposable local data, record the actual system control and results, inspect original captures, and retain failures. A new production behavior correction requires its failing observation first. Compile affected targets and run strict Swift/Markdown lint. Do not add a controller seam, injected UndoManager, fabricated snapshot or production callback. This does not qualify actual Mac text/window behavior, per-window isolation, asynchronous retry, physical devices or whole-app accessibility acceptance.

## Initial executed observations

The first phone invocation fails in 179.754 seconds and the first iPad invocation in 187.797 seconds. Both reach the typed draft and open the system editing overlay. Their exported native hierarchies contain `UIUndoInteractiveHUD`, with a labeled Undo action exposed as an Other element. The controller incorrectly queries a Button, so neither invocation executes text Undo or proves its result.

The corrected controller scopes its action to that actual editing overlay, using its observed Undo label. It captures the system control before invoking it. The fixture uses the single word Temporary to keep the typing action unambiguous. No production behavior or test seam changes. The normal system text-editing overlay may show text Redo; Planner still supplies no association Redo in this slice.

The second phone invocation fails in 180.959 seconds and the second iPad invocation in 192.756 seconds. Both successfully execute system text Undo and require the title to be empty, but their whole journeys still fail. Phone's compact editor exposes Back rather than Cancel. The iPad capture and hierarchy show the persistent system editing overlay covering Cancel, so that tap does not exit the editor. These are partial observations, not passing restoration qualification.

The final controller dismisses the editing overlay by tapping the native title field, requires it to disappear, then uses the existing adaptive Back/Cancel helper. Association restoration and relaunch assertions remain unchanged. The four original second-attempt captures were inspected directly; they show the typed title, empty title after native Undo, and the separate removal action still visible. They do not prove the later restoration.

## Final executed results

`SavedAppearanceJourneyTests.testNativeTextUndoPreservesTheSeparateRemovedMembershipAction` passes against the same final source on both simulators.

| Destination and appearance | Functions | Result | Duration |
| --- | --- | --- | --- |
| iPhone, dark | One | Pass, zero failures | 204.823 s |
| iPad, light | One | Pass, zero failures | 213.377 s |

Both final invocations execute the system editing action, require the empty title, dismiss the overlay, close the unsaved editor and require the original membership still absent. The explicit association action then restores that original appearance identity and Done state. Relaunch retains the same completed appearance and expires the old Undo action. Native elapsed times are functional execution evidence, not physical responsiveness measurements. Simulator appearance/contrast settings are restored after each invocation.

All four mobile and both existing local ad hoc Mac compiler epochs pass. The intermediate compiler results supply no runtime credit. No actual Mac UI function executes in this slice. Affected strict Swift/Markdown lint, whitespace, local links and the bounded credential-pattern scan pass. No new Core/MCP run is needed for a test-only function and report; their production inputs remain unchanged.

## Evidence and visual review

The [observed-results index](evidence/navigation/native-association-text-undo/final-validation/observed-results.json) retains all twelve build/runtime epochs, including the four failed whole journeys. The [production-source comparison](evidence/navigation/native-association-text-undo/final-validation/production-source-comparison.json) verifies all 149 production Swift inputs match across those epochs. Test-source comparisons distinguish the diagnostic controllers from the final code. The [manifest](evidence/navigation/native-association-text-undo/final-validation/evidence-sha256.json) binds the evidence files.

Ten original captures were inspected and recorded with hashes in the [visual review](evidence/navigation/native-association-text-undo/final-validation/visual-review.json). The final [phone editing overlay](evidence/navigation/native-itinerary-window-compatibility/phone-text-undo-final/473392F0-E2A3-4F9E-A2A4-87FBEA1C21B1.png) and [iPad editing overlay](evidence/navigation/native-itinerary-window-compatibility/tablet-text-undo-final/FFAD1EC5-7953-4901-BCAC-3990864EAA9C.png) show the native text action separately from Undo Remove from List. Their empty-title captures show normal text Redo enabled. Final [phone restoration](evidence/navigation/native-itinerary-window-compatibility/phone-text-undo-final/FBA3445F-3432-4609-8C40-E7F69793CD80.png) and [iPad restoration](evidence/navigation/native-itinerary-window-compatibility/tablet-text-undo-final/4F6677B1-6168-4990-8D81-E81351A1550B.png) show the restored completed Item with the draft gone.

Phone form content passes behind the floating removal action and tabs in these captures. That retains the broader scroll-clearance/readability review; this test adds no rendered contrast, keyboard-clearance or whole-app visual acceptance. The iPad's empty detail after closing the draft is intentional.

## Remaining acceptance

This proves the represented mobile workflow using actual system text Undo and the explicit association action. It does not prove standard Mac Edit Undo registration after text-editor dismissal, per-window isolation, asynchronous queue/retry outcomes or all native editing controls. Q108 remains a separate proposed test boundary. Actual Mac runtime, physical devices, signing and final whole-app review retain their existing gates. No association Redo or owned-association/Move semantics are added.
