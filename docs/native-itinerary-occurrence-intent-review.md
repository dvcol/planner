# Itinerary occurrence selection in App Intents

Status: Q114 A is approved on 20 October 2026. Choose the Itinerary first, then its exact Item appearance. Get/local completion are implemented; [local qualification](prototypes/native-itinerary-item-intents.md) records the evidence. Populated system picker injection remains open. This workflow decision adds no test boundary.

## Context

An itinerary can reference the same Item or List more than once. Each Item appearance has independent local completion. Source UUID or title alone cannot identify an appearance. A whole List entry is also distinct from one expanded child; an empty List contributes no Item rows but remains a route entry.

Core already returns exact direct and expanded identities in an unrestricted explicit Manual itinerary query. Direct identity includes the Item source, itinerary and entry IDs. Expanded identity includes the Item source, itinerary, List-entry and membership IDs. Source reads supply owner/List names and saved top-level and child order. Positions are descriptive context, never identity.

The existing SavedItemWindow reader combines these public reads and validates its retained query generations after metadata assembly. An occurrence reader must likewise avoid mixing generations. Current row reads do not directly embed owner/List names or route ordinals. No new Core API is presumed.

## Workflow options

Q114 A chooses the Itinerary first, then a scoped native Item-appearance picker. Labels distinguish repeated stops and List branches. Exact identities remain bound to their selected context; removed or mismatched selections reject without retargeting.

Q114 B uses one global picker with the Itinerary, List context and route position on each result. It avoids a parent parameter but reads across itineraries and needs longer descriptions.

Neither option changes saved order, shared content or completion. Top-level removal/reordering must use entry identities and cannot treat an expanded child as a new top-level entry.

## Verified SDK facts and test limit

Apple's public `IntentParameterDependency` supports a query shared by several Intent types through separate typed dependencies. Apple demonstrates this in [Explore enhancements to App Intents](https://developer.apple.com/videos/play/wwdc2023/10103/). A standalone compiler probe against the installed macOS 27 SDK accepts two such dependencies and `@Parameter(query:)`.

The dependency projection is read-only and has no public constructor or assignment API. Negative compiler probes reject direct binding. Q112's ordinary `@Dependency` store binding therefore cannot populate an Itinerary projection in a directly constructed query. The public AppIntentsTesting query methods expose no parent-Intent argument. Passing a complete entity to `callAsFunction(donate: false)` does not demonstrate system picker choices.

Exact-identity execution and public reads can use the established local boundary. Actual system injection, choices after changing the parent, discovery and invocation remain separate open gates on the recorded Customer runtime. No signing change, private interface, runtime bypass, test-only production parameter or new target is authorized by this investigation.

The read-only fact checks used source `fdf038d8` and the installed public SDK. Compiler probes are temporary environment evidence, not app behavior tests. The concrete production interface and test requirements are below.

## Concrete local slice

The implementation uses the existing Q112 production Intent/EntityQuery test boundary and real Planner storage. No additional direct helper test boundary is introduced. Reuse SavedItemWindow's approved itinerary metadata/paging interface rather than add another route assembler or Core query.

PlannerItineraryItemEntity exposes the Item title, human context and global/local/effective Done plus Item archive observations. Its opaque stable string ID is versioned and includes the Item source UUID and every contextual UUID. Direct IDs are `v1/direct/<itinerary>/<entry>/<item>`; expanded IDs are `v1/list/<itinerary>/<list-entry>/<membership>/<item>`. UUID case variants normalize to the same canonical ID. Raw IDs and technical enum names are absent from display labels.

Get Item in Itinerary and local completion require both the selected Itinerary and exact appearance. Identifier lookup can resolve an existing saved entity without system picker injection. Malformed, foreign, removed or deleted selections cannot fall back to another appearance or global Item completion. Ordinary missing IDs are omitted during entity resolution; execution requires a current exact match. Names, route positions and completion are read live.

Scoped search/suggestions use Apple's selected-parent dependency. Without a parent, there are no suggested appearances. All results retain saved Manual route order and canonical Core search. A surrounding Core generation validates the full read after paging, so changes cannot yield a successful mixture of generations. The adapter returns a useful read failure on invalidation. This adds no new Core, transport or backup format.

Required local tests cover direct/expanded repeats, live names/positions, malformed/version/case/foreign/missing identities, removal and ordinary re-add, global precedence with independent local flags, archive, saved order/content/schedule preservation, cancellation, unavailable storage and actual recovery failure without replay. Existing Intent regressions, extracted metadata and Mac/Simulator/unsigned device compilation remain required. Actual populated parent injection/search and changing-parent system behavior remain open gates; the local tests must not claim that credit.
