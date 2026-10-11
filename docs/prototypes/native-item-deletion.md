# Native Item deletion

## Context, starting state and goal

At `7612097`, public Core can review and delete an Item's owned links, direct Schedules, memberships, direct Itinerary entries, label associations and persisted expanded completion. The native app can archive Items and delete labels, but has no Item Delete action.

The goal is an explicit Delete review in the original Item's actions menu. It must explain the complete removal impact, preserve the other Items and containers, and clear selections whose source or appearance disappeared. Cancellation must keep the original data and state. Archive remains separate; there is no Trash workflow.

## Definition of ready

- Core review, token validation, exact replay and independent recovery outcomes are qualified at `7612097`.
- The accepted native test boundary uses actual controls with real temporary datasets. Core and authenticated HTTP remain separate approved boundaries.
- R10 requires confirmation and reference removal. Q8 limits global actions to the original Item view. Lists and Itineraries retain their sources when their own container is deleted.
- Native presentation must respect rejected, unverified and applied-but-incomplete outcomes. Local deletion markers do not prove physical CloudKit conflict behavior.

## Definition of done for this slice

- The original Item menu exposes Delete Item and prepares Core's complete review before showing a native Form and system sheet.
- The review identifies the Item, reports the saved reference count, and describes the removed owned data and associations. It also handles an Item with no references.
- Cancel executes no deletion. Confirmation uses the issued review token; a stale review requires a separate confirmation of its refreshed impact.
- A verified complete deletion dismisses the review, clears removed source/appearance selections, and refreshes the catalogs and live route. Failed or incomplete saves retain their domain status.
- Item content, container identities, surviving appearances, order, completion and appointments remain correct after relaunch.
- Focused iPhone/iPad journeys and the shared label-confirmation regression pass. Affected Swift lint and platform compilation pass. Native Mac runtime and controlled native failure presentation remain separate gates.

## Required /tdd and qualification

Write the shared-reference native journey first. Create Museum and Park, a Wishlist containing both, and a route containing Museum, Wishlist and Museum. Complete two Museum appearances, add separate Item and Itinerary appointments, and establish functional red at the missing Item Delete control. Implement the review and confirmation flow, then verify Cancel, confirmed removal, preserved Park/route state and relaunch.

Later native qualification covers an unreferenced Item and opening the original Item from a List appearance. The latter must clear the removed membership selection while retaining the now-empty List. Run the existing Itinerary-only Tag deletion journey because the Item and label reviews share their native Form. These additional tests qualify implemented behavior; no additional missing-feature red is claimed.

## Implemented behavior

Delete Item is available only in the original Item menu. A contextual List appearance keeps View Item and Remove from List; an Itinerary appearance retains its contextual actions. The existing label review Form now accepts a typed source and displays either label owner counts or the Item's complete reference count. Native controls, loading indicators and interactive-dismiss protection remain in use.

The reviewed-change adapter retains Core's failure distinctions. A changed dependency set refreshes the displayed review without confirming it. The successful callback receives the actual applied review, so selection cleanup uses the latest removed membership and entry identities. A locally applied deletion clears invalid selections even if recovery publication is incomplete; its status remains visible in the sheet and later writes stay blocked. Ordinary data reloads resume when the sheet closes.

## Qualification

Four native functions pass on each iOS 27 simulator with zero failures/skips: the shared-reference graph, unreferenced Item, original Item reached through a List appearance, and existing Itinerary-only Tag confirmation. The runs took 517.449 seconds on iPhone and 559.240 seconds on iPad. Mac app/test bundles compile with zero native UI runtime functions. Six affected Swift files pass strict formatting lint. Eight saved app captures were individually inspected and retained.

The first complete iPhone graph journey passed in 203.402 seconds. Before implementation, two runs stopped on native fixture/element lookup errors; the functional red then reached the missing Delete action in 116.623 seconds. The first implementation attempt reached the five-reference review and Cancel, but failed when the test treated a grouped appointment row as a Button. The captured hierarchy showed that row as Other and retained Museum's notes and appointment. Correcting the lookup produced the first pass. Byte-identical red/green test files are not claimed.

The [evidence record](evidence/navigation/native-item-deletion.json) retains logs, commands, result summaries, screenshot provenance and both 282-file source/configuration epochs. Only the two added qualification functions differ between the first successful tracer and final qualification; removing those functions reproduces its exact file hash. All production/configuration bytes match across those epochs. Core, HTTP, package and project configuration hashes for 227 files still match `7612097`, so their recorded deletion, recovery and agent-permission results are reused without a new runtime claim. Schema 14, portable format 1 and localOnly remain unchanged.

The iPad runner emitted 396 ignored remote-hierarchy diagnostics while checking for interrupting Springboard elements. All journey assertions passed; resolution of those automation diagnostics is not claimed. The Mac build also emitted metadata-extraction warnings for targets without an AppIntents framework dependency.

## Remaining gates

Controlled native stale-review, unverified-save and incomplete-recovery presentation still need runtime qualification. The existing Core recovery I/O tests establish transaction outcomes at their own boundary. Native Mac runtime, signed sync/account/Share, returning offline-device deletion conflicts, container source deletion, recovery repair, import/restore and whole-app polish remain open. The phone route title/toolbar crowding remains a polish finding. Calendar modes/navigation and itinerary estimates await Q59-Q61; Calendar export remains outside the map.
