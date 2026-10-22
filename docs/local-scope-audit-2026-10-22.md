# Remaining local scope audit, 22 October 2026

## Context and goal

At `bd25816e`, the map index emphasizes import decisions, Mac automation and signing gates. Those gates do not cover every unfinished requirement. This audit compares the retained product brief and accepted contracts with production scenes, Core interfaces and executed tests. Its goal is an accurate implementation frontier, without reducing scope or treating a compilation result as feature completion.

The [release goals](release-goals.md) retain the [product brief](product-brief.md) as a scope reference. The [historical exclusions](history/decision-map-2026-10-22.md) defer embedded Google Maps and Apple Calendar export. They do not defer the filtered native map or embedded linked webpages. Backup and recovery administration remain manual.

## Filtered native map

Before: `SavedPlannerView` has Lists, Items, Inbox, Itineraries and Calendar destinations. `ItemLocationMap` renders one location in Item details. Temporary Maps-link cards are also implemented. Neither establishes the brief's selected/List-filtered annotations or annotation-to-Item selection.

After: a native MapKit representation shows the applicable located Items, preserves exact source/appearance scope, and selecting a pin opens its corresponding current details. Filtering and live content changes update annotations coherently. Existing compact Item maps remain useful.

DoR: settle the actual navigation/presentation workflow and concrete loading/selection contract before implementation. Reuse approved Core reads and native test boundaries where sufficient; review any additional public interface or test seam. Do not resurrect the rejected prototype's Inspect sheet or unexplained layout-comparison selector. Do not assume the unresolved Mac Calendar inspector is safe to reuse.

DoD and tests: real-data filtering, missing locations, duplicate coordinates, selected identity, live edits/deletion, stale/canceled loading and empty/error states; actual phone/tablet journeys and Mac resizing/keyboard qualification. A single-pin preview or fixture comparison supplies no aggregate-map completion credit.

## Embedded linked webpages

Before: saved links and rich cards use SwiftUI `Link`. Production has no embedded webpage scene. Metadata/image previews do not satisfy the brief's linked-page browsing requirement.

After: the user can deliberately open a saved webpage inside Planner as well as through the existing external opening path. Use the current native SwiftUI WebKit components where available, preserve the original URL, and keep browsing state outside saved Planner content and backups.

DoR: make presentation, navigation, external-scheme behavior and cancellation concrete. Check the installed SDK and accepted native UI boundary before introducing another wrapper or test seam.

DoD and tests: actual page loading, back/forward, failure/retry, original-link fallback, closure and selected-owner changes, followed by phone/tablet and Mac layout/accessibility checks. External opening and a preview image alone do not close this requirement.

## Core change notifications

Before: A21 and Q33 declare a dataset-bound cancellable `changes` stream and typed `PlannerChange` payloads in the [architecture packet](architecture-review-packet.md) and [adapter contract](adapter-contract.md). Core does not implement that interface. The native store's own `changeRevision` updates do not prove independent-writer observation.

After: consumers receive truthful dataset-scoped data/recovery changes and rerun canonical reads. Unknown affected identities remain explicitly unknown. Account/cloud observations retain their separate actual integration gates; no event proves every device is current.

DoR: reconcile the concrete stream lifecycle with the accepted facade, native status values, independent writers and existing public tests. Review changed public declarations before tests.

DoD and tests: subscriber lifetime/cancellation, another real writer, unrelated datasets, replay/no-op behavior, recovery transitions and canonical refresh. Test through the production public interface, not private observer call counts. Physical CloudKit/account events remain separately qualified.

## Bulk database-save failure and Share migration presentation

Bulk completion's existing precommit recovery obstruction and postcommit recovery checks leave genuine database-save rollback open. The existing isolated native-save filesystem technique can exercise List, Itinerary and exact List-entry scopes through the approved Core operation interface. Require complete rollback, truthful operation evidence, unchanged recovery, safe reviewed retry and exact replay after reopen. Preserve the distinct applied-but-recovery-incomplete outcome.

The subsequent [bulk-save follow-up](prototypes/core-bulk-native-save-rollback.md) records the actual rollback defect, correction and executed qualification. Its result does not close the independent scenes or observation stream above.

Share already rejects old schemas before loading providers and asks the user to open the main app. Core migration checks establish that refusal, but existing native Share journeys do not establish the migration-required message and subsequent capture after main-app migration. Reuse genuine schema fixtures and the accepted explicit-configuration Share boundary. Installed Share/App Group access remains a signing/device gate.

## Completion limits

These scope findings do not approve new navigation choices or test seams. The linked bulk follow-up supplies its own implementation evidence; the other findings remain unfinished. Q127-Q129, the current-build List-title observation, Mac automation, signed storage and physical/system tests stay open. Whole-app UI polish follows feature completion.
