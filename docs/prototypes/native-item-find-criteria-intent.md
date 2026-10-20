# Native cumulative Item criteria

Status: the settled cumulative criteria pass at the production Intent boundary. Mac, Simulator and unsigned device products compile. Signing remains deferred.

## Context and goal

The [first Find Items slice](native-item-find-intent.md) supports text, completion, archive, All Items/Inbox scope and sorting. This follow-up adds the remaining settled criteria: shared Categories, Tags and Lists with Any/All matching, owned-address presence, saved-link presence and scheduled/unscheduled state. Criteria narrow together through the existing Core query. It still returns shared Item entities with global completion.

Use typed native entity arrays for identity selections. Names and cached display values never replace saved identities; duplicate selections collapse through Core's identity sets. Empty or omitted groups impose no restriction, including under All matching. Each group selects Any or All independently, and groups combine cumulatively. No source/label content, membership, local completion or presentation preference changes during a Find.

Address means saved owned address data, not a coordinate-only location or information inferred from a Maps bookmark. Links means saved bookmarks. Scheduled state follows existing direct/itinerary references, including retained past bookings, without provider lookup or an estimate-derived end. Duration-range input remains pending under Q115 and is not silently reduced to a different input presentation.

## Test boundary and requirements

Use the existing Q112 production Intent invocation, EntityQuery and real disposable Core/native-store boundaries in PlannerMCPTests. Test public results, not a private mapping helper. No new target, package, Core/MCP query contract, schema, dependency-injection hook or replacement provider is introduced.

Qualify stable identity matching across duplicate names and renames, Any/All and empty groups, cumulative Category/Tag/List/state/text criteria, current Inbox membership and unknown/stale selections according to Core's existing semantics. Verify owned-address and bookmark distinctions, direct and itinerary scheduling, retained past entries and refresh after removal. Keep prior paging, cancellation, unavailable-store and incomplete-recovery checks. Compare read-only portable data and source/reference preservation.

Inspect actual optional-array, enum and Boolean metadata while retaining the existing six Find inputs and Item-array result. Compile matching sources for Mac, Simulator and unsigned device products. Native system pickers, actual invocation/background/locked behavior and physical performance remain separate gates. No signing or installation is performed by this slice.

## Native API fit

The installed Xcode 27.1 SDK provides Apple's [EntityPropertyQuery](https://developer.apple.com/documentation/appintents/entitypropertyquery), which generates an additional property-based Find action. It requires queryable entity properties and supplies a flat overall And/Or mode. Its array [ContainsComparator](https://developer.apple.com/documentation/appintents/containscomparator) compares one element. It does not directly represent Category Any selections AND Tag Any selections AND the other cumulative criteria.

The existing Item entity also lacks those relationship properties and the timestamps/estimate properties needed for native sorting. Core text matching searches authored fields together, so presenting it as Title Contains would misdescribe the search. Adding property-query conformance would require a separately reviewed adapter and properties, including Q117's pending boundary. This slice keeps Apple's standard typed AppIntent fields and existing EntityQuery choices, with a direct mapping to the agreed Core query. This SDK inspection establishes API shape, not actual Shortcuts rendering.

## Executed checks

Each Category, Tag/List and presence/scheduling slice has a missing-parameter red followed by a passing production-interface test. A fourth case verifies unknown identities without changing production code. Tests use duplicate label/container names, stale display names after a live rename, duplicate selections, Any/All, empty and omitted groups, cumulative text/state/group criteria and current membership changes. Portable data stays byte-identical across read-only sequences.

The presence case distinguishes a saved address from a coordinate-only pin, a name-only location and a Maps bookmark. Direct and inherited past bookings remain scheduled through archived Lists/Itineraries; removing the inherited booking updates results while retaining the direct booking. Unknown identities are never matched by name or silently dropped from All criteria.

| Check | Actual result |
| --- | --- |
| [Combined Mac run](evidence/navigation/native-itinerary-window-compatibility/app-intent-item-find-criteria-final-clean/test-results-summary.json) | 35 pass, zero failures/skips: 33 XCTest cases in 17.750 seconds plus two real Calendar HTTP compatibility tests |
| Find-specific cases | Ten pass in 11.062 seconds, including four new criteria cases and existing sorting, paging, cancellation, unavailable storage and incomplete-recovery checks |
| [Fixture lifecycle](evidence/navigation/native-itinerary-window-compatibility/app-intent-item-find-criteria-final-clean/fixture-lifecycle-report.json) | All 33 marked stores disposed after verified host/database closure; no SQLite lifetime diagnostics in the original combined log |
| [Native contracts](evidence/navigation/native-itinerary-window-compatibility/app-intent-item-find-criteria-final-clean/extracted-intent-identifiers.json) | 67 actions, unchanged ten entities/queries, 11 enums. Find retains its six-parameter prefix and Item-array output, then adds three optional entity arrays, three matching selectors, two Booleans and Scheduling |
| [Source comparison](evidence/navigation/native-itinerary-window-compatibility/app-intent-item-find-criteria-final-clean/baseline-source-comparison.json) | Same 1038 frozen inputs; only the existing Find production/test files change relative to the first Find checkpoint |
| [Simulator compilation](evidence/navigation/native-itinerary-window-compatibility/app-intent-item-find-criteria-mobile-compile/exit.json) | App and existing native UI-test target compile with matching inputs/contracts; no runtime credit |
| [Unsigned device compilation](evidence/navigation/native-itinerary-window-compatibility/app-intent-item-find-criteria-device-compile/embedded-products-verification.json) | App and exactly one mobile Share extension compile for arm64; no installation or launch |

All three compiler logs have zero current diagnostics. The collector compares against the recorded clean-base warning packet rather than treating incremental silence as proof that historical warnings were fixed. The first collection command omitted DEVELOPER_DIR and could not find xcresulttool; the corrected command reads the original successful result bundle without rerunning or altering tests.

Evidence packets under [native-itinerary-window-compatibility](evidence/navigation/native-itinerary-window-compatibility/) use the `app-intent-item-find-category-*`, `app-intent-item-find-tag-list-*`, `app-intent-item-find-presence-scheduling-*`, `app-intent-item-find-missing-criteria` and `app-intent-item-find-criteria-*` prefixes. They retain exact commands, exits, logs, source overlays/hashes, result summaries, metadata, product and fixture checks. Strict affected Swift/Markdown lint and platform type checks pass.

## Remaining map work

This implements the settled Category/Tag/List, presence and scheduling criteria. Duration-range input still waits for Q115. Q117's deferred properties and Q118/Q119's Schedule input/choice workflows retain their separate decisions. Actual Shortcuts/Siri invocation, system picker injection, signed Agent Control, shared/account-bound storage and CloudKit implementation/proof, installed Share, physical qualification and feature-complete whole-app UI polish remain open. Compilation and app-hosted tests do not close those gates.
