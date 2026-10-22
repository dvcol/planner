# Native Map collection contract review

Status: Q143 A accepted. Q131-Q142 settle the collection workflow and shared saved-data read. The user approves the app-internal loader, temporary resolution lifecycle and additional direct test seam described here. Implementation and qualification remain open.

## Context, before and after

Core's `mapRows` now supplies every matching Item or appearance, independent of visible List pages. Native details already have owned-coordinate maps, address previews and saved Maps-link previews. There is no aggregate collection Map loader or marker-choice state.

The detail preview facades intentionally have different lifetimes. Address requests share pending work and may finish/cache after a detail disappears. Maps-link requests reject obsolete publication but do not deduplicate pending calls. Their caches can evict entries. Neither facade retains the complete matching Map result or limits Map-created work across filter changes.

The end state is one app-internal `SavedMapCollection` for a main window. Views receive a coherent complete matching set, location-resolution states and exact marker choices through its small production interface. Keep the existing detail preview behavior. Do not turn provider coordinates into saved content, modify completion or add a package/target.

## Production interface

Construct the module with the existing `PlannerAddressPreviews` / `PlannerMapsPreviews` facades. Each reload receives the actual Planner and dataset session together, so one window can preserve occupied-operation accounting across dataset changes. These are production dependencies already used by details. Their existing provider protocols remain the controllable external I/O seams; no test-only initializer, callback, clock or debug setting is added.

Expose:

- `reload(planner:session:query:identity:)`, using the same typed Item query and `SavedItemWindowIdentity` dataset/revision value as the collection's List representation.
- `cancel()`, stopping queued work and obsolete publication when Map closes or its query/dataset changes.
- Observable loading/ready/failure state, complete rows and List-branch metadata, located/unresolved/no-input counts and per-input resolution state.
- Exact-row Retry, Maps-link choice and ambiguous-address candidate choice. Choices retain the full row identity and exact source/input binding; they are temporary to this window's Map state.
- Located groups keyed by identical coordinate values, with all exact row choices in original query order. Grouping never substitutes source identity for appearance identity.

The module retains every current matching row and resolved position independently of the List's 64-row presentation windows and preview-cache eviction. It does not retain full notes or complete Item forms. Complete Map inputs are intentionally not a bounded-memory promise; physical performance remains to measure.

## Complete loading and selection

1. Issue the existing Item query, then read all `mapRows` pages in bounded 64-row batches. Validate each page's generation, count, exact identities and repeated collection/branch metadata. Do not publish a mixture of generations. Stale reads restart the complete collection; other failures are visible.
2. Publish coherent saved inputs before resolving missing coordinates. Owned pins appear immediately. Items without location inputs remain in the accessible Locations list and counts.
3. Use the existing detail precedence: owned coordinates, otherwise an owned address, otherwise the selected saved Maps link, initially its first saved Maps link. An owned location with only a name does not block a usable saved link. Multiple address candidates require an explicit native choice; zero/failed candidates remain unresolved. Google search-location previews retain their existing uncertainty wording.
4. Repeated appearances share work for the same exact source lifetime/input while preserving their separate selectable identities. A repeated source is not collapsed into one completion context. Matching List headers never cause nonmatching children to appear.
5. Preserve a valid selected detail across representation switches and filtering. An actually removed Item/appearance follows the accepted invalid-selection rule. Pin and Locations-list choices open the existing typed detail; they never rebuild an action target from title, route number or coordinate.

## Bounded work, timeout and cache rules

Reuse available temporary detail-cache values. Submit at most four distinct Map preview operations at once, deduplicated by the existing namespace/source-lifetime/address-byte or link-identity/original-URL keys. This is a bound on Map operations, not a claim that unrelated detail views cannot also request previews.

An address already loading through a detail is observed until its terminal cache state, rather than treated as an empty result or started again. Map-created work uses the existing facade/provider I/O. Cache eviction after publication does not remove a current pin.

