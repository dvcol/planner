# Native archived-Item manual budget qualification

Status: the focused archive/manual-branch journey passes on phone and iPad. The affected existing local-completion regression passes against the final test source. Production estimate and archive behavior remain unchanged.

## Context, goal and starting state

The [accepted estimate fixtures](../container-estimates-and-calendar.md) require Q76's missing-finished-estimate warning for local Done, global Done and archive retirement, including partial manual List branches in an Itinerary. Earlier native journeys qualify local Done and independently completed repeated branches. The [estimate report](native-container-estimates.md) retains further archive/uncertainty UI fixtures as open work.

This slice exercises archive retirement of an unknown-duration Item inside a partial manual branch. The expected end state is truthful upper-bound text, whole-branch budget retirement once its children finish, and restored local states after unarchive/relaunch. A separate direct appearance must retain its own completion and budget. This is behavior qualification before final whole-app polish.

## Readiness and required tests

Use the already accepted public native UI seam with ordinary saved data and no fixture injection, new target or production callbacks. The test's native controller reuses the current phone-tab/iPad-sidebar navigation helper. Pending Q108/Q109/Q110 concern different Undo work and do not alter this seam.

Create Museum with 120 minutes, Lunch with no estimate and Morning with a manual 240-minute total. The Itinerary contains Morning and a separate direct Museum. Every local/global Done flag starts false.

- Initially the branch has full/remaining 240; the Itinerary has full/remaining 360.
- Archive Lunch through its shared Item details. Its global Done remains false. The branch shows up to 240 remaining and the Itinerary up to 360, each with one missing finished estimate. Progress is one of three finished, distinguished as Archived.
- Complete only the branch's Museum. Its whole 240-minute budget retires; the direct Museum stays Todo and the Itinerary has 120 remaining. Full estimate remains 360.
- Relaunch and require the same branch identity, local completion and remaining values.
- Unarchive Lunch through its source details. The original three appearances return with local states Done, Todo, Todo. The branch has 120 remaining, Itinerary 240 and full estimate 360. Archive has not rewritten Lunch's global Done.

Run the new journey on phone and iPad and an affected existing local-completion estimate journey after the controller update. Inspect actual captures; record failed attempts and exact source epochs. Compile both platforms and run affected strict Swift/Markdown lint. No new Core/MCP test or unit test for SwiftUI structure is needed for this test-only slice.

## Definition of done and limits

Publish exact executed outcomes, source/product hashes, inspected originals and any correction. A failing controller or product assertion remains a failure until resolved and rerun. This slice does not establish the separate global-Done unknown-estimate fixture, whole-app visual/accessibility acceptance, Mac runtime, physical performance, signing or CloudKit/Share behavior.

## Executed archive journey

`SavedContainerEstimateJourneyTests.testArchivedUnknownEstimateKeepsItsManualBranchBudgetAndRestoresLocalStateAfterRelaunch` passes in 190.377 seconds on dark iPhone and 198.008 seconds on light iPad. Both invocations execute the complete numeric, progress, identity, retained global Todo, relaunch and unarchive assertions above. The first retirement uses Active filtering, hiding Lunch while preserving the full denominator. No production correction was necessary.

Two first attempts remain failed evidence. Phone stops in 113.617 seconds because the controller looks for a catalog row while its remembered Lunch detail is open. iPad stops in 136.877 seconds because the older catalog helper does not recognize the Itinerary's native Back identifier. The exported hierarchies identify those actual scenes. Neither attempt establishes the post-archive budget. The corrected controller uses the existing adaptive section helper and visible native Back controls, then runs unchanged on both platforms. It introduces no production test hook.

The first affected local-completion regression also fails, in 41.415 seconds before its budget assertions. Its older helper tries to open a nonexistent phone sidebar while New List is available through toolbar overflow. The final helper checks actual visible Back/Sidebar controls and leaves overflow handling to the existing caller. Final-source reruns of both callers follow this test-only correction; the earlier passing archive epochs keep their own test hashes.

All three mobile and both Mac app/UI-host compiler epochs pass. Mac uses the existing local ad hoc settings and has no runtime credit. The actual Simulator appearance/contrast settings are restored after every invocation.

| Final source and invocation | Function | Result | Duration |
| --- | --- | --- | --- |
| Dark iPhone | New archive/manual-branch journey | Pass | 188.823 s |
| Same iPhone bundle | Existing missing-finished local-completion regression | Pass | 122.749 s |
| Light iPad | New archive/manual-branch journey | Pass | 198.330 s |

The whole final phone bundle passes both functions in 311.572 seconds, with zero failures. The final iPad bundle passes its one function with zero failures. These are functional execution durations, not physical responsiveness measurements. The existing regression still shows an exceeded manual total with unfinished progress, resolves the missing finished estimate through the Item editor, and finishes with zero remaining without clearing the manual total. Affected strict Swift/Markdown lint, whitespace and local-link checks pass. The bounded credential-pattern scan has zero findings.

## Evidence and visual review

The [observed results](evidence/navigation/native-container-estimate-archive/final-validation/observed-results.json) retain the failed attempts and final executions. The [production-source comparison](evidence/navigation/native-container-estimate-archive/final-validation/production-source-comparison.json) verifies all 149 production Swift inputs are unchanged across these epochs; test sources retain their actual diagnostic/final hashes. The [evidence manifest](evidence/navigation/native-container-estimate-archive/final-validation/evidence-sha256.json) binds the archived files.

Twelve original archive-journey captures across the diagnostic/final source epochs and two final existing-regression captures were inspected and recorded in the [visual review](evidence/navigation/native-container-estimate-archive/final-validation/visual-review.json). The final-source [dark phone upper bound](evidence/navigation/native-itinerary-window-compatibility/phone-archive-budget-final/1B0BE78F-B7DD-4DEB-9645-7586EDDF5D14.png) and [light iPad upper bound](evidence/navigation/native-itinerary-window-compatibility/tablet-archive-budget-final/0654E859-BED1-4F41-956C-D5C551A2CA74.png) show six hours full, up to six remaining, and the partial four-hour manual branch. The finished-branch captures show its zero remaining and the direct Museum's two hours. Unarchive captures show the original Done/Todo/Todo appearances and restored four-hour root remaining. The report does not claim that every exported existing-regression attachment was visually reviewed.

The phone's scrolled title and bottom content pass beneath floating native controls in some captures. They retain the existing scroll-edge/readability finding, rather than establishing full clearance. iPad's empty detail pane is intentional because this journey selects no Item. No rendered contrast audit, VoiceOver, keyboard or complete visual acceptance is added by these budget assertions.
