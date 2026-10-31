# Native large collection and far-end search

## Context, starting state and goal

The map approves 5,000 Items and 200 Lists for the eventual 300 ms physical-device acceptance gate. The current native loading journey proves forty Items and four Lists. Production native Item catalogs initially requested every matching row in one Core read. Native lazy rendering alone did not make those reads interruptible or prove bounded data fetching.

The goal here is a real native baseline at the approved size. Open the large collection, find its last alphabetical Item through search, complete it, inspect its live appearance in the two-hundredth List, and reopen the same source identity and completion. This supplies a runnable fixture for later paging, latency and memory work. It does not substitute for that work.

## Definition of ready

Q52 approves the dedicated fixture scheme using production views and real local stores. The accepted duration/search record specifies the collection size and far-end search requirement. Use public portable-data decoding, reviewed import and durable save to seed a disposable local-only dataset. Public Core queries verify exactly 5,000 Items and 200 Lists on initialization and relaunch. Each List contains twenty-five Item references; every Item appears once. Existing schema, query, sort, completion and native UI seams remain unchanged. Q85 governs separate catalog sorting and is not assumed answered.

## Required qualification and definition of done

- Import 5,000 unique Items, 200 unique Lists and 5,000 memberships through the public Core boundary. Reopening must not reseed a populated dataset or silently accept the wrong source counts.
- Open the production Items catalog at Scale Item 00001. Search Scale Item 05000 and require one result with the expected far-end notes. Complete it globally from its original Item view; its valid detail stays selected.
- Traverse to Scale List 200. Its twenty-five live children must derive one finished Item. Show all completion states and observe the far-end appearance as Completed.
- Relaunch, include Done Items, search the same far-end source and retain its identity, notes and global Done state.
- Run the focused native journey on phone/tablet, strict affected Swift/Markdown checks and Mac fixture/test-host compilation. Retain actual failures, original captures, commands, source/product hashes and exact qualification limits.

The native baseline found real completion and search failures at this size. The unchanged five-second completion wait failed on phone and tablet. A serial search reproduction also exceeded its thirty-second wait. Those public native failures precede the production fixes below; fixture-schema and probe-compilation failures are setup errors and receive no feature-red credit. Full traversal completeness, stale-query races, every sort, final-input-to-visible latency, scrolling hitches, peak/steady memory, bounded data paging and physical-device acceptance remain open. No window size or query retention cap is introduced. Mac runtime, account/sync/Share and whole-app polish remain separate gates.

## Diagnosis and change

A three-second sample of the exact disposable simulator process found 770 of 829 sampled worker stacks in membership validation. Each Membership scanned the Item collection to verify its binding. Item and List lifetime indexes now replace those repeated scans. Existing duplicate-source checks precede index construction; kind, identity, lifetime and canonical-rank checks remain unchanged. Full recovery preparation, validation and durable acknowledgment remain required.

A separate serial search reproduction sampled native full-catalog row reads while the final search was waiting. Item reads now use generation-bound pages of 64 rows and check cancellation around every page. A stale generation discards the entire accumulation and restarts its query. This permits newer searches and details to run between pages, without truncating results or changing Core's public query contract or Q84 C retention policy. The native catalog still accumulates its complete matching array before display. Moving-window retention remains unqualified.

The first paged-read attempt passed the sole far-end search but retained the completion failure. Its original capture showed the prior completion after the saving overlay had disappeared. The existing selected-Item refresh now runs before List and Item catalog refreshes, retaining its identity, revision and deletion guards. Selected-appearance handling remains in its existing order.

Temporary tagged logging and the extra sixty-second diagnostic observation were removed. The extra observation never replaced the original failing five-second assertion. It established that the earlier save returned after about 17.37 seconds and the selected detail changed after about 30.16 seconds in that diagnostic run. These simulator observations are not calibrated physical-device latency measurements.

The next attempt passed search and completion, then stopped at an incorrect test expectation. The unarchived fixture uses the existing label "1 of 25 items done", rather than "finished". Correcting that assertion changes no production behavior and receives no product-red credit.

A subsequent attempt reached the saved Completed List appearance and relaunched, then tried to open Filters while the catalog still showed its loading state. The controller now waits for that actual native control to exist before interacting, just as it waits for the initial catalog. This is a test-readiness correction; the completion and final-search waits remain unchanged.

The earlier complete phone pass did not settle the iPad result. An iPad attempt still missed the original completion wait and showed Completed only in the following capture. Its separate tagged probe measured about 4.49 seconds until the save returned, then about 2.09 seconds for selected-source reading. Item-source reads previously fetched every Item before filtering by identity. They now use a native UUID predicate with a two-record limit, preserving the exactly-one guard and the existing content/reference validation. This follows the existing List-source fetch pattern. Temporary probes were again removed before qualification.

## Execution

The complete large-collection journey passes on the final source revision on both simulators:

| Runtime | Native functions | Failures / skips | Function elapsed time |
| --- | --- | --- | --- |
| iPhone 18 Pro, iOS 27.0 | 1 | 0 / 0 | 212.900 seconds |
| iPad Air 11-inch M4, iOS 27.0 | 1 | 0 / 0 | 206.542 seconds |

Each run retains the same far-end source identity, notes and global Done state after relaunch, verifies its Completed List appearance and observes one Done child out of twenty-five in List 200. Public fixture queries/export verify the complete source/membership counts on initialization and reopen. Each run retains four original PNGs and its exact observed Item, List and appearance IDs.

The latest focused Core checks pass twelve functions across nine suites, with forty-one invocations including thirty invalid-input cases. Recovery inspection also rejects fourteen malformed membership/expanded-context payloads inside its existing function. These checks cover completion, owned references, missing-store admission, recovery integrity and large import decoding through public boundaries. The introduced immutable-variable warning was corrected before this final run.

Two nearby native regressions also pass on each device, four invocations in total. They cover Item draft cancellation and global completion after relaunch, and deletion from a List appearance clearing the removed selection while preserving the List. Their six original PNGs and result records are retained.

The current-source Mac fixture/test-host compilation and ordinary app build both pass with signing disabled. Strict formatting passes for all nine affected Swift files. Test-function elapsed time includes setup, automation and traversal; it is not final-input latency. No Mac runtime, physical-device, CloudKit or HTTP run is credited by this slice.

The original iPad captures still show a catalog heading clipped beneath its native toolbar. App-wide adaptive polish remains open.

The evidence packet separates setup errors, diagnostic attempts, superseded source revisions and final runs. Its commands, source and product hashes, raw compressed logs, result summaries and original images make those boundaries reviewable.
