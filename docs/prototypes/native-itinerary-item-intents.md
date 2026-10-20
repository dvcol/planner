# Exact itinerary Item Intents

Status: exact Get and local completion are implemented. All 91 affected adapter cases and Mac, Simulator and unsigned device builds pass. Populated system picker injection remains unqualified.

## Context, starting state and goal

At `2f87fb82`, ordinary Item/List/Itinerary Intents exist, but no action identifies one Item appearance within an itinerary. Repeating Hotel directly or through repeated Lists requires exact association identities and independent local completion. Q114 A selects the Itinerary first, then its scoped native Item picker. The goal is exact live Get and local completion without retargeting, changing shared Item content or copying global completion into local flags.

## Definition of ready

The [Q114 review](../native-itinerary-occurrence-intent-review.md) records the workflow, opaque ID grammar, context labels and system-injection limitation. Q33/Q112 authorize ordinary commands and the production Intent/EntityQuery test interfaces with Apple's actual dependency manager and disposable real storage. The approved SavedItemWindow supplies itinerary metadata, validation and paging. No Core API, test-only production parameter, new target or direct helper test boundary is required.

## Required tests and definition of done

Record executable missing-action reds before Get and completion. Qualify direct/expanded repeats, empty List route positions, live title/List/Itinerary names and saved ordering, UUID case normalization and malformed/version/source/context identity rejection, and reads beyond the first 64-row page. Completion must preserve independent contexts, global precedence, archive semantics, content and schedule/order. Removed/deleted selections and ordinary re-add cannot retarget. Qualify cancellation, unavailable storage and real recovery failure without replay.

Run affected Intent regressions, strict lint/type/whitespace checks, actual Mac/Simulator/unsigned device builds, metadata and embedding checks, and frozen-source verification. Retain actual logs/outcomes and verify fixture disposal only after host exit. Do not claim populated picker injection/search, background/locked invocation, physical execution or whole-map completion from these local tests.

## Executed slices

Get first fails at its missing action in 0.584 seconds, then passes in 0.302 seconds. It resolves the second of two direct Hotel stops with its own local Done flag, current name/context and unchanged source identity. Requested entities retain caller order and collapse duplicate IDs without collapsing distinct stops.

Repeated expanded branches then pass with an empty List between route stops. Renaming the Item, List and Itinerary and changing saved route/child order updates human labels while retaining each exact association identity. Archived Items remain readable and their archive flags do not rewrite local/global completion. A 65-stop read crosses the 64-row boundary, normalizes UUID case, omits invalid/version/missing IDs and retains all requested distinct stops. No selected parent yields no suggestions/search results; that does not prove populated system injection.

Local completion first fails at its missing action in 0.533 seconds, then passes in 0.698 seconds. It changes the selected expanded appearance while preserving direct repeats, other branches, the standalone List, shared content and scheduling. Global Done masks a cleared local flag; global Reopen reveals retained local flags. Archiving the source List retires its branches without rewriting those flags. Saved Manual order and all-day booking survive reopening.

The first additional safety attempt fails to compile because the cancellation-test Task leaves Apple's invocation result ambiguous. The test is corrected with an explicit Void result. No test executes in that attempt; its failed compiler log remains separate from feature reds.

All eight local cases then pass. Direct completion and Reopen persist, while pre-cancelled writes/reads reject. Malformed, foreign, wrong-source, removed and deleted selections cannot retarget or mutate global/local state. Ordinary re-add creates a different Todo stop, leaving the original cached identity missing. Actual unavailable storage rejects reads/choices/Get/completion and preserves the obstructing file.

Actual post-save recovery obstruction retains the applied local Done flag and blocks a later change. Native retry acknowledges the same operation without changing route references/timestamp or replaying completion. A later explicit Reopen succeeds. These safety cases require no further production behavior change.

## Combined and platform qualification

All 91 affected Item/List/Itinerary/Category adapter cases pass with zero failures/skips in 35.450 seconds. The actual XCTest summary is retained. The original log contains no compiler warnings or SQLite lifetime diagnostics. All 93 owned fixtures are verified disposed after host exit and closed SQLite handles. Timings are XCTest durations, not physical performance claims.

Mac metadata preserves the existing catalog and adds exactly GetPlannerItineraryItemIntent, SetPlannerItineraryItemCompletionIntent, PlannerItineraryItemEntity and its query: twenty-four actions, five entities and five queries. The existing four-case placement enum is unchanged. The actual Simulator app/native UI-target and unsigned generic iOS-device builds pass with matching catalogs. The device app embeds one mobile Share extension; both executables are arm64. All 995 frozen inputs match current source in all three final packets.

Strict affected Swift/Markdown lint, actual platform type checks and final Git whitespace checks pass. No Core/schema, target, dependency, transport, backup format, entitlement or native UI change is introduced. The native loader is reused without modification. Existing ad hoc Mac configuration is reused; no signing/account setup, device installation or actual system invocation is claimed.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains `app-intent-itinerary-item-*` packets, source epochs, commands, original logs and actual exits. Expected missing-action failures have separate inspected fixture disposal, retaining failed qualification. The failed cancellation-test compile executes zero tests and creates no fixtures. Passing runs use the guarded post-host verifier.

System-populated dependent choices, search and parent changes, discovery/invocation, background/locked execution and native system confirmation remain open. A deliberately interleaved adapter stale-read failure and explicit unverified-operation fault are not newly qualified by this slice. Top-level route removal/reordering, remaining ordinary Intent fields/catalogs/scheduling/capture, Q100 B signed Agent Control, shared/account-bound storage and CloudKit implementation/proof, installed Share, physical performance and feature-complete whole-app polish remain on the map. The map is incomplete and signing remains deferred.
