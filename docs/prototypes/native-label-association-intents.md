# Label association Intents

Status: all four actions, 32 affected label-adapter cases and Mac/Simulator/unsigned device builds pass locally. Actual system invocation remains open.

## Context, starting state and goal

At `9b4d24e4`, Shortcuts can create, read and rename shared Categories and Tags, but cannot assign them to an Item or Itinerary. Native editors and Core already support these associations. Add typed actions to assign or unassign one selected label, retaining all other labels and owner data. Labels remain live references. Unassigning never deletes the shared label or changes another owner.

## Definition of ready

Q33 approves ordinary organization and guarded content edits. Q112 A approves production Intent invocation through Apple's dependency manager with disposable real Core storage in the existing app-hosted test target. Use that boundary, current owner field hashes and the existing edit commands. Required typed owner/label parameters and an Assigned Boolean match the existing explicit-state completion/archive actions. No Core API, schema, new test boundary, target, dependency or system authority is added.

## Required tests and definition of done

Work test-first through Item Category, Item Tag, Itinerary Category and Itinerary Tag actions. Prove reopening preserves selected and unrelated label identities, shared label content, other owners, notes, route/membership order, local/global completion and bookings. Repeating assignment cannot duplicate a reference; repeating unassignment cannot remove unrelated labels. Missing, wrong-kind and deleted selections reject rather than silently switching targets or recreating data.

Exercise cancellation, unavailable storage and actual post-save recovery obstruction through the approved production boundary. Recovery must acknowledge the original applied operation without replay or loss; blocked mutations must remain blocked. Run affected adapter regressions, strict lint, actual Mac/Simulator/unsigned device compilation, metadata parity and source verification. Dispose owned fixture stores only after the host and SQLite handles close. Actual Shortcuts picker injection, system invocation, background/locked behavior, signing and physical qualification remain distinct open gates.

## Implemented behavior

Set Item Category, Set Item Tag, Set Itinerary Category and Set Itinerary Tag each require one typed owner and one typed shared label. Assigned defaults to true; false removes only that selected association. The adapter resolves both current sources, updates the selected identity set and submits an existing guarded Core edit. It never substitutes a name, changes another label kind or offers source deletion. Missing or deleted labels reject even when unassigning. Current label deletion and field-hash validation remain Core-owned.

Applied changes return a truthful recovery dialog without a fallible post-save lookup. Incomplete recovery preserves the applied change and blocks subsequent mutation. Native recovery acknowledges the original operation; the adapter does not replay it or expose recovery administration.

## Executed test-first slices

Each action first fails compilation at its missing production type. Item Category then passes in 0.550 seconds, Item Tag in 0.304 seconds, Itinerary Category in 0.313 seconds and Itinerary Tag in 0.309 seconds. Existing passing slices are rerun as the shared adapter grows. The first Item Category implementation used an opaque result whose associated value was insufficient for Apple's invocation API; it failed compilation before tests. Matching the existing concrete IntentResultContainer declaration fixes it. That failed packet is retained without runtime credit or created fixtures.

The final nine association cases prove reopen, default assignment, repeated assignment/unassignment, live names despite stale entity display data, unrelated labels and independent owner associations. The strengthened graph includes two ordered List memberships, two independent appearances of the same Item, retained global/local flags and an all-day booking. Wrong-kind, missing and deleted selections cannot switch targets, mutate surviving owner observations or resurrect sources. Precancelled actions leave hashes, timestamps and references unchanged. Unavailable storage preserves the actual obstructing file.

Actual post-save recovery obstruction runs separately for each owner/label combination. All four applied assignments remain readable, another edit is blocked, and native retry acknowledges the same operation without rewriting owner identity, hashes, timestamps, references or completion. A later explicit unassignment succeeds. No additional production behavior change is needed for these safety cases.

## Combined qualification

All 32 association, rename, Category and Tag adapter cases pass with zero failures/skips in 16.346 seconds of XCTest execution. The actual result summary and original log are retained. The final run has no compiler diagnostics or SQLite lifetime warnings. All 37 owned fixtures are disposed after verified host exit and closed database handles. Earlier passing slices dispose another 22 fixtures through the same guarded verifier.

Mac metadata retains every previous action, entity, query and enum case while adding exactly the four assignment actions. It contains 34 actions, seven entities and seven queries. The new parameters resolve to their expected owner/label entity types, are required, and declare Assigned's true default. All 1000 prior frozen inputs are unchanged; the new production and test files bring the final source epoch to 1002 verified inputs. Broader runtime evidence remains retained, without claiming an unrelated full-suite rerun or physical performance result.

The actual Simulator app/native UI-test target and unsigned generic iOS-device builds pass with the same complete metadata catalog, enum cases and parameter contracts. The device app embeds exactly one mobile Share extension; both executables are arm64. All 1002 frozen inputs match the current source for every platform. Strict affected Swift/Markdown lint, platform type checks and Git whitespace checks pass. No dependency, Core/schema, public command, package, target, entitlement or native UI change is introduced. Existing ad hoc Mac configuration is reused; no account/signing setup, physical installation or system invocation is claimed.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains `app-intent-*-association-*` packets, original commands/logs, source hashes, actual exits, fixture verification and metadata. Expected missing-action and concrete-result compiler failures remain failed qualification packets. Metadata extraction and generic compilation do not establish system picker injection or invocation.

Richer editable fields, ordinary scheduling/capture/bulk Intents and actual system discovery/invocation remain on the map. Q100 B signed Agent Control, shared/account-bound storage and CloudKit implementation/proof, installed Share, physical performance and feature-complete whole-app polish also remain open. Signing stays deferred, and the map remains incomplete.
