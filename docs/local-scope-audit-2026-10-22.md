# Remaining local scope audit, 22 October 2026

The [26 October MVP amendment](release-goals.md#accepted-mvp-amendment-26-october-2026)
supersedes the older requirement to complete JSON export/import qualification
before daily use. Prioritize the core scenes and durable sync below; optional
manual portability/restoration work is post-MVP. Existing evidence and safety
contracts remain intact.

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

These scope findings do not approve new navigation choices or test seams. The starting-state descriptions above are historical observations at `bd25816e`. The following checkpoints record subsequent implementation without treating their represented local checks as release acceptance.

## Current implementation frontier, 26 October 2026

The storage audit additionally finds missing production integration: Core exposes
only local-only storage, opens SwiftData with CloudKit disabled, and has no
implemented account/cloud observer. CloudKit is implementation work followed by
actual container/device qualification. It is not solely a signing/test gate.
The [shared native storage checkpoint](prototypes/native-shared-storage.md#registered-app-checkpoint-27-october-2026)
now wires the registered App Group into main and both extensions. Five Mac
storage tests pass, including actual provisioned main-app group access; two
mobile capture regressions pass. The user authorizes a fresh test-data app,
leaving the old prototype untouched. Signed physical iPad creation/relaunch and
the Map link/uncertainty journey now pass after a root-view startup correction.
The [physical itinerary follow-up](prototypes/native-shared-storage.md#physical-itinerary-journeys-28-october-2026)
also passes second-plan creation/relaunch and empty/selected-plan deletion while
retaining the shared Item. Those two journeys use disposable local-prototype
datasets; they do not qualify the normal shared store or synchronization.
Installed extension discovery/execution, broader physical acceptance and cloud
synchronization remain open.

| Original finding | Current implementation and evidence | Remaining acceptance |
| --- | --- | --- |
| Filtered native map | Shared complete Map rows, bounded temporary resolution and collection List/Map modes are implemented. [Native collection journeys](prototypes/native-map-collection-ui.md), [location controls](prototypes/native-map-location-controls.md), [accessibility checks](prototypes/native-map-accessibility.md) and [refresh/selection journeys](prototypes/native-change-observation.md) cover represented phone/iPad workflows. The [Mac contextual pair](prototypes/native-map-collection-ui.md#mac-repeated-contexts-and-window-resizing-28-october-2026) now passes exact repeated Item/List choices and independent completion through actual narrow/wide window resizing. | Native Map divider/keyboard interaction, full scene/accessibility review and physical/provider performance. Individual reports retain their exact contextual and source-epoch limits. |
| Embedded linked webpages | The native reader is implemented. [Lifecycle](prototypes/native-webpage-lifecycle.md), [rotation](prototypes/native-webpage-rotation.md), [restored-context](prototypes/native-webpage-restored-context.md) and [restored-source](prototypes/native-webpage-restored-source.md) journeys qualify represented loading/history/return and removal cases. [Pending-load Return](prototypes/native-webpage-pending-return.md#final-local-checkpoint) additionally preserves the exact Item/bookmark and fresh reopened history after release of an abandoned response. Other navigation-policy checkpoints are indexed in the map. The [loaded reader pane-width checkpoint](prototypes/native-reader-pane-width.md) preserves the linked page/history and exact bookmark Return through actual iPad sidebar resizing; its phone regression also passes. The [Mac runtime pair](prototypes/native-reader-pane-width.md#mac-runtime-qualification-28-october-2026) passes actual window resizing, native toolbar overflow, history/reload and pending-load Return. | Remaining caller/remount and full accessibility review, third-party website/session acceptance and physical behavior. Metadata previews alone still supply no reader credit. |
| Core change notifications | The [public Core stream](prototypes/core-change-stream.md#final-filesystemdata-core-checkpoint) and [native canonical refresh](prototypes/native-change-observation.md) are implemented and exercised with independent local writers, recovery transitions, retained drafts and represented contextual selections. | Implement missing CloudKit/account integration, then qualify account/cloud delivery, system/installed writers, wider window/lifecycle acceptance and physical scale. A local invalidation never proves cloud convergence. |
| Bulk database-save rollback | The [real save-failure checkpoint](prototypes/core-bulk-native-save-rollback.md) corrects and qualifies the represented rollback and retry/replay behavior. | Physical interruptions, cloud/account behavior and broader native/system acceptance keep their distinct gates. |
| Share migration presentation | The [native migration journeys](prototypes/native-share-migration.md#ipad-sidebar-diagnosis-and-corrected-regression) exercise refusal before main-app migration, preserved data and subsequent capture on phone/iPad. | Installed Share/App Group access, actual Mac runtime and signed/physical qualification. |

The remaining implementation list is maintained in the [current map](implementation-map.md#remaining-implementation-and-acceptance). Q127's Mac split pane is implemented but actual resizing remains unqualified. Q128/Q129 have approved Q147/Q148 contracts and subsequent local checkpoints. Native membership consolidation, Q156 post-import completion history and Q157 unreferenced source maintenance have implemented local checkpoints. Q158 and Q160 additionally qualify independent target rebinding. Q161/Q162 ordinary owned collections and label-identity collisions now have local implementation and fault checkpoints; Q163 A now explicitly defers crossed source/owned-family reconciliation beyond MVP, preserving every record and the existing rejection. Affected datasets remain unavailable for canonical reads/export until explicit recovery or later reconciliation. These are distinct from signing. The feature-complete whole-app UI pass and the human's final coherence/layout acceptance remain required.

## Local runtime update, 27 October 2026

Manual Enable UI Automation approval now permits actual Mac journeys. The
[Calendar checkpoint](prototypes/native-calendar-shared-time-ruler.md) records
three intermediate Mac resize passes and a separate failed all-day date-entry
driver. Final-source Mac execution remains pending, with divider, width-growth
and broader interaction acceptance still open. Its final phone/iPad cohort
passes seven tests of the shared time ruler, saved bookings and represented
inspector behavior. This supersedes the earlier absence of actual Mac resizing
evidence without closing full Q127 acceptance.

The [shared-storage app-hosted checks](prototypes/native-shared-storage.md) also
execute four existing tests successfully. They qualify the local helper, not
installed Share or provisioned App Group integration. Fixture cleanup remains
limited by macOS container access protection. Production CloudKit and account
observation remain unimplemented; account-transition testing is user-deferred.

The [Calendar sizing follow-up](prototypes/native-calendar-shared-time-ruler.md#accessibility-sizing-and-mac-follow-up)
adds large-text column sizing and corrects native test scrolling/date entry.
Represented largest-text and ordinary mobile scenarios pass, as do actual Mac
Month/Day/Week resizing and the corrected three-day all-day form. Their source
epochs and failed attempts remain separate. Inspection also exposes a clipped
sidebar at the narrow Mac width; passing retained-detail assertions do not close
that defect or full pane/accessibility acceptance.

The [bounded Calendar split pane](prototypes/native-calendar-mac-inspector-resize.md#bounded-split-pane-27-october-2026)
subsequently corrects the sidebar clipping. Three final Mac journeys pass
820-point fitting, native divider movement and measured width recovery while
retaining the exact Schedule. Week viewport retention, broader accessibility
and physical acceptance remain open.
