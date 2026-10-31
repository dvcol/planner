# Finding Lists and Itineraries in Shortcuts

Status: both actions and 40 affected checks pass locally. Mac, Simulator and
unsigned device products compile. Signing remains deferred.

## Context, starting state and goal

At `b311f707`, Core and native catalogs implement the Q85–Q87 text/archive/sort
contract. Shortcuts List/Itinerary choices still expose text-only search and
alphabetical suggestions. Add Find Lists and Find Itineraries through the
existing Core catalog query, returning the existing typed entities.

Each action takes search text, archive state, sort mode and direction. Defaults
match the existing entity choices: empty text, all archive states and Title
ascending. Sort offers Title, Created, Last updated and Full estimate, with both
directions. Core retains exact/incomplete/unavailable certainty groups and fixed
identity ties. These are source-catalog reads, not a plan's saved manual
child/route order or a completion action. Results do not save a device's sort
preference.

## Definition of ready and test boundary

The shared catalog contract is approved under Q87. Q112 approves production
Intent invocation and EntityQuery interfaces using Apple's dependency manager
and disposable real Planner storage. Reuse the existing List/Itinerary query
loaders for both choices and Find. No new Core/MCP input, property-getter seam,
test-only hook, target or package is needed. Q115 estimate input and Q117–Q119
property/Schedule choices remain separate.

## Required tests and definition of done

Implement vertical failing/passing slices for native filtering and sorting. Test
cumulative text/archive criteria, both directions of every sort,
exact/incomplete/unavailable estimates and manual totals. Expected sequences
come from literal saved fixtures, not another invocation of the production sort.
Preserve source identity/content, manual order, contextual/global completion and
bookings across read-only finds. Verify export equality.

Exercise every page, live changes from another writer, valid empty results,
precancellation, unavailable storage and reads during actual incomplete recovery
without acknowledging it. Retain existing List/Itinerary
identity/search/suggestion and Item Find regressions. Dispose only marked
fixtures after verified host/SQLite closure.

Inspect the two actions' native parameters, entity-array outputs and enum cases
while preserving all prior contracts. Compile matching frozen inputs for Mac,
Simulator and unsigned device products; verify the existing single mobile Share
extension and run strict affected lint/type checks. Actual system invocation,
picker injection, background/locked behavior, signed Agent Control,
CloudKit/shared-storage proof, installed Share, physical qualification and
whole-app polish retain their map gates.

## Literal sorting fixture

Create plans in this order: Long, Partial short, Museum, Overflow, Empty,
Partial long, Manual. Full totals are respectively 300, at least 120, 180,
unavailable, 0, at least 240 and a manual 240 minutes. Incomplete plans each
have one missing child estimate; Overflow contains Int64.max minutes plus one
minute. Manual includes a missing child. Before querying, edit Long's notes
last.

Expected ascending Title is Empty, Long, Manual, Museum, Overflow, Partial long,
Partial short; descending reverses those distinct titles. Created ascending
follows creation order, and descending reverses it. Last updated ascending is
Partial short, Museum, Overflow, Empty, Partial long, Manual, Long; descending
reverses it. Full estimate ascending is Empty, Museum, Manual, Long, Partial
short, Partial long, Overflow. Descending is Long, Manual, Museum, Empty,
Partial long, Partial short, Overflow. These independent literal expectations
apply to each container kind, without changing saved child or route order.

The final fixtures include a locally Done child in Partial short, a globally
Done Museum, an archived Long Item, a direct timed Item booking and an all-day
Itinerary booking. Those states do not change the full-plan estimate order.
Read-only exports preserve their saved values and order.

## Executed checks

The List text/archive test first fails for the missing action, then passes after
its implementation. The sorting test has a separate missing-input/enum red, then
passes all eight mode/direction sequences. The Itinerary action also has its own
missing-action red before passing filtering and every sort. Production changes
are limited to two native actions, three native enums and reusing the two
existing typed catalog loaders; no Core/MCP contract changes are needed.

Four subsequent qualification cases pass without further production changes.
They cover valid empty results, precancellation, actual bootstrap filesystem
obstruction, every page of 65 results per kind, and another writer's
rename/archive reflected in identities, titles, order and filtering. Actual
post-save filesystem faults prove that both Finds read the applied rename
without clearing recovery blockage. Explicit checkpoint retry acknowledges only
the original edit. An initial recovery assertion used an outcome case rather
than the operation-status case; its compiler failure is retained separately from
the corrected runtime qualification.

| Check                         | Actual result                                                                                                                                                                                                            |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Affected Mac run              | 40 pass, zero failures/skips: 38 XCTest cases in 37.918 seconds plus two real catalog-sort HTTP declarations in 2.740 seconds                                                                                            |
| New Find cases                | Seven pass in 15.256 seconds, with filtering/sorting, read-only graph preservation, paging/live refresh, cancellation, unavailable storage and incomplete recovery                                                       |
| Executed-count reconciliation | Original log and actual result summary agree. Every new test method has a passing runtime record; fixture counts are recorded independently                                                                              |
| Fixture lifecycle             | All 40 marked stores disposed after verified host/database closure; no SQLite lifetime diagnostics in the original combined log                                                                                          |
| Native contracts              | 69 actions, unchanged ten entities/queries, 14 enums. Each addition has four defaulted native inputs and the correct existing entity-array output; all 67 prior action contracts and eleven prior enums remain unchanged |
| Source comparison             | 1040 frozen inputs: two existing query files change and the new native action/test files are added. Other prior inputs remain unchanged                                                                                  |
| Simulator compilation         | App and existing native UI-test target compile with matching inputs/contracts; no system runtime credit                                                                                                                  |
| Unsigned device compilation   | App and exactly one mobile Share extension compile for arm64 with the same inputs/contracts; no installation or launch                                                                                                   |

All three current compiler logs have zero diagnostics, with the known clean-base
warning packet retained separately. Strict affected Swift/Markdown lint and
platform type checks pass. The tests establish precancellation and changes
between completed invocations; they do not prove every in-flight
cancellation/change interleaving. These result arrays collect all matches, so
this slice makes no claim of bounded total Core memory or measured physical
performance.

Packets under native-itinerary-window-compatibility use the
`app-intent-container-find-*` prefix. They retain original commands/exits, logs,
frozen source overlays/hashes, result summaries, fixture dispositions, metadata
and product checks. Earlier per-slice results remain separate from final
qualification.

## Remaining map work

These actions implement already accepted catalog queries at the native Intent
boundary. Duration input/ranges still wait for Q115, deferred saved-content
properties for Q117, and Schedule input/choice workflows for Q118/Q119. Actual
Shortcuts/Siri invocation and picker injection, signed Agent Control,
shared/account-bound storage and CloudKit implementation/proof, installed Share,
physical qualification and feature-complete whole-app polish remain open. The
map is incomplete; signing/account setup and device installation have not been
performed.
