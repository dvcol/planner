# Native collection Map place choices

## Existing boundary and first failure

Q144’s [additional hosted-window trial](native-map-place-choice-view.md) failed to reach Locations and retains no positive control credit. The established PlannerFixtures app already compiles the production Map/navigation sources and supplies the controlled address provider through its accepted interface. Continue through AddressCandidateJourneyTests in that existing native UI boundary. No shipping flag, test-only production parameter, new target or dependency is added.

The existing address-candidates fixture supplies North entrance at 35.662,139.717 and South entrance at 35.655,139.717 for the same owned address. The first actual phone journey opens the collection Map and Locations, reaches the exact ambiguous source row and confirms Choose a place. It fails at the missing Location options control in 25.288 seconds. This is behavioral red at the missing production control, rather than a hosting or picker-query failure. The represented iPhone build compiles Q130’s Core declaration; it does not execute the change stream.

## Minimum implementation under test

Show the existing native Location options menu for an ambiguous address. Its Matching places Picker uses the loader’s existing validated candidate-selection command. Retain the temporary chosen candidate identity alongside its row resolution so the native Picker represents the exact choice. This state is in-memory only and clears with the collection publication. No owned address, coordinates, completion or bookmark is saved. Existing Maps-link and Retry controls remain in that menu.

The first compilation attempt used a dictionary keyed by PlannerRowIdentity, which is not Hashable. Preserve the public identity type. Align temporary selection storage with the loader’s existing row-indexed arrays instead. The failed compiler attempt is retained without runtime credit.

The first green journey must choose North, reopen and choose South, verify the corresponding native pin changes, then check unchanged owned name/address, absent owned pin, original notes and completion. Relaunch must retain the source identity and require a new temporary choice. Repeated itinerary appearances, existing address-detail and Map-link/Retry regressions, dark iPad and Mac compilation follow before the full native chooser checkpoint. Existing loader/Core tests retain exact before/after export qualification.

## First native chooser result

The first complete phone journey passes in 69.614 seconds. Both original captures are inspected and show the native pin at the distinct expected North/South coordinates. The test uses actual Locations and nested Picker controls, checks the unchanged saved source identity/name/address, absent owned coordinates, original notes and global completion, then relaunches and confirms the choice is temporary. Its 1,076 workspace/frozen inputs and four products reconcile.

Extend the existing fixture with an itinerary referencing the same ambiguous Item twice through real domain commands. The next native test chooses South for Stop 1 while Stop 2 still requires a choice, chooses North for Stop 2 without moving Stop 1, then changes Stop 1 to North and expects the counted two-appearance marker. Relaunch must retain both association identities and require fresh temporary choices. Existing North/South provider inputs are reused; no new fixture scenario or production hook is introduced.

## Final local chooser checkpoint

The final source reconciliation covers eight passing native UI executions across four functions: the two collection Map journeys on iPhone and dark iPad, plus both existing address-detail/retry journeys on each. Sixteen original captures are inspected. All represented 1,076-input manifests match the final source. The iPad remains in its original dark appearance after the run. The exact repeated association identities survive relaunch, while temporary choices reset. Native Map pins move independently and merge into the counted marker only when their selected coordinates coincide.

All twelve existing loader functions pass, including exact/stale address choices, independent Maps-link choices, cache reuse, delayed/cancelled providers, four shared slots across dataset changes, concurrent refresh and offscreen owned pins. Thirteen owned fixtures are removed only after the host and database handles close. The additional getter assertions establish the selected candidate identity as well as its coordinate. Separate matching Mac build-for-testing succeeds; it is compiler evidence, not Mac UI acceptance.

Two initial regression launches stop at sandbox-denied compiler caches before compiling or testing. Their exit-74 packets are retained without runtime credit. The authorized focused retries pass. The earlier behavioral red, failed dictionary compilation and failed Q144 hosted-window trials retain their original status.

This closes the missing native ambiguous-address chooser through the already accepted production-source fixture boundary. Live geocoding, Mac UI, physical devices, broader accessibility, window resizing and final whole-app polish remain separate. Narrow iPad navigation-title truncation is visible in the retained captures and is not credited as polished. Q130 cross-writer native refresh still needs its remaining implementation and qualification.
