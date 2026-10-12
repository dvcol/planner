# Archive-aware container progress

## Context, before and goal

At `3b43d43`, Core counts only global or local Done children toward container completion. A List with one Done child and one archived Todo child remains partial. Q68/Q69 require both children to finish that List, and require an archived referenced List to finish its branch inside an itinerary. Stored Done flags stay independent from archive.

## Definition of ready and public contract

- Q68 B, Q69 A and Q72 B are settled. An archived container's own progress remains child-based; its own archive flag does not finish its children. An archived List branch finishes its child appearances in the parent itinerary.
- Keep `doneCount` as the number of effectively Done appearances. Add `archivedCount` for appearances finished through Item or branch archive which are not already effectively Done. Add derived `finishedCount`, the sum of those disjoint counts. A nonempty container is complete when finished equals total; empty remains empty.
- Source reads and unfiltered progress in query snapshots must agree. Item completion predicates and appearance reads retain global Done OR local Done, without treating archive as a Done flag. Container/header completion uses finished progress.
- These are derived read values. No schema, portable backup, recovery content or saved completion flags change. MCP serializes established counts as exact decimal strings and unavailable counts as null.
- Use the agreed public Core execute/read/query, actual HTTP and native UI seams. No private-helper tests or test-only production injection.

## Definition of done and required /tdd

- A List with one locally Done child and one archived Todo child becomes complete after archive and reopen. Its memberships, content and retained Done flags stay unchanged. Unarchive restores partial progress.
- Archive a referenced List with active Todo children: the itinerary branch finishes, while an active direct appearance of the same Item remains unfinished. Standalone List progress stays child-based. Repeated branches count independently.
- Source reads and filtered query progress expose the same full counts. Done/archive overlap counts once; own container archive, empty Lists and global Reopen preserve their accepted semantics.
- Native progress uses finished counts, distinguishes Done from archive retirement and keeps check circles attached to actual Done state. Header matching uses that itinerary branch's completion. HTTP exposes the same exact counts.
- Focused store/reopen, wire and native journeys pass; lint/type checks and real captures qualify the affected paths. Signed sync/account/Share and whole-app polish retain their separate gates.

## Execution

The public store/reopen test first failed because the archived-child List remained partial. Further red results exposed mismatched filtered query progress and missing retirement of repeated List branches. Source and query reads now report disjoint Done and archive-retirement counts, with finished as their sum. Tests prove unarchive, global Reopen, Done/archive overlap, independent direct appearances and an archived container's own child-based progress without changing saved Done flags or reference identities.

Ten focused public Core test functions pass across eight affected suites. Nine actual loopback HTTP test functions pass across two suites, including exact decimal count strings and the zero-count empty envelope. The HTTP red exposed the missing two response fields. One existing exact appearance-key assertion also omitted the already-contracted labels field; the corrected assertion and full affected suite pass. Seven affected Swift files pass strict lint, and the Mac app/test host compiles as part of the HTTP run.

The [execution record](evidence/core/archive-progress/execution.json) includes Core red/green logs, actual HTTP summaries and the source snapshot. Storage schema 14, portable format 1 and local-only ownership remain unchanged. [Native List presentation](native-list-archive-progress.md) is now qualified on phone/tablet. Native itinerary progress/header matching, aggregate estimates/remaining, Calendar, physical sync/account/Share and whole-app polish remain open.
