# Calendar window contract review

Status: approved under Q81 A and Q82 A on 14 October 2026. This packet declares the concrete public reads before their tests or implementation. Existing Schedule catalog and Item-query defaults remain unchanged.

## Context, goal and readiness

Calendar currently loads the whole Schedule catalog and reads each Schedule form and owner title separately. Its selected-day view then filters that collection. Day, Week and Month need a shared date-window read that cannot combine records from different generations.

Q81 accepts the shared Core capability. The [Calendar readiness gate](container-estimates-and-calendar.md#definition-of-ready) still requires its separate public contract step. The end state is one typed query shared by native and agent clients, followed by generation-bound pages containing the exact Schedule and live owner information needed to render the visible period. Storage fetch counts and performance require execution evidence.

## Proposed public values

Add `calendar(PlannerCalendarQuery)` to the existing native query request and its `planner_query` encoding. The query contains `startDay` and `endDay` as Gregorian `PlannerCivilDate` values, both inclusive, and `displayTimeZone` as a valid Foundation timezone identifier. Invalid dates, an end before the start, and invalid zones fail before publishing a snapshot. Clients request the period they actually display; changing the display zone changes timed bucketing, never saved instants or all-day dates.

The Calendar snapshot returns its dataset session, generation, full matching count and matching Schedule identities. `calendarRows(generation:offset:limit:)` on the existing read interface returns pages of `PlannerCalendarEntry` values from that generation. Each entry contains `schedule: PlannerEntityReference`, `source: PlannerEntityReference`, `title: String`, and `form: PlannerScheduleForm`. Source is the live Item or Itinerary owner. Titles and forms are captured consistently for that generation. Detail/edit views can separately open the current source; these entries do not carry full notes, labels, links or editing hashes.

Paging follows the existing nonnegative-offset/positive-limit contract without a new arbitrary cap. A changed store or dataset makes an old generation fail with `staleSnapshot`; clients refresh rather than mix old identities with current titles/forms. Snapshot identities use stable ascending Schedule UUID order, retaining the current Schedule-catalog convention. Native layouts derive visual chronological placement from each form; Day/Week/Month do not become query sort modes.

Include every retained Schedule with a valid live owner, including archived owners. Archive alone does not delete a Schedule. Deleted or unresolved owners never become invented entries; unresolved data fails the read rather than silently claiming a complete calendar. Query and page operations perform no domain writes, provider lookup or system Calendar access.

## Proposed date matching

Convert the selected civil-date window into its local start-of-first-day and start-of-day-after-last-day instants using the display zone and calendar arithmetic, without assuming 86,400 seconds per day.

- A timed span with an end matches when it overlaps that half-open instant window. An end exactly at its start boundary does not match; a start exactly at its end boundary does not match.
- A start-only timed Schedule matches when its start lies within that half-open window. An estimate never supplies a synthetic end.
- An all-day Schedule matches when its inclusive civil-date span intersects the inclusive requested dates. An absent end means its single start day. Travel does not change this comparison.

## Required TDD and completion evidence

At the approved public Core query/read/store boundary, cover an empty window; mixed Item/Itinerary owners; exact start/end boundaries; start-only entries; spans crossing the window; inclusive one-day and multi-day all-day entries; Tokyo/Paris display changes; daylight-saving short/long days; and repeated local clock times as distinct instants. Reject invalid windows together without saved-data changes.

Prove complete matching identities, pages without duplicates or omissions, zero/positive paging boundaries, live rename on a refreshed generation, stale pages after form/title/delete/account changes, archived-owner inclusion, deleted-owner exclusion and an unchanged export. A seeded large catalog must record actual storage work, latency and memory for small visible windows. One facade call is not evidence of one database fetch.

Qualify the same encoding through the existing MCP HTTP seam. Native integration retains Q79's wide Calendar and inspector, Q80's UIKit mobile Month/SwiftUI Mac grid, and the separate Day/Week/Month overlap, overflow, accessibility and adaptive-layout gates. Physical sync/account recovery and Apple Calendar export retain their existing scope.
