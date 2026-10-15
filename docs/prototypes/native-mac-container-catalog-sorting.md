# Native Mac container catalog sorting

## Context and starting state

Q87 approves shared List/Itinerary catalog sorting and native per-device choices. Core, real MCP HTTP and phone/tablet native journeys already qualify the behavior. The saved-data catalog-sort UI class currently excludes Mac, so Mac compilation supplies no runtime evidence for these workflows. Earlier read-only prototype journeys establish that Mac automation has executed; this slice must test the saved application itself.

## Goal, readiness and expected end

Use the accepted Q34 production native UI boundary, existing catalog-sorting disposable fixture and the same two journeys. Adapt native sidebar navigation, menu dismissal and checkbox roles to Mac without changing production behavior. The first journey must observe all declared orders, separate Lists/Itineraries preferences, relaunch persistence, new-dataset defaults and restoration of the first dataset's choices. The second must preserve a valid selected List during sorting, remove an Item estimate through its native form and observe live uncertainty-group updates in both catalogs. Itinerary own Last updated order and the final archive/sort result must remain correct.

## Required tests and definition of done

Run only the two affected saved-data Mac UI functions against a disposable fixture app. Record actual source/product hashes, commands, original results or explicitly scoped derivatives, plus original fixture-window captures, then inspect the captures. Run strict Swift lint for the changed test and Markdown lint for this report. Retain failures and distinguish test-adapter corrections from product failures. Preserve phone/tablet interactions and run the corresponding focused mobile check for any shared controller changes.

This qualifies represented catalog workflows, not the whole Mac application, physical account isolation or overall accessibility. Native fixture data remain disposable local data. Core/HTTP behavior and the existing map gates retain their separate evidence.

## Execution

Production sources remain unchanged. Test setup uses the saved application's sidebar identities and native mouse-click helper, while mobile keeps its existing native tabs and touch controls. At the default 900-point Mac window width, the sort Menu appears in the system toolbar overflow. The overflow entry exposes its native title rather than the SwiftUI toolbar identifier. The controller must account for foreground activation and that native representation.

| Phase | Result | Observation |
| --- | --- | --- |
| mac-native-probe | Two failures, 57.782 s | Direct toolbar/readiness assumptions prevent reaching the sort workflow. |
| mac-window-readiness | One failure, 23.026 s | The fixture window is present; the sort control is in native toolbar overflow. |
| mac-native-overflow | One failure, 11.189 s | Foreground readiness fails before the section action; the app reports background state and zero accessible windows. |
| mac-foreground-overflow | One failure, 16.690 s | Native overflow opens, but its Sort entry has a title without the toolbar identifier. |
| mac-native-menu-titles | One failure, 47.536 s | Full estimate ascending/descending and Last updated are selected before foreground readiness is lost. |
| mac-dismiss-overflow | One failure, 10.731 s | Foreground readiness fails before a menu is reached, so the dismissal hypothesis is not tested. |
| mac-foreground-readiness | One failure, 73.704 s | Explicit foreground checks allow the List orders to execute. The visible Itinerary MenuButton exposes its summary as native title, with an empty label. |
| mac-sort-title-adapter | Two failures, 44.086 s | The persistence journey loses foreground readiness before its first action. The live-edit journey reaches selected List contents, then encounters its remaining direct-toolbar assumption. |
| mac-selected-catalog-overflow | One failure, 16.181 s | The corrected selected-catalog adapter is not reached; the fixture loses foreground/window readiness before its first action. |

These diagnostic failures receive no functional qualification credit. Subsequent Mac captures and failure descriptions are scoped to fixture windows. The first probe's complete original log remains local because its full-application debug description includes unrelated system-menu recent-document names. The shared derivative explicitly marks the omitted hierarchy blocks and records the original hashes and local location; it is not presented as an unmodified raw log.

## Current qualification boundary

Mac runtime qualification is incomplete. A read-only console query reports an active console but no lock-state key, so it does not establish whether the desktop is unlocked. A process check finds only the current Xcode build, fixture test runner and fixture application, with no competing Planner UI run. The user has been asked whether the desktop can remain unlocked and idle for a short retry. Neither observation establishes an operating-system or product root cause.

The unqualified draft adapts native menu titles and overflow, retains exact row-order and data checks, and confines Mac screenshots to the fixture window. It is preserved as an exact compressed patch and source in the evidence packet. The canonical test remains unchanged and iOS-only until both Mac journeys pass. It has not passed both saved-data Mac journeys. The first raw application-scoped PNG, if present in a diagnostic result bundle, also remains local and supplies no visual qualification credit. Only final deliberately window-scoped captures will be considered for shared visual evidence.

## Mobile compatibility and handoff

The final draft passes both affected iPhone simulator functions, with zero failures or skips. Persistence and dataset isolation take 121.599 seconds; selected-data refresh takes 108.371 seconds. This checks the shared test controller, with production code unchanged. The corresponding original phone/tablet feature qualifications remain in the earlier [native catalog sorting report](native-container-catalog-sorting.md). No additional tablet or physical run is credited here.

Strict single-file Swift format lint passes for the preserved draft. Source epochs, exact commands, products and original compressed logs are retained in the [evidence packet](evidence/navigation/native-mac-container-catalog-sorting/). The first probe's explicitly scoped log/summary derivatives retain their original local locations and hashes. Other failure descriptions are scoped to fixture windows. One deliberately window-scoped original Mac PNG was individually inspected; it shows the expected descending List order with incomplete estimates last, while some sidebar duration text truncates. A partial capture never replaces the full journey's failed outcome.

Resume the draft only after desktop readiness is available. Run both saved-data Mac functions, inspect their original window captures, resolve any remaining native checkbox/menu assumptions, and verify corresponding mobile behavior if shared control logic changes. Do not claim saved-data Mac qualification, enable the draft in the canonical target or close the map from these diagnostic runs. Signing, physical CloudKit/account/Share, full Mac interaction/accessibility and whole-app polish retain their independent gates.
