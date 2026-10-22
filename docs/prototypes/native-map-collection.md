# Native complete Map collection

## Context, before and after

Q143 A approves the [native loader and production-interface test boundary](../native-map-collection-contract-review.md). Core already supplies generation-bound `mapRows`; the native app still has only single-location previews and List presentation windows. The Map must retain every matching saved input independently of those windows, with exact selectable appearance identities and temporary provider results.

The first vertical slice reads 130 real saved Items across three 64-row pages. Owned pins at positions 0, 63, 64 and 129 must all appear immediately. Two share a coordinate and retain separate exact choices. The other 126 Items have no location input. Reading must not call a provider or modify portable Planner data.

## Definition of ready

Use the approved app-internal `SavedMapCollection` interface in the existing app-hosted `PlannerMCPTests` target. Prepare disposable real Planner storage through public commands. Construct the existing address/Maps preview facades with their actual external-provider protocols; observe those calls and the production loader's state/results. Do not inspect private registries, fake Core or add test-only production parameters.

## Required /tdd and definition of done

Declare only enough of the approved interface for a native behavioral red, then implement coherent complete paging and owned-coordinate grouping. Require all 130 identities in query order, exact boundary pins/group choices, correct located/no-input/unresolved counts, no invented collection/List metadata, no provider calls and byte-identical portable data before/after.

Retain the unchanged red/green test, actual source/product evidence and affected strict lint/compiler checks. This first slice does not complete address/link resolution, ambiguity, cancellation/deadlines, stale refresh, List/Itinerary metadata or native Map UI. Those follow one behavior at a time under Q143; physical and signing gates stay separate.

## Owned-coordinate execution, 22 October 2026

The actual app-hosted Mac test first failed against the declared empty loader, returning zero rows instead of 130. The unchanged test then passed in 37.329 seconds after complete paging and grouping were implemented. It verifies exact query-order identities, all four owned pins at the page boundaries, both choices at the shared coordinate, 126 no-input rows, no provider calls and byte-identical portable data before and after the read.

The [green evidence](evidence/native-map-collection/owned-pins-green/qualification.json) records 1,072 matching frozen/workspace source inputs, three actual app/test executable hashes, one executed function, zero failures/skips and no SQLite unlink diagnostics. Its test-file hash matches the [behavioral red](evidence/native-map-collection/owned-pins-red/test-summary.json). This is a local production-interface test, not native Map interaction, physical scale, signed CloudKit or system Shortcuts acceptance.

## Address-cache and repeated-stop execution

The next unchanged test first failed with four unresolved address appearances and no new provider request. After implementation it passed in 0.315 seconds. A cached address is reused, a second address is requested once for its two appearances, and an owned pin suppresses its address lookup. Both pairs retain their exact itinerary-entry identities and query order. Collection metadata and portable-data equality also pass.

The [actual green packet](evidence/native-map-collection/address-cache-native-green/qualification.json) records matching source/products and no SQLite unlink diagnostics. The preceding sandbox-cache denial and one row-identity compiler correction remain separate failed attempts. Neither counts as a behavioral red. The provider test still does not establish bounded concurrency, ambiguity, timeout/cancellation or native Map interaction.

## Occupied provider slots

The cancellation test first failed against the sequential implementation. Its unchanged green passes together with the address-cache regression. Four first-query providers stay occupied after Cancel and a replacement query. Releasing one admits exactly one replacement request; releasing another admits the second. Old results never locate the replacement rows, abandoned queued requests never start, and all controlled providers finish before the test ends.

The [two-function green packet](evidence/native-map-collection/occupied-slots-green/qualification.json) retains actual native execution, matching source/product hashes and no SQLite unlink diagnostics. This establishes the represented Map-operation bound across query cancellation. It does not establish a forced provider timeout, a deadline or external detail requests sharing that bound.

## Real UI deadline and Retry

The next test crossed the actual ten-second interval and first failed because the row stayed loading and Retry issued no new lookup. Its unchanged green marks the current row unavailable while the controlled provider still occupies its slot. Retry waits for that provider to finish, then explicitly retries through the real facade. The expired result does not publish a pin. The new result does, and Cancel removes its published state.

The [final four-function Mac run](evidence/native-map-collection/ui-deadline-green/qualification.json) passes complete offscreen loading, cached repeated stops, query cancellation and deadline/Retry together. It records 1,072 matching source inputs, three actual executable hashes, zero failures/skips and no SQLite unlink diagnostics. The full-row function takes 36.248 seconds and the real deadline function 10.522 seconds. These are functional test durations, not performance benchmarks.

Remaining work under Q143 includes Maps links and explicit choices, ambiguous/failed addresses, existing detail in-flight requests, saved-input/dataset lifetime changes, complete List/Itinerary filter metadata, stale-generation restart, native Map integration and its visual/accessibility journeys. Signing remains deferred.
