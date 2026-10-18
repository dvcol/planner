# Native container catalog presentation windows

Status: approved under Q103 A on 18 October 2026. Extend the existing loader with this catalog overload and qualify it through the real-Core/native UI boundaries below. Q98 qualification continues independently.

## Context and goal

`SavedPlannerStore.readLists` and `readItineraries` still read every matching row with `limit: Int64.max`. The separate List-choice catalogs were explicitly left out of Q98. SwiftUI's lazy rendering does not prevent those complete presentation reads.

Before: Lists, Itineraries and List destination/filter choices retain every presentation. After: those views retain complete typed source identities and matching counts, load the first 64 presentations, then visible pages plus at most one neighboring page on either side. Preserve live names, archive state, estimates, selected sort, destination and first-survivor selection.

This changes native presentation retention. Core query captures and full identity sequences remain resident. It does not establish bounded total memory, database-fetch counts or physical performance.

## Proposed production interface

Extend the existing app-internal `SavedItemWindow` with one overload, keeping existing callers unchanged:

```swift
func reload(query: PlannerItemQuery, identity: SavedItemWindowIdentity) async
func reload(catalogQuery: PlannerCatalogQuery, identity: SavedItemWindowIdentity) async
```

Catalog requests admit List and Itinerary kinds. Complete `PlannerRowIdentity.source` values, matching counts, loaded `PlannerRowRead` values and loading/failure states use the existing output. Catalogs have no List-content source or Itinerary-content metadata. Validate every source kind and exact page identity/count. Validate container estimate fields before presenting an actionable container row.

Keep one implementation of 64-row paging, visible/neighbor retention, cancellation, stale-generation refresh, replacement and retry. Retain the actual query kind internally so a stale catalog reload cannot become an Item query. No package, target, Core query, MCP schema or backup field changes.

## Callers and behavior

- Main Lists and Itineraries retain their explicit per-device/dataset sort choices and archive filters. Full query identities determine valid selection and the accepted first visible survivor after deletion. Selected source details load independently of cached catalog rows.
- List filter choices keep archive All and omitted sort/text. Their current selected IDs survive offscreen presentation release; invalid IDs follow the existing filter behavior.
- Capture destinations, Itinerary List choices and Add/Move-to-List forms keep archive Active and omitted sort/text. They retain offscreen selected sources and the originating context. Capture's remembered-subset validation and the mixed Item/List picker's readiness remain intact. Move excludes its originating List.
- Omitted sorting stays Core's insensitive alphabetical order with stable identity ties. A destination picker does not inherit a main catalog's chosen sort.
- Newly choosing a row requires its loaded presentation. Unloaded placeholders expose no selection or operation pretending that content loaded. An already selected valid identity remains usable after its presentation is released.
- Replace the eager shared `SavedPlannerStore.lists` destination array and its refresh calls once its consumers use windows. Remove obsolete complete-presentation readers after all callers migrate.

## Coherence and failure rules

Publish the query's complete typed identities, count and generation-validated first page together. Empty results still require a positive-limit page validation. Metadata from a different query, kind, revision or dataset cannot be combined with current rows. Each await checks cancellation/replacement before publishing.

Stale history refreshes the complete query and current visible identities. A released selected presentation does not change destination, source lifetime or action scope. Filter/archive changes and deleted targets revalidate selection through complete identities and the existing command/review rules. Namespace replacement cancels the prior window and prevents obsolete work from republishing.

This preserves existing ordinary commands and confirmation behavior. It adds no automatic creation, import, completion or reorder.

## Definition of ready and required tests

Q103 A approves this overload and the existing app-hosted real-Core/native UI boundaries. Use disposable local Core data and public commands/imports in `PlannerMCPTests`; observe the loader's actual interface, not private pages/tasks or database internals. No test-only initializer, delay or callback is added.

Cover one behavior at a time:

- Both container kinds with more than 64 sources: literal complete identities/order, first-page hydration, full matching count and empty results.
- Explicit sort modes/directions, unchanged omitted alphabetical order, archive choices and full estimate metadata.
- Visible/neighbor retention, release/revisit, offscreen selection, real rename/archive/delete/sort-key changes and stale refresh.
- Source-kind/query/dataset replacement and cancellation without mixed publication. Retain the existing Item/Inbox/List/Itinerary regressions.
- Actual native catalog scrolling, sort/relaunch, first-survivor selection and each destination/filter picker, including Capture's remembered subset and mixed Itinerary readiness. Inspect original populated/loading/empty captures on represented platforms.

Core cannot deterministically pause every internal await at this boundary. Review publication guards and retain that limitation rather than claiming exhaustive race coverage.

## Definition of done

All current complete List/Itinerary presentation readers and eager destination-array consumers are migrated or explicitly identified as still open. Affected Core/native regressions, strict Swift lint and mobile/Mac compilation pass. Record exact sources/products, failures, executed destinations and inspected captures. No runtime credit comes from compilation alone. Native/physical scale and final whole-app acceptance remain separate gates.

## Alternatives

A extends the existing loader as proposed. It reuses paging/coherence but requires regression checks for existing callers.

B adds a dedicated catalog loader with the same behavior and real-Core/native test boundaries. It isolates existing clients but duplicates paging and refresh logic.

C revises this proposed interface or retention/caller rules before implementation. Existing Q98 checks continue.
