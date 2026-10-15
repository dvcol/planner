# Large Item windows after another writer

## Context and starting state

The accepted paging contract rejects a generation after saved history changes. The existing two-Item test proves that rule on a small store. The large read-only qualification traverses 5,000 Items under eight sorts but performs no intervening write. This leaves the large-store page/refresh boundary unqualified.

## Goal and expected end state

Read the first page of 5,000 Todo Items. A second Planner writer then durably marks Item 05000 globally Done. Reads from the old generation must reject at offsets 0, 64 and 4992. A fresh query must return exactly the other 4,999 Todo identities across 79 pages, preserving the completed source and all saved references.

## Definition of ready

Use the already accepted public Core bootstrap, import/review/execute, query/read and export/decode boundaries with two Planner actors sharing one real local-only store. Reuse the verified 5,000-Item/200-List fixture and retain its named directory until the test process exits. This is one controlled write between page reads, not a physical multi-device or arbitrary concurrency test. Q86 does not affect it.

## Required tests and definition of done

Require staleSnapshot with the requested generation on all three obsolete page reads. Request offset 64 first, matching the next-page boundary, before rechecking offsets 0 and 4992. Compare every refreshed page against the independent seeded identity sequence without Item 05000. Verify the changed generation, full 4,999 count, page offsets and Todo/Active state. Read Item 05000 as Done and Active. Decode the saved export and verify all 5,000 source Items, 200 Lists, unique 5,000 memberships, complete Item coverage and twenty-five members per List. Compare every membership record before/after, preserving identities, lifetimes, bindings, ranks and local Todo flags. Run the one focused Core function and affected formatting/Markdown checks; retain exact source/product hashes, raw output and cleanup evidence.

## Execution

The initial function passes in 22.101 seconds. Its old-generation reads request offsets 0, 64 and 4992. That revision and output are retained separately. The final revision requests offset 64 first, so another stale read cannot clear the requested binding before the actual next-page boundary is checked.

The final function passes in one suite, one invocation, with zero failures/skips in 20.588 seconds on macOS 27.0.1. All three obsolete reads return staleSnapshot with the requested generation. The original reader then refreshes to exactly 4,999 Todo/Active Items across 79 pages, matching every seeded identity except Item 05000. That source remains saved, globally Done and Active. The decoded export retains all 5,000 Items, 200 Lists and 5,000 unique memberships. Every membership record equals its pre-write value, including local completion and saved order.

The external runner observed the SQLite store after successful test-process exit, then removed only the generated fixture directory. The [evidence packet](evidence/navigation/core-large-item-window-refresh/execution.json) retains exact commands, initial/final source revisions, source/product hashes, raw output and cleanup receipts. Strict formatting passes the one affected Swift file; the report passes Markdown lint.

This qualifies existing behavior; no functional red is manufactured and production code is unchanged. The two Planner writers share one real local-only store in one process. Native cancellation/selection, simultaneous or physical-device writes, memory/hitches and the physical latency gate remain separate requirements. Q84 C and the pending Q86 choice are unchanged.
