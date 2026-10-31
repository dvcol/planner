# Native whole-Move Undo

Status: the represented whole-Move journey passes on dark iPhone and light
iPad. The [27 October Mac follow-up][mac-undo] also qualifies native keyboard
Undo and relaunch. Earlier controller/HTTP results retain their recorded
scope. Other variants and whole-app acceptance remain open.

## Context, goal and starting state

The [Core Move inverse](core-move-undo.md) implements Q109 A and the [Q111 contract](../native-compound-association-undo-contract-review.md), including atomic destination reversal and preservation of newer work. The native Move caller still discards its operation companion through a Boolean response, so it cannot register the accepted per-window Undo action.

The goal is to carry the truthful operation response through the existing Move form to window history, preserve its dataset binding and offer a named native Undo. The containing List must remain usable after its selected appearance moves elsewhere. Undo restores that original appearance identity and local Done, removes only the newly created destination appearance, preserves source notes and survives relaunch as data while its editing history expires.

## Readiness and implementation

Q108 approves the real native history-controller interface. Q111 approves the compound inverse, naming, replay/recovery rules and existing Core/native UI seams. Reuse `SavedAssociationUndoHistory`, the window's UndoManager and the explicit mobile control. No new module, target, test-only hook, schema, backup or receipt format is added.

`SavedPlannerStore.moveMembership` now returns the operation response. The form forwards an applied response only while its namespace still matches the captured dataset, then dismisses. The parent registers Move Item and clears only the removed selection. The existing compact-column binding returns a cleared selected appearance to its containing List. Wide layouts keep their native content/detail panes. Existing applied/incomplete recovery handling remains intact.

## Executed red and green observations

The first dark-phone invocation fails in 75.683 seconds before reaching the Undo assertion. Its actual hierarchy shows an Item moved detail page with Back; the List's No items state is hidden behind that compact detail. Returning the invalid selection to the existing content column fixes that behavior.

The next dark-phone invocation reaches No items, then fails at the absent Undo control in 68.029 seconds. This is the native registration red. Wiring the existing response and history supplies the named action. Both failures and their actual hierarchies remain recorded.

The new native controller case passes first in 0.136 seconds using real `SavedPlannerStore`, Foundation UndoManager and public Core exports. It verifies Move Item / Undo Move Item naming, the whole inverse and absent association Redo. The final affected Mac app-hosted invocation passes all six controller functions in 0.745 seconds and thirteen actual HTTP functions in 1.256 seconds. Native administration, including `restoreAssociation`, remains forbidden to agents.

## Final native journey

`SavedAppearanceJourneyTests.testNativeUndoMoveRestoresOriginalDoneAppearanceAndRemovesItsCreatedDestination` passes against the same final source on both simulators:

| Destination | Functions | Result | Duration |
| --- | --- | --- | --- |
| iPhone, dark | One | Pass, zero failures | 109.624 s |
| iPad, light | One | Pass, zero failures | 120.458 s |

The journey completes an origin membership locally, moves it into a previously empty destination, requires the native action, and verifies the new destination identity is different and locally Todo. Invoking Undo from that destination empties it. The origin's exact public appearance identity and Done state return, with its existing notes. Relaunch preserves the inverse and expires old history. Simulator appearance/contrast settings are restored after each invocation. These elapsed times are execution records, not physical responsiveness measurements.

Final native Mac app/UI-test and mobile compiler epochs pass. App-hosted Mac controller execution is distinct from actual Mac window/text-field XCUITest; the latter's recorded startup failure remains unresolved. No signing account, team or capability configuration changes are made.

## Evidence and visual review

The observed-results index retains all eleven native build/runtime epochs, including both failed phone journeys and the intermediate compiler epoch. The source comparison distinguishes diagnostic callers from the final production/test sources. The final runtime and compiler records bind the same current inputs. The validation packet records affected strict Swift/Markdown lint, whitespace, links and bounded credential scanning. The manifest covers exact evidence files.

All six original passing captures were inspected and hashed in the visual review. The phone and iPad show Undo Move Item, the restored checked row/progress and the empty destination after relaunch. The phone's restored row uses dark native surfaces; the iPad's restored row retains native panes in light appearance. The iPad's unselected detail placeholder is intentional.

The phone's relaunch capture also shows part of its navigation title clipped behind toolbar controls. Keep that concrete finding on the final UI pass. These captures do not establish rendered contrast ratios, Increase Contrast, keyboard clearance, every scene or whole-app accessibility acceptance.

## Definition of done and remaining gates

The represented new-destination Move, named Undo, original contextual state and relaunch flow now pass through actual native controls. Core separately qualifies preexisting destination preservation, unsafe relationship rejection, independent contexts, save rollback, recovery and replay. This slice does not claim an executed native UI journey for every guarded/preexisting-destination variant.

The [grouped-removal checkpoint](native-owned-association-undo.md) implements
bookmark/label removal Undo separately. Broader window/focus behavior, physical
CloudKit/account/Share, scale and final whole-app acceptance retain their map
gates. Agent Control remains outside MVP. No association Redo or persistent
editing history is added.

[mac-undo]: native-association-undo.md#native-mac-keyboard-undo-27-october-2026
