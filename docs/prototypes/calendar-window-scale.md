# Calendar owner reads at scale

Calendar now resolves referenced owner titles in batches while retaining the existing source, lifetime, relationship and form checks. On a desktop fixture with 5,000 Schedules, the median unlogged three-day query fell from 1.611 to 0.304 seconds. A separate native SQL trace fell from 30,011 to 17 SELECTs for a query and three one-row pages.

## Context and goal

Before: each retained Schedule fetched its owner separately. SwiftData also loaded the owner's memberships, links, label associations and itinerary references, although Calendar needed only identity, lifetime and title. The 5,000-Schedule trace contained 5,000 SELECTs for each of those five owner/relationship tables, plus Schedule and history reads.

After: Calendar groups referenced Item and Itinerary identities, fetches each owner kind together and requests only its identity, lifetime and title properties. Native relationship validation remains in place. The same public query returns the same three identities, live titles, saved forms and generation-bound pages. Exported data is byte-identical before and after the reads. No schema, command or public read contract changes.

Review also found an existing duplicate-identity gap: two Schedules with one identity but different dates could escape the check after filtering. Every resolved Schedule identity is now checked before filtering, so that malformed catalog rejects the whole read.

## Definition of ready

Q81 A and Q82 A approve the [Calendar contract](../calendar-window-contract-review.md), including public Core query/read/store tests and the real MCP HTTP seam. The contract requires measurements of actual storage work, latency and memory. This step uses a local-only disposable dataset and the current versioned public import/export grammar.

## Definition of done for this step

- Measure the existing implementation through public Core calls with a large saved graph and a small date window.
- Reduce repeated owner fetches without weakening ownership, lifetime, relationship, form or generation validation.
- Preserve complete identities, live titles, ordered pages and the saved backup.
- Reproduce and fix the duplicate identity gap through a public failure regression before committing.
- Pass affected Core and actual HTTP tests, strict Swift lint, native compilation and both review axes. Retain commands, input, measurements, logs and hashes.

## Measurements

The fixture contains 5,000 Items, 200 Lists, 5,000 memberships and 5,000 start-only timed Schedules, one per day from 1 January 2026 in GMT. The requested 9–11 January window contains exactly three Schedules. Each of three iterations reads a fresh query and three one-row pages. The probe uses only public Core APIs and verifies literal expected identities and titles.

| Measurement | Before | After |
| --- | --- | --- |
| Unlogged query seconds, three iterations | 1.6114, 1.6110, 1.6136 | 0.3001, 0.3039, 0.3101 |
| Median query plus three pages, seconds | 1.6801 | 0.3785 |
| Logged SELECTs for query plus pages | 30,012 / 30,011 / 30,011 | 18 / 17 / 17 |
| Process resident memory after first query | 380,108,800 bytes | 380,485,632 bytes |

SQL tracing changes timings, so latency uses separate unlogged executions. The first logged iteration includes one SQLite metadata SELECT. Final logged iterations contain two Schedule SELECTs, one Item SELECT, four relationship SELECTs and ten history SELECTs. This fixture schedules Items only; ordinary Core tests also cover Itinerary owners.

Resident memory is the entire macOS debug probe after importing and exporting the large graph. It is neither query allocation nor a mobile memory budget, and does not show a memory improvement. All iterations retained the three matching identities, titles and pages. Full exports remained unchanged.

## TDD and qualification

The new public regression creates two valid Schedules on separate days, then introduces duplicate native identities at the SQLite I/O boundary. Before the fix, requesting one day returned a successful incomplete snapshot. It now returns `readUnavailable`. Test setup uses the native SQLite C API, with no production injection or private-model assertions.

The final affected Core run passes 32 invocations across 11 suites. It covers Calendar windows, pages, invalid inputs, live owner changes, temporal boundaries and the shared Schedule read/edit/delete/zone/catalog behavior. One existing all-day function has two zone arguments. The actual MCP HTTP run passes four tests with zero failures or skips. The iOS app and native UI test host compile; the affected regression source also type-checks for the iOS simulator with Swift Testing's native macro plugin. Two affected Swift files pass strict lint. Standards and Spec reviews have no remaining confirmed findings.

No native UI journey ran for this Core-only step. The macOS app and HTTP test host compile as part of the real HTTP run. Physical device, CloudKit and account-recovery evidence is unchanged.

[Execution evidence](evidence/navigation/calendar-window-scale/execution.json) retains the exact probe, public export templates, compressed fixture, measured SQL logs and summaries. `generate-fixture.py` reconstructs the exact 5,118,801-byte input and checks its hash. The archived probe expects that input at `/private/tmp/PlannerCalendarScale5000.json`; its result path is fixed, so copy each result before another run. Rebuild its temporary package against the intended checkout before comparing versions.

## Remaining gates

Calendar still fetches and validates every retained Schedule before matching dates. These batches reduce repeated native fetches; they do not prove bounded work as the catalog grows. Candidate date fetching, generation-cache retention and physical mobile latency/memory remain open. Existing temporal/adaptive/accessibility qualification and whole-app native UI polish also remain open. Apple Calendar export stays outside the map.
