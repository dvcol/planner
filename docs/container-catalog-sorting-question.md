# Q85, sorting the List and Itinerary catalogs

Status: pending human decision. No production sorting change is authorized by this proposal alone.

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

- The human selects the catalog scope and shared-versus-native approach.
- For a selected extension, review the concrete supported sorts, default/tie rules, uncertain-duration placement and preference scope before TDD.
- Use the approved public Core/HTTP and production-view native fixture seams. No private sorting helper becomes a separate test interface.

## Definition of done and required TDD if extended

- Add focused failing public tests for both catalog kinds and supported directions, preserving omitted-sort behavior, search/archive identity sets and deterministic ties.
- For shared sorting, prove Core and actual HTTP parser/read agreement, invalid sort rejection, generation-bound page ordering and stale-generation handling. Preserve Q84 C's lifetime policy.
- Native journeys select modes/directions, relaunch and retain device/dataset preferences, keep valid selection, and verify that sorting never rewrites route or child order. Exercise full estimates after a referenced Item estimate changes.
- Cover missing/uncertain estimates and overflow according to the separately accepted rules. Keep full and remaining estimates distinct.
- Qualify focused native behavior on phone/tablet, compile Mac, run affected strict lint/type checks, and retain original evidence. Mac runtime, scale/moving-window reads, physical sync and whole-app polish stay separate gates.

If C is selected, record the narrower scope and retain the existing implementation. It requires no invented red/green qualification credit.
