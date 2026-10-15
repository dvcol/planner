# Shared container catalog sorting

## Context and starting state

Q85 A approves shared sorting for the top-level Lists and Itineraries catalogs. Q86 A settles exact/incomplete/unavailable estimate groups. Q87 A approves the [concrete public contract](../container-catalog-sort-contract-review.md). Before this slice, Core accepts only kind/text/archive for catalog queries and always returns alphabetical names with ascending UUID ties.

## Goal and expected end state

Implement the approved optional catalog sort through the existing public Core query/read boundary. Omitted sort remains alphabetical. Explicit Title, Created, Last updated and Full estimate support both directions without changing saved data, route/child order, completion, schedules or Q84 generation lifetime. HTTP and native integration follow separate vertical slices at their approved boundaries.

## Definition of ready

The public Core bootstrap/execute/import/export/query/read, actual MCP HTTP and production native UI seams are already approved. This first implementation cycle uses Core with a real temporary local-only store. Add only the approved value declarations before the test, leaving query behavior unchanged, so the red can observe incorrect order rather than fail to compile.

## Required TDD and definition of done

The first function creates Zoo, CAFÉ, cafe, Alpine and archived Bee for each container kind. Folded Café ties use ascending source UUID in both directions. Omitted sort and explicit ascending must give Alpine, Bee, the two tied Café identities, Zoo. Descending must give Zoo, the same ascending-UUID Café pair, Bee, Alpine. Active/archive and cumulative insensitive text selection retain their identity sets. Read two-row windows, revisit the first window and read the empty terminal window. Full export bytes must remain identical across reads.

Subsequent cycles declare independent timestamp and full-estimate fixtures before their tests. They must cover every remaining approved mode/direction, invalid kind/sort admission, stale generations after relevant edits, unchanged omitted non-container behavior and full backup preservation. The estimate sequences and uncertainty/tie rules are fixed in the approved contract. Only completed cycles receive qualification credit; adding enum cases is not evidence that a mode works.

The admission cycle queries each empty Category, Tag and Schedule catalog with archive all and omitted sort. Every explicit mode/direction must then reject with invalidInput at `/query/sort`. The original empty generations remain readable and exported data remains byte-identical. Item catalog discovery retains its existing separate rejection.

The chronological cycle imports Zulu, Alpha, CAFÉ, cafe and Beta for each container kind through the public backup boundary. Their Created offsets are 10, 30, 20, 20, 20; Last updated offsets are 50, 70, 60, 60, 80. Stable seeded identities order CAFÉ before cafe. Created ascending is Zulu, Beta, CAFÉ, cafe, Alpha; descending is Alpha, Beta, CAFÉ, cafe, Zulu. Last updated ascending is Zulu, CAFÉ, cafe, Alpha, Beta; descending is Beta, Alpha, CAFÉ, cafe, Zulu. All four orders differ. Date ties always retain ascending title/identity order. Verify persisted dates, every two-row page, filtered matches and unchanged export bytes.

The Full estimate cycle creates fifteen plans of each kind. Exact totals are Empty 0, Manual overflow 60, Museum 180, two folded Café names and Manual at 240, Long 300, Huge lower 9007199254740992 and Huge upper 9007199254740993. Incomplete plans have two folded Partial café names at least 120 with different missing counts, Partial short at least 120, and archived Partial long at least 240. Alpha overflow and Overflow are unavailable. The Café pairs use ascending UUID ties. Ascending follows those groups and values; descending reverses numeric values within each group while retaining ascending title/UUID ties and leaving both unavailable plans last in alphabetical order.

Museum's Item is globally Done and Long's Item is Archived, so remaining time cannot substitute for full estimate. Manual has missing children; Manual overflow's calculation overflows. Both manual full budgets remain exact. Itinerary Café plans reference the live 240-minute manual List, and its Overflow plans reference the unavailable List. Verify literal full totals and missing counts in every row, cumulative archive/text filtering, complete/revisited/terminal pages, retained schedules and byte-identical full exports.

External-writer qualification creates Zulu A before Alpha B for each kind. Lists reference 30-minute and 60-minute Items; Itineraries reference those Lists. A has the earlier own timestamps, and its standalone List membership is locally Done. Initial full order is A/B. Another Planner writer changes the shared 30-minute Item to 120 minutes. All old full/date generations must reject offsets 1 then 0 with staleSnapshot. Refreshed full order becomes B/A, while own timestamps and Last updated A/B stay unchanged. Renaming each A to Aardvark then gives Title A/B and Last updated B/A, retaining Created A/B and Full estimate B/A. Verify source references, membership state and byte-identical exports across read-only portions.

