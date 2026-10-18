# Native globally finished unknown estimates

Status: the represented global-Done/manual-budget journey passes on phone and iPad. Production estimate and completion behavior remain unchanged.

## Context, goal and starting state

The [accepted Q76 fixtures](../container-estimates-and-calendar.md) require missing-finished-estimate coverage for local Done, archive retirement and global Done. The [archive qualification](native-container-estimate-archive.md) supplies the first two native paths. Global completion takes precedence over retained local flags, so reopening a source must reveal those flags without copying global Done into them.

The goal is to verify the remaining global-Done path through ordinary source Item controls and live manual List/Itinerary budgets. Existing public native UI journeys remain the approved test boundary. No new controller/unit seam, fixture injection, package, target or production callback is proposed.

## Ready fixture and required outcomes

Museum has a 120-minute estimate. Lunch has no estimate and is completed globally in its Item details. Morning has a manual 240-minute total and references both Items. An Itinerary references Morning through one live List entry. New memberships/appearances retain local Todo.

- List and Itinerary show full 240 and up to 240 remaining, with one missing finished estimate. Lunch displays Done through source precedence.
- Globally reopen Lunch. Both Itinerary appearances display Todo and remaining becomes 240. Identities and the manual full total remain unchanged.
- Give Lunch a 60-minute estimate through its native editor and complete it globally. List and Itinerary remaining become 180, without the missing-finished warning.
- Complete only Museum's Itinerary appearance. The Itinerary becomes fully finished with zero remaining and full 240 retained. Its standalone List still has 180 remaining and Museum Todo.
- Relaunch and require the same membership/appearance identities, scoped states, manual total and distinct remaining values.

## Definition of done and limits

Run the new journey on phone and iPad, inspect actual original captures, retain any failed attempts, and qualify affected Swift/Markdown lint and both compiler targets. Observe results through native controls rather than private model/database state. Any production correction requires its failing native observation first. This does not establish whole-app accessibility/visual review, physical performance, actual Mac runtime, signing or CloudKit/Share behavior. Pending Q108/Q109/Q110 remain independent.

## Executed results

The unchanged `SavedContainerEstimateJourneyTests.testGlobalUnknownEstimateKeepsManualBudgetsAndRevealsRetainedLocalStatesAfterReopening` passes on both simulators on its first execution. No test-driver or production correction was needed for this slice.

| Destination and appearance | Functions | Result | Duration |
| --- | --- | --- | --- |
| iPhone, light | One | Pass, zero failures | 178.307 s |
| iPad, dark with Increase Contrast | One | Pass, zero failures | 185.473 s |

Each invocation executes the upper-bound, global-reopen, known 60-minute estimate, 180-minute remainder, all-finished zero and relaunch/identity assertions above. The four-hour manual List total is retained. Completing Museum only in the Itinerary leaves its standalone membership Todo and three hours remaining there, including after relaunch. These durations measure the complete native workflow, not physical input latency. Simulator appearance/contrast settings are restored afterward.

Both the mobile and existing local ad hoc Mac app/UI-host compiler checks pass. All 149 production Swift inputs match across the four evidence epochs. Only a new native test function is added; existing helpers and production behavior remain unchanged from the archive checkpoint. No Core/MCP rerun or new test seam is needed for that test-only addition. Affected strict Swift/Markdown lint, whitespace and local links pass. The bounded credential-pattern scan reports zero findings.

## Evidence and inspected originals

The [observed-results index](evidence/navigation/native-container-estimate-global/final-validation/observed-results.json) retains both compiler and both runtime results. The [production-source comparison](evidence/navigation/native-container-estimate-global/final-validation/production-source-comparison.json) and [manifest](evidence/navigation/native-container-estimate-global/final-validation/evidence-sha256.json) retain source/product attribution and file hashes.

All eight original journey captures were inspected and recorded in the [visual review](evidence/navigation/native-container-estimate-global/final-validation/visual-review.json). The [light phone upper bound](evidence/navigation/native-itinerary-window-compatibility/phone-global-budget-first/1A3D9722-396D-4CE2-B1DD-9F57EACE3058.png) and [dark iPad upper bound](evidence/navigation/native-itinerary-window-compatibility/tablet-global-budget-first/05BCA5BB-362E-4F1F-8564-BFADF8B38C26.png) show the missing-finished warning and shared-source Done precedence. The reopen captures show both appearances Todo, four hours remaining and no missing-finished warning. Final Itinerary captures show zero remaining while preserving its four-hour full budget. The [phone standalone List](evidence/navigation/native-itinerary-window-compatibility/phone-global-budget-first/CC0C95D1-1B4C-4273-8B76-2333B0074859.png) and [iPad standalone List](evidence/navigation/native-itinerary-window-compatibility/tablet-global-budget-first/F56A408D-C84A-48F4-A9BA-1C5854521113.png) after relaunch retain the separate one-of-two completion and three-hour remainder.

Native disabled controls and the crowded phone inline title do not receive readability acceptance from these functional assertions. The iPad's empty detail is intentional. No rendered contrast audit, VoiceOver/keyboard, maximum-text, complete scene or physical/Mac runtime acceptance is added. Together with the earlier local-Done and archive reports, this supplies the represented mobile Q76 paths while preserving the broader map gates.
