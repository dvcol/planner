# Cancellation before empty native choices

Status: the common-context fix and 82 affected checks pass locally. Mac,
Simulator and unsigned device products compile. Signing remains deferred.

## Context, starting state and goal

At `3f6c8bdf`, Item Find and identity reads handle precancellation even with
empty results. Category, Tag, List and Itinerary queries check cancellation only
inside result loops. Itinerary appearance and route-entry queries can also
return early for empty/malformed identities or an unselected parent. Those paths
report successful empty choices despite an already cancelled caller.

The existing Q112 EntityQuery boundary and real disposable Planner storage
remain the test interfaces. This is a correction of accepted cancellation
behavior, with no new product choice, public input, entity property, Core/MCP
contract or test hook.

## Reproduction and correction

One production-interface regression exercises 20 empty query paths across the
six affected entity types. It checks identity resolution, text search and
suggestions, including malformed scoped identities and unscoped searches. The
initial attempt puts asynchronous calls in XCTest autoclosures and fails
compilation; that construction error is retained separately. The corrected test
then executes and records 20 actual cancellation failures. Its marked fixture is
removed only after verified host/SQLite closure, without giving that failed run
qualification credit.

The shared SavedPlannerStore.appIntentContext now checks cancellation before
opening storage and after awaiting opening. Every affected query already calls
that method before its empty early return. The two checks therefore fix the
shared path without duplicating logic in six adapters. Ordinary native open
behavior and executeAppIntent's admitted-write/recovery handling stay unchanged.
There is no new cancellation check after an applied mutation.

The regression passes after the fix, while uncancelled empty suggestions still
succeed and exported Planner data remains identical. This proves precancellation
through those public queries. The after-open check is also reviewed, but the
tests do not claim deterministic coverage of every cancellation interleaving
during bootstrap.

## Required qualification

Run affected Item Find, Item, Category, Tag, List, Itinerary, appearance and
route-entry suites, including ordinary creation/editing, paging, unavailable
storage and truthful recovery outcomes. Preserve the real Calendar HTTP
compatibility checks. Verify the original log has no SQLite lifetime diagnostics
and dispose only marked fixtures after test-host/database closure.

Compare the unchanged native action/parameter/output, entity/query and enum
contracts. Compile matching frozen inputs for Mac, Simulator and unsigned device
products; verify the existing single mobile Share extension. Run strict affected
Swift/Markdown lint. Actual Shortcuts/Siri invocation, system picker injection,
background/locked behavior, physical qualification and signing remain separate
map gates.

## Executed local qualification

| Check                       | Actual result                                                                                                              |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Affected Mac run            | 82 pass with no failures/skips: 80 XCTest cases in 96.911 seconds and two real Calendar HTTP declarations in 0.186 seconds |
| Fixture lifecycle           | All 81 marked stores disposed after verified host/database closure; no SQLite lifetime diagnostics                         |
| Native contracts            | All 67 action parameter/output contracts, ten entities/queries and 11 enums unchanged                                      |
| Source comparison           | Same 1038 inputs as the cumulative Find checkpoint; only SavedPlannerStore and the existing Find test file change          |
| Simulator compilation       | App and existing native UI-test target compile with matching source inputs and native contracts; no runtime credit         |
| Unsigned device compilation | App and exactly one mobile Share extension compile for arm64, with the same inputs/contracts; no installation or launch    |

All three current compiler logs have zero diagnostics, with the known clean-base
warning packet retained separately. Strict affected Swift/Markdown lint passes.
This does not claim historical warnings were fixed or that platform compilation
qualifies actual system behavior.

The initial collector guessed 81 passes from method declarations. The actual
result bundle reports 82, including nine Itinerary cases with its separate
extension case. The collector is corrected to that actual result; the count
correction and initial collector remain archived. No test result or production
input was changed or rerun to fit it. Marked fixture counts are recorded
independently from test counts.

Evidence in native-itinerary-window-compatibility uses the
`app-intent-related-empty-cancellation-*` prefix. It retains the
test-construction failure, actual runtime red, closed-fixture dispositions,
green/final logs, original commands/exits, frozen sources, metadata and product
checks. The map remains incomplete; this correction does not qualify actual
system invocation or signing-dependent workflows.
