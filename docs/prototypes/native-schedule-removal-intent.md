# Native Schedule removal

Status: implemented and locally qualified. Signing remains deferred. The wider map remains open.

## Context and goal

At aa2267c9, six [native Schedule read actions](native-schedule-read-intents.md) expose current saved bookings, but Shortcuts cannot remove one. Core, the app and MCP already support removeSchedule with stable Schedule identities, independent owners and truthful durable-save/recovery outcomes.

Add Remove Planner Schedule through the existing command. Removing one Item or Itinerary booking preserves the source, its content, completion/archive state, route/memberships and every other booking. Resolve the selected Schedule UUID rather than its cached title, form or owner. Missing, wrong-kind or already removed identities fail. Removal does not introduce source Delete, Trash, bulk mutation or Apple Calendar export.

## Definition of ready

The underlying scheduling/removal policies and ordinary Intent authority are accepted. Q112 approves the production Intent invocation, EntityQuery and real-store test boundary. Use Apple's dependency manager, actual callAsFunction invocation, existing local Core commands and actual filesystem recovery faults. No additional test seam, package, target, test-only production parameter or Core/MCP signature change is needed.

## Required tests and definition of done

Start with a missing-action compiler red, then execute production removal against disposable storage and verify reopened results. Cover Item and Itinerary owners, retained other bookings, independent source state and references, missing/wrong-kind/already removed choices, cancellation and unavailable bootstrap. A real post-save recovery failure must retain the applied removal, block another mutation and complete only through explicit recovery of the original operation.

Run the affected native Schedule/timezone reads and actual Calendar/Itinerary scheduling HTTP regressions. Require strict Swift/Markdown lint and Mac, Simulator and unsigned generic-device compilation at matching source hashes. Inspect generated metadata for one additional typed Schedule parameter, no data return and unchanged existing contracts. Verify the device app's single mobile Share extension, without installation or signing changes.

Actual system Shortcuts invocation, confirmation/picker behavior, launch/lock restrictions, physical qualification, account/shared storage and CloudKit, Agent Control, installed Share and final whole-app polish remain separate open gates. Creation/editing of Schedule forms and other map features remain work after this action.

## Fixture-lifetime diagnosis

The first combined run passed its 27 behavior tests, but the existing verifier rejected its SQLite lifetime diagnostics. The original log and failed lifecycle record remain in the unqualified packet. Its 21 marked Intent fixtures were removed only after independently checking host/database closure.

A [clean-base reproduction](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-removal-http-base/base-reproduction.json) uses exactly the 1033 inputs from aa2267c9, with no new action or working-tree overlays. Both existing Itinerary scheduling HTTP tests delete their temporary directories before all Core SQLite handles close. The base run reports unlink/descriptor violations for three SQLite files.

[8056a7c7](https://github.com/dvcol/planner/commit/8056a7c708ce62e01b3bd026ffa83ee7d283f8bd) changes only those tests to use the existing marked-fixture factory. Their planner configuration and HTTP assertions remain unchanged. Two real HTTP cases plus one existing native read pass against otherwise committed sources, with no compiler/lifetime diagnostics. The [lifecycle verifier](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-http-fixture-lifetime-green/fixture-lifecycle-report.json) safely disposes all three stores after host exit. This test-only correction is committed separately from the removal feature.

## Final local evidence

| Check | Actual result |
| --- | --- |
| [Final Mac results](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-removal-final-clean/test-results-summary.json) | 27 tests pass with no failures/skips: 23 XCTest cases in 9.573 seconds and four actual scheduling/Calendar HTTP cases |
| Removal cases | Six cases pass in 0.460 seconds, covering both owner kinds, archived plans, retained source state/references, other bookings, rejected identities, cancellation, unavailable storage and real incomplete recovery |
| [Safe lifecycle](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-removal-final-clean/fixture-lifecycle-report.json) | All 23 marked stores removed after verified host/database closure; no SQLite lifetime diagnostics |
| [Native metadata](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-removal-final-clean/extracted-intent-identifiers.json) | 64 actions, ten entities/queries and four AppEnums; existing action parameters/results, entities, queries and enums unchanged |
| [Simulator compilation](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-removal-mobile-final-clean/exit.json) | App and existing native UI target compile; no system UI tests run |
| [Unsigned device build](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-removal-device-compile/embedded-products-verification.json) | arm64 app plus exactly one embedded mobile Share extension; no installation or launch |
| Source comparison | All three platform packets use matching 1034 input hashes. Compared with the prior 1033 inputs, changes are the action, shared test-fixture visibility and separately committed HTTP cleanup; one removal-test file is added |
| [Strict lint](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-removal-final-clean/strict-lint.json) | All four affected Swift files pass |

The [compiler comparison](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-removal-final-clean/baseline-compiler-diagnostics.json) records one existing redundant-require macro warning from ItemLabelQueryRoutingTests in the final Mac run. The same warning is present in the clean committed-base build. No introduced compiler diagnostics appear; Simulator/device compilation emits none. The clean-base full recompilation also exposes existing unnecessary-try and unused-value warnings outside this change, retained in the comparison artifact. Incremental builds with zero diagnostics do not establish that those baseline warnings are gone.

An applied removal with incomplete recovery returns its truthful applied dialog, retains the removal and blocks another mutation. Explicit native recovery completes the original operation without repeating it or removing the second booking. Unverified outcome handling follows the existing store/Intent policy; this slice does not manufacture an unverified fault with a test hook or claim system dialog presentation is qualified.

## Remaining work

Schedule creation/editing, other native fields and capture/bulk coverage remain on the map. Q115 estimate input and Q117 deferred content-property decisions remain pending. Actual Shortcuts/Siri invocation, launch/lock restrictions, signed/account-bound storage, CloudKit, Agent Control, installed Share, physical performance/accessibility/layout checks and feature-complete whole-app polish remain open. This slice changes no app layout, signing setup, backup format or public Core/MCP contract.
