# Timed Schedule choices in Shortcuts

Status: Q119 A is implemented locally. Four production-provider tests and 22 existing Schedule read/zone cases pass. Actual system picker invocation remains open.

## Context, starting state and goal

At `34856b66`, Set Timed Schedule Timezone uses the general Schedule picker. It can suggest all-day bookings that the action correctly rejects at execution. Q119 A approves native DynamicOptionsProvider choices and direct production `results()` tests against real disposable data in the existing app-hosted target.

## Expected and resulting behavior

The provider reuses the current generation-validated Schedule query and returns only saved timed bookings. Archived owners retain their bookings; current titles and forms are read afresh. Converting a booking to all-day removes it from these choices; converting an all-day booking to timed adds that same identity. Removing a booking removes its choice. The default Schedule query still returns both forms for other actions.

Suggestions do not grant execution authority. The timezone action retains its current-source read and rejects a now-all-day, missing, wrong-kind or deleted selection. It still preserves exact timed instants and owner identity. A read failure throws rather than reporting an empty list. Reading neither mutates data nor acknowledges incomplete recovery.

## Definition of ready and required tests

Q119 A approves the production provider boundary; Q112 covers existing action/query regressions. Tests use actual Planner storage and the SDK's ordinary dependency property assignment, matching existing direct EntityQuery tests. No test-only constructor, manager, confirmation hook, resolver or new target is added.

The first red attempt also had an incorrect fixture field-change spelling. The corrected red fails only for the missing provider. The first implementation run then crashes before its read because direct SDK provider calls do not automatically initialize AppDependency from the manager. Explicitly assigning the real store through the native dependency property corrects the setup. This failed run retains its original log and no passing credit; its marked fixture is removed only after verified host/database closure.

The final run passes 26 tests with zero failures/skips: four provider cases and 22 existing Schedule read/zone cases. They prove live forms/titles, both owner kinds, archived owners, removal, unchanged general choices, precancellation, unavailable storage and reads during actual incomplete recovery without acknowledgment. Existing action tests prove execution rejects stale/all-day choices and preserves fractional/repeated-hour instants. Existing reads also cover multiple pages and Calendar boundaries. All 27 final fixtures and the one initial passing fixture are disposed after host and SQLite closure.

## Validation and definition of done

Mac app-hosted tests, Simulator app/UI-target compilation and unsigned device compilation pass with the same 1,046 frozen inputs. Affected strict Swift/Markdown lint and whitespace checks pass. Extracted catalogs retain all 72 actions, ten entities, ten queries and existing enum cases. The only contract change is the timezone action's Schedule parameter using native dynamic options instead of its explicit general-query binding; its requiredness and entity type remain unchanged. Only alternate `resolvableInputTypes` ordering is normalized during comparisons.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains the `app-intent-timed-options-*` packets, original commands/exits, source epochs, logs, summaries, metadata and fixture dispositions. No schema, Core/MCP, backup, entitlement, target or signing/account change is introduced. Real picker presentation/injection, actual Shortcuts invocation, signed/shared storage and physical tests remain separate gates. Q118 creation inputs and full form edits retain their pending Q124/Q125 review. No map issue is closed by this slice.
