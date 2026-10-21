# Native Schedule workflow review

Status: Q118 A and Q119 A accepted on 21 October 2026. Four focused creation actions and the timed-provider production test boundary are approved. [Timed choices are implemented locally](prototypes/native-timed-schedule-options.md). Concrete occurrence and full form-edit inputs remain the next decisions.

## Context and goal

The native adapter now reads saved Schedules and removes individual bookings. A zone-only timed edit is being implemented independently, using the existing Core command. Creation and form editing still need native action inputs.

Keep inclusive civil dates for all-day bookings. Timed creation interprets entered local components in the planning timezone, rejects nonexistent local times and requires an explicit occurrence for repeated times. A zone-only edit preserves the exact saved instants. Estimates never supply a missing end. This review changes none of those policies.

## SDK facts

Installed macOS/iOS 27 compiler probes accept DateComponents with date, time and dateTime kinds. Actual extracted metadata distinguishes civil DateComponents from Date instants. Public conditional summaries can declare separate timed/all-day field presentations. Their inactive fields must still be optional in the declared interface, and Planner must validate the active form at execution.

No public picker-timezone binding was found. Planner can resolve complete civil fields against its separately selected planning-zone entity, but compiler metadata does not prove what the actual system picker renders or coerces. Real Shortcuts input, serialization and invocation remain separate gates.

A DynamicOptionsProvider can offer only timed Schedule entities while reusing the existing Schedule entity/default query. This needs no extra EntityQuery type. Execution still must read the current form and reject an all-day, missing or changed selection; filtering suggestions alone does not enforce the command.

The [SDK evidence recipe](prototypes/evidence/navigation/native-itinerary-window-compatibility/app-intent-schedule-zone-final-clean/civil-sdk-facts-recipe.json) retains the selected probe source, actual extracted metadata and exact reported commands. macOS object compilation and metadata extraction, and the iOS typecheck, have separately recorded exit zero. The standalone macOS typecheck exit was not captured separately. These are compiler facts, not actual system-picker qualification.

## Q118: creation action layout

A. Four focused native actions: timed Item, all-day Item, timed Itinerary and all-day Itinerary. Each has its own required native start input and only relevant fields, with an optional end. The action library gains four entries; selecting the action chooses the form. Recommend this for explicit inputs and straightforward chaining.

B. Two native actions, one per owner kind, with a Timed/All day selector and conditional summaries. The library gains two entries and the form is chosen inside the action. Form-specific inputs must be declared optional, inactive retained fields must be ignored, and execution validates that the selected form's required input exists.

Both use existing Core createSchedule, typed owner identities and exact generated Schedule references. Neither copies source content, changes estimates or replaces the accepted temporal rules. Concrete occurrence input and form-editing choices follow the selected workflow.

## Q119: timed Schedule choices and test boundary

A. Use Apple's production DynamicOptionsProvider to offer timed choices for the zone action, retaining current-form validation during execution. Approve direct results() tests against real disposable Core data in the existing app-hosted target. Verify saved identities, live form/title changes, archived owners, cancellation and unavailable storage. No private-helper tests, test-only hooks, new target/package or replacement query type. Actual system picker invocation stays open. Recommend this for relevant choices and repeatable production-boundary coverage.

B. Keep the existing general Schedule query in this action. The picker may offer all-day entries; execution rejects them with a clear error. This uses only the already approved Intent/EntityQuery boundary, but choosing an inapplicable booking requires a correction after selection.

Q112 names Intent invocation and EntityQuery interfaces. It does not name DynamicOptionsProvider.results(). The TDD skill says, "No test is written at an unconfirmed seam." Q119 A therefore asks for the added production SDK boundary before those tests or provider implementation.

## Readiness and required evidence

Implement the approved four-action layout and timed-only choices at the accepted boundaries. Settle the concrete occurrence and full form-edit inputs before implementing those inputs. Existing temporal policies remain unchanged.

After approval, implement vertical failing/passing slices at the selected production interfaces. Test exact IDs/forms, invalid/incomplete civil input, applicable temporal rules, source state preservation, cancellation, unavailable storage and real recovery failures. Inspect actual parameters/conditional metadata, compare existing contracts and compile the same inputs for Mac, Simulator and unsigned device products. Do not convert compiler facts into actual system-picker qualification.
