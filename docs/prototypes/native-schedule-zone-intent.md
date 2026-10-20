# Native planning-timezone change

Status: runtime adapter locally qualified. The final picker choice and any added provider/test boundary await Q119. Signing remains deferred.

## Context, starting state and goal

At f1f36823, native actions read and remove Schedules but cannot change their planning timezone. Core already exposes changeScheduleZone with current form hashes. Scheduling Q13 requires exact saved instants to survive a zone-only edit.

Add Set Timed Schedule Timezone with a saved Schedule and typed planning-Timezone value. Read the current Schedule by UUID and submit its current field hashes through the existing store command. Preserve exact start/end instants, missing ends, Schedule/owner identity, source content/state/references and other bookings. Resolve the timezone by its identity rather than cached display properties.

Reject all-day, missing, removed or wrong-kind choices without converting them or redirecting the operation. A stale all-day display may name a booking that is now timed; the current saved form controls applicability. Cancellation and unavailable storage cannot acknowledge mutation. Applied changes with incomplete recovery remain applied and block another mutation until explicit recovery completes the original operation.

## Definition of ready

Q13 settles the temporal behavior. The existing Core command and Q112 production Intent/EntityQuery boundary are accepted. Use actual AppDependencyManager, callAsFunction, disposable local storage and the existing filesystem recovery obstruction. No Core signature, backup schema, package/target or test-only hook changes.

The current action uses the general Schedule query and revalidates the current form. Q119 proposes offering only timed choices through a native DynamicOptionsProvider and separately asks approval for tests of its production results() interface. That unresolved provider is not implemented or tested here. Q118's creation workflow is independent.

## Required tests and definition of done

Start with a missing-action compiler red, then verify the zone-only command against saved/reopened data. Cover exact fractional starts/ends, absent ends, an explicitly chosen New York repeated-hour instant, typed timezone aliases and stale display properties. Cover Item and archived Itinerary owners, both directions of cached/current form changes, invalid identities, cancellation, unavailable bootstrap and actual incomplete recovery.

Run affected native Schedule reads/removal/timezone regressions and real scheduling/Calendar HTTP cases. Verify closed fixture lifetimes, strict Swift/Markdown lint, actual native parameter/result metadata and preservation of prior contracts. Compile the same source epoch for Mac, Simulator and unsigned generic-device products, checking the embedded mobile Share extension. Record actual diagnostics against the known clean-base warnings.

Actual system picker/invocation behavior, locked/background execution, signing/account-bound storage, CloudKit, Agent Control, installed Share, physical performance/accessibility/layout and final whole-app polish remain open. The pending timed-choice provider means this is runtime-adapter qualification rather than proof of the final picker workflow.

## Local evidence

| Check | Actual result |
| --- | --- |
| [Final Mac run](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-zone-final-clean/test-results-summary.json) | 34 pass, no failures/skips: 30 XCTest cases in 10.276 seconds plus four actual scheduling/Calendar HTTP cases |
| Zone cases | Seven cases pass in 0.539 seconds, covering exact start-only and repeated-hour spans, archived Itineraries, both cached/current form directions, aliases/stale presentation, invalid identities, cancellation, unavailable storage and actual incomplete recovery |
| [Fixture lifecycle](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-zone-final-clean/fixture-lifecycle-report.json) | All 30 marked fixtures removed after host/database closure; no SQLite lifetime diagnostics |
| [Native metadata](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-zone-final-clean/extracted-intent-identifiers.json) | 65 actions; one added action with required Schedule and Timezone entity parameters and no data result. Prior action parameters/results, entities, queries and enums unchanged |
| [Simulator compilation](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-zone-mobile-compile/exit.json) | App and existing native UI target compile; no actual system picker invocation |
| [Unsigned device product](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-zone-device-compile/embedded-products-verification.json) | arm64 app plus exactly one mobile Share extension; no installation or launch |
| Source equality and diagnostics | All three packets contain matching 1035 input hashes and zero current compiler diagnostics. Compared with the previous 1034 inputs, only the production Schedule adapter changes and one zone-test file is added |
| [Strict lint](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-zone-final-clean/strict-lint.json) | Both affected Swift files pass strict swift-format lint |

The compiler collector retains the earlier clean-base warnings in its comparison artifact. These incremental zero-diagnostic builds do not establish that the unrelated baseline warnings have been fixed.

The first test failed to compile solely because the action did not exist. Its implementation passed the initial start-only/reopen case before the safety regressions. The earlier six-case 33-test epoch remains preserved separately; the final epoch adds the timed-Itinerary/current-form case.

No synthetic failure hook is used. Real post-save recovery-directory obstruction leaves the zone edit applied with exact original instants, blocks another edit, and allows explicit recovery to acknowledge only the original operation. The current-form read and Core field-hash precondition protect the mutation; these tests do not force every concurrent interleaving between awaits.

## Pending native workflows

[Q118 and Q119](../native-schedule-intent-workflow-review.md) remain open. No creation workflow or DynamicOptionsProvider is implemented on an assumed answer. The existing general picker can still offer all-day Schedules, which this action rejects using current saved data. Q119 A would narrow suggestions and add its approved production-boundary tests; Q119 B would retain that general picker.

The delegated [SDK probe recipe](evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-zone-final-clean/civil-sdk-facts-recipe.json) preserves actual reported commands, selected source/metadata/logs and their limits. macOS object/constant compilation, metadata extraction and iOS Simulator typecheck have recorded exit zero. The standalone macOS typecheck's exit was not captured separately and remains unknown. None qualifies actual system-picker timezone rendering or coercion.
