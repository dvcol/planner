# Q85, sorting the List and Itinerary catalogs

Status: the human accepted Q85 A, Q86 A and Q87 A on 15 October 2026. Shared Core/native sorting, uncertainty groups and the concrete public contract are settled for implementation. Runtime qualification remains required.

## Context, before and goal

The accepted [sort controls](duration-and-search.md#sort-controls) cover Item results and the contents of a List. They do not explicitly settle the top-level List and Itinerary catalogs. Both catalogs currently use folded Title ascending with stable identity ties. Native views have archive controls but no sort selector. They consume Core's catalog sequence.

The proposed goal is to find a reusable List or Itinerary by title, creation date, its own last update or full estimate. For example, choose a short List for a free afternoon or find a recently edited Itinerary. Sorting must change presentation only. It must preserve source identities, references, route/manual child order, completion, archive state and calendar bookings.

## Options and impacts

| Choice | Result | Impact |
| --- | --- | --- |
| A, shared Core catalog sorting, recommended | Add explicit Title, Created date, Last updated and Full estimate modes with ascending/descending direction for both catalogs. Native views and agents use the same ordering. Omitted sort remains Title ascending. Native choices are remembered per device and account/dataset/catalog. | Adds an optional public Core/MCP query contract and its tests. No new saved top-level Manual order. Native controls reuse the existing system menu/picker pattern. |
| B, native-only catalog sorting | Offer the same modes and per-device preferences, but native clients assemble and sort their results. Existing agent catalogs remain alphabetical. | Avoids a new public query contract. Current lightweight rows omit timestamps, so date modes require additional source reads. Consistent paging and refresh remain client responsibilities. |
| C, retain alphabetical catalogs for this map | Keep both catalogs in their current Title-ascending order. Existing Item and List-content sort controls remain available. | Adds no catalog sort capability or controls. Finding a container by date or duration remains unavailable in this scope. |

## Established facts and dependent decisions

[PlannerCatalogQuery](../Packages/PlannerCore/Sources/PlannerCore/PlannerValues.swift) currently accepts source kind, text and archive scope. It has no sort field. Core applies native folded-title comparison and stable identity ties. [SavedPlannerStore](../Planner/Scenes/SavedPlannerStore.swift) preserves that sequence when reading the full catalog.

Both source types already have created/updated timestamps and [container estimates](container-estimates-and-calendar.md). A container's own updates include content, archive and contextual organization/completion. Editing a referenced Item can change live content or aggregate estimates without rewriting the container's timestamp. Extending sort does not by itself change that timestamp meaning.

Full estimates may be exact, a known lower bound with missing child estimates, or unavailable after overflow. Existing Item rules for unknown durations do not decide how an uncertain container subtotal should compare with an exact total. If A or B is selected, that ordering question and the concrete query/control contract must be settled before implementing duration sorting. The proposal does not introduce Remaining-time sorting or infer a top-level Manual order.

## Definition of ready

- The human selected shared Core and native sorting through Q85 A.
- For a selected extension, review the concrete supported sorts, default/tie rules, uncertain-duration placement and preference scope before TDD.
- Use the approved public Core/HTTP and production-view native fixture seams. No private sorting helper becomes a separate test interface.

## Definition of done and required TDD if extended

- Add focused failing public tests for both catalog kinds and supported directions, preserving omitted-sort behavior, search/archive identity sets and deterministic ties.
- For shared sorting, prove Core and actual HTTP parser/read agreement, invalid sort rejection, generation-bound page ordering and stale-generation handling. Preserve Q84 C's lifetime policy.
- Native journeys select modes/directions, relaunch and retain device/dataset preferences, keep valid selection, and verify that sorting never rewrites route or child order. Exercise full estimates after a referenced Item estimate changes.
- Cover missing/uncertain estimates and overflow according to the separately accepted rules. Keep full and remaining estimates distinct.
- Qualify focused native behavior on phone/tablet, compile Mac, run affected strict lint/type checks, and retain original evidence. Mac runtime, scale/moving-window reads, physical sync and whole-app polish stay separate gates.

The unselected B/C alternatives remain recorded for context. This scope decision supplies no runtime qualification credit. Q86 below settles uncertain-duration ordering.

## Q86, incomplete full estimates

The human accepted A on 15 October 2026 after Q85 A. Current full totals are exact, a lower bound with missing-child count, or unavailable after checked arithmetic fails. A manual overall budget supplies an exact full total even when its separate calculation is incomplete. Empty automatic containers have exact zero full duration and retain empty progress. Upper bounds describe remaining time and do not currently arise as full estimates.

For exact 180-minute and 300-minute plans, a plan of at least 120 minutes with one missing estimate, and an unavailable total:

- A, accepted: exact totals first, incomplete lower bounds next, unavailable last in both directions. Sort each numeric group by the selected direction. Ascending gives 180, 300, at least 120, unavailable. Descending gives 300, 180, at least 120, unavailable.
- B: mix exact totals and numeric lower bounds in the selected direction, then unavailable. Ascending gives at least 120, 180, 300, unavailable, despite the incomplete plan potentially taking longer.
- C: exact totals in the selected direction, then all incomplete/unavailable plans in title order. Known incomplete subtotals do not affect their order.

Q86 supplies the uncertainty policy. Q87 A approves the [concrete contract](container-catalog-sort-contract-review.md), including supported public values, defaults, fixed title/identity ties, native preference scope, errors and generation-bound reads. Required public Core/HTTP tests must cover both container kinds, both directions, multiple lower bounds, unavailable totals, numeric ties, exact manual budgets with incomplete calculations and empty automatic zero totals. Native rows must retain their uncertainty warnings, and selecting this sort must preserve remaining totals, completion, route order and bookings. No catalog sort is implemented by this decision record.
