# Large Item query windows

## Context and starting state

The native scale journey imports 5,000 Items and 200 Lists, finds the far-end Item and keeps its saved completion after relaunch. It does not traverse every source through the shared Core paging interface. The accepted duration/search gate requires comparison with the complete logical result, no missing or duplicate identities, a far-end sole match and revisiting earlier rows.

## Goal and expected end state

Qualify the existing public Item query and row-window reads at the approved size. Read all 5,000 identities across 64-row windows in Title, Created, Last updated and Duration order, both directions. Revisit each first page, read past each final row and find Item 05000 as the sole search match. The oldest generation must remain readable after the other sort queries. A full portable export must remain byte-identical after these reads.

## Definition of ready

Use the accepted Core query/read and portable import/export boundaries with a disposable local-only real store. Import exactly 5,000 Items, 200 Lists and 5,000 memberships through decode, review and durable execution. Decode the saved export to verify unique membership identities, complete Item coverage and twenty-five children per List. Fixed-width titles, increasing creation dates and minute estimates, and decreasing last-update dates define independent forward/reverse sequences. Keep the named fixture directory until the test process exits; the external runner then removes only that generated directory. This qualification adds no production API, storage policy or test-only production parameter. Q84 C is preserved; Q85 container sorting is not assumed answered.

## Required tests and definition of done

Compare every public query snapshot and traversed page against all seeded source identities in the specified order. Require 79 pages per sort/direction combination, one generation per traversal, correct offsets/counts and unchanged presentation context. Revisit the first 64 identities after every traversal; offset 5000 returns an empty window with full matching count retained. The first title generation still serves its original page after all eight queries. A query for Paging Item 05000 returns exactly that source. Global Todo, local-state absence and archive values remain unchanged. Run the focused Core test, affected Swift formatting and Markdown checks, and retain exact commands, results and source/product hashes.

## Execution

The initial title-only function passes in 18.664 seconds, covering all 79 pages and retaining byte-identical exported data. The first eight-combination function passes in 90.635 seconds. Both revisions and raw outputs are preserved. Review then added explicit persisted-membership assertions and moved disposable-store cleanup beyond the SwiftData test process's lifetime.

The reviewed revision passes one function in one suite, one invocation, with zero failures/skips in 96.307 seconds on macOS 27.0.1. Its eight internal sort/direction scenarios traverse 632 pages and 40,000 ordered row appearances. Each scenario revisits its first 64 rows and reads an empty terminal window. The oldest title generation remains readable after the other sort queries; the far-end search returns exactly Item 05000. The full backup remains byte-identical. Saved export validation proves 5,000 unique memberships, complete Item coverage, exactly 200 referenced Lists, twenty-five members per List and retained local Todo state.

The external runner observed the SQLite store after process exit, then removed that exact generated fixture directory. The evidence packet retains its cleanup receipt, raw outputs, source revisions, compiled-test hashes and commands. Focused formatting passes the one changed Swift file, and the report passes Markdown lint. There is no production change or new native UI, HTTP, CloudKit or physical-device execution.

This is qualification of existing behavior, with no manufactured functional red. Additional tie/missing-estimate fixtures, scoped Manual order, concurrent stale/canceled queries, full native traversal, memory/hitches and physical 300 ms acceptance receive no new credit here.