Run one failing behavior test at a time, implement its minimum correction and rerun it. Retain exact commands, raw output, source/product hashes and actual counts. Run focused strict Swift and Markdown checks before committing. HTTP, native controls/preferences, Mac runtime, physical performance, CloudKit/account transitions and broader map gates remain open until their own evidence is recorded.

## Initial red/green cycles

The first Title function failed on descending row/page order before implementation, in 0.315 seconds with twelve expectation issues across the two catalog kinds. Omitted and explicit ascending behavior passed. After the minimal descending-title correction, the same function passed in 0.272 seconds, one test in one suite. These are initial behavior results; final-source qualification follows below.

The admission function failed with 24 unsupported successful snapshots in 0.071 seconds. Adding the explicit non-container sort guard makes the same one-test/one-suite function pass in 0.059 seconds, including preserved prior generations and backup bytes.

The chronological function failed in 0.207 seconds with 28 ordering/page issues; the imported dates themselves round-tripped correctly. After fetching and validating only the selected sort dates, the same one-test/one-suite function passed in 0.298 seconds.

The Full estimate function failed on 44 ordering/page expectations in 47.009 seconds; its literal row totals passed. The first implementation passed the same function in 49.437 seconds. Initial source review then identified unsafe in-process SQLite fixture cleanup and duplicated catalog ordering. The reviewed revision retains named stores until process exit, with external cleanup, and shares one private sorter between model-specific adapters. Earlier greens do not establish that final revision.

## Reviewed Core qualification

All five functions pass in one suite on macOS 27.0.1, with zero failures or skips and a 22.049-second suite duration. Function times overlap because Swift Testing runs the isolated fixtures concurrently; they must not be added into a claimed suite duration.

| Function | Seconds | Qualified behavior |
| --- | ---: | --- |
| Explicit Title directions | 0.400 | Defaults, fixed UUID ties, cumulative filters, complete/revisited/terminal pages, retained earlier generation and unchanged backup |
| Non-container admission | 0.147 | All 24 unsupported kind/mode/direction combinations reject at the agreed path; omitted reads and generations survive |
| Chronological catalogs | 0.336 | Four distinct seeded date orders for each kind, persisted timestamps, fixed ties, filters, complete pages and unchanged backup |
| Full estimate catalogs | 22.049 | Certainty groups, manual/missing/overflow totals, live List branches, exact large integers, every row's full total, filters, paging and unchanged backup |
| External edits | 0.542 | Second-writer estimate/rename changes invalidate old pages and refresh order; parent timestamps, references, memberships and read-only backup bytes retain their required meanings |

The external runner waited for process exit, verified all five named UUID fixtures still contained their SQLite stores, then removed only those generated directories. Cleanup receipts are retained. No production close method or test-only public parameter was added.

Affected Mac and iPhone Simulator fixture apps and test hosts compile with signing disabled. No UI test was executed for this Core slice. Strict Swift lint passes the two affected production files and new test file. The report and adapter documentation pass Markdown lint. Logs retain an AllDayScheduleTests redundant-`#require` warning also observed in the pre-behavior-change run. A NativeCaptureLoadingTests warning appears in later logs; that source is unchanged from the base commit. The affected sources have no reported compiler warnings.

The [evidence packet](evidence/navigation/core-container-catalog-sorting/) retains exact commands, raw compressed output, initial and reviewed source revisions, source/product hashes, the external runner and cleanup receipts. The baseline is Xcode 27.0 build 27A266a, Apple Swift 6.4 and macOS 27.0.1. Final standards and specification reviews found no remaining behavior or standards issues. The specification review identified the warning-history wording above, which has been corrected.

## Remaining map gates

The optional typed Core sort is implemented and qualified here. MCP parsing/schema/HTTP adoption and native menus/preferences are separate pending integration slices. There is no claim of native catalog controls, iOS runtime sorting, Mac UI runtime, physical latency, large-catalog memory/scrolling, CloudKit/account recovery or whole-app polish. Read-only backup equality covers the actual fixtures above; it does not substitute for those broader gates. The map remains open.
