# Native itinerary filters

## Context, before and goal

At `f4929b8`, saved itinerary contents use an unrestricted public Core Item query in Manual order. The native view has no search or cumulative filter control and renders every route entry and child. Q57 requires a referenced List group to remain visible when its own metadata or at least one child matches, and to disappear when neither matches.

Lists own a name, notes and presentation metadata; they have archive state and derived progress, but no Category/Tag associations, address, links or direct Schedule. Item predicates already exist at the public query boundary. A List's standalone local completion must never replace completion inside an itinerary occurrence.

## Settled end state

- Reuse the native adaptive Filters control and searchable navigation. Criteria narrow cumulatively; Clear removes restrictions. Selection remains attached to a valid appearance when a filter hides its row.
- Show only matching children inside each visible group. A matching List can remain visible with zero matching children; explain that state rather than revealing filtered-out Items.
- Q75 A requires every selected criterion when matching a List header. Active Item-only restrictions make its own match false. A child matching all criteria can still retain the group. Lists gain no Category/Tag/address/link/Schedule fields.
- Preserve saved route order, repeated List-entry identities and independent appearance completion. Every intentional appearance remains distinct.
- Full progress and bulk-action targets remain independent of filters. Show matching-versus-full child counts so hidden and archived appearances do not cause unexplained denominators.
- Use Core queries for Item and catalog text matching; do not add a second native text-search algorithm or infer List labels from its children.

## Definition of ready

- Q57 and Q75 A are settled. Header matching applies every criterion; an unavailable Item-only field cannot satisfy an active restriction. Matching headers may still have zero matching children.
- Retain the accepted archive-progress distinction: an archived List branch is finished inside the parent, while the container's own progress remains child-based. Core's derived reads and the [native branch/header qualification](native-itinerary-archive-progress.md) now cover that prerequisite.
- Use the existing public read/query and actual native UI seams, captured history validation and durable command acknowledgements. No new test-only production injection is needed for these data-only filter cases.

## Definition of done and required /tdd

- Prove all three visibility paths: header matches with zero matching children; child matches while header does not; neither matches and the group disappears. Cover empty Lists and repeated references independently.
- Exercise the accepted Q75 policy with a matching List name plus Category/Tag/address/link restrictions and no matching child. Verify identity-based Any/All filters and cumulative combinations, including explicit Clear.
- Search and filter changes preserve source identities, reference order, local/global Done flags, archive state, schedules and persisted content. A valid selected detail stays current; removal clears it without retargeting an action.
- Verify full progress and reviewed bulk targets while some children are hidden; selection and toggling in one repeated appearance cannot alter another's local state.
- Native iPhone/iPad journeys must exercise the actual Filters sheet/popover and search controls, inspect real captures, and survive relaunch. Mac compilation and runtime are reported separately. Keep large-list performance and whole-app polish as separate gates.

## Execution and remaining qualification

The native implementation reuses searchable navigation and the existing adaptive Filters Form. Core's public Item query supplies matching appearances in Manual order. Its List catalog supplies header text/archive matches, and itinerary-local children determine the header's completion match. Item-only restrictions disable the header's own match. The original full snapshot remains the authority for progress, order and bulk targets; captured history validation rejects mixed-generation reads.

The journey passes once on iPhone 18 Pro and once on iPad Air 11-inch simulators running iOS 27, with zero failures or skips. It covers matching headers with zero matching children, matching children with nonmatching headers, neither matching, repeated List identities, independent local completion, Any/All label combinations, address/link restrictions, Clear and relaunch. On the simultaneous iPad layout, valid selected details remain open after their row leaves the query. The phone uses its native detail navigation.

Actual XCTest captures show [matching headers on phone](evidence/navigation/native-itinerary-filters/phone-matching-header.png), [retained iPad details](evidence/navigation/native-itinerary-filters/tablet-retained-detail.png) and [no matching entries with unchanged full progress](evidence/navigation/native-itinerary-filters/tablet-no-matches.png). Matching captions count the filtered result, including children inside collapsed groups. Filters preserve the user's disclosure state.

The missing native search and Filters controls supplied the functional red results. Early selector, offscreen-popover and collapsed-group assumptions were corrected in the journey; those failed attempts are excluded from successful qualification. Five affected Swift files pass strict lint. The final Mac app/test target compiles, with zero Mac UI runtime executions. Five focused public Core query/catalog tests pass across three suites; Core storage and the portable format remain unchanged. The [execution record](evidence/navigation/native-itinerary-filters/execution.json) preserves simulator summaries and the matching app/UI-test source snapshot.

Five existing itinerary compatibility journeys also pass on iPhone against the final native source: bulk completion, dragging, reordering, removal/re-add and repeated-entry bulk completion. This brings the slice to seven native executions with zero failures or skips. Those compatibility journeys use unrestricted views; they do not qualify bulk review or dragging with active filters.

This qualifies the implemented search/filter subset. The later [archive-aware branch/header slice](native-itinerary-archive-progress.md) supplies fresh archive completion evidence. Empty List runtime coverage, bulk review and dragging with active filters, duration controls, large-list performance, Mac UI runtime, physical sync/account/Share and whole-app polish remain open. The full ticket Definition of done is not yet satisfied.
