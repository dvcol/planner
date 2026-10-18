# Native Item picker presentation windows

Status: the first picker compatibility baseline passes. Production window adoption is next. Q98 remains pending and no itinerary-window interface changes are part of this slice.

## Context and starting state

Items, Inbox and standalone List contents use the accepted Q95/Q97 `SavedItemWindow`. Add existing Item and the Item section of Add Itinerary Entry still call `readItems`, retaining every matching Item presentation before showing their choices. Their native Lists render lazily, but the complete presentation arrays remain retained.

The complete candidate identity set also validates an offscreen selection. Replacing it with the currently loaded page would disable Add or select the wrong source after scrolling. Saving must retain the selected shared Item and original List/Itinerary destination. A new List appearance starts local Todo, subject to global Item Done precedence.

## Goal and resulting state

Adopt the existing, unchanged Item-window interface in both Item picker clients. Show its initial 64-row page, request visible and neighboring pages, and release distant Item presentations. Keep the complete candidate identity sequence for selection validation. Loading/failure placeholders expose no invented Item selection. Cancel, native selection, Add, dataset/revision replacement and relaunch preserve their existing behavior.

The itinerary picker's List catalog is separate retained metadata and remains eager in this slice. Itinerary contents and broader catalog windowing are separate map work. Complete Core identities/captures remain resident under Q84. No total-memory or latency improvement is claimed from page retention alone.

## Definition of ready and test boundaries

Reuse the Q95/Q97 production loader exactly as approved: real Planner/session initializer, typed Item query, namespace/revision identity, reload, visible-index request, cancel, complete row identities, state/count and loaded/loading/failed presentation. No new module, package, target, public query, loader output or test-only option is proposed.

The loader's existing real-Core tests already establish Item first-page retention, release/revisit, replacement and stale refresh. Integration uses the already accepted native UI seam and isolated large fixture. Accessibility identifiers name actual native controls; there is no test-only jump, page counter or cache inspection.

First qualify observable picker compatibility against the eager reader. Traverse intermediate boundaries, select a later-page source, scroll to the end and back to the first page, then Add the still-selected source. Assert the original destination, exact Item content, new local Todo appearance, complete count and stable membership after relaunch. A passing eager baseline is compatibility evidence, not a retention red. The earlier real-Core loader red/green supplies retention evidence; source adoption and native regression together qualify the integration.

Then adopt and requalify one client at a time. Exercise existing Add/cancel and source-kind selection journeys, candidate changes, navigation and phone/tablet layouts through the existing seams. Test no private page or task state. If a new tested production interface becomes necessary, propose it separately before tests, as required by the TDD skill.

## Definition of done

Both Item picker clients no longer call the eager Item reader. A selected surviving source remains valid after its presentation page is released. An invalidated or stale candidate cannot be submitted. Save continues to use the original container and accepted domain command; Cancel creates no reference.

Affected strict Swift lint and mobile/Mac compiler checks pass. Record exact source/product epochs, baseline/integration results and inspected original captures. Mac runtime, physical performance, signing, itinerary/List-catalog windowing and final whole-app visual/accessibility acceptance remain open until their own evidence passes.

## Baseline evidence

The [qualified eager iPad baseline](evidence/navigation/native-item-picker-windows/picker-list-tablet-directional-baseline/exit.json) passes in 263.052 seconds. It traverses choices 65 and 129, selects 129, reaches choice 193 and returns to the first page with Add enabled. Save retains the source's exact notes, original List, full two-item progress count and new local Todo appearance. Relaunch preserves that membership identity and state. This establishes compatibility, not moving-window retention or performance.

The first attempt tapped a row that had scrolled beneath the native sheet navigation bar; its [recording-frame review](evidence/navigation/native-item-picker-windows/picker-list-tablet-eager-baseline/failure-review.json) classifies a controller failure. The next attempt added viewport checks but its forward-only fallback overshot the target and kept swiping at the end. A [live Simulator capture](evidence/navigation/native-item-picker-windows/picker-list-tablet-visible-baseline/controller-review.json) proved that condition; the specific diagnosed runner was interrupted and its result retained. Neither attempt supplies product-red credit. The passing controller follows visible fixture-row ordinals through actual gestures, reverses overshoot and requires the complete target below the native navigation bar. Existing ordinary List traversal keeps its original controller.
