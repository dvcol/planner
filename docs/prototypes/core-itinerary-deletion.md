# Reviewed Itinerary deletion

## Context, starting state and goal

At `852ba27`, Core supports reviewed Item, List, Category and Tag deletion. Itinerary deletion remains unavailable. An Itinerary owns ordered Item/List entries, links, label associations, appointments and persisted expanded local completion. Its referenced Items and Lists also serve other plans and retain their own completion.

The goal is container-only deletion through public Core. Review the complete owned removal set, require an issued review token, commit it together locally, and preserve every shared source and other plan. This slice provides the transaction; native presentation follows separately.

## Definition of ready

- Archive plus confirmed Delete, without Trash, is accepted. Container deletion preserves source Items and Lists.
- Repeated appearances have independent local completion. Item global Done takes precedence; List-local completion remains independent of itinerary appearances.
- Full review covers owned links, labels, appointments, route entries and persisted expanded contexts, including archived content.
- Minimal lifetime markers, exact operation replay and independent local recovery are accepted.
- Tests use public Core commands/reads/recovery inspection, configured recovery I/O and actual authenticated HTTP. The existing native-save notification obstruction observes real I/O; no private database query or production test-only seam is added.

## Definition of done for this Core slice

- Review identifies the Itinerary and every owned reference. Source Items, Lists, labels and appointments owned elsewhere never enter the deletion set.
- Missing, unknown or foreign-session tokens and changed commands apply nothing. A changed removal set requires fresh review.
- One local save removes the closure and stores minimal markers and a replayable receipt. Recovery failure before save preserves the dataset; failure after save reports applied but incomplete and blocks later writes.
- Source content, states, timestamps and membership order remain unchanged. Other itinerary route order, local completion and appointments survive reopening.
- Empty Itinerary deletion is valid. Exact replay works after the source is gone; ordinary later commands cannot recreate the deleted identity.
- Recovery rejects markers that close a live Itinerary, unsupported restoration-family metadata and duplicates. MCP refuses deletion even with a native-issued token.
- Affected Core, simulator and HTTP qualification, strict Swift lint and compilation pass with recorded source epochs and limits. Native UI and physical iCloud proof remain separate gates.

## Required /tdd and observed behavior

The public tracer creates Museum and globally Done, archived Park with separate links and shared labels. Tokyo Food contains both; Wishlist contains Museum. Tokyo Food's standalone Museum is locally Done. Archived Weekend contains Museum, Tokyo Food twice and Wishlist in saved order, with separate appearance flags yielding four of six Done. Rain plan independently contains Park, Tokyo Food and Museum, with three of four Done. Museum and Rain plan each own an appointment; Weekend owns two links, two labels and two appointments.

The initial tracer stopped at compilation because it assumed a top-level portable `ownedLinks` field. The corrected tracer reached functional red at the unavailable Itinerary review in 1.366 seconds, with all 285 baseline source/configuration files unchanged. Its unchanged first green passed in 1.591 seconds.

Review reports 13 targets: the Itinerary and 12 removed references. The two owned Schedule sources also appear in deletion impact. Confirmed deletion preserves both Items' content, hashes, timestamps and global/archive states; both Lists' content, state, memberships and standalone progress; and Rain plan's content, hashes, timestamp, route order, three-of-four progress and appointment. Museum's appointment survives. Recovery retains seven sources, six label associations, three memberships, three route entries, one expanded context, two appointments and nine minimal markers. Reopening proves the deleted plan and appointments remain absent and exact replay returns the original result.

Later admission tests qualify second-writer additions of an entry, expanded completion, owned link, appointment or label association after review. Each invalidates the old token without changing acknowledged data; fresh review succeeds. Token/session identity, changed replay, empty impact and configured recovery I/O failures also pass. A compilation correction replaced guessed mutation cases with the existing guarded `editItinerary` command. No additional missing-feature red is claimed.

## Qualification

Final qualification passes 54 Core functions in 25 suites, the same 54 functions in 25 suites on the iOS 27 simulator, and three macOS authenticated HTTP functions in three suites. All report zero failures/skips. The HTTP deletion function covers five source kinds. Eight affected Swift files pass strict formatting lint; Core and the Mac app compile. Shared deletion, bulk completion, membership/appointment removal and itinerary edit/archive/schedule/completion tests cover the recovery changes.

The evidence record retains commands, log hashes, transitions and both source/configuration epochs. First green contains 286 files; qualification adds the admission test and changes only the existing integrity and HTTP tests, for 287 files. Production and the tracer remain unchanged after first green. The committed simulator summary, test tree, HTTP summary and HTTP test tree retain authoritative counts and parameterized cases.

The HTTP host emitted autoShortcut service-connection diagnostics. Metadata-extraction diagnostics and the previously recorded AllDayScheduleTests redundant-require warning remain unresolved. This slice supplies zero native UI runtime functions and no physical sync qualification.

## Implementation and remaining gates

Core resolves native inverse relationships and reverse records before deletion. The digest binds the Itinerary lifetime, links/appointments, label associations, route entries and persisted expanded membership lifetimes, plus the exact removed relationships. Existing Item, List and label digest formats are unchanged.

Deletion prepares independent recovery, explicitly deletes child records because native relationships nullify, and commits the removal, receipt and minimal markers in one local transaction. Surviving sources retain their timestamps. Markers contain identity metadata rather than the deleted title or notes. Expanded contexts close with their entry lifetimes; no Trash interface is introduced.

No persisted fields, migration, portable version or agent permissions change. Schema 14 and portable format 1 remain localOnly. Native Itinerary Delete, controlled native failures, admin/restore, physical mirrored conflicts, signing/account/Share, native Mac runtime and whole-app polish remain open. Local markers do not prove deletion wins against an offline device returning through iCloud. Calendar/estimates await Q59-Q61; Q57/Q58 groups/loading remain pending. Calendar export remains outside this map.
