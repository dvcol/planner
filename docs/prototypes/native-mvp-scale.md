# Local MVP scale checkpoint

30 October 2026. The production `SavedItemWindow` is exercised through its
existing app-hosted test interface with real local Core storage. No cloud data,
new production seam or package is added.

One reviewed bulk import creates 5,000 Items and 200 Lists. All Items belong to
one List; the other 199 Lists are empty. The check verifies the complete ordered
appearance identities, full progress count, first-page loading, last-page access
and release of offscreen row presentations. It then verifies the 200-List catalog
and its last page. The affected existing List-header regression also passes.

The focused run passes two tests in
20.525 seconds. On this execution Mac, the fixture import takes 11.780 seconds,
opening the 5,000-Item List takes 4.130 seconds, and the combined List/catalog
query and paging portion takes 8.219 seconds. These are observed same-process
local timings after import, not cold-start guarantees or a measured improvement
against a baseline. Retaining fewer row presentations does not imply bounded
total Core memory.

An initial cohort was deliberately stopped after 150.957 seconds while an older
catalog fixture was still creating individual Lists. The new scale scenario had
not started. That cancellation is retained separately and is not reported as a
passing run or a verified baseline failure. The focused run uses bulk seeding.

All 11 selected temporary test folders from these and the preceding storage
checks are removed through their owning signed diagnostic after the test hosts
exit. Two completed diagnostic/test build caches are removed (4,097,703,936
allocated bytes reported before deletion); prepared signed app builds remain.

Physical-device memory, actual scrolling/hitches, distributed List workloads,
Map scale and final visual acceptance remain open. This checkpoint does not
replace those release gates.
