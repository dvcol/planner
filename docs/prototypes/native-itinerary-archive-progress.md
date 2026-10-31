# Native itinerary archive progress

## Context, before and goal

At `2e452ff`, List progress presents the qualified Core Done/archive-retirement counts, but itinerary and branch widgets still show Done only. Header completion matching also ignores retirement. Q68/Q69 require archived Items and archived List branches to finish route progress without changing any source or appearance Done flags.

## Definition of ready

- Use Core `492b558`'s qualified source/query progress. Keep archived containers' own progress child-based under Q72 and preserve repeated entries' independent completion.
- Reuse the native ProgressView presentation qualified for Lists. Show finished totals with Done/archive breakdown when retirement contributes; label archived List groups explicitly.
- Q57/Q75 header matching remains cumulative. A List header's completion comes from this itinerary branch, including archive retirement. Item completion filters and check circles continue to use actual global OR local Done.
- Retain captured history validation and the existing native UI test seam. No schema, portable format, source flags or Schedule mutation.

## Definition of done and required /tdd

- Complete a standalone List's child, then reference it twice alongside a direct appearance of that Item. All itinerary appearances start locally Todo and remain independent of the standalone List.
- Archive the List: both branches finish, while the direct Todo appearance remains unfinished. Show two of three finished with zero Done and two archive retirements, without checking any child circle.
- Searching the List name with Done retains both matching branch headers and no child rows. Todo hides those headers when no child matches. Full progress stays unchanged.
- Relaunch preserves the same entry/source identities and retained Todo flags. Unarchive restores unfinished route branches while preserving the standalone List's local Done flag.
- The affected existing bulk journey must account for an archived Item in full progress while retaining hidden targets and global completion precedence.
- Phone/tablet journeys, capture inspection, strict Swift lint and Mac compilation pass. Mac UI runtime, performance and physical sync/account/Share retain their separate gates.

## Execution boundary

The functional red fails on the missing finished route caption after archiving a referenced List. Production reads List archive state with its header content, reuses the native completion widget for route and branch totals, and includes retirement when matching header completion. Check circles retain actual Done state.

The complete branch journey passes once on iPhone 18 Pro and once on iPad Air 11-inch, both iOS 27 simulators, with zero failures or skips in those final runs. It proves independent standalone/itinerary completion, repeated archived branches, cumulative Done/Todo header matching, full progress despite hidden rows, relaunch identities and unarchive. Phone archive, tablet Done filter and tablet unarchive are inspected XCTest captures.

The affected existing itinerary bulk function also passes on both devices. Those two executions came from earlier mixed-result bundles whose new branch journey failed on accessibility selectors; the full bundles are not called passing. Subsequent changes only corrected the new journey's selectors, with identical app sources. The final branch journey uses exact identities and generic native queries for empty groups and Toggles. The execution record retains both source epochs and the actual passed-function records.

Four affected Swift files pass strict lint. The final Mac app/UI test host compiles, with zero Mac UI runtime executions. Core and HTTP source hashes remain unchanged from their qualified 492b558 slice. An iPad launch approval review timed out once; its permitted retry ran, and no approval block remains. Empty List runtime coverage, filtered dragging, duration controls, estimates/remaining, Calendar, scale, physical sync/account/Share and whole-app polish remain open.
