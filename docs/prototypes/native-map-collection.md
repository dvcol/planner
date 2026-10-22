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

## Sharing an in-flight detail request

The next actual test first reproduced an early unavailable result while Item details still held the same address request. The correction observes the production facade's loading state until it changes, retaining the Map operation while the provider is occupied. No polling clock, extra provider request or production test parameter is added.

The [three-function green](evidence/native-map-collection/detail-in-flight-green/qualification.json) passes shared detail completion, the cancellation slot bound and the real UI deadline. Its unchanged shared-detail test observes one provider call and one resulting location. Matching source/products and zero SQLite unlink diagnostics are retained. This adds the represented shared-address outcome; native Map presentation remains unfinished.

## Ambiguous addresses and changed input

The ambiguity test first failed because multiple candidates became an unavailable result. Its unchanged [two-function green](evidence/native-map-collection/address-choice-green/qualification.json) now exposes the actual candidates without a pin. An unrelated candidate is rejected; choosing the second actual candidate places its coordinates without changing exported Planner data. A real saved-address edit invalidates that earlier choice. Zero matches remain unresolved, then explicit Retry resolves the new address once its provider returns a candidate.

The shared in-flight detail case also passes in that packet. These results cover the represented address-choice/input-binding behavior, not Maps links, native pickers or a physical provider.

## Temporary Maps-link resolution

The Maps-link test first reached the actual loader and failed with the two linked appearances unresolved and no Maps provider request. The unchanged [six-function green](evidence/native-map-collection/maps-link-green/qualification.json) now resolves the first saved Maps link when owned location contains only a name. Repeated appearances share its lookup and keep separate exact choices. Owned pins and owned addresses suppress link lookup. The actual Google search candidate retains its attribution and unverified-place warning. Exported Planner data stays byte-identical.

Address and Maps inputs use the same operation queue and deadline accounting. The address cache, ambiguity, shared-detail, cancellation and real-deadline regressions pass in this packet. A preceding asynchronous XCTest fixture compiler error remains separate from the behavioral red. Maps-link selection, mixed-provider bounds and native Map UI still need their own qualification.

## Exact choices, mixed providers and collection context

The unchanged [Maps-choice red/green](evidence/native-map-collection/maps-choice-green/qualification.json) qualifies a text-only search without an invented coordinate, then a temporary selection of a different saved link for one exact itinerary appearance. Its sibling appearance remains unresolved until separately selected and then reuses the cache. Exported data is unchanged. A request from the earlier namespace is rejected after reload.

The [mixed-provider test](evidence/native-map-collection/mixed-dataset-slots/qualification.json) passes without another production change. Two addresses and two Maps links occupy the four slots across a switch between two real Planner instances/datasets. Finishing one old address admits one new address; finishing one old Maps call admits one new Maps call. Old results never place new pins and abandoned queued inputs never start. Every controlled provider finishes.

The [address-reselection red/green](evidence/native-map-collection/address-reselection-green/qualification.json) retains the candidate set so a choice can be changed without another provider lookup. The stale-address and mixed-dataset cases pass beside it. The [context test](evidence/native-map-collection/filtered-contexts/qualification.json) independently qualifies standalone List membership identities, empty Lists, repeated itinerary branches and cumulative Todo/Active/text filtering. A matching List header admits no nonmatching children. Reads preserve portable data.

## Concurrent saves and coherent restart

Eight real public completion saves interleaved with collection reloads first reproduced the stale error, "Run the query again before requesting this row window." The unchanged [two-function green](evidence/native-map-collection/concurrent-refresh-green/qualification.json) restarts the complete query rather than publishing that stale failure. Exact identities and all owned pins survive each interleaving; the filtered-context case also passes. This tests actual Core saves, without a fake Core, query interception or production test hook.

## Final local qualification

The [final Mac cohort](evidence/native-map-collection/complete-loader-owned-fixtures-mac/qualification.json) executes all twelve production-interface functions together with zero failures/skips or SQLite unlink diagnostics. Its 1,072 frozen source inputs and three actual executable hashes match. The tests use the repository's existing owned-fixture helper. The [disposal report](evidence/native-map-collection/complete-loader-owned-fixtures-mac/fixture-disposition.json) verifies the recorded host has exited and SQLite handles are closed before removing all thirteen fixtures. The earlier twelve-function run remains separately retained; adopting the ownership helper changes test setup, not production behavior.

The [matching mobile build](evidence/native-map-collection/complete-loader-owned-fixtures-mobile-compiler/qualification.json) compiles the supported app, Share and navigation-test targets with five recorded product hashes. This is compiler evidence only. Xcode rejected an earlier direct iPhone attempt before execution because `PlannerMCPTests.xcconfig` explicitly supports `macosx`; that attempt has no passing credit. No target/platform or signing changes were made. Native phone/tablet Map interaction belongs to the existing UI targets.

Q143 remains open for native Map integration, counted-marker/exact-row selection, accessible Locations and candidate/link controls, third-pane/compact navigation, draft protection, representation switching and visual/accessibility/resizing acceptance. Real provider/physical scale and signed capability gates also remain separate. No native Map UI or whole-app completion is claimed by this loader checkpoint.
