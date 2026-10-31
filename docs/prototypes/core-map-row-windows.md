# Shared Map row windows

## Context and outcome

Q142 A approves a saved-data projection for the collection Map workflow.
Previously, Item queries knew every matching identity, but visible native pages
omitted offscreen locations and ordinary row reads omitted Maps links. Clients
would have needed complete Item reads and separate route reconstruction.

Core now implements `mapRows` for an existing Item-query generation. It returns
every requested matching identity, saved owned location, original Apple/Google
Maps bookmarks and exact contextual placement. Itinerary metadata includes
matching List branches, including header-only and empty branches, without
admitting nonmatching children. Repeated direct stops and repeated List entries
retain their distinct identities and saved positions despite query sorting.

The MCP read tool exposes the same projection and canonical decimal-string
counts. Notes, editing hashes, ordinary website links and provider results do
not enter this read. No schema, backup or receipt format changes. Reads perform
no lookup or write.

## Ready and done criteria

The [accepted contract](../map-row-contract-review.md) supplies the starting
state, concrete declaration, DoR, DoD and required TDD. Tests use the existing
public Core real-store seam and real loopback MCP HTTP seam. No additional
direct native controller seam is introduced.

This shared-read slice is implemented and locally qualified. Aggregate native
Map presentation, temporary lookup coordination, exact marker choices and the
embedded browser remain separate unfinished work. Signing, physical performance
and full-app acceptance remain open.

## Behavior and safeguards

The generation retains its originating Item query. Map pages validate
dataset/session and storage history before and after projection. A changed
title, location, Maps link, membership, route order or deletion invalidates the
old generation. Wrong query kinds fail explicitly; unknown and cross-session
generations are stale. Empty and beyond-end pages still validate history and
retain collection/branch metadata.

Location rows validate their owned-link relationships rather than fetching only
links whose owner columns already appear valid. The integrity test exposed a
silent omission when an owned link had a mismatched owner lifetime. The
corrected read rejects that page with `readUnavailable`, rather than presenting
incomplete saved inputs as complete. No provider coordinate is inferred or
persisted.

## Executed TDD

Each paired behavioral red and green retains the same test bytes, verified in
qualification.json.

| Slice                 | Observed failure                                                 | Passing correction                                                                                               |
| --------------------- | ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Complete saved inputs | Valid fixture red reaches the unimplemented Map read.            | Global green returns all 130 identities and the literal location/bookmark inputs at positions 1, 64, 65 and 130. |
| Exact plan context    | Context red rejects unsupported contextual appearances.          | Context green preserves repeated stops/Lists, saved positions and header-only/child-only/neither-match behavior. |
| Unresolved owned link | Integrity red incorrectly returns an empty Maps-link collection. | Integrity green rejects the unresolved relationship.                                                             |
| Real HTTP admission   | HTTP red rejects `mapRows` as an unsupported read kind.          | HTTP green exposes saved inputs and contextual placement through the actual listener.                            |

Compiler failures, invalid early fixtures and the first HTTP helper's attempt to
decode a plain-text error as JSON remain recorded in their earlier packets. They
receive no behavioral red credit.

Later tests add cumulative Inbox/category/address/link filtering, empty/terminal
pages, invalid counts, wrong generations, independent-writer invalidation,
unchanged exports and advertised HTTP schema. HTTP additionally covers direct
and expanded itinerary pages, decimal counts, missing notes, structured failures
and retained empty-page metadata.

## Final qualification

| Platform and seam            | Result                                                                                                                                   | Evidence                 |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| Mac public Core              | Ten functions in seven suites pass. Includes five Map functions, three Calendar functions and affected Item/Itinerary query regressions. | Final execution          |
| iPhone Simulator public Core | Eight functions pass, zero failures/skips. Includes the same five Map functions and three Calendar functions.                            | iOS execution            |
| Mac app-hosted real MCP HTTP | Six functions in four suites pass, zero failures/skips. Includes Map, Calendar, List and Itinerary reads.                                | Corrected HTTP execution |

All final runs have zero SQLite unlink diagnostics. The first wider HTTP
regression caught an incorrect test expectation: the established response to an
extra property is `unknownField`, not `invalidInput`. It also exposed three
older query fixtures deleting their open SQLite stores. Those fixtures now use
the existing marked disposable-storage helper; cleanup occurs only after host
exit and closed-handle verification. No production storage behavior was changed
to pass these tests. The failed run remains recorded.

The final Mac Core manifest's 745 inputs and the final native HTTP manifest's
1,068 inputs match the working sources. The iOS archive also contains native
adapter files from an earlier epoch, but its selected package build does not
compile those files. Every Core package input in that run matches the final Core
sources. Its passing credit is explicitly Core-only.

Actual final products match their recorded digests. An inherited standalone
runner initially collected unrelated older ImportLifetimeAuditBuild product
hashes. Those original hashes receive no Map product credit. The explicit
provenance correction preserves that mistake and records the actual Map products
before another build. The final Mac runner uses the corrected Map product path.

The Core cleanup, iOS cleanup and HTTP cleanup verify exited hosts and closed
SQLite handles before removing fourteen marked fixture directories. Failed
diagnostic fixtures are not silently treated as successful cleanup candidates.
After final artifact verification, the completed standalone build cache was
removed, accounting for 496 MiB of allocated build files. The user comparison
app and active native caches were preserved.

Affected strict Swift lint, compiler checks and whitespace validation pass.
These tests establish the represented read behavior, not a measured
database-fetch count, bounded total memory, provider reliability, native Map
interaction or physical-device performance. The local Mac host uses ad-hoc
signing; it does not qualify protected Agent Control storage, an enrolled team
or installed Share.
