# Native deletion with no visible survivor

Status: the focused Q89 Item and List journeys pass on both simulators. This extends the [existing deletion-selection evidence](native-deletion-selection.md) without changing the pending Q93 creation contract.

## Context and expected state

Q89 selects the first visible survivor after confirmed deletion. An empty filtered result must stay empty even when archived records remain in the dataset. Those archived records must retain their identities and data, and become reachable when the user changes the archive filter. Compact layouts return to the catalog; regular layouts have no replacement detail to select.

## Definition of ready

Q89 already approves this selection behavior. The accepted public native UI boundary and existing Core fixture commands supply the test. A disposable fixture creates one active Item/List and one archived Item/List, with each Item referenced by its corresponding List. Fixture setup uses ordinary creation and membership commands separately; it neither exercises nor substitutes for Q93's proposed atomic creation path.

## Required checks and definition of done

- Record an archived Item's identity, return to Active, and delete the only visible Item through its actual reviewed deletion form. Show the empty filtered catalog without selecting hidden details or showing an unavailable-source error. Show archived records explicitly and verify the original surviving identity and notes after relaunch.
- Repeat for the only visible List. Keep its source Item, retain the archived List and its membership, and verify their identities after relaunch.
- Run the affected journeys on iPhone and iPad, inspect original own-app captures, and retain literal command/results and frozen source records. Run affected strict lint and compiler checks. Mac UI runtime remains dependent on its outstanding availability check.

## Results

The first attempt fails before deletion because the controller queries navigation while fixture setup is still running. Its own-app hierarchy later contains the expected native tabs. Waiting for the actual tab's existence and hittability fixes setup; this is not a product deletion failure.

The readiness-qualified Item journey passes in 80.552 seconds and the initial List journey in 97.543 seconds. Review then identifies a weak List assertion: the sidebar can show an empty catalog independently of the detail selection. The strengthened journey checks absent List actions, Add and loading state at both empty-result checkpoints. Regular layouts must positively show the List deleted detail. Compact layouts must have no Hidden List navigation. No production behavior change is required.

| Represented passing journey | iPhone seconds | iPad seconds |
| --- | --- | --- |
| Delete the only visible Item; retain archived identity and notes after relaunch | 81.620 | 82.582 |
| Delete the only visible List; retain archived List/membership and original source Item | 115.339 | 132.117 |

The Item results come from each device's `combined-selection-qualified` phase. The phone batch passes both functions; the iPad batch passes Item but fails List setup before deletion because the archive control moved into native toolbar overflow. That batch is not represented as wholly passing.

The List controller now opens the observed Planner sidebar's More menu. A later iPad assertion still expects the empty sidebar to be visible after deletion. Its actual hierarchy instead shows the correct List deleted detail with the native sidebar collapsed. The test first checks the empty detail and absent selection controls, then reopens the sidebar to inspect its empty catalog. Each device's `list-native-sidebar` phase passes the complete List journey with zero failures/skips. These controller corrections do not change production behavior.

All eight original named captures for the four represented journeys are inspected. The 232 source inputs differ between the Item and final List epochs only in the test-controller file. Both simulator app executable hashes remain identical; the final List test products also match across devices. Final List and Mac compilation source records match the current worktree. The revised Mac fixture app and test targets compile without signing; no Mac UI function is executed.

All four affected Swift files pass strict lint. The reports pass Markdown lint. Source and evidence reviews remain separate from the wider open acceptance gates.

[The evidence packet](evidence/navigation/native-deletion-empty-results/) retains literal commands, logs and frozen source/product hashes. Test epochs include unfinished production creation/selection work; no Q88/Q93 writer completion or full Q89 completion is credited. These journeys do not complete Q89's delayed-refresh, dataset-transition, retained-dialog or Mac runtime matrices. Q93 ordinary creation, physical sync/account/Share, accessibility, performance and final UI polish remain open.
