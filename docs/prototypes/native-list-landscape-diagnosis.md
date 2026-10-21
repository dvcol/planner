# Landscape List-loading diagnosis

## Context, starting state and goal

The ordinary phone resizing regression stalls after creating its first List in landscape. The actual screen shows Opening List; the native UI query cannot find No items. This blocks the local navigation qualification and must be fixed before the handoff feature is treated as qualified.

The same reduced public UI journey fails on committed production code at 5baa1b79, with only the new UI test overlaid. Its original App, SavedPlannerView and project bytes were independently compared with HEAD. The directed-window feature is absent from that baseline. Both runs exceed the explicit two-minute test allowance. The first larger journey was interrupted after recording the same stalled screen and timed-out accessibility query.

## Definition of ready and test boundary

Use the existing approved native UI seam and disposable local prototype dataset. The reduced journey is SavedAppearanceJourneyTests/testCreatingFirstListInLandscapeLoadsItsContents, driven by the retained PlannerOpeningUIQualification runner. It launches landscape, creates one List through the real form and requires its No items content to appear. No private-helper unit test, production injection point, new target or signing change is needed.

A three-second sample of the exact simulator test app records 98.8% CPU and main-thread SwiftUI/AttributeGraph preference/layout work. This distinguishes the visible loop from a merely slow UI assertion; it does not prove a particular cause.

## Hypotheses and isolated probes

The initial new-wrapper and value-backed-window hypotheses are contradicted by the committed-base reproduction. Existing landscape navigation remains the relevant path.

| Probe | Prediction | Observed result |
| --- | --- | --- |
| Defer creation selection until sheet onDismiss | If creation-sheet dismissal competes with selecting the List, selection after native dismissal should load normally. | Failed on committed base plus only this patch. Same spinner and roughly one CPU core. The patch was reverted. |
| Keep native content title and inline toolbar mode during loading | Stable loading chrome should allow content to load if that transition causes the loop. | Failed; reverted. |
| Use the ordinary row-selection binding after creation | Its native column-visibility transition should avoid an inconsistent programmatic selection. | Failed; reverted. |
| Remove shared compact-column input from inactive Item/Inbox splits | If hidden splits are feeding back into the same state, removing that coupling should stop it. | Failed; reverted. |
| Omit the disabled Undo tab accessory | If the empty accessory causes bar-preference updates, its absence should stop the loop. | Failed; reverted. |
| Replace automatic overflow with a standard native More menu | If automatic overflow is cycling, the same actions in a fixed Menu should load. | Failed; reverted. |
| Reduce loaded empty-state content to Text, preserving toolbar/search | Distinguish content layout from navigation chrome. | Passed in 16.282 seconds. Diagnostic reduction only; full content restored afterward. |
| Keep complete content inside native ScrollView | Give the empty-state header and unavailable view a scrolling context in a short viewport. | Passed in 16.289 seconds on committed base plus only this patch, with original toolbar/search and no diagnostic logging. |

Tagged loading/lifecycle instrumentation records one real load reaching ready, without repeated column writes. The reduction also records compact horizontal size class, no cancellation and unchanged query inputs. It does not identify a private framework algorithm. All temporary logging was removed.

Each probe keeps the exact same UI scenario. The runner retains the baseline, patch, actual patched source, hashes, command and original result. Failed probes remain failed.

## Required completion and other checks

Identify and remove the reproduced cause, then pass the reduced journey and original Save/Discard/Keep editing/resizing journeys on phone and tablet. Preserve typed identities, completion scopes, moving-window semantics, source data and native controls. Run affected formatting/type checks, record actual captures and remove disproved production changes and temporary instrumentation. Actual Mac, system and physical gates remain separate. The full-content landscape capture was visually inspected: the native title, Estimate, Remaining, No items and existing toolbar/tab controls are visible. In the full handoff working tree, the strengthened landscape case also passes with both metric identifiers present; the Save/Discard/Keep editing journey passes too. That three-case invocation still fails overall because its rich-draft case was actively progressing at 119.9 seconds when the diagnostic two-minute allowance stopped it. With a five-minute allowance, the full rich-draft phone journey passes in 243.849 seconds. The dark iPad landscape and rich-draft cases pass in 23.169 and 206.409 seconds. The separately corrected iPad draft-decision controller passes in 90.703 seconds. Its earlier failures were missing native sidebar navigation and an overlay blocking keyboard focus, not failures of the three displayed draft choices. The original failed invocations remain failed. Broader platform checks remain open; no map issue is closed.

## Inspected native captures

The original [dark iPad empty List](evidence/navigation/native-itinerary-window-compatibility/native-plan-opening-tablet-dark-final/1B9E1DD6-19B6-4AD8-B31C-7DD72BF24EE0.png) shows the List title, both estimate metrics and No items in the content column. The original [dark iPad draft decision](evidence/navigation/native-itinerary-window-compatibility/native-plan-opening-tablet-draft-final/E4F7CD29-583A-431D-A08A-F9784F10B014.png) shows Save, Discard and Keep editing together in the native popover. The [rich iPad editor](evidence/navigation/native-itinerary-window-compatibility/native-plan-opening-tablet-dark-final/263CA6A7-2AF7-478E-82CE-B5363D87D7A4.png) retains its location, address and bookmark fields alongside the originating List. The [landscape phone editor](evidence/navigation/native-itinerary-window-compatibility/native-plan-opening-phone-rich-final/38BDA34F-5E1F-4102-B7F3-EFA93A354EDC.png) retains those fields and native Save/Back controls. Its floating bottom tabs still cover part of the form at this scroll position. That existing readability concern remains on the final polish inventory; passing draft persistence does not resolve it.

## Final assembly cleanup follow-up

The final assembly run reaches No items and both metric assertions and records its landscape capture in 19.99 seconds. It then exceeds the two-minute allowance while resetting orientation in teardown. The owned app uses 0% observed CPU, and a bounded process sample shows its main thread waiting in the UIKit event loop. This is distinct from the earlier 98.8% layout loop, but it does not establish a framework cause. The invocation remains failed. An isolated cleanup probe terminates only its own disposable app before resetting device orientation. That rerun also reaches every app assertion and records a capture in 18.43 seconds, closes Planner, and then times out waiting for SpringBoard to idle during the orientation reset. It remains failed and does not qualify the cleanup change. The unsuccessful cleanup experiment is reverted; no framework cause is assumed. The rich-draft journeys retain their earlier passing actual in-app orientation transitions.
