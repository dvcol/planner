# Itinerary entry removal and ordering Intents

Status: exact entry resolution, removal and all four placements are implemented. All 99 affected adapter cases and Mac, Simulator and unsigned device builds pass. Actual system picker injection remains open.

## Context, starting state and goal

At `c6d2d5d0`, Intents add live Item/List route entries and read/complete exact Item appearances. They cannot remove or reorder a top-level route stop. A repeated List entry has its own identity; an empty List is still a stop despite contributing no Item rows. The goal is exact entry removal and saved ordering without deleting shared sources or changing surviving completion/schedules.

## Definition of ready and interface

Q33 approves ordinary entry removal and first/last/before/after placement. Q114 A supplies the Itinerary-first scoped native picker convention. Q112 A approves production Intent/EntityQuery tests with Apple's dependency manager and disposable real Core storage. Reuse the approved SavedItemWindow metadata/paging interface and existing canonical Core commands. No new direct helper test boundary, target, Core API or test-only production hook is needed.

PlannerItineraryEntryEntity identifies a top-level Item or List using `v1/entry/<itinerary>/<entry>/<item-or-list>/<source>`. UUID case normalizes; display shows current title, owner/stop context, native Item/List type and archive observation. Expanded Item IDs are not entry IDs. Removal requires an exact current entry in the selected Itinerary. Reordering uses a native Beginning/End/Before Entry/After Entry enum; Before/After require a current exact anchor in the same route. Beginning/End ignore inactive relative selections. No invalid selection retargets by name, position or source alone.

Search/suggestions use the same native List-name-or-matching-child behavior and saved route order as SavedItemWindow. No selected parent produces no choices. An outer Core generation guards the complete metadata/page read, including names. Source deletion and editing-history restoration remain native workflows, outside these actions.

## Required tests and definition of done

Record executable missing-action reds before removal and reordering. Reopen real storage to verify exact removal of repeated Item/List entries, empty List resolution, live names/positions, all placements and unchanged sources, memberships, surviving local/global flags, saved child order and bookings. Qualify malformed/version/wrong-source/foreign/removed/deleted selections, invalid/self anchors, ordinary re-add, cancellation, unavailable storage and actual incomplete recovery without replay.

Run affected Intent regressions, strict lint/type/whitespace checks, actual Mac/Simulator/unsigned device compilation, metadata/enum and embedding checks, and frozen-source verification. Retain failed attempts and fixture closure/disposal evidence. Actual populated system choices/search, changed-parent injection, background/locked invocation, physical tests and whole-map completion remain separate gates.

## Executed removal and placement slices

Removal first fails at its missing action in 0.523 seconds. The initial implementation check fails because the test incorrectly expects every incoming List reference to remain: removing a route stop correctly removes that incoming itineraryEntry. Correcting the expected reference set needs no production change. The corrected journey passes in 0.454 seconds, preserving shared content/timestamps, memberships, the surviving branch, empty stop and all-day booking. The final fixture additionally retains two ordered List children and verifies both shared Items and their independent states.

Before Entry first fails at its missing action in 0.536 seconds, then passes in 0.315 seconds. Repeated Hotel stops keep their own IDs and local flags after changing order; the empty List and booking remain. Beginning first reaches its deliberately unsupported placement in 0.392 seconds. Implementing Beginning, End and After Entry completes the placement journey. Beginning ignores an inactive malformed relative selection, End works with no relative selection, and After Entry targets another exact stop sharing the same Item.

## Safety qualification

Eight entry-specific cases pass before the combined regression. The large read case first resolves 65 empty List stops from a route with zero Item rows. It then adds 65 Item stops and resolves all 130 entries across Item pages. Renamed Item/List/Itinerary names, UUID-case normalization, source archive observations and saved positions remain live. Duplicate requests collapse while repeated route entries stay distinct. Unselected-parent queries return no choices; this does not qualify populated system injection/search.

Malformed/version/wrong-kind/wrong-source/foreign IDs, absent/self/stale anchors and removed/deleted sources reject without appending or retargeting. Ordinary re-add creates a new local Todo stop and leaves the original ID missing. The combined regression uses an actual other route/entry for foreign selection and verifies its preservation. Cancellation leaves saved references/timestamps unchanged; a later explicit direct Item removal succeeds. Unavailable storage rejects identity reads, choices, removal and ordering while preserving the obstructing file.

Actual post-save recovery obstruction is exercised independently for removal and reordering. Each applied route survives; further mutation is blocked. Native retry acknowledges the original operation without rewriting route references/timestamp or replaying the action, and a later explicit reorder succeeds. No additional production behavior change is needed for these safety cases. Test durations include real fixture construction and recovery writes and are not physical performance measurements.

## Combined and platform qualification

All 99 affected Item/List/Itinerary/Category adapter tests pass with zero failures/skips in 99.432 seconds. This includes two ordered shared List children and an actual independent foreign route/entry. The actual XCTest summary is retained. The original log contains no compiler warnings or SQLite lifetime diagnostics. All 102 owned fixtures are verified disposed after host exit and closed database handles.

Mac metadata preserves every existing action/entity/query and adds RemovePlannerItineraryEntryIntent, ReorderPlannerItineraryEntryIntent, PlannerItineraryEntryEntity and its query: twenty-six actions, six entities and six queries. Three exact native enums are retained: the existing List placement enum, the new two-case Item/List type and the new four-case route placement enum. Simulator app/native UI-target and unsigned generic iOS-device builds pass with identical catalogs/cases. The device app embeds one mobile Share extension; both executables are arm64. All 997 frozen inputs match current source in all three final packets.

Strict affected Swift/Markdown lint, actual platform type checks and final Git whitespace checks pass. No Core/schema, target, dependency, transport, backup format, entitlement or native UI change is introduced. Existing ad hoc Mac configuration is reused; no signing/account setup or physical installation is claimed. The shared native loader is unchanged.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains `app-intent-itinerary-entry-*` source epochs, commands, original logs and actual exits. Expected missing-action/placement failures and the incorrect incoming-reference expectation remain failed evidence with separate inspected fixture disposal. Passing runs use the guarded post-host verifier.

Populated system picker choices/search, changed-parent injection, actual discovery/invocation, background/locked behavior and native system confirmation remain unqualified. A deliberately interleaved adapter stale-read failure and explicit unverified-operation fault are not newly qualified here. Remaining ordinary Intent fields/catalogs/scheduling/capture, Q100 B signed Agent Control, shared/account-bound storage and CloudKit implementation/proof, installed Share, physical performance and feature-complete whole-app polish remain on the map. This slice does not complete the map; signing remains deferred.
