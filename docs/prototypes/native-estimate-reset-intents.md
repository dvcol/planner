# Estimate reset Intents

Status: all three actions, ten reset cases, 41 affected adapter cases and Mac/Simulator/unsigned device builds pass locally. Q115 remains pending for estimate input and does not govern these explicit clearing operations.

## Context, starting state and goal

At `388a48a0`, native editors and Core can clear an Item's activity estimate or remove a List/Itinerary's manual overall estimate. Shortcuts cannot perform those ordinary changes. Add Clear Item estimate, Use calculated List estimate and Use calculated Itinerary estimate using existing typed commands. These remove only the selected estimate setting; Core recalculates live full/remaining summaries. Shared content, contextual completion, saved order and Schedule forms remain intact.

## Definition of ready

Q33 accepts ordinary guarded edits; the manual-estimate contract explicitly defines clear as returning to calculation. Q112 A approves production Intent invocation with Apple's dependency manager, disposable real Core storage and actual filesystem recovery faults in the existing app-hosted target. Reuse that boundary and current field hashes. No new duration input, conversion, aggregation formula, schema, command, target or test hook is proposed.

## Required tests and definition of done

Record a missing-action red and passing implementation for each owner kind. Reopen real storage to prove the Item estimate or selected manual override is nil, while source identities/lifetimes, other content/hashes, ordered references, local/global/archive states and bookings survive. Container summaries must return Core's exact or uncertain calculations, including repeated List appearances, independent completion and missing child estimates. Resetting an empty plan retains No items.

Qualify repeated reset, missing/wrong-kind/deleted selections, cancellation, unavailable storage and actual post-save recovery obstruction without replay. Run affected native adapter regressions, strict lint and Mac/Simulator/unsigned device compilation. Verify extracted metadata/embedding and frozen source hashes; dispose fixture stores only after host exit and closed SQLite handles. Actual system invocation and physical qualification stay open, and signing remains deferred.

## Executed slices

The first fixture incorrectly expected List source reads to expose a lifetime property. That compiler-only failure is retained without feature-red or runtime credit. The check now uses the existing source identity and unchanged lifetime-bound field hashes; Item/Itinerary lifetime properties are also checked directly. No Core read API is added. The corrected Item red fails only at its missing production action. Its implementation then passes in 0.658 seconds.

The fixture has two ordered List memberships, the same List referenced twice in an Itinerary, a separate direct Item appearance and independent local flags. Clearing the 90-minute Item estimate preserves the 240-minute List and 480-minute Itinerary manual budgets. Their derived reads retain the missing-time uncertainty; the List's remaining time is an upper bound of 240 minutes with one finished estimate missing. All other content fields, labels, source identities, references, completion/archive and timed/all-day bookings survive reopening.

List reset first fails at its missing action, then passes in 0.499 seconds. It clears only the List manual override, yielding 120 full minutes and 30 remaining. Both live List appearances update the Itinerary's calculated total from 570 to 330 minutes, while that Itinerary retains its own 480-minute manual total and 390-minute remaining estimate.

Itinerary reset first fails at its missing action, then passes in 0.396 seconds. It preserves the List's 240-minute manual budget and its independent standalone completion. The Itinerary returns to 570 calculated full minutes and 480 remaining, accounting for only its own one finished appearance. Repeated reset preserves every association and booking. Timings are XCTest durations, not physical performance measurements.

## Safety and affected regression evidence

All ten reset cases pass. Clearing all three settings keeps missing estimates explicit: the List has a 30-minute lower bound with one missing estimate and 30 remaining; the Itinerary has a 60-minute full lower bound with three missing estimates and a 60-minute remaining lower bound with two missing estimates. No adapter calculation is added. Empty plans return to calculated zero while retaining No items. Archived and globally Done sources retain their own states and differing local appearance flags.

Missing/wrong-kind selections reject without changing any observed source field, timestamp or relationship. Native reviewed deletion invalidates the selected source; reset cannot resurrect it or change the surviving unrelated Item. Precancelled resets preserve data and contexts. Unavailable storage rejects all three actions and retains the actual obstructing file.

Actual post-save recovery obstruction runs separately for Item, List and Itinerary. Each applied reset persists, another mutation stays blocked, and native retry acknowledges the same operation without rewriting content, timestamps, relationships or completion. A later explicit reset of another still-set estimate succeeds. The adapter reports applied/incomplete and unverified outcomes through the established result handling without a fallible post-save lookup. An explicit unverified-operation fault remains a separate open qualification gate.

The combined run passes all 41 reset and affected Item/List/Itinerary adapter cases with zero failures/skips in 11.485 seconds. Its actual summary and original log are retained with no compiler diagnostics or SQLite lifetime warnings in the final run. All 43 final fixtures, and 18 from earlier passing slices, are disposed only after verified host exit and closed database handles. Compiler-only missing-action and fixture-correction failures retain failed qualification and no runtime credit.

## Platform and source qualification

Mac metadata retains all 34 prior action identities and adds exactly the three reset actions, giving 37 actions, seven entities and seven queries. All prior enum cases and existing Item creation/editing parameter contracts remain unchanged. Each new action has exactly one required owner of its correct native entity type. There is no duration/unit/count input while Q115 remains pending. All 1003 prior source inputs are unchanged; the two new production/test files bring the verified current epoch to 1005 inputs.

The actual Simulator app/native UI-test target and unsigned generic iOS-device builds pass with matching catalogs, enum cases, new owner parameters and retained Item parameter contracts. The device app embeds one mobile Share extension; both executables are arm64. All 1005 current input hashes verify for every platform packet. Strict affected Swift/Markdown lint, actual platform type checks and staged Git whitespace checks pass. No Core/schema, public command, dependency, package, target, entitlement or native UI change is introduced. The existing ad hoc Mac configuration is reused; no signing/account setup, physical installation or system invocation is claimed.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains `app-intent-*-estimate-reset-*` and `app-intent-estimate-reset-*` packets, original commands/logs, actual exits, source hashes, summaries, metadata and fixture verification. Narrow adapter evidence does not establish actual Shortcuts system picker/invocation, background/locked behavior, physical performance or whole-map completion.

[Q115](../native-estimate-intent-input-review.md) still needs a duration-input presentation choice. Estimate setting/reads, other richer content and remaining scheduling/capture/bulk Intents stay open. System invocation, signed Agent Control, shared/account-bound storage and CloudKit implementation/proof, installed Share, physical qualification and feature-complete whole-app UI polish retain their separate gates. Signing remains deferred.
