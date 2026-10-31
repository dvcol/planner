# Native full-graph backup file

## Context and starting state

Native import has represented Tag and invalid-input evidence. The approved portable fixture contains two Items, two Lists, one Itinerary, a Category and a Tag, with memberships, independent completion, bookings, labels, bookmarks and deletion/history metadata. Core accepts that graph, but the native file import/export path has not established that it delivers the complete graph.

## Goal and expected end state

Import the committed [version-1 graph](../fixtures/portable-backup-v1.json) into an empty local planner through Files. Review seven source additions and explicitly confirm. Export through the native Save flow, then compare the actual delivered JSON with the expected graph, allowing only the documented version-2 format and absent manual-estimate fields. Preserve every source, relationship, lifetime, rank, timestamp and owned value.

After relaunch, native UI must show Museum globally Todo with live Food/rainy-day labels and Original notes. Tokyo Food retains its locally Done Museum and archived lunch, finishing both appearances. Wishlist's Museum stays Todo. Tokyo Weekend remains independent with one archived child finished out of three appearances.

## Definition of ready

Full-backup, exact-identity, empty import, independent local completion and version migration rules are settled. Reuse existing native file-import/export and public delivered-file boundaries. Stage the unchanged committed input in the disposable simulator Files location. No additional production interface, test hook, target, dependency, data format or signing setup is proposed.

## Required tests and definition of done

- Execute one native full-graph journey on phone and tablet. Record its real filename, review/apply/save outcomes, relaunch and literal source/context expectations.
- Compare the actual delivered file against the independent fixture. Keep all record groups and field values; do not normalize away changed identity, lifetime, rank, completion, content or history. Record any allowed format migration explicitly.
- Compare top-level record tables as complete collections, preserving duplicate counts, every rank and all nested sequence values. JSON booleans remain distinct from numbers; numerically equal integer/decimal encodings represent the same numeric value.
- Recheck an existing Tag export/import consumer after sharing its native exporter helper. Preserve failed attempts and actual result/source evidence.
- Inspect original named captures, run affected lint/type checks and compile the Mac app/native UI target. Keep runtime Mac, replacement/deletion-family/stale/recovery cases, physical sync/account/Share and final polish separate.

## Execution

The initial phone invocation fails in 62.988 seconds at its new global-completion assertion. The test used the mobile button-only lookup helper for a native Toggle. The correction uses the existing any-element identity query and waits for that control before reading its Boolean state. This failed invocation remains failed; no wrong imported state or production defect is established by it.

Before that assertion, the same invocation completes native import and export. Its actual 12,498-byte delivered file independently matches all eleven complete record collections against the committed fixture. The only data-format migration is version 1 to 2 and a null manualEstimate field for List/Itinerary content. Every source, lifetime, rank, timestamp, scoped completion, booking, bookmark, label association and deletion/history value matches. The verification explicitly records that the UI invocation failed. Both original review/export captures were inspected.

The corrected phone journey passes in 89.279 seconds. The iPad dark-mode bundle passes the graph journey in 98.010 seconds and the existing malformed/Tag export/import regression in 88.286 seconds. The affected phone regression also passes separately in 66.820 seconds. These are four final passing invocations of two functions, with zero failures/skips; the earlier phone invocation remains failed.

Both final delivered files are 12,498 bytes with SHA-256 `3849d4f9cf2dd4d4928eb22d8cf6713bfb61278328ae2de0663c1851745fd75a`. Independent verification compares every typed field and collection with the version-1 fixture after the declared format migration. Table order is treated as representation; duplicate counts, ranks and nested order remain exact. The files are read from the real native Save destinations and have modification times after their test starts. This verifies delivered content rather than inferring it from the export-success label.

Six final captures per device were individually inspected. They show review/export, global Todo, locally Done Museum in Tokyo Food, independent Todo in Wishlist and one archived appearance out of three in the Itinerary. The native schedule previews retain the one-hour timed booking separately from the two-hour Item estimate and preserve the October 9–11 all-day dates. The tablet returns to its original light appearance after the dark run.

The first inspection incorrectly reported invisible Estimate/Remaining titles in the dark tablet's standalone List header. Reopening the original Tokyo Food and Wishlist captures confirms both titles are visibly rendered in secondary text. That finding is withdrawn; no production correction or regression test is justified by these captures. The original review JSON retains the historical claim, superseded by this correction. These represented captures still do not establish complete dark-mode acceptance.

## Final validation and limits

Mac app/native UI-target compilation passes with the existing local ad hoc configuration and no UI invocation. Final phone, tablet, regression and Mac epochs match 1042 frozen source/configuration/fixture inputs. Affected strict Swift/Markdown lint, whitespace, original result reconciliation, unchanged-production checks and compiled-product checks pass. No production, Core/MCP, schema, dependency or signing/account behavior changes in this slice.

The evidence directory retains `native-backup-graph-*` commands, logs, actual summaries, input hashes, original captures, the delivered JSON files and their verification recipes. The input fixture initially remained staged for follow-up. After the [nonempty graph qualification](native-backup-graph-conflicts.md), its phone/tablet copies are removed only after hash verification. No Planner dataset or delivered export is removed. This does not claim the separate App Intent fixture-disposal procedure applies to native UI datasets.

This qualifies the represented full graph's empty native file import, relaunch, scoped state and delivered export. Nonempty Skip/Overwrite graph conflicts, restoration families/deleted lifetimes, stale review, read/save/termination and incomplete recovery retain their own gates. Actual Mac interaction, signed CloudKit/account/Share, physical performance and final whole-app polish remain open. No issue is closed.
