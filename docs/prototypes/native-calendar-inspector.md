# Native Calendar inspector

## Context and goal

Calendar previously occupied one navigation column beside permanent details. Day and Week need room for appointments, and Q79 A accepts a wide Calendar with optional native inspector details on iPad and Mac. The end state preserves the selected Schedule and its live Item or Itinerary while details are hidden, then restores the same details through the toolbar or by selecting the entry again.

## Definition of ready

Q79 A and the existing native UI seam are approved. This step changes presentation without adding a Core query or changing saved Schedule forms. The [date-window contract](../calendar-window-contract-review.md) remains pending under Q82. Mobile compact navigation retains its existing pushed details; ordinary Item and List navigation retains its existing columns.

## Definition of done for this step

- Use SwiftUI's native inspector for Calendar in regular-width layouts and native Inspector commands on Mac.
- Give Calendar the available main width when details are hidden. Reopen the same selected Schedule through the toolbar or by selecting its entry again.
- Preserve the Schedule identity and saved form through presentation changes. Reuse existing live Item and Itinerary details and their contextual child navigation.
- Qualify the inspector through a native iPad journey and rerun the affected Calendar journeys on iPhone and iPad. Run strict Swift lint and build the Mac app.
- Record actual outcomes and inspected native captures. Keep Mac runtime, physical devices, Day/Week/Month rendering and the date-window API as separate gates.

## Implementation and qualification

The Calendar uses a native trailing inspector on iPad and Mac. Its own navigation stack preserves Itinerary child navigation. Hide Details belongs to the inspector toolbar; Show Details belongs to Calendar. The shared sidebar is reused in the Mac's two-column Calendar layout. Inspector visibility is separate from Schedule selection, so hiding details does not clear their identity. The selection binding also handles selecting the same entry again. Obsolete Calendar branches were removed from the cached Lists tab.

The initial journey reproduced the absent inspector control. Layout probes distinguished integrated and full-height inspector placement, its navigation lifecycle, and a duplicate route in the inactive Lists tab. The native full-height inspector can overlay content while preserving its underlying frame. The final journey therefore verifies that details disappear, the Show Details control is usable, and the same Schedule reopens without changing its saved form. Native captures verify the visible layout. The Itinerary journey opens and cancels the actual Schedule action through either the direct toolbar menu or UIKit's native overflow menu, then opens its existing contextual child details.

Removing the duplicate route exposed a phone deletion regression: the pushed details relied on a hidden Calendar read to dismiss invalid selection. Confirmed Item and Itinerary deletion now clear their matching Calendar selection directly. The existing native deletion journey covers Cancel, confirmed removal, return to a usable empty agenda, and absence after relaunch.

SwiftUI documents context-dependent inspector presentation and provides native Inspector commands. Apple's example explains navigation and toolbar placement and adaptive iPad overlays. This implementation uses those APIs directly. [SwiftUI inspector](https://developer.apple.com/documentation/swiftui/view/inspector(ispresented:content:)), [Apple's inspector guidance](https://developer.apple.com/videos/play/wwdc2023/10161/)

Final qualification passed seven iPad functions across four suites and six iPhone functions across three suites, with no failures or skips. The inspector function also passed a portrait capture follow-up, giving eight iPad invocations across two runs. Its final test uses the full-screen capture API and the correct saved-app navigation identifiers on Mac. The Mac app and native test host built successfully. Five changed Swift files passed strict lint; this report passed Markdown lint. Both source reviews found no remaining confirmed findings after the routing and deletion corrections. Six original native captures were visually inspected; clipped landscape exports are excluded. [Execution evidence](evidence/navigation/native-calendar-inspector/execution.json) records the actual results, diagnostic failures, commands and verified source/product hashes. Mac UI runtime was not executed.

## Remaining work

Q80's decorated mobile UICalendarView and Mac event grid, Day/Week appointment layout, overlap/overflow, timezone/DST display, accessibility, moving-window performance and Q82's Core date-window contract remain open. Mac runtime and signed physical sync/account/Share qualification remain open. This step does not complete those gates or whole-app polish.
