# Native Tag Intents

Status: name-only Create/Get and live Tag lookup/search/suggestions are implemented. All 16 affected label-adapter cases and Mac, Simulator and unsigned device builds pass. Actual system invocation remains open.

## Context, starting state and goal

At `27fb27a3`, native Planner/Core manage shared Tags and Categories, but App Intents expose only the Category catalog. This slice adds name-only Create Tag, Get Tag and live ID/search/suggestion resolution. Tags remain distinct from Categories and from other same-name Tags. Editing labels/associations and richer fields remain separate work; source deletion stays native.

## Definition of ready

Q33 authorizes ordinary data actions. Q112 A approves the production Intent/EntityQuery boundary with Apple's dependency manager and disposable real Planner storage in the existing app-hosted target. Use the same typed Core commands, canonical queries and process-lifetime fixtures as the Category implementation. No new test boundary, package, target, injected environment, schema or backup format is required.

## Required tests and definition of done

Work executable missing-action reds and following implementations for Create, live identity/Get and search. Reopen real storage to verify returned identities/content. Qualify duplicate names, same-name Category/Tag separation, requested-ID order/deduplication, canonical insensitive cumulative search beyond 64 rows, malformed content/cancellation, missing/deleted/wrong-kind IDs, unavailable storage and real post-save recovery failure without replay. Preserve original logs and dispose owned fixtures only after verified host/database closure.

Run affected Tag/Category adapter regressions and strict lint/type/whitespace checks. Existing production modules remain unchanged; preserve the earlier broader Intent evidence without claiming it was rerun here. Compile actual Mac, Simulator and unsigned device products, verify the complete extracted metadata catalog and Share embedding, and retain source hashes/actual outcomes. Keep actual Shortcuts/Siri discovery/invocation, background/locked execution, signing/account setup, physical tests and whole-map completion as separate gates.

## Executed slices

Creation first fails at its missing action in 0.443 seconds, then passes in 0.198 seconds. The returned ID and authored name survive reopening real storage; color/icon default to nil and Tags have no Done/Archive state.

Live identity/Get first fails at its missing lookup in 0.563 seconds. Canonical source resolution passes the creation and identity journeys together. Requested order is preserved, repeated IDs collapse and missing/wrong-kind sources are omitted. Get resolves a renamed Tag's current name and rejects a Category sharing another existing Tag's current name; it neither guesses by name nor alters that Category.

Search first fails at its missing implementation in 5.436 seconds, then passes in 4.783 seconds. The adapter delegates insensitive cumulative matching and ordering to Core and reads generation-bound 64-row pages. All 65 IDs survive, suggestions include every page and an absent term returns no choices.

Eight Tag cases then pass. Duplicate names retain distinct IDs/lifetimes and canonical ID tie order. Blank names and pre-cancelled creation leave an empty Tag catalog. Native reviewed deletion leaves the selected ID missing while preserving a surviving Tag. Actual unavailable storage rejects choices, identity, Get and Create and preserves the obstructing file.

Actual post-save recovery-file obstruction retains the applied Tag and blocks another creation. Native retry acknowledges the original operation and preserves identity/timestamps without replay; a later explicit creation succeeds independently. These safety checks require no further production behavior change. Timings are XCTest durations, not physical performance claims.

## Combined and platform qualification

All 16 Tag/Category adapter cases pass with zero failures/skips in 10.472 seconds. The actual XCTest summary is retained. The original log contains no compiler warnings or SQLite lifetime diagnostics. All 16 owned fixtures are verified disposed after host exit and closed database handles. The earlier [99-case checkpoint](native-itinerary-entry-intents.md) is retained, not rerun: all of its 997 source/configuration inputs are unchanged. Only the new production Tag file and its test file extend the frozen build inputs to 999.

Mac metadata preserves the complete prior catalog and adds exactly CreatePlannerTagIntent, GetPlannerTagIntent, PlannerTagEntity and its query: twenty-eight actions, seven entities and seven queries. All three existing native enums are unchanged. The actual Simulator app/native UI-target and unsigned generic iOS-device builds pass with matching catalogs/cases. The device app embeds one mobile Share extension; both executables are arm64. All 999 frozen inputs match current source in all three final packets.

Strict affected Swift/Markdown lint, actual platform type checks and final Git whitespace checks pass. No existing production module, Core/schema, target, dependency, transport, backup format, entitlement or native UI changes are introduced. Existing ad hoc Mac configuration is reused; no signing/account setup, physical installation or actual system invocation is claimed.

The evidence directory retains `app-intent-tag-*` source epochs, commands, original logs and actual exits. Expected missing-implementation failures remain failed qualification with separate inspected fixture disposal. Passing runs use the guarded post-host verifier.

Shared-label editing/associations, richer fields and remaining ordinary scheduling/capture/bulk Intents remain on the map. Actual system discovery/invocation, background/locked behavior, native system confirmation and explicit unverified-operation fault qualification remain open. Q100 B signed Agent Control, shared/account-bound storage and CloudKit implementation/proof, installed Share, physical performance and feature-complete whole-app polish also remain open. This slice does not complete the map; signing stays deferred.
