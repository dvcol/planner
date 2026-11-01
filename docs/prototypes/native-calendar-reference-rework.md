# Calendar reference rework

The November 2026 iPhone/iPad reference request supersedes the earlier decorated
mobile month picker and header-only polish. Calendar now uses a shared SwiftUI
event grid, a companion booking list, and native navigation, controls and booking forms. Saved
Schedule forms, exact owner identities, civil dates and timezone rules remain
unchanged. No storage, CloudKit or public Core/MCP contract changes are involved.

## Reference comparison

| View | Implemented comparison | Deliberate differences / limits |
| --- | --- | --- |
| Portrait | Leading month/year, continuously scrolling calendar above a booking list, pinned day headings, compact times and floating native controls. The handle selects Day, Week, Month or Year. | Today/range navigation replaces Fantastical's calendar-set selector. Planner has no external calendar accounts or weather. |
| Landscape phone | Agenda at left and calendar at right, with fixed date headings and no generic navigation-title band. Controls float over content; range controls center on the calendar pane. | Dense overlapping weeks can pan horizontally. Text stays within device safe areas. |
| iPad | Calendar owns the main width; date navigator and booking list at left, four-level native view picker above the canvas, existing selected-source inspector. App destinations remain available through the native menu. | The booking list can be hidden. It is a companion, not a separate Calendar mode. |
| Day/Week | One hour ruler, proportional event placement, independent overlap lanes, selected/today indication, red current-time line and compact continuous all-day bars. Titles use available card height before truncating. | Two all-day lanes are visible; a native overflow list exposes every other booking. Narrow columns retain full names and captions through accessibility/details. |
| Month | Seven columns with event names, all-day spans per week row, selected/today indication and a complete day agenda on overflow/day selection. | Dense cells truncate names. Opening the day exposes the full entries; selecting an event opens its exact source. |
| Year | Adaptive mini-month grids with booking-density shading; selecting a day opens its Month view. | Density describes saved bookings, not task completion or external calendar availability. |

Agenda and canvas share one date/time focus. User scrolling updates that focus;
programmatic scrolling does not feed back into the active gesture. Grid scrolling
moves the agenda, agenda scrolling moves the grid, and horizontal date navigation
keeps the focused day reachable. Date navigation preserves the clock position.
Rotation restores that focus. An ongoing timed booking takes priority over a
nearby future start in the agenda. Pinned agenda headings leave room for the
focused row, including the last day in a short result. Timed titles remain visible
while the beginning of a long event is scrolled above the grid.
Day, Week, Month and Year scroll continuously in both directions. Lazy native
scroll views render a rolling date window, and settling a gesture recenters that
window while preserving the shared date/time focus. Month uses consecutive week
rows without repeated month-boundary weeks. Year appends/prepends complete years.
The booking list keeps a nearby rolling range and shares coherent Calendar reads
with the canvas. Empty dates remain reachable. Arrows and the date chooser are
optional shortcuts, not page boundaries.

The portrait handle drags upward toward Day and downward toward Year, one level
per gesture. Tap cycles the four scales; accessibility supports adjustable
increment/decrement. Agenda and Quarter are removed from the mode picker. Changing
scale retains the focused date/time. No new saved preference or data contract is
introduced.

Selecting an agenda row, a timed block or an all-day span retains the exact
Schedule and Item/Itinerary identities. Phone opens native pushed details with
Back navigation. Wide layouts reuse the existing details presentation. Calendar's
Add action chooses a live Item/Itinerary and reuses its existing Save/Cancel form,
prefilled with the selected date and display timezone.

## Verification

The original build 3 Simulator journeys covered six modes; the current four-scale
revision replaces their mode selections and navigator assertions. Focused journeys cover populated Day/Week/Month/Year,
portrait/landscape, bidirectional scroll state and visible agenda changes,
all-day alignment, exact Item/Schedule opening from both agenda and grid, and
exact Itinerary/Schedule opening from a multi-day bar. One existing autumn
clock-change journey checks unchanged clock placement and saved content.

Final app checks also cover the scale handle, navigation to other
collections, date-preserving booking creation, light appearance, floating
controls and all-day overflow. iPad dark appearance is checked against the
supplied wide-layout references. Screenshots/results are temporary, never source
assets. The fixture uses synthetic plans and one real atomic import, not the
private contents of the references.

Physical-device visual acceptance remains an owner check after updating
TestFlight. The separately recorded Home/lock-screen confirmation for the iOS
background-termination fix remains open; no repeated iCloud off/on session is
needed. Mac compilation is checked separately from native Mac UI automation.

The original build 3 focused phone checks passed for six modes, both orientations, navigator
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
Fantastical assets. The year overview scrolls through complete years instead of a fixed
sixteen-month horizon.

## Internal delivery, 1 November 2026

iOS `1.0.0 (3)` is processed and **Testing** in the existing Personal group.
The app and Share extension signatures/build identities validate, and focused
Calendar testing notes are saved. Mac TestFlight remains on build 1. The exact
uploaded archive and dSYMs are retained locally; the two disposable Simulators
and 85 intermediate result/log/image paths were removed. A few final synthetic
comparison previews remain outside Git. No App Store submission was made.

## Continuous scrolling revision, build 4

The four focused continuous-scroll journeys cover both directions in Day/Week,
all five handle transitions with a visible selected date/current clock, a booking
eight months ahead beyond Month's initial read window, and a booking four years
ahead beyond Year's initial read window followed by scrolling back to an earlier
year. The distant Month booking opens its exact saved Item/Schedule. Native
navigation tests also open exact visible Item bookings from the list and time
grid, and an Itinerary from a multi-day Month span. A current-time synthetic
booking makes grid activation independent of the hour the test runs.

Final phone dark and iPad light comparisons cover all four scales, both
orientations, current-date/hour indication, pinned headings, two-way linked
scrolling and source navigation. January headings label the year at boundaries.
The pass corrected lazy-layout offset estimates, stale row heights when expanding
Month, a sticky header intercepting downward gestures, and eager list realignment
during browsing. Native selection and Schedule persistence remain unchanged.

The existing autumn clock-change regression passes. Validation stays scoped to
the changed app, existing fixture/native journeys and strict Swift formatting;
there is no repeat of CloudKit off/on, migration or full-repository matrices.
Physical-device visual acceptance and full Mac UI automation remain separate.

## Internal delivery of build 4

iOS `1.0.0 (4)` is processed and **Testing** in the existing Personal group.
The focused Calendar testing notes are saved. Source is published on `main` at
`57a3a42`. Mac compiles successfully; its TestFlight build remains 1.
The app/Share signatures and build numbers validate, and the retained archive's
app/dSYM UUIDs match. Both disposable Simulators and the reviewed intermediate
result/log/image paths were removed. Only a few final synthetic previews remain
outside Git, alongside the release archive/symbols. No App Store submission was
made. Device visual acceptance and the earlier Home/lock confirmation remain
owner checks after updating TestFlight.
