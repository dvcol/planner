# Sync crash and cold search investigation

## Evidence

Six symbolicated iPhone reports from version 1.0.0 (17), on iOS 27.0.1, share
one stack: SwiftData inverse-relationship reconstruction during
`ModelContext.rollback()` in `Planner.persistPrivateSync`. The process aborts
with a Swift dynamic-cast failure. These reports are not memory-pressure kills.
The reports do not include the validation error that led to rollback.

Disposable SQLite fixtures exercised deletions, related inserts, malformed
records, and post-staging validation failure on Mac and iOS. The largest
rollback probe covered 48 cases on iOS. They did not reproduce the framework
abort. The original incoming graph and its rejected validation error remain
unknown.

## Import failure safeguard

The incoming import already uses a fresh context with autosave disabled. It
validates the staged graph before its first save. On validation failure, discard
that context and the cached container without invoking rollback. The original
error still propagates to the private-sync error reporting path. No validation,
ownership check, or recovery requirement is relaxed.

`PrivateSyncImportIsolationTests` exercises rejected incoming graphs at the real
SwiftData/SQLite boundary, reopens the store, compares every saved cloud node,
and saves a subsequent valid import. It verifies failure isolation and retry;
it does not reproduce the original device abort or identify the rejected record.
Physical-device private-sync verification remains necessary.

## Cold text search

A read-only query of the selected Mac library took 29.5 seconds on its first
text search and 0.12 seconds on a repeat. A controlled fixture reproduced the
scaling problem through the public Core query API:

| Shared-label Items | Before | After |
| --- | ---: | ---: |
| 100 | 0.843 s | 0.065 s |
| 500 | 76.872 s | 0.656 s |

These measurements use a Mac debug build, one category, one tag, and one link
per Item. They are not physical iPhone latency measurements.

A process sample showed repeated `Item.value` → `Category.value` /
`Tag.value` → `LabelAssociation.value` traversal. Each Item revalidated the same
shared label graph. Text matching now shares the existing label read scope
within one synchronous query. Every association still receives its integrity
checks; full shared-label validation runs once per unchanged query. The scope
is not retained across writes or requests.

`ColdSearchPerformanceTests` keeps the 500-Item public-query fixture, checks cold
and warm results agree, and applies a generous ten-second regression budget.
Existing text, label-integrity, other-writer invalidation, and contextual query
tests cover the functional contract.

Startup, list loading, and Item loading also need measurements on the user's
devices after updating. The search result alone does not establish that every
reported performance problem is resolved.

## Release baseline

Build 18 omitted performance and cancellation changes previously shipped in
build 17 from a separate checkout. It was removed from the Personal TestFlight
group, without expiring it or removing build 17. Build 19 reconciles that saved
source with the private connection, then adds the scoped text read and import
failure safeguard described above.
