# Native Category Intents

Status: name-only Create/Get and Category lookup/search/suggestions are implemented and locally qualified. All 83 affected adapter tests and Mac, Simulator and unsigned device builds pass. Actual system invocation remains open.

## Context and goal

At `fdf038d8`, native Planner and Core manage shared Categories, but App Intents cannot create or resolve them. This slice adds name-only Category creation, live identity lookup, Get Category and canonical search/suggestions. Duplicate names remain separate identities. Category colors/icons and association actions are separate work; source deletion remains native.

## Definition of ready

Q33 authorizes ordinary data actions. Q112 A approves testing production Intent invocation and EntityQuery interfaces with Apple's dependency manager and disposable real Planner storage in the existing app-hosted target. This slice uses those same interfaces and canonical Core commands/reads. No new test boundary, package, target, injected environment or storage format is required. Fixtures remain alive until the host exits.

## Required tests and definition of done

Begin with an executable missing-creation red, then implement creation and verify the returned identity/content after reopening real storage. Follow with live identity/Get resolution, duplicate names, canonical search across multiple pages, invalid/cancelled requests, missing/deleted/wrong-kind identities, unavailable storage and actual post-save recovery failure. Applied-but-recovery-incomplete outcomes must remain applied without silent replay. Preserve original logs and verify fixture disposal after host exit.

Run affected adapter regressions and strict lint/type checks. Compile the actual Mac, Simulator and unsigned device products, inspect extracted metadata and Share embedding, and retain source hashes and actual exit codes. Do not claim actual Shortcuts/Siri invocation, signed storage, physical execution or whole-map completion from these local checks.

## Executed slices

Creation first reaches the intended missing action and fails in 0.316 seconds. The initial implementation check exposes a test-query error: Category catalogs require archive All because Categories have no archive state. The original failed attempt is retained; correcting that query requires no creation change and the reopen journey passes.

Live identity/Get lookup then fails at its missing implementation in 0.437 seconds. Canonical source resolution makes both creation and live lookup pass. Requested IDs retain their order, duplicates collapse, missing/wrong-kind IDs are omitted, and a cached entity resolves the Category's renamed value. Get rejects a missing identity rather than substituting another Category.

Search first fails at its missing implementation in 5.182 seconds. Delegating to Core's unrestricted Category catalog and generation-bound 64-row pages passes the same case in 4.782 seconds. All 65 results remain in canonical order, cumulative terms match case/diacritic-insensitively, suggestions include every page and an absent term returns no choices. Duplicate-name creation retains separate IDs/lifetimes and canonical identity ties.

Eight Category cases then pass together. Invalid whitespace names and pre-invocation cancellation leave no saved Categories. Native reviewed deletion leaves the removed ID missing and preserves the surviving Category. Actual unavailable storage rejects choices, ID lookup, Get and Create without replacing the obstructing file or acknowledging success.

Actual post-save recovery obstruction retains the returned Category and blocks further creation. Native recovery acknowledges the same operation and preserves its timestamps/identity. No automatic creation replay occurs; a later explicit creation succeeds independently. These safety cases need no additional production change.

## Combined and platform evidence

All 83 affected Item/List/Itinerary/Category adapter cases pass with zero failures/skips in 28.452 seconds. The actual XCTest summary is retained. The original log contains no compiler warnings or SQLite lifetime diagnostics. All 85 owned fixtures are verified disposed after host exit and closed database handles. Timings are XCTest durations, not physical performance claims.

The Mac catalog preserves every existing action/entity/query and adds exactly Create Category, Get Category, PlannerCategoryEntity and PlannerCategoryEntityQuery: twenty-two actions, four entities and four queries. The existing four-case placement enum is unchanged. Simulator app/native UI-target and unsigned generic iOS-device compilation pass with matching catalogs. The device product embeds one mobile Share extension; both executables are arm64. All 993 frozen inputs match current source in all three final packets.

Affected strict Swift/Markdown lint and final Git whitespace checks pass. No Core contract/schema, dependency, backup format, target, entitlement or native UI change is introduced. Existing local ad hoc Mac configuration is reused; no physical installation, actual system invocation or signing/account setup is claimed.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains `app-intent-category-*` packets, original commands/logs/source epochs and actual exit codes, including the erroneous test query. Expected missing-implementation fixtures are separately inspected/disposed with qualification still recorded as failed. Passing runs use the guarded fixture verifier.

Tag parity, richer Category fields/associations and remaining ordinary Intents remain on the map. [Q114 A](../native-itinerary-occurrence-intent-review.md) settles Itinerary-first exact-appearance selection; its implementation and actual system picker injection remain open. CloudKit/account-bound shared storage, signed Agent Control, installed Share, physical qualification and feature-complete whole-app polish also remain open. This slice does not complete the map.
