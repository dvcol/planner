# Shared Map row contract review

Status: accepted under Q142 A on 22 October 2026. Q131-Q141 already settle the workflow. This declaration governs the added public read and its tests. Implementation and qualification are in progress.

## Context, starting state and goal

Core's Item query already returns the complete matching identity sequence for Items, Inbox, a List or an Itinerary. It applies the accepted cumulative filters, sort and contextual completion rules. Native row windows retain only visible and neighboring presentations. A map made from those presentations would omit offscreen matches.

The existing row read contains owned locations and one ordinary preview link. It deliberately omits Maps links. Reading each complete Item and referenced List would recover those inputs but also hydrate notes, editing hashes and unrelated content. It would require clients to reconstruct route labels and keep several reads coherent.

The proposed end state reuses an existing Item-query generation and adds a compact location-input projection. Native Map and agents can read the same saved data and exact contextual identities. Core performs no network requests, geocoding, coordinate inference or domain writes.

## Concrete declaration

Add `mapRows(generation: UUID, offset: Int64, limit: Int64)` to `PlannerReadRequest` and `mapRows(PlannerMapRowWindow)` to `PlannerReadResult`. Expose the same `kind: mapRows` in `planner_read`, with the existing adapter format version, UUID generation and decimal-string offset/limit conventions. Existing query and read results remain unchanged.

Only a generation issued by `.items(PlannerItemQuery)` is eligible. A valid catalog or Calendar generation fails with `invalidInput`. Unknown, superseded or other-session generations fail with `staleSnapshot`. Offset is nonnegative and limit positive, following existing paging behavior. An offset at or beyond the matching count returns an empty page. Invalid input changes no saved content.

`PlannerMapRowWindow` contains:

- `generation`, `offset`, `matchingCount` and `rows`. Count and row sequence are exactly those of the originating Item snapshot, including matches without a usable location.
- Optional `collection`, containing the scoped List or Itinerary reference, lifetime and live title. Global and Inbox scopes have no container object.
- `listBranches`, containing compact descriptors for all Itinerary List entries retained by Q57. Other scopes return an empty collection. Descriptors are generation metadata repeated on each page, including empty pages, so a matching empty List header remains explainable without another source read.

Each `PlannerMapRowRead` contains `identity: PlannerRowIdentity`, `sourceLifetimeId`, `title`, optional `ownedLocation`, `mapsLinks` and optional contextual placement. `mapsLinks` uses the existing `PlannerOwnedLinkRead` value and retains every saved Apple/Google Maps link in saved order, including original URL bytes, link identity, label, kind and provider reference. Ordinary website links are excluded. A source with no owned location or Maps link still returns its row.

Placement contains the saved Itinerary entry identity and one-based route position for a direct appearance. An expanded List appearance additionally contains its List reference/lifetime/title, membership identity and one-based saved child position. Standalone List memberships contain their exact membership and saved child position. Global/Inbox rows have no contextual placement. Positions describe saved order before filtering and sorting; they never become action identifiers.

A List-branch descriptor contains its exact Itinerary List-entry identity and saved route position, List reference/lifetime/title, whether the header itself matches, and the count of individually matching children. Repeated uses of the same List remain separate descriptors. Descriptors follow saved route order.

Notes, editing hashes, ordinary website links, provider results and browser state are excluded. This read does not add persisted values or change the portable backup format.

## Filtering and coherence

Map rows use the existing Item query without broadening its matches. Preserve Q57's current rule: retain a List branch when its own header or at least one child matches; a header match does not admit children that fail the Item criteria. A matching header may have zero matching children and no marker.

Header matching follows the accepted native composition. Item-only criteria prevent header-self matching. Otherwise, List text/archive matching and that branch's contextual completion determine its header match. Full progress, full estimate and remaining time retain their existing meaning regardless of Map matches or location availability.

Keep the originating Item query privately with the generation binding so Core can derive this metadata. Validate the same dataset, source/association lifetimes and storage-history generation before and after projection. A changed store invalidates old pages; clients restart the complete map load rather than combine generations. Failed or unresolved relationships return a structured failure rather than a fabricated complete map.

Native Map reads every matching page, separately from the List presentation cache. Temporary lookup results remain bound to the original namespace, source lifetime, exact address or link identity/URL and active Map request. Dataset, filter or source changes cancel obsolete publication. Resolution bounds and source-choice presentation have their own implementation review; this declaration does not authorize new provider-data persistence or a different preview test boundary.

## Definition of ready

Q142 A accepts the concrete fields, eligibility, matching and wire behavior below. The production public Core query/read/store and real MCP HTTP boundaries are already approved. No additional direct controller seam, test hook, package or target is proposed. Q127-Q130 remain separate pending choices.

## Required /tdd and definition of done

Write one failing behavior at a time through the existing public Core boundary, using literal owned fixtures and real disposable storage:

1. Query 130 matching Items. Read positions 1, 64, 65 and 130 across pages and verify the exact complete identities, original URLs, saved-order Maps links and owned locations. Rows without location inputs remain counted. An ordinary website link must not enter `mapsLinks`.
2. Exercise Global, Inbox, standalone List and repeated direct/expanded Itinerary appearances. Verify literal saved route/child positions despite alphabetical sorting and filters. Repeated Hotel and repeated List entries keep separate exact contextual identities.
3. Cover header-only, child-only, neither-match and matching empty-List branches. Confirm header matching never admits a nonmatching child and Item-only restrictions prevent a header-self match.
4. Cover empty/terminal pages, invalid offsets/limits, wrong query kinds, unknown/cross-session generations, unresolved references and stale pages after real title, location, Maps-link, membership, route-order, deletion or dataset changes. Refresh returns current inputs without changing saved data.
5. Compare complete exports before and after successful and failed reads. Qualify the new encoding and structured failures through real MCP HTTP, while rerunning affected ordinary row and Calendar reads.

Run affected strict Swift lint and compiler checks. Review the implementation against this declaration. This slice is done when the shared saved-data read and affected regressions pass with exact source/product evidence. Native pins, bounded temporary resolution, exact chooser interaction, three-platform layout/accessibility, physical performance and whole-app polish remain distinct acceptance work in the parent map.

## Alternatives and impacts

A approves the projection above. It shares the existing filter/snapshot contract and avoids full-source client reconstruction, while adding one public read result and its HTTP encoding.

B revises the proposal before implementation. Specify the fields, matching rule or wire behavior to change. The accepted collection Map workflow and exact appearance scope stay in force.
