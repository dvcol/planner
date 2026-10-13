# Native Calendar destination and Month agenda

Planner has a main Calendar destination, a native graphical date picker and a selected-day agenda backed by saved Item and Itinerary schedules. Calendar entries open the existing source details through their Schedule/source identities. This is the first Calendar implementation step; Day/Week appointment grids remain required.

## Context and goal

Before: users could save schedules from Item and Itinerary details, but could not browse them in a Calendar destination. After: phone tabs and the Mac sidebar expose Calendar; iPad uses native split presentation. A selected day shows its retained assignments, and Today returns to the current day. Date selection never writes or reschedules domain data.

## Definition of ready

Q60 A and Q61 A approve Day/Week/Month and a main destination. Q5/Q6/Q9/Q13 preserve inclusive civil dates, optional supplied ends, fixed instants and display-zone behavior. A3 preserves valid selection after filtering and clears invalid references. Q8 keeps global Item completion in Item details. The [native component investigation](../research/native-calendar-display-components.md) confirms the available date controls and the absence of a public event time grid. Existing Core/native UI seams remain the test boundaries.

## Definition of done for this step

- Use native TabView, NavigationStack/NavigationSplitView, DatePicker, Buttons, ProgressView and ContentUnavailableView. Show loading, failure/retry and empty states from actual saved Schedule reads.
- Discover retained Schedule identities through the existing public catalog/window facade and resolve live owner titles. Do not create copied Items/Itineraries or persist presentation state in backups.
- Project timed spans using native day boundaries in the display timezone. Start-only assignments belong to their start day; an absent end remains absent. All-day dates compare inclusive Gregorian civil fields, without an instant conversion that changes dates across travel.
- Preserve Schedule identities through date selection, Today, source completion and relaunch. Reuse source details, keeping global actions in Item details and contextual actions in Itinerary details. Removed references clear Calendar selection; filters alone do not.
- Show native all-day or timed captions, with Start only explicitly labeled. Details retain their original planning-zone presentation.
- Run focused Core Schedule contracts, four native journeys on phone/tablet, strict lint and the Mac app/test-host build. Inspect exported native screenshots and record actual executed counts.

## Tests and qualification

The first native journey failed at the absent Calendar tab. After adding it, a diagnostic queried the graphical DatePicker as a Button; the native hierarchy showed the picker and the selector was corrected. The saved all-day journey then failed because selecting another month did not narrow the agenda. The Itinerary journey failed because its row did not open source details. The caption check failed because All day metadata was absent. Each corresponding behavior was then implemented through the existing native UI boundary. Review found that reused Itinerary child links lacked a Calendar destination. The expanded journey reproduced the missing contextual notes before the scoped native destination was added. The iPad journey also exposed a collapsed sidebar hiding the New Itinerary action; the test now reveals the native sidebar before using that action.

Four journeys cover the empty Calendar, saved all-day Item identity/date selection/Today/relaunch/global completion, a nonempty Itinerary entry opening its existing live notes and Schedule, then its child appearance details without global Item actions, and a timed start-only caption matching the saved appointment after relaunch. Existing shared tests cover Schedule catalogs/live owners, complete source reads, civil-date validation/recovery and fixed instants/zones.

Final qualification passes four native functions on iPhone and four on iPad, with no failures or skips. Seventeen focused Core functions pass in six suites. Strict lint passes four Swift files, and the Mac app/test host builds; no Mac UI functions ran. Both review axes have no remaining findings. [Execution evidence](evidence/navigation/native-calendar-month-agenda/execution.json) records commands, final source hashes, actual native result trees and original captures. Four captures were visually inspected, including the contextual child route on each device and final all-day/timed agendas. Pending Maps lookup work is excluded from the qualified Core revision.

## Remaining Calendar and map work

Day/Week grids, month event overview/overflow, overlapping assignments, chronological agenda ordering, timed-span boundary/DST/travel UI fixtures, the per-device display-zone override, Calendar editing/selection after external refresh and deletion, paging/performance, accessibility/keyboard and Mac UI runtime retain their gates. Current tests do not qualify those scenarios.

Maps HTTP lookup awaits Q78's controlled transport decision. Capture/Share/Intents/MCP integration, import reconciliation/forms, genuine save-failure/termination, physical iCloud/account/Share checks and whole-app native UI polish remain required. Apple Calendar export remains outside the map.
