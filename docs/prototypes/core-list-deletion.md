# Reviewed List deletion

## Context, starting state and goal

At `db43f2d`, Core reviews Item, Category and Tag deletion, and the native app confirms those actions. List deletion remains unavailable. A List owns memberships and may appear repeatedly in an Itinerary; each expanded Item appearance can have its own local completion. Its Items may also belong to other Lists, appear directly in routes and own appointments.

The goal is container-only deletion through public Core. Review the complete List removal set, require the current session's token, and save the container, memberships, itinerary references and expanded contexts together locally. Retain the Item sources, their owned content and state, other Lists, direct route entries and every surviving appointment. There is no Trash state or automatic deletion timer.

## Definition of ready

- R10's confirmed removal and R14's Archive plus Delete contract are accepted. Deleting a List preserves its source Items.
- Q8 and the later repeated-appearance decision govern independent completion. Archived and filtered children belong to the complete removal closure.
- Minimal deletion metadata, exact operation replay and truthful independent recovery outcomes are already accepted.
- Tests use the approved public Core commands/reads, recovery inspection and configured recovery I/O, plus actual authenticated HTTP. No private database queries or production test-only seams are added.

## Definition of done for this Core slice

- Review identifies the List and every owned membership, referencing itinerary entry and persisted expanded completion, without adding Item or Schedule sources to the deletion set.
- Changed dependencies require a fresh review; missing, unknown or foreign-session tokens and changed commands apply nothing.
- One local save removes the complete closure and stores minimal lifetime markers and a replayable receipt. Failure before save preserves the previous dataset; failure after save reports applied but incomplete and blocks later writes.
- Remaining Item content, archive/global completion, labels, links, timestamps and appointments remain unchanged. Other List state/order and surviving itinerary appearances/local completion/order remain readable after reopening.
- Empty List deletion is valid. Replay does not require the deleted source to remain present, and later ordinary membership/entry commands cannot recreate it.
- Recovery rejects a marker that closes a live List, unsupported restoration-family metadata and duplicate markers. MCP still rejects source deletion even with a native-issued review token.
- Focused Core, simulator and HTTP qualification, affected-file lint and compilation pass, with exact source epochs and limits recorded. Native List Delete presentation and physical iCloud proof remain separate work.

## Required /tdd and observed behavior

The public tracer creates Museum and archived Park with separate links and shared labels. Tokyo Food owns both memberships; Wishlist independently owns Museum. Tokyo Weekend contains Museum, Tokyo Food twice, Wishlist and Park in saved order. Independent direct and expanded completion makes four of seven itinerary appearances Done. The Item and Itinerary each own a separate appointment.

Two initial runs stopped at test compilation because the assertions assumed Hashable references, Equatable source state and a List-read lifetime field. The corrected test compares exposed state fields and reads the List lifetime through public recovery inspection. Its functional red reached the unavailable List review in 0.828 seconds. The unchanged tracer then passed in 0.974 seconds.

Review reports seven targets: the List, two memberships, two route entries and two persisted expanded contexts. Confirmed deletion retains Museum, Park, Wishlist, shared labels and both appointments. The surviving route has Museum, Wishlist and Park in the original order and two of three appearances Done. Wishlist's standalone completion remains zero of one. Recovery contains five minimal markers and the one retained expanded context. Reopening proves the deleted List and contexts remain absent and exact receipt replay returns the applied result.

Later admission tests qualify a second writer adding a membership, route reference or persisted expanded context after review. Each rejects the old token without changing the acknowledged data and succeeds only after fresh review. Token and operation identity checks, empty impact and real recovery I/O obstructions also pass. These qualify implemented behavior; no additional missing-feature red is claimed.

## Qualification

Final focused qualification passes 37 Core functions in 18 suites, 28 iOS 27 simulator Core functions in 14 suites and three macOS 27 authenticated HTTP functions in three suites, with zero failures/skips. Eight affected Swift files pass strict formatting lint; the targets compile. Existing Item/label deletion, List edits/archive, bulk completion, membership and schedule removal, and itinerary completion/closure tests cover the shared recovery changes.

The evidence record retains commands, log hashes, before/after behavior and both source/configuration epochs. First green contains 283 files; final qualification adds the admission test file and updates only the existing integrity and HTTP qualification tests, for 284 files. Production and the original List tracer remain unchanged after first green. The simulator summary, simulator test tree, HTTP summary and HTTP test tree retain the authoritative results and parameterized cases. The test tree reconciles an interleaved simulator log row without reducing the reported scope.

The HTTP host emitted autoShortcut service-connection diagnostics. Compilation also emitted metadata-extraction diagnostics and the previously recorded AllDayScheduleTests redundant-require warning. Resolution of those diagnostics is not claimed here; no native UI or physical sync runtime qualification is claimed for this Core slice.

## Implementation and remaining gates

Core resolves the native and reverse relationships before saving. Its review digest binds the List, memberships, Item lifetimes, itinerary entries and owning Itinerary lifetimes, plus the exact removed reference relationships. The existing Item and label digest formats are unchanged.

Deletion prepares the independent backup, explicitly deletes child reference records because native relationships nullify, and saves the List removal, receipt and markers in one local transaction. Surviving Itinerary entries retain their rank and completion. Only affected Itinerary timestamps change; Item and unrelated List timestamps do not change. Expanded contexts close with their membership/entry lifetimes. List markers retain identity metadata without the deleted List's name or notes.

No persisted fields, migration, portable version or agent permissions change. Schema 14 and portable format 1 remain localOnly. Native List/Itinerary Delete, recovery repair, import/restore, nonempty restoration families, native save-failure presentation and whole-app polish remain open. The local transaction and markers do not prove physical iCloud deletion winning over a returning offline device. Signing/account/Share and native Mac runtime retain their gates. Calendar and itinerary estimate implementation awaits Q59-Q61; Calendar export remains outside this map.
