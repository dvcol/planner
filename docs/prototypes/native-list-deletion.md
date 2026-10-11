# Native List deletion

## Context, starting state and goal

At `7ca7a1c`, public Core reviews and deletes a List together with its memberships, referencing itinerary entries and persisted expanded completion. Source Items, other Lists, Itineraries and appointments survive. The native app can confirm Item and label deletion, but its List actions menu has no Delete action.

The goal is a native, explicitly reviewed List Delete through the existing SwiftUI Form and Core command. Cancel preserves the complete dataset. Confirm removes the container and its references, retains shared sources and surviving route order/completion, and clears removed selections. Archive remains a separate action; there is no Trash workflow.

## Definition of ready

- The accepted R10/R14 contract requires confirmed container-only deletion, with no deletion timer or removal of source Items.
- Q8 and repeated appearances retain independent contextual completion and global Item precedence.
- The complete Core List review, local transaction, replay and independent recovery outcomes have recorded qualification.
- Native tests use the agreed real controls and temporary local dataset. No private database queries, scripted data injection or production test-only seams are added.

## Definition of done for this native slice

- A selected List's native actions menu offers Delete List, including an empty List. Empty-container bulk completion remains disabled.
- The existing native confirmation Form shows the List name, complete reviewed reference count and container-only impact. Cancel applies nothing.
- Confirm sends the actual current review through the shared adapter. Removed source/appearance selections are cleared only after an applied result, including an applied but incomplete recovery result.
- A stale review retains the Form with refreshed impact. Failed/unverified results retain their status. Controlled native presentation qualification remains a separate gate.
- Both source Items, surviving List membership identity/state, itinerary entry order/completion and separate Item/Itinerary appointments remain after cancellation, confirmed deletion and relaunch.
- Focused native journeys, strict affected Swift lint and target compilation pass; exact source epochs and inspected captures are recorded. No physical iCloud or native Mac runtime claim follows from simulator results.

## Required /tdd

The native tracer creates Museum and Park, Wishlist containing both, and Rain plan independently containing Museum. Weekend route contains Museum, Wishlist twice and Rain plan in saved order. Completing the direct Museum appearance and one expanded Wishlist appearance yields two of six Done. Museum and Weekend route own separate appointments.

Review must report five saved references: two memberships, two referencing List entries and one persisted expanded completion. Cancel retains all six appearance identities, two-of-six completion, both Wishlist memberships and the itinerary appointment. Confirm retains both source Items with global Todo and their notes, Rain plan's original membership with zero-of-one standalone completion, the original direct and Rain plan route appearances in order with one-of-two completion, and both appointments through relaunch.

The second journey reviews an empty List with no references, confirms both bulk completion actions are disabled, cancels unchanged and then deletes it. It also deletes Rain plan while its Museum detail is selected, clears the removed membership/detail, and retains the original globally Todo Item after relaunch. The existing Item deletion reached through a List appearance and Itinerary-only Tag confirmation exercise the shared Form callers. These qualify implemented behavior without claiming another missing-feature red.

## Red, observation corrections and qualification

The first native tracer reaches the missing Delete List control in 165.869 seconds, with all 284 baseline source/configuration files unchanged. The same test bytes then reach review and cancellation, before a full-row assertion fails in 175.215 seconds. The [recording frame](evidence/navigation/native-list-deletion/phone-viewport-observation-failure.png) shows two-of-six full progress and later route rows below the viewport. A native scrolling helper collects the actual appearance identities in order and returns to the top. Production remains fixed; the corrected tracer passes in 266.573 seconds.

Initial four-function qualification passes on iPhone. On iPad, the unchanged Item and Tag regressions pass, while both new List functions stop during setup at the test's directly visible Add-button assertion. The [iPad recording frame](evidence/navigation/native-list-deletion/tablet-toolbar-observation-failure.png) and saved accessibility hierarchy show the system OverflowBarButtonItem in the narrow List column. The test now observes the empty container and opens List actions through native overflow when needed. It also uses the actual collapsed back button without requiring one in the expanded layout. No app code changes after the first implementation run.

The two affected List functions then pass on both simulators with zero failures/skips, in 408.769 seconds on iPhone and 472.870 seconds on iPad. The unchanged Item/Tag functions from the preceding run retain their passing qualification. Four unique functions are therefore qualified per simulator across recorded test epochs. The final Mac app/test build succeeds with zero native Mac UI runtime functions, and three changed Swift files pass strict lint. Ten qualification captures and the two failure-recording frames were individually inspected.

The [evidence record](evidence/navigation/native-list-deletion.json) retains commands, logs, result summaries, capture provenance and the 285-file source/configuration epochs. First implementation preserves the original red test bytes. Later changes affect only the native List test file: scrolling observation, the second qualification function and toolbar overflow observation. All production/configuration bytes stay fixed during those changes. The 229 unchanged Core/HTTP/package/project/configuration files match `7ca7a1c`; its recorded Core, simulator Core and HTTP results are reused without a new backend runtime claim. Schema 14, portable format 1, localOnly and the MCP source-deletion prohibition remain unchanged.

The final iPad run emits 328 ignored remote-hierarchy diagnostics, and compilation emits metadata-extraction diagnostics. The failed runs also record diagnostic-collection failures. Their resolution is not claimed. Inspected images retain the compact phone route title/toolbar crowding and repeated deleted-List empty state in iPad content/detail columns as whole-app polish findings.

## Implementation and remaining gates

The selected List's system actions menu now offers Delete List. The existing Form reviews its complete reference count and explains container-only impact. Confirm uses the shared reviewed-change adapter. On an applied result, the actual applied review clears the deleted List, its child appearance and removed itinerary row selections while preserving unrelated source/route selections. Reads of the reviewed List and its child selection pause until dismissal, then refresh. Failed or stale reviews keep their existing Form/status behavior; their controlled native presentation still needs qualification.

Calendar/estimate choices await Q59-Q61. Native Itinerary Delete, administration/recovery, controlled save-failure presentation, Mac runtime, signed physical sync/account/Share and whole-app polish remain open. Local deletion markers do not prove deletion winning against a returning offline device. Apple Calendar export remains outside this map.
