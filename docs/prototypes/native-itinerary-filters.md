# Native itinerary filters

## Context, before and goal

At `f4929b8`, saved itinerary contents use an unrestricted public Core Item query in Manual order. The native view has no search or cumulative filter control and renders every route entry and child. Q57 requires a referenced List group to remain visible when its own metadata or at least one child matches, and to disappear when neither matches.

Lists own a name, notes and presentation metadata; they have archive state and derived progress, but no Category/Tag associations, address, links or direct Schedule. Item predicates already exist at the public query boundary. A List's standalone local completion must never replace completion inside an itinerary occurrence.

## Settled end state

- Reuse the native adaptive Filters control and searchable navigation. Criteria narrow cumulatively; Clear removes restrictions. Selection remains attached to a valid appearance when a filter hides its row.
- Show only matching children inside each visible group. A matching List can remain visible with zero matching children; explain that state rather than revealing filtered-out Items.
- Preserve saved route order, repeated List-entry identities and independent appearance completion. Every intentional appearance remains distinct.
- Full progress and bulk-action targets remain independent of filters. Show matching-versus-full child counts so hidden and archived appearances do not cause unexplained denominators.
- Use Core queries for Item and catalog text matching; do not add a second native text-search algorithm or infer List labels from its children.

## Definition of ready

- Q57 is settled. Q75 remains the sole header-applicability decision: should an active Item-only criterion make the List's own match false, or be ignored for its header while still filtering children?
- Resolve that choice before implementing header matching. It does not reopen the rule that matching headers may have zero matching children.
- Retain the accepted archive-progress distinction: an archived List branch is finished inside the parent, while the container's own progress remains child-based. Full implementation of those derived reads is a prerequisite for qualifying completion-filter behavior.
- Use the existing public read/query and actual native UI seams, captured history validation and durable command acknowledgements. No new test-only production injection is needed for these data-only filter cases.

## Definition of done and required /tdd

- Prove all three visibility paths: header matches with zero matching children; child matches while header does not; neither matches and the group disappears. Cover empty Lists and repeated references independently.
- Exercise the accepted Q75 policy with a matching List name plus Category/Tag/address/link restrictions and no matching child. Verify identity-based Any/All filters and cumulative combinations, including explicit Clear.
- Search and filter changes preserve source identities, reference order, local/global Done flags, archive state, schedules and persisted content. A valid selected detail stays current; removal clears it without retargeting an action.
- Verify full progress and reviewed bulk targets while some children are hidden; selection and toggling in one repeated appearance cannot alter another's local state.
- Native iPhone/iPad journeys must exercise the actual Filters sheet/popover and search controls, inspect real captures, and survive relaunch. Mac compilation and runtime are reported separately. Keep large-list performance and whole-app polish as separate gates.

This document defines the next slice; it does not claim implementation or runtime qualification.
