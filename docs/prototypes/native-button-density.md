# Native button density refinement

Status: implemented with focused local mobile qualification. This follows the user's 20 October request for icons or better-spaced labels, with less capitalization. Mac runtime verification awaits desktop availability; signing remains deferred.

## Context and intended result

At `2051822c`, toolbar labels depend partly on platform defaults, many actions use title case, and the mobile Undo control repeats its full action name visually. Link URL fields, action menus and labels use the default stack spacing.

The intended result is quieter native toolbars and readable sentence-case actions. Keep enough visible wording to distinguish confirmation, filtering and destructive choices. Preserve accessible names, action identities, keyboard shortcuts, validation and the existing save/selection behavior.

## Changes

Main Add, label-management, Settings, new List/Itinerary, itinerary-edit and action-menu controls explicitly use SwiftUI's icon-only label style with descriptive help. Calendar's display-zone control uses its globe; Today keeps its concise text. Sort already uses an icon. Cumulative Filters retain their summary and help; native compact bars can display only their symbol. Native Edit/Done, Save and Cancel retain their short labels.

Menus and forms use sentence case, including dynamic New category and New tag actions. The label-management Add menu uses its existing plus symbol. Link rows have explicit spacing between URL fields, action menus and their label fields. Their Add link button keeps its label and regular native control size.

The visible Undo control is shortened to Undo with its system arrow and a large native control size. Its accessible label and help retain the complete issued action name, including retry context. Native Undo history and restoration behavior are unchanged.

These are native label, spacing and copy changes. They add no component library, custom button renderer, persistence change, agent contract or new test interface. Journey queries use the updated visible copy while their stable accessibility identifiers remain unchanged. User-owned titles and label names are preserved.

## Readiness and validation

The user directly authorizes this styling work. The existing native UI test boundary covers actual menus, creation/cancellation, label selection, capture, restoration and relaunch. No new unit test is added to mirror capitalization or padding constants. Compile the affected native targets, lint the changed Swift, run focused existing journeys on phone/tablet/Mac, and inspect original captures before crediting the result.

## Executed local checks

| Existing native journey | Dark iPhone | Light iPad |
| --- | --- | --- |
| Rich List-origin Item creation, Cancel, Save and relaunch | Pass, 151.315 s | Pass, 168.788 s |
| Untouched-link capture | Pass, 22.655 s | Pass, 23.105 s |
| Repeated-entry Undo, independent checks, filters, order and relaunch | Pass, 144.136 s | Pass, 131.858 s after the readiness correction |
| Staged labels, Cancel/reopen, rotation and shared identities | Pass, 141.598 s | Pass, 156.600 s after the overflow corrections |
| Items/Inbox title width and toolbar overlap | Pass, 19.543 s | Not run in this slice |

These runs enable Increase Contrast and restore the original appearance/contrast afterward. The table combines explicitly recorded source epochs, not one all-green batch. App and native fixture test targets compile. Selected original dark-phone and light-tablet captures were inspected: native icon bars, sentence-case editor headings, concise Undo and separated link rows remain readable. The native title check independently measures real title/button frames. The floating-tab scroll edge remains a final-polish observation.

Both initial simulator attempts stop before any Test Case because testmanagerd socket paths are missing. Restarting only the two test simulators without erasing them restores execution. The failed attempts and restart commands remain in the evidence.

The initial iPad failures expose controller assumptions. Returning from Calendar is checked before the selected itinerary's navigation bar appears; waiting for that actual bar fixes the repeated-entry journey. Label setup assumes New list is directly visible even when the system puts it in overflow; reusing the existing overflow-aware creation helper reaches the editor. Its next failure is another direct-visibility assertion for Add after Cancel. The passing final follow-up checks the actual reopen flow instead, retaining Cancel/no-created-Item, rotation, Save/relaunch and identity assertions. Production toolbar placement and data commands are not changed to satisfy these assumptions. Failed attempts remain recorded separately.

Mac builds pass, but actual execution times out while enabling automation mode with XCTFuture error 1000 before any Test Case. App and runner signatures verify. The read-only console probe does not establish lock state; the user's awake/unlocked/idle availability answer is pending. No new Mac runtime credit is claimed for this refinement, and no permission or signing changes are performed.

Source/product hashes, exact commands, logs, original captures and inspection records are retained under navigation compatibility evidence. Compiler evidence alone does not establish usable controls or appearance acceptance.

## Remaining scope

Q113's separate compact-toolbar More-menu workflow is still pending; this refinement does not adopt it. Final whole-app scene, accessibility, keyboard and physical-device acceptance remain open under ticket 23. Existing signing, shared-container/CloudKit and actual system Intent gates remain separate work.