A ten-second Map UI deadline marks an unresolved attempt unavailable and offers Retry. Cancellation or timeout prevents its result from publishing into an obsolete request. A source/lifetime/address/URL edit or dataset change also invalidates prior choices. A new epoch can use only correctly bound cache values.

Do not equate a stopped UI wait with a stopped provider. A canceled/timed-out operation continues to occupy its Map slot until its facade/provider await actually terminates. Preserve operation accounting across reloads in this window. Retry queues behind occupied slots; it does not create an unbounded second set. Shared address work keeps its existing ability to finish/cache after caller disappearance. Thus a noncooperative provider can delay later lookups, but cannot cause unlimited replacement work. The UI must explain pending/unavailable locations and remain usable.

Do not use a TaskGroup race as proof of a hard timeout: a group waits for its children. Apple HTTP timeout/cancellation and MapKit cancellation have separate adapter evidence. This proposal promises a responsive UI deadline and bounded Map work, not forced termination of arbitrary provider code.

Temporary results and choices stay outside Core data, JSON backups, operation receipts and app-state restoration. Cancel clears current Map publication/queued work. Retained in-flight draining work holds only its bound request until completion. Closing the window does not authorize new work.

## Definition of ready

Q143 A approves this concrete app-internal interface and its direct tests. The existing public Core/HTTP seam remains unchanged. Native Map UI testing is also approved, but it cannot deterministically establish every delayed-provider case.

The approved additional seam is the production `SavedMapCollection` interface in the existing app-hosted `PlannerMCPTests` target, using disposable real Planner storage and the existing controlled address/Maps provider protocols. Observe public state/results and actual external-provider calls. Do not inspect private task registries or replace Core with a fake.

## Required /tdd and definition of done

Work through one failing behavior and minimal implementation at a time:

- Read 130 matching rows with saved pins at literal page boundaries. Verify all exact identities, List metadata, no-input counts and pins beyond loaded List presentations. Cover empty, header-only, cumulative filtered and repeated-entry collections.
- Reuse available cache results; resolve missing inputs through the real facades. Verify repeated appearances share a request and still yield separate choices. Cover owned-pin/address/link precedence, multiple link selection and zero/one/multiple address candidates without guessing a pin.
- Use controlled provider completions to observe the four-operation bound. Cross a real UI deadline, cancel or reload while a provider ignores cancellation, then finish it. Assert no obsolete publication and no early replacement slot release. Release every controlled operation before the test ends.
- Edit saved input or source lifetime, switch dataset/query, refresh after an independent real writer and retry a failed lookup. Verify exact input binding, coherent refresh, and unchanged portable data.
- Through actual native UI, select counted coincident pins and every exact choice, including two appearances of one Item. Check local completion scope, accessible Locations fallback, no-location/error/retry states, third-pane details, compact pushed details and representation switching.
- Qualify narrow/wide layouts, long plan titles, light/dark mode, increased contrast, larger text and keyboard/VoiceOver access using native Map, List, Menu, Picker, ProgressView and system presentation controls. Requalify affected List/draft navigation.

This module slice is done when its approved production-interface tests, native integration, affected strict lint/compiler checks and represented native runtime journeys pass with exact source/product evidence. Native Map interaction, live SDK behavior and physical scale remain separately reported where unexecuted. Signing remains deferred.

## Alternatives and impacts

A approves the module and direct tests above. It centralizes complete paging and temporary lookup coordination, gives repeatable cancellation/ambiguity evidence, and preserves the existing detail cache semantics. It adds one app-internal production module and test seam.

B keeps only the existing public Core, provider and native UI tests. Implement the same accepted Map workflow through native UI, without direct loader tests. This avoids an added direct seam, but delayed-provider reload and occupied-slot outcomes stay incompletely qualified until native tests can reproduce them.

C revises this interface, lifecycle or test boundary first. Q131-Q142's accepted Map behavior remains in scope.
