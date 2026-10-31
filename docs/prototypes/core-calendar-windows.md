# Core Calendar windows and typed pages

Core and MCP now return matching Schedule identities for an inclusive civil-date window, followed by generation-bound pages containing each Schedule's saved form and live Item/Itinerary identity and title. Later native integration and storage measurements are linked below.

## Context and goal

Before: Calendar clients discovered the whole Schedule catalog, then separately read forms and owner titles. Those separate reads could cross saved generations. After: `Planner.query(.calendar(...))` captures matching entries consistently, and `calendarRows` pages those captured values. A changed store rejects an old generation rather than mixing it with current data. Schedule UUID ordering preserves stable paging; clients place entries chronologically from their forms.

## Definition of ready

Q81 A accepts the shared query. Q82 A approves its concrete [Core contract](../calendar-window-contract-review.md), including the existing public Core query/read/store and actual MCP HTTP test seams. Fixed instants, inclusive all-day dates, optional ends and archived-owner retention remain accepted. No schema migration, provider lookup or Calendar export is required.

## Definition of done for this step

- Validate Gregorian dates, their availability in the display timezone, the inclusive window order and the zone. Invalid requests publish no snapshot or data changes.
- Match timed overlaps against actual local day boundaries; start-only entries match their start day. Item estimates never fill missing ends. Match all-day entries through inclusive civil dates across travel.
- Capture exact Schedule/owner identities, live titles and forms together. Pages preserve the full count, support nonnegative offsets and positive limits without another cap, and reject stale or unrelated generations.
- Qualify the public Core interface and the advertised MCP query/read grammar. Preserve existing Item/Schedule catalog reads and exported data.
- Pass strict lint and compile the affected native app/test-host graphs. Record actual executions and source hashes.

## Tests and qualification

The initial empty-window tracer failed at the absent API. Timed and all-day tracers then failed at missing matching behavior before their implementations passed. The HTTP tracer first caught the new enum's missing adapter case, then reached the real server and rejected the unavailable Calendar query. It passed after query admission and typed-page encoding were implemented.

Review identified two temporal defects. Public regressions reproduced both before correction: Pacific/Apia's skipped 30 December 2011 normalized to the next day, and Sao Paulo's 4 November 2018 midnight clock change extended the upper boundary into 5 November. Local date round-tripping now rejects unavailable dates, and the upper boundary uses the next day's actual start. The same suite covers New York's 23- and 25-hour days, both repeated clock-time instants, Tokyo/Paris travel and missing ends.

The final Core run passes 12 functions across five suites, with 13 invocations because the all-day test uses two zones. Nine new functions cover Calendar behavior; three existing functions cover Schedule catalog/source regressions. Paging and invalid-input checks preserve the full export. Another writer's owner rename, Schedule edit and confirmed owner deletion invalidate previous pages and refresh the retained identities/forms correctly.

The final authenticated HTTP run passes four functions across three suites, with no failures or skips. It verifies exact typed wire values, schema advertisement, malformed fields/paging, stale generations, unchanged export and existing Item/Schedule query compatibility. Ten affected Swift files pass strict lint. The macOS app/test host and iOS app/native UI test host compile. No native UI functions ran for this step.

Execution evidence retains commands, source hashes, original result summaries and logs. Both review axes have no remaining confirmed implementation findings; adapter documentation now includes the approved wire forms.

## Remaining work

Follow-up work switched native consumers to Calendar windows, added [Day/Week layouts](native-calendar-day-week.md) and [per-device display zones](native-calendar-display-zone.md). The [large-catalog measurements and owner batching](calendar-window-scale.md) now record actual storage work, latency and desktop resident memory. Candidate date fetching, generation-cache retention and physical mobile latency/memory retain their gates.

Account/dataset-transition qualification, physical sync/recovery/Share, temporal/adaptive UI and accessibility, and whole-app polish remain open. Apple Calendar export remains outside the map.
