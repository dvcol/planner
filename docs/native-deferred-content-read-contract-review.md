# Native saved-content property review

Status: Q117 A accepted on 21 October 2026. Deferred properties and the production getter test boundary below are approved and [implemented locally](prototypes/native-deferred-content-properties.md). Actual system property fetching remains open.

## Context, starting state and goal

At `dbc609ae`, native Item, List and Itinerary entities expose identity, title/name and state. Their exact-identity queries read full sources but discard other content; search and suggestions use lightweight paged rows. Those rows do not contain Notes. Initializing a stored optional Notes property to nil from a row would incorrectly present unloaded content as absent.

The goal is to let Shortcuts read saved content from the existing entities without adding full source reads for every picker choice. The existing typed identities, action parameters/results, query filters, paging and mutation rules remain in use.

## Proposed observable properties

| Entity | Additional properties | Native value |
| --- | --- | --- |
| Item | Subtitle, Notes, Location name, Address | Optional String |
| List | Notes | Optional String |
| Itinerary | Notes, Location name, Address | Optional String |
| Item and Itinerary | Pin | Optional native PlaceDescriptor |
| All three | Created, Last updated | Date |

Use Apple's public `@DeferredProperty` for these properties. Each getter resolves the current SavedPlannerStore through AppDependencyManager, reads the source of the entity's declared kind and UUID, and returns its saved value. Preserve text exactly, including optional absence. Location fields describe only owned content; reading them performs no address lookup, geocoding or Maps-link enrichment. Pin contains only a saved coordinate, without provider names, address representations or inferred locations. It is absent when the source has no owned coordinate. Separate name/address properties preserve name-only and address-only locations without inventing a pin.

A missing/deleted source or unavailable store throws a useful error. Nil means a successful read of an absent optional field, never a missing source or failed read. Cancellation propagates. Archived and globally Done sources remain readable. Reading creates no ordinary data change or mutation receipt.

These are individual live reads. A source edit between two property requests can produce values from different generations. This interface does not promise a coherent multi-property snapshot or alter the existing stored title/state properties. No result entity is replaced with a new entity type. Estimate, label and schedule reads are separate remaining work, not represented as empty fields by this proposal. Reading the optional location values does not expose an additional structural distinction between a missing location and a location whose fields are all absent.

## Alternatives and impacts

A. On-demand native properties as proposed. Pickers keep their existing row reads; new properties perform current-source reads only when requested. This adds asynchronous read failures and does not promise atomic multi-property snapshots.

B. Hydrate every picker entity with the additional stored fields. Each entity carries a source snapshot, but search and suggestions need an extra full read per result and generation-consistency handling. Values can become stale after that snapshot.

C. Keep entity properties unchanged and add separate field-read actions. Each action can read current saved content, but users need an additional action for Notes, Address or other fields and cannot use those fields directly as entity properties.

Recommendation: A, following the accepted preference for first-party components and lightweight collection reads.

## Definition of ready

The user approved the choice and production property-getter test boundary in Q117 A. Q112's AppDependencyManager, real disposable Core storage and existing app-hosted target remain the environment. No new target/package, test-only constructor, injected property resolver, private helper test or runtime replacement is proposed.

Apple documents asynchronous deferred properties in [Explore new advances in App Intents, 24:48](https://developer.apple.com/videos/play/wwdc2025/275/?time=1488) and [DeferredProperty](https://developer.apple.com/documentation/appintents/deferredproperty%28title%3A%29). Public installed-SDK probes compile optional String async throwing getters that resolve an AppDependency under Swift 6 strict concurrency for macOS 27 and iOS 27 Simulator. ComputedProperty rejects async getters. These facts establish a supported declaration, not actual system invocation, caching, request ordering or snapshot guarantees.

## Required tests and definition of done

Use the declared production getters on entities returned by production creation/read actions and identity/search/suggestion queries, with actual dependency registration and disposable saved data. Use one failing vertical slice before each implementation increment. Verify exact multiline and non-ASCII text, absent fields, subtitle, independently optional owned location text, pin-only and name/address-only locations, origin and boundary coordinates, archived/Done sources and saved timestamps. A saved Maps bookmark must not become a Pin. An entity obtained before an ordinary edit must read the current new property value afterward; source deletion must throw rather than return nil or redirect to a same-named source. Verify List and Itinerary kind boundaries independently.

Exercise precancellation and an actual bootstrap filesystem obstruction. Read through an actual incomplete-recovery state where normal reads remain available, without claiming that a read acknowledges recovery. Compare public source content, hashes, timestamps, references and completion before/after reads. Reopen storage to verify preservation. Dispose fixtures only after their host and SQLite handles close.

Run affected entity/action regressions, strict Swift/Markdown lint and Mac, Simulator and unsigned generic-device type/build checks. Verify the new extracted property types and retention of existing entity identities, actions, parameters, output types, queries and enums. Record original commands, outcomes and frozen source hashes. Actual Shortcuts property discovery/fetching, background or locked-device execution, physical performance and signing remain separate qualification gates.
