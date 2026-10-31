# Reusing unchanged Calendar captures

Repeated Calendar queries can now reuse an immutable capture when the authorized session, saved history and complete returned values match. Each query still validates the current native store before reuse. This avoids retaining another copy of identical entries and identities on every refresh.

## Context, goal and readiness

The [Calendar window contract](../calendar-window-contract-review.md) requires consistent captured values and stale-safe paging. It does not require a fresh UUID for every identical invocation. Generation retention remained an open gate after [owner batching](calendar-window-scale.md).

Before: 100 unchanged queries each retained another full 5,000-Schedule result until saved history changed. The public probe verified the oldest and latest pages and an unchanged full backup, but macOS process resident memory grew by 48,152,576 bytes between the first and hundredth query.

After: a fully validated result can reuse a capture with the same complete Calendar entries and exact session under the same history token. Ordinary query bindings cannot match because they have no Calendar entries. Different values, saved history or sessions require another capture. No expiry, count cap, release operation, schema or wire fields are added.

The agreed public Core query/read/store and real MCP HTTP seams remain sufficient. The performance probe calls only public methods and observes this process's resident memory through Darwin's native API. No private cache count or production injection is used.

## Definition of done for this step

- Measure repeated full Calendar queries with a known large saved graph before changing retention.
- Reuse equivalent immutable Calendar values only after current entry and history validation.
- Preserve complete matching identities, live titles, valid early/latest pages and byte-identical saved backups.
- Preserve stale rejection after a saved change and ownership checks across sessions and query kinds.
- Pass affected Core and HTTP tests, strict lint, native compilation and separate Standards/Spec reviews. Record the source, commands, input provenance, products and original measurements.

## Measured behavior

The public probe imports the same 5,000-Item, 200-List, 5,000-membership and 5,000-Schedule fixture used for owner batching. Each of 100 iterations queries 1 January 2026 through 31 December 2039 in GMT and verifies all 5,000 literal Schedule identities. The final iteration reads five literal titles and identities from both the earliest and latest issued generation. A full export before and after is byte-identical.

The final execution returned one unique public generation across all 100 queries. The before implementation creates a UUID per invocation; the before probe did not record a unique-generation counter. Its archived source and measured values are retained without inventing that observation.

| Whole-process measurement | Before | Final |
| --- | --- | --- |
| Resident bytes after query 1 | 359,317,504 | 367,984,640 |
| Resident bytes after query 10 | 360,349,696 | 368,099,328 |
| Resident bytes after query 50 | 344,014,848 | 360,939,520 |
| Resident bytes after query 100 | 407,470,080 | 311,263,232 |
| Median query seconds | 0.3151 | 0.3205 |

Resident memory is whole-process debug macOS memory after large import/export. It can fall when the runtime reclaims allocations. These runs show repeated-refresh behavior rather than query allocation, peak memory or an iPhone budget. They do not establish a general bound for different query results or sessions.

All latency comparisons use `querySeconds`. The before probe retained a legacy `queryAndThreePagesSeconds` key for elapsed iteration time, although this retention scenario reads pages only on the last iteration. The final probe names it `iterationSeconds`; neither field is used to infer query latency.

## Tests and qualification

The measured baseline preceded implementation. The same public scenario then retained correct results, early/latest paging and unchanged data after reuse. The final affected Core run passes 32 invocations across 11 suites. Those suites cover paging, invalid windows, duplicate native identities, external owner rename, Schedule edit/delete, temporal rules and the shared Schedule operations. Saved changes still invalidate old generations and expose fresh owner/form data.

The actual MCP HTTP run passes four tests with zero failures or skips. The macOS app and HTTP test host compile through that run. The iOS app and native UI test host also compile. The changed Core file passes strict Swift lint; both review axes report no confirmed findings. No native UI journey or physical CloudKit/account test ran in this step.

Execution evidence records final source/product hashes, exact probe versions, before/final measurements and logs. The input fixture is the verified compressed input in the preceding scale evidence, with SHA-256 `ceece309121ad136cf6cff6a8369c35c97e70e57ea94d7ba54586d68a4c4bb65`.

## Remaining gates

Distinct Calendar results and sessions still retain their own captures; this change provides no eviction policy or maximum memory guarantee. Other query kinds retain their existing behavior. Candidate date fetching, native/physical memory and latency, and account/dataset-transition qualification remain open. Native temporal/adaptive/accessibility work and whole-app polish also remain open.
