# Container catalog sort contract review

Status: ready for Q87 review following accepted Q85 A and Q86 A on 15 October 2026. Scope and uncertainty placement are settled. This concrete public contract requires review before TDD; no new catalog sort is implemented by this document.

## Context, starting state and goal

The human approved shared sorting for the top-level Lists and Itineraries catalogs. Both currently return folded Title ascending. Native views preserve that order and expose archive controls. Item queries already support explicit sorting, but applying their entire sort type to catalogs would also admit Manual, whose saved route/child ordering has a different scope.

The end state adds Title, Created date, Last updated and Full estimate sorting to both catalogs through the existing public Core query and MCP HTTP interfaces. Native controls use the same ordering. Omitted sort keeps existing callers alphabetical. Search, archive filters, source identities, child order, completion and bookings retain their accepted meanings.

## Proposed public values

Add an optional `sort` to `PlannerCatalogQuery`, defaulting to nil. Its nested `Sort` declares `Mode` values `title`, `created`, `lastUpdated` and `fullEstimate`, plus `Direction` values `ascending` and `descending`. Constructing a Sort defaults to Title ascending. A nil catalog sort means the current order. Explicit sorts are supported only for List and Itinerary catalogs; Category, Tag and Schedule catalogs retain their current behavior.

Keep the existing query/read return types. A query snapshot captures all matching source identities in the selected order. Existing generation-bound row windows hydrate that captured sequence. Date sorting uses persisted source timestamps without adding timestamps to every lightweight row. Full estimate sorting uses the existing live `containerEstimates.fullEstimate`, never `remainingEstimate` or the separate calculated subtotal when a manual budget overrides it.

The `planner_query` format stays version 1 and gains an optional object on List/Itinerary catalog queries:

```json
{
  "formatVersion": 1,
  "query": {
    "kind": "catalog",
    "sourceKind": "list",
    "text": "",
    "archive": "active",
    "sort": { "mode": "created", "direction": "descending" }
  }
}
```

When present, `sort` requires both mode and direction. Null, missing members, wrong types and unsupported values fail with `invalidInput` at `/query/sort`, `/query/sort/mode` or `/query/sort/direction` as appropriate. Unknown members retain `unknownField` and their escaped property path. A sort on Category, Tag or Schedule fails at `/query/sort`; an omitted sort preserves those catalogs' existing admission rules. Core rejects unsupported catalog/sort combinations at the same path. The HTTP tool schema advertises sorting only on the List/Itinerary variants. Existing Item sort encodings and defaults stay unchanged.

## Ordering and consistency

Title uses the existing Foundation case/diacritic-insensitive comparison with the existing POSIX locale. Direction reverses the title comparison; equivalent titles retain ascending source UUID ties. Created and Last updated compare the saved source date in the selected direction, then folded Title ascending and source UUID ascending. Equal full-estimate keys use those same ascending title/identity ties. Direction never reverses the fixed tie-break.

Accepted Q86 A fixes three groups in this order for both directions: exact full totals, incomplete lower bounds, then unavailable totals. Sort the numeric value within each of the first two groups in the selected direction. Equal numeric values and unavailable totals use the fixed ascending folded-Title/UUID tie-break. Manual overall budgets are exact full estimates even when their separate calculated estimate is incomplete; empty automatic containers have exact zero. Neither case rewrites completion. Full totals currently do not produce upper bounds, which belong to remaining-time presentation. Arithmetic failure remains unavailable rather than an invented number.

For independently specified full estimates of Empty 0, Museum 180, Manual 240 with missing children, Long 300, Partial short at least 120, Partial long at least 240 and Overflow unavailable, the required sequence for either container kind is:

| Direction | Required full-estimate sequence |
| --- | --- |
| Ascending | Empty, Museum, Manual, Long, Partial short, Partial long, Overflow |
| Descending | Long, Manual, Museum, Empty, Partial long, Partial short, Overflow |

These examples specify expected values, not executed evidence. The tests also cover ties and multiple unavailable containers. Displayed warnings are retained; sorting never turns a lower bound into an exact total.

Query and row reads perform no domain writes. Preserve search/archive matching and reject unresolved source identities, required sort data or live references rather than silently omitting rows. A saved-history change invalidates an old generation, including a source rename, changed timestamp or referenced Item estimate. Clients refresh the whole result instead of combining generations. Q84 C's retained-generation lifetime is unchanged; sort selection introduces no expiry or eviction.

## Native controls and preferences

Use the established native Menu and Picker pattern for a sort-mode selector and ascending/descending choice. Label the container estimate mode Full estimate. Keep Lists and Itineraries choices separate, remembered locally per device and dataset ownership namespace, with Title ascending as the missing/invalid-preference fallback. Do not write these preferences into Planner data or portable backups.

Changing sort refreshes the catalog while retaining a valid source selection. A removed source clears its invalid selection through the existing navigation rules. Late results must not replace a newer sort, archive, revision or dataset request. Cancellation must not publish partial mixed results. Moving between these two catalogs or changing their selected display sort never rewrites an itinerary's route or a List's saved child order.

## Definition of ready

- Q85 A authorizes shared Core and native sorting.
- Q86 A settles uncertainty groups. The human reviews this concrete query, ordering, preference and error contract through Q87 before TDD.
- Use existing public Core import/query/read/export boundaries, the actual MCP HTTP routing seam and production native views with disposable local fixtures. No comparator or preference helper becomes a test-only public interface.
- Declare the exact seeded orders for both catalog kinds and each direction before writing their behavior tests.

## Required TDD and definition of done

At the public Core boundary, first require omitted-sort compatibility and explicit Title, Created, Last updated and Full estimate sequences for Lists and Itineraries in both directions. Seed independent dates, folded-title ties, stable UUID ties, exact and multiple incomplete totals, overflow, exact manual budgets with missing children and empty zero totals. Verify cumulative text/archive matching and complete ordered paging, including a revisited page and an empty terminal window.

After a referenced Item estimate changes, require stale old pages and the correct refreshed container order. Rename and container-own timestamp changes must produce their specified refreshed sequences. Retain the same source identities and full backup bytes across read-only sorting. Verify route/child order and local/global completion remain unchanged. Reject invalid sort combinations without saved-data changes.

At the real MCP HTTP boundary, require schema/encoding agreement with Core, omitted defaults, every supported mode/direction and strict malformed/unknown-field errors with exact property paths. Existing Item and non-container catalog requests must keep their previous behavior.

Native phone/tablet journeys select mode and direction, retain each catalog's preference after relaunch, preserve valid detail selection and verify a live estimate refresh. Exercise rapid sort/filter changes without stale results replacing the final choice. Verify namespace isolation through an approved dataset-switch journey when available; a relaunch alone does not prove it. Retain original screenshots and raw results. Compile the affected Mac targets and run affected strict lint/type checks.

Record red/green commands, source/product hashes, execution counts and limitations. Mac runtime, physical-device latency, scrolling/memory, CloudKit/account transitions and whole-app polish retain their independent map gates. A completed sort slice does not close those gates.
