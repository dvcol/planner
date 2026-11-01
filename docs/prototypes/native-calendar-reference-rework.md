# Calendar reference rework

The November 2026 iPhone/iPad reference request supersedes the earlier decorated
mobile month picker and header-only polish. Calendar now uses a shared SwiftUI
event grid, an agenda, and native navigation, controls and booking forms. Saved
Schedule forms, exact owner identities, civil dates and timezone rules remain
unchanged. No storage, CloudKit or public Core/MCP contract changes are involved.

## Reference comparison

| View | Implemented comparison | Deliberate differences / limits |
| --- | --- | --- |
| Portrait agenda | Leading month/year, compact date navigator, collapsible week strip, pinned day headings, compact times and floating native controls. | Today/range navigation replaces Fantastical's calendar-set selector. Planner has no external calendar accounts or weather. |
| Landscape phone | Agenda at left and calendar at right, with fixed date headings and no generic navigation-title band. Controls float over content; range controls center on the calendar pane. | Dense overlapping weeks can pan horizontally. Text stays within device safe areas. |
| iPad | Calendar owns the main width; date navigator/agenda at left, native view picker above the canvas, existing selected-source inspector. App destinations remain available through the native menu. | Agenda mode uses the date navigator beside a full agenda rather than duplicating the agenda in two panes. |
| Day/Week | One hour ruler, proportional event placement, independent overlap lanes, selected/today indication, red current-time line and compact continuous all-day bars. Titles use available card height before truncating. | Two all-day lanes are visible; a native overflow list exposes every other booking. Narrow columns retain full names and captions through accessibility/details. |
| Month | Seven columns with event names, all-day spans per week row, selected/today indication and a complete day agenda on overflow/day selection. | Dense cells truncate names. Opening the day exposes the full entries; selecting an event opens its exact source. |
| Quarter/Year | Adaptive mini-month grids with booking-density shading; selecting a day opens its Month view. | Density describes saved bookings, not task completion or external calendar availability. |

Agenda and canvas share one date/time focus. User scrolling updates that focus;
programmatic scrolling does not feed back into the active gesture. Grid scrolling
moves the agenda, agenda scrolling moves the grid, and horizontal date navigation
keeps the focused day reachable. Date navigation preserves the clock position.
Rotation restores that focus. An ongoing timed booking takes priority over a
nearby future start in the agenda. Pinned agenda headings leave room for the
focused row, including the last day in a short result. Timed titles remain visible
while the beginning of a long event is scrolled above the grid.
The agenda shares the loaded date window with the canvas. Arrows and the date
chooser move farther; this slice does not add an infinitely scrolling horizon.

Selecting an agenda row, a timed block or an all-day span retains the exact
Schedule and Item/Itinerary identities. Phone opens native pushed details with
Back navigation. Wide layouts reuse the existing details presentation. Calendar's
Add action chooses a live Item/Itinerary and reuses its existing Save/Cancel form,
prefilled with the selected date and display timezone.

## Verification

Focused Simulator journeys cover populated Day/Week/Month/Quarter/Year/Agenda,
portrait/landscape, bidirectional scroll state and visible agenda changes,
all-day alignment, exact Item/Schedule opening from both agenda and grid, and
exact Itinerary/Schedule opening from a multi-day bar. One existing autumn
clock-change journey checks unchanged clock placement and saved content.

Final app checks also cover the collapsed navigator, navigation to other
collections, date-preserving booking creation, light appearance, floating
controls and all-day overflow. iPad dark appearance is checked against the
supplied wide-layout references. Screenshots/results are temporary, never source
assets. The fixture uses synthetic plans and one real atomic import, not the
private contents of the references.

Physical-device visual acceptance remains an owner check after updating
TestFlight. The separately recorded Home/lock-screen confirmation for the iOS
background-termination fix remains open; no repeated iCloud off/on session is
needed. Mac compilation is checked separately from native Mac UI automation.

The focused phone checks pass for the six modes, both orientations, navigator
collapse, linked scrolling, exact owner navigation, booking creation, all-day
overflow and all-day chronological order. The populated iPad journeys also pass,
including the final rotation/linked-scroll rerun. The autumn clock-change
regression passes. The affected Mac app compiles, all 22 changed Swift files pass
strict swift-format lint, and the diff has no whitespace errors. Full native Mac
UI automation and physical-device acceptance were not rerun for this slice.

The visual pass corrected all-day bars that were centered instead of aligned to
their dates, row/header overlap, overly short event titles, missing repeated
all-day labels, short-agenda date alignment, and rotation losing the shared clock
position. Remaining differences are the deliberately smaller planning feature set
in the table above and the native system typography/materials, rather than copied
Fantastical assets. The year overview uses a calendar year instead of a rolling
sixteen-month horizon.
