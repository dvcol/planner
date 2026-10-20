# Native Schedule end clearing

Status: production-interface runtime qualified locally; Mac, Simulator and unsigned device products compile. Signing remains deferred.

## Goal and behavior

Before this slice, Shortcuts can read and remove a booking or change a timed booking's planning timezone. It cannot clear an optional end independently. The new Clear Schedule End action keeps the booking identity, owner and current start. Timed bookings retain their exact instant and planning-zone identifier; all-day bookings retain their civil start and become single-day. Activity estimates never supply a replacement end.

The action reads the current saved Schedule through Core, builds the same form without its end, and submits the existing complete-form hash with editSchedule. Cached entity presentation does not determine the form or start. Rejected and unverified outcomes throw useful errors. An applied change with incomplete recovery remains applied and reports that recovery is incomplete; further changes wait for explicit recovery.

This uses the existing Q112 production Intent invocation boundary, Apple's dependency manager and disposable real Planner storage in PlannerMCPTests. No new test seam, dependency, package, target, Core command, schema or backup format is added.

## Qualification

The first attempted test had fixture compilation errors; they were corrected before implementation. The separate feature-red run then failed solely because ClearPlannerScheduleEndIntent did not exist. An all-day test assertion also needed the correct optional-Bool comparison. Preserve these logs rather than treating test compilation errors as clean feature reds.

The [first timed case](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-end-green/exit.json) passes in 0.350 seconds. It reopens the original booking after clearing a repeated-hour span, preserving a fractional start, the current New York zone, source state/references, the separate 90-minute activity estimate and both other bookings. Its marked fixture is removed only after host and database closure.

The final seven cases cover current fractional/repeated-hour starts, stale entity presentation, both saved forms, archived owners, absent ends, preserved source state and other bookings, invalid identities, precancellation, unavailable storage and real post-save recovery failure. Reopen checks use public Core reads. The applied-change test initially expected receipt status to be available during the archive obstruction. Core correctly returns unavailable then. The corrected test reads applied Schedule data during the fault, verifies the original incomplete receipt after restoring archive access, then explicitly retries recovery. The failed run and its safe fixture disposal remain recorded separately; it receives no qualification credit.

| Check | Actual result |
| --- | --- |
| [Final Mac run](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-end-final-clean/test-results-summary.json) | 41 pass, no failures/skips: 37 XCTest cases in 11.473 seconds plus four actual scheduling/Calendar HTTP cases |
| End-clearing cases | Seven pass in 0.721 seconds |
| [Fixture lifecycle](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-end-final-clean/fixture-lifecycle-report.json) | All 37 marked fixtures removed after host/database closure, with no SQLite lifetime diagnostics |
| [Native metadata](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-end-final-clean/extracted-intent-identifiers.json) | 66 actions. The new action has one required Schedule entity parameter and no data result. Prior action parameter/results, entity, query and enum contracts are unchanged |
| [Source comparison](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-end-final-clean/baseline-source-comparison.json) | 1036 inputs; only the Schedule adapter changes and one end-clearing test file is added relative to the previous 1035 inputs |
| [Strict Swift lint](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-end-final-clean/strict-lint.json) | Both affected Swift files pass |
| [Simulator compilation](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-end-mobile-compile/exit.json) | App and existing native UI target compile, with the same 1036 inputs and native contracts |
| [Unsigned device product](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-end-device-compile/embedded-products-verification.json) | arm64 app and exactly one mobile Share extension compile, with the same 1036 inputs and native contracts; no installation or launch |

The current three platform builds emit no compiler diagnostics. The collector retains and compares known clean-base warnings separately; incremental silence does not prove that unrelated baseline warnings have been fixed. Field-hash protection uses the actual Core command; this slice does not force every concurrent interleaving between the adapter's reads and save.

Actual Shortcuts/Siri discovery, invocation, pickers, background/locked execution and physical-device qualification remain open. Compiler metadata and app-hosted calls do not prove those system behaviors. Q115, Q117, Q118 and Q119 remain unresolved; this slice chooses no pending workflow. Shared/account-bound storage, CloudKit, Agent Control, installed Share and final whole-app native polish remain on the map.
