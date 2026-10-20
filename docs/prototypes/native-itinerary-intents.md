# Native Itinerary creation and lookup Intents

Status: Create/Get Itinerary and live entity lookup/search are locally qualified. All 44 affected adapter tests pass. Mac, Simulator and unsigned device builds pass. Actual system invocation and physical testing remain separate gates.

## Context and starting state

At `c53f165f`, Core, native screens and MCP already create/read Itineraries through live source identities. App Intents cover basic Item/List workflows but have no Itinerary entity or creation/read/query actions. Q33 ordinary authority and the Q112 A production Intent/EntityQuery test boundary apply to this increment of the full catalog.

## Goal and expected end state

Create an Itinerary with title/optional notes, return its Core-generated identity and resolve its live title/archive values through EntityStringQuery and Get Itinerary. Use canonical insensitive search, archived-inclusive choices, stable order and generation-bound pages. Preserve distinct same-name sources. Missing/deleted identities stay missing, and read failures throw rather than invent empty successful data.

Creation rejects invalid/canceled requests without partial data. Actual post-save incomplete recovery preserves the saved source and blocks subsequent mutation until native recovery retry. It adds no persisted parent Done state or child copies. Richer fields, edit/archive, organization, contextual/bulk completion and scheduling remain on the full catalog's map; this increment does not replace their scope.

## Definition of ready

- Q33 accepts ordinary read/create and shared command/read encodings. Q6 C retains the explicit always-allowed policy where Apple permits it.
- Q112 A confirms existing app-hosted production `callAsFunction(donate: false)` and EntityQuery interfaces, Apple's dependency manager, disposable real storage and actual recovery-filesystem failure.
- Core create/read/catalog commands and the native Store adapter are canonical. No new package, target, dependency injection hook or persistence format is needed.
- Local Mac app-hosted execution and unsigned platform compilation are available. The native Mac UI reservation and actual system/signing gates remain separate constraints.

## Required tests and definition of done

Record executable missing-implementation reds before creation, identity lookup, Get and catalog search. Reopen the returned source to verify title/notes, Active state, empty progress and absent parent Done. Qualify live/missing/deleted lookup, duplicate requested IDs, same-title sources, archived-inclusive insensitive search beyond one page, invalid/pre-canceled creation, unavailable storage and real incomplete recovery.

Run the affected Intent classes together, compile actual Mac/Simulator/unsigned device products, verify extracted metadata and affected strict lint/whitespace checks. Retain exact source epochs, commands and actual results. These adapters do not prove Shortcuts/Siri discovery, background/locked execution, system confirmation, iCloud/account-bound storage or physical behavior. The broader map stays open.

## Executed vertical slices

| Behavior | Executable red | Following green |
| --- | --- | --- |
| Create and reopen | Missing creation throws, 1.739 s | 0.217 s; original identity/title/notes, Active, empty progress and no parent Done |
| Live identity resolution | Missing lookup throws, 0.623 s | 0.092 s; first-request order, deduplication, missing/wrong-kind omission and live renamed/Archived values |
| Get from cached entity | Missing Get throws, 0.482 s | 0.036 s; canonical renamed title and explicit missing-source failure |
| Catalog search/suggestions | Missing search throws after real fixture creation, 6.045 s | 6.170 s; all 65 identities across the 64-row boundary, canonical order, archived source and insensitive title matching |

All packets are in [the compatibility evidence](evidence/navigation/native-itinerary-window-compatibility/) under `app-intent-itinerary-*`. Each retains its own original source epoch; following passes do not change earlier failed outcomes. Timings are XCTest durations rather than application latency or physical performance.

## Failure and identity qualification

These required cases pass on first execution against the implemented actions, without another production correction or fabricated executable red.

- Invalid required title and cancellation before invocation leave the reopened catalog empty, 0.158 s.
- Native reviewed Delete makes the cached source unavailable while the surviving Itinerary's identity/title/notes remain intact after reopening, 0.082 s. No Delete Intent is registered.
- Two same-title creations retain distinct identities, notes and canonical ascending identity tie order, 0.190 s.
- An actual filesystem obstruction makes suggestions/search/identity/Get/create all throw, leaves storage unavailable and preserves the obstructing file, 0.166 s.
- Actual post-save recovery-copy failure retains the returned Itinerary and readable choices, blocks the next creation, then native retry acknowledges the original operation without duplication. A later explicit creation succeeds, 0.307 s. Recovery administration remains native-only.

The production query delegates search/order to Core and reads 64-row generation-bound pages. It checks cancellation, source kind and archive state and throws on a failed or unexpectedly empty page, rather than returning a partial successful array. It introduces no custom search library or artificial total-choice cap.

## Combined and platform evidence

All 44 affected Item/List/Itinerary tests pass together with zero failures or skips in 19.186 seconds. This adds nine Itinerary cases to the existing 35; it is not a full target or repository test run. The final packet retains the actual XCTest summary. Mac metadata extracts twelve actions, three entities and three queries, including Create/Get Itinerary and its EntityStringQuery. Metadata proves compilation/extraction only.

The production app and native UI target compile for the generic iPhone/iPad Simulator destination. The generic unsigned iOS device build also passes and embeds one mobile Share extension. Both executables contain arm64. Mobile/device metadata matches the Mac twelve-action, three-entity, three-query catalog. Each final platform packet retains 985 source/configuration inputs that match the current repository files. Commands, logs, product hashes, metadata and embedding checks are retained. Affected strict Swift/Markdown lint passes. Team/account configuration and entitlements are unchanged; Mac uses the existing local ad hoc configuration. No physical device was installed or launched.

## Remaining map work and limits

Richer data fields and the rest of the ordinary Intent catalog, actual system/background/locked/confirmation behavior, native capture invocation, signed Agent Control/reader/real clients, shared/account-bound iCloud implementation, installed Share, physical convergence/recovery/performance and final whole-app polish remain open. The [compact toolbar checkpoint](../native-list-toolbar-review.md) records the separately pending Mac UI retry.

Explicit unverified-outcome fault qualification remains open. Existing test-fixture cleanup can unlink temporary SQLite files while SDK-retained stores still have connections; original logs retain those warnings. These checks do not establish clean shutdown or a production integrity defect. Affected new Intent/test sources introduce no compiler warnings in the final Mac invocation; no repository-wide warning freedom is claimed.
