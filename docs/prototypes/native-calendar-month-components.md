# Native Calendar Month components

## Context and goal

Before this step, Calendar used a graphical date picker and assembled the entire Schedule catalog through separate form reads. Month browsing lacked saved-entry indicators. The accepted Q80 and Q81–82 end state uses decorated UICalendarView on iPhone/iPad, a SwiftUI event grid on Mac, and the shared generation-bound Calendar window reads. Selecting a date or Schedule preserves its saved identity and never reschedules it.

## Definition of ready

Q80 A approves the platform components and selected-day agenda. Q82 A approves the concrete Core query already qualified in [Core Calendar windows](core-calendar-windows.md). Q79 retains wide Calendar content with optional native inspector details on larger devices. A3 preserves valid selected details outside the current query. The native UI boundary is an approved /tdd seam; no new provider, persistence schema or test-only public parameter is required.

## Definition of done for this step

- Read the visible month through the typed Calendar query and generation-bound pages. Discard partial stale pages and refresh consistently. Preserve loading, error/retry and empty states.
- Decorate scheduled mobile dates using native UIKit decoration and selection APIs. Keep the agenda below the Month on compact layouts and beside it where space allows. Bound the native Month width so neighboring pages cannot leak into the layout.
- Show a Mac month grid with weekday headings, date selection, compact live event titles, full per-day counts and an overflow action opening that day's agenda.
- Keep the selected day inside a browsed month. Today restores the current day. Preserve a valid selected Schedule outside the window, and ensure an obsolete validation read cannot clear a newer selection.
- Verify saved Item/Itinerary details, chronological agendas, deletion, date navigation, relaunch and native inspector behavior through the affected native journeys. Run strict Swift lint and build the affected Mac app/test host.
- Inspect original simulator captures and record executed functions, failures, skips and source/product hashes. Keep wider temporal, overflow, keyboard, accessibility, storage-scale and physical-device requirements open until separately qualified.

## Implementation

Calendar reads typed Schedule/source/title/form entries in pages of 64, restarting after stale-generation rejection. It no longer separately reads every owner and Schedule form. Core's candidate scan and generation retention still need measured storage qualification.

The mobile control wraps UICalendarView directly. Its native custom decoration shows a small dot and exposes the full scheduled-entry count to accessibility. Native selection and month-navigation delegates update the agenda date. ViewThatFits chooses a bounded Month beside the agenda or a vertical layout. The Mac grid uses native Buttons and DatePicker within a SwiftUI seven-column layout, displays two event titles per day, and opens the full agenda through overflow. Its date accessibility descriptions use the explicit display calendar and timezone.

The first iPad layout regression failed because the picker expanded to 788 points. Bounding it to 400 points and adapting the agenda layout passed the same journey; the original capture shows one Month and a side agenda. The phone month-navigation regression failed because browsing left the old selected day outside the newly loaded window. The corrected native delegate selects the browsed month's first day, and the same journey passes. Review also identified an obsolete selection-validation response clearing a newer selection; post-await invalidation now requires selection equality.

## Qualification

Seven iPhone functions across four suites and eight iPad functions across five suites pass across two qualification runs per device, with no skipped functions. The first runs passed five and six functions respectively, then failed deletion and ordering at obsolete DatePicker selectors. Only those two selectors changed; both functions pass on each device in the focused reruns. Production source and the other functions were unchanged. The earlier layout and navigation red/green runs are recorded separately.

Eight changed Swift files pass strict lint. Both source review axes have no remaining confirmed findings. Original iPhone Month, iPad Month, iPad chronological agenda and iPad inspector captures were inspected. The execution record retains commands, source/product hashes, actual result summaries/trees, diagnostic failures and original captures.

The final Mac app/test host builds in a fresh temporary directory. The Mac runtime probe failed before connecting to its test runner, so it executed no journey functions. Developer mode was reported disabled; that observation does not establish the cause of the startup failure. The launched temporary test bundle subsequently rejected linker writes with Operation not permitted. A fresh build directory passed without source changes or system-permission changes. Mac UI behavior remains unqualified.

## Remaining work

Day/Week appointment grids, overlap/overflow fixtures, timezone/DST travel presentation, per-device display-zone override, keyboard/accessibility qualification, compact iPad layouts and large-catalog storage/performance retain their gates. Mac runtime and signed physical sync/account/recovery/Share remain open until demonstrated. Whole-app SwiftUI polish follows feature completion. Apple Calendar export remains outside the map.

## Mac runtime follow-up, 22 October 2026

The recovered Mac UI runtime now reaches native Schedule creation and the saved Month marker through the existing approved journey. Its capture uses Planner's own window. The first invocation fails after 20.974 seconds because the existing mobile assertion reads the marker's empty Mac label. The Mac grid uses native SwiftUI Text, whereas the mobile decoration supplies an explicit accessibility label.

The corrected Month invocation passes in 19.625 seconds. Its actual native StaticText value is 1 scheduled entry; it also verifies the exact saved Schedule identity and live owner title. The original owned-window capture was inspected and shows the selected date's count/title and its agenda entry. Production views, schedules, Calendar queries and persistence remain unchanged. A broad diagnostic query chain remains local; its exact first attribute line and source hash are retained as a scoped observation. The final driver records only the identifier, label and value.

The recovered inspector journey also finds a real Mac resize crash after its native segmented-control lookup is corrected. Planner aborts during live narrowing with details open. The [diagnosis and pending Q127 presentation choice](native-calendar-mac-inspector-resize.md) retain the exact failed runs, owned-window bounds, exception and unchanged acceptance requirements. Those failures receive no passing credit. Unsuccessful production variants are reverted; shared Schedule semantics and the verified List header remain unchanged. Independent Month and display-zone qualification continues with the corrected Mac count-value driver and owned-window captures.

The final Mac Month and display-zone invocation passes three cases with zero failures/skips: all-day override and return to device zone in 50.197 seconds, start-only override/relaunch in 40.483 seconds, and Month identity/count in 20.689 seconds. Actual saved Schedule identities and descriptions remain unchanged. All three deliberate owned-window captures were inspected. They show the scheduled civil date remaining fixed, the timed entry moving to the override's displayed day/time, and the same Month source in its selected-day agenda. Production/configuration inputs match the committed app; this checkpoint changes only native test drivers. Inspector resizing remains failed and Q127 remains pending.
