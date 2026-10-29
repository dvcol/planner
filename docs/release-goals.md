# Release goals

Accepted resolution for [Release goals](https://github.com/dvcol/planner/issues/2), confirmed by the human on 2026-10-08. The human subsequently deferred Apple Calendar export outside the entire map in [Scheduling Q7](itineraries-and-scheduling.md#accepted-export-scope-scheduling-q7). The amended release stages, priorities and daily-use gates below govern subsequent decisions; detailed domain semantics remain assigned to their owning tickets. The original [product brief](product-brief.md) and [decision map](https://github.com/dvcol/planner/issues/1) remain the scope references.

## Accepted MVP amendment, 26 October 2026

The user moves JSON export/import outside the MVP and asks to focus on core
planning features. Keep the existing tools available as optional administration;
further portability polish, advanced import/Overwrite/restoration scenarios and
their qualification are post-MVP work. They no longer block V2. This supersedes
the earlier requirement for a verified JSON recovery fixture in the first
daily-use release, without claiming deferred work is complete.

Prioritize saving and organizing Items, Lists and places, capture, itineraries,
estimates, scheduling, maps and native UI quality on iPhone, iPad and Mac.
Durable offline saves, safe synchronization and truthful failure handling remain
MVP requirements. Existing import validation and saved data stay intact; this
amendment authorizes no destructive simplification or new recovery framework.

## Mac Share MVP focus, 28 October 2026

Installed macOS Share integration and its system handoff qualification are
post-MVP. In-app New Item and From Link or Text cover Mac capture for the first
personal release. Preserve the existing extension and its evidence for later
qualification; the current Mac management-policy restriction does not block
MVP. Mobile Share capture, core Mac interaction, durable saves and private
CloudKit synchronization retain their existing scope.

## Private-cloud storage boundary, 29 October 2026

The user requires Planner content to use only their private CloudKit database
and its user-owned iCloud storage. There is no public, shared or developer-funded
cloud fallback. This applies to development diagnostics and release builds.

When private iCloud is disabled, unavailable or out of quota, preserve local
content and remain device-local/offline, with truthful synchronization status.
Do not redirect pending saves, recovery data or uploads to another database or
hosting service. A full private quota does not authorize a storage upgrade or
developer-billed fallback. Device-local App Group storage remains the accepted
offline store; it is not developer cloud hosting.

Apple documents the distinction between the
[user's private database quota](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase)
and the
[app's public database quota](https://developer.apple.com/documentation/cloudkit/ckcontainer/publicclouddatabase).
Development/Production environment selection does not replace explicit private
database selection. The integration must qualify unavailable-account and
quota-error behavior before claiming synchronized daily-use acceptance.

## Confirmed priorities

- The first daily-use release must support both saving/organizing places and assembling trips with scheduled itineraries. Ordinary tasks remain supported by the generic item model.
- The first usable release covers iPhone, iPad, and native macOS. Each platform must feel native; an enlarged iPhone layout on iPad or Mac does not satisfy this requirement.
- Durable offline saves, demonstrated two-device sync and visible sync failures are daily-use gates. JSON export/import is optional post-MVP administration. Missing place enrichment and delayed synchronization may be acceptable; lost or silently overwritten plans are not.
- Quality and stability are the highest priority. There is no deadline. Release when the agreed quality gates pass.
- Use the accepted [native Xcode and Swift Package Manager workflow](https://github.com/dvcol/planner/issues/18).

## Accepted V0–V3 stages

The accepted progression makes V2 the first daily-use release because both selected travel workflows must be present.

| Stage | User journeys and scope | Intended use and exit gate |
| --- | --- | --- |
| V0 | Create a generic item, put it in a list, search, edit, complete/reopen and archive/unarchive it. Establish local SwiftData durability and a minimal private CloudKit synchronization slice. Introduce the native project, local PlannerCore package and focused tests. | Learning and foundation work with disposable data. Pass relevant domain unit, persistence, basic UI and two-device checks. This is not the first daily-use release. |
| V1 | Save places manually, retain arbitrary links, view located items on the native map, organize items in multiple lists, and use search, categories/tags and duration filters. Keep ordinary items without locations usable. | Travel collection and organization trial. Pass the resolved domain/search fixtures and map/offline fallback checks. Itineraries and the complete capture workflow still prevent this stage from satisfying both daily-use goals. |
| V2 | Capture Apple Maps, Google Maps and Safari links through the app, plus native Share on iPhone/iPad. Review/edit partial captures. Assemble and reorder referenced items/lists in itineraries, then schedule them in Planner's canonical calendar. | First daily-use release. Both travel workflows operate on all three platforms with native layouts. Relevant unit, integration, UI and physical-device gates pass; no critical core-planning reliability scenario remains unverified. JSON portability and installed Mac Share integration are outside this MVP. |
| V3 | Add selected App Intents/Shortcuts, applicable Siri/Spotlight integrations, and manually enabled localhost MCP Agent Control on macOS using the same PlannerCore behavior. | System and agent integration release. Advertise only demonstrated system/client capabilities. Pass command equivalence, permissions, authentication, shutdown and selected-client checks. |

JSON portability and installed Mac Share integration are post-MVP under the amendments above. App Intents and MCP remain V3. Apple Calendar export is deferred outside the entire current V0-V3 map, as accepted in Scheduling Q7; it is not a V3 commitment. V0 and V1 are learning/trial stages; V2 is the first release intended for daily personal use.

The user's 2026-10-08 vocabulary clarification separates todo/done from active/archived. Completion/reopening and archiving/unarchiving change different states; see the [accepted vocabulary](planner-vocabulary.md). Local work can start without paid membership, while private CloudKit validation still requires an active Program team; see [Apple test access](setup/apple-test-access.md).

## Acceptance examples

All examples describe future implementation evidence. No application check has run as part of this release decision. Confirm public test interfaces under `/tdd` before code; work one failing behavior test and its minimum passing implementation at a time.

| Journey and initial state | Action and required end state | Required evidence |
| --- | --- | --- |
| First launch, no iCloud account and no network; empty local data | Create `Book train tickets` with note `Check departure`. Close and relaunch. One local item with the same identity and note is available; sign-in is not required to save it. The UI truthfully communicates unavailable sync. | Public domain unit test, real-store relaunch integration check, first-launch UI check. Account changes and recovery policy are resolved before implementation. |
| Empty `Tokyo Museums` list; map lookup unavailable | Capture an Apple or Google Maps URL, enter `Nezu Museum` manually in the partial editor, and save. One item retains the original URL and entered title. Missing coordinates/details do not prevent the accepted partial-save flow. Cancellation creates no item. | Provider/parser unit fixtures, capture/store integration, in-app capture on Mac and mobile Share UI checks with the host open and closed. Use representative real provider payloads in the prototype; exact normalization and duplicate policy come from the capture decision. |
| That saved place exists on iPhone; iPad uses the same test iCloud account | Synchronize, then find the same item on iPad with its title, URL and list reference intact. A delayed cloud upload is not represented as complete. | Physical two-device evidence, public-query identity checks and sync-state UI checks. Record observed latency; do not invent a CloudKit delivery guarantee. |
| A synced item has note `Check opening hours`; Mac is offline | Edit the note to `Check opening hours on Friday`, save, and relaunch offline. The edit survives. After reconnection, the chosen recovery rules govern remote convergence and any conflicting edits. No silent loss passes the release gate. | Store integration, offline UI and physical-device scenarios. Exact concurrent-edit, reorder and deletion outcomes belong to the recovery decision and must be approved before tests are written. |
| Two saved places and a list exist; no itinerary or schedule | Create `Museum morning`, add references to the chosen places/list, reorder them, and schedule the itinerary for a chosen date in Planner. Edit a source item's title. The itinerary still refers to that item and displays the updated title; scheduling does not copy the underlying plan. | Public command/query unit tests, persistence integration, scheduling UI and synchronized-reference checks. Nesting, ordering, durations, time zones and schedule identity remain owned by the scheduling decision. |
| The same travel fixture is available on all three platforms | Complete capture, organization, itinerary and scheduling journeys. iPhone works at compact sizes; iPad makes effective use of its available space; Mac works with resizing and keyboard navigation. No platform merely scales the iPhone presentation. | Focused XCUITest journeys where observable, manual platform review, accessibility checks and human approval in Navigation prototype. Exact navigation and layouts are that ticket's decisions. |
| V3 Agent Control is off | A client cannot connect because no Planner listener exists. Enable access and run an agreed command. Long idle periods, lock, sleep and last-window closure do not disable access; the running app retains a menu-bar status and Stop control. Stop or app quit removes the listener and revokes access. Relaunch starts Off. | Transport/policy unit checks, real-listener lifecycle integration and selected Codex/Claude demonstrations. No duration picker, countdown, maximum duration or idle expiry. Authorization and retry semantics come from Shared command contracts. |

The human's 2026-10-08 [Agent Control amendment](shared-command-contracts.md#accepted-amendment-no-automatic-agent-access-expiry) supersedes the original brief's automatic session timeouts and the earlier duration/idle answers. The manually controlled lifecycle above is the current release criterion.

JSON export/import's existing identity-preserving round-trip, validation and
failure-atomicity contracts remain recorded for the optional tool. They are
post-MVP acceptance, not prerequisites for core planning. Do not expand their
scenario matrix while core MVP work remains.

## Quality and evidence gates

Each stage requires the relevant committed native configuration, shared schemes, pinned dependencies, focused build/test commands and results. Record executed tests and actual SDK/destination versions. Package tests cannot stand in for app/extension builds, and simulator results cannot stand in for physical CloudKit behavior.

V2 requires successful native app and bundled extension builds, demonstrated local relaunch durability, core synchronization/concurrent-edit/deletion scenarios on two physical OS 27 devices, mobile Share capture with the host closed and reference-safe itinerary scheduling. Open failures in those critical scenarios block daily use. Installed Mac Share handoff, JSON export/import and advanced manual-recovery scenarios do not block MVP. Hardware/signing access is tracked separately in [Apple test access](https://github.com/dvcol/planner/issues/7).

Platform review must cover the core journeys, resizing/orientation where applicable, keyboard navigation on Mac, Dynamic Type and VoiceOver labels/selection. The navigation prototype must show native interaction on every device; feature parity does not require identical layouts.

## Decisions still owned elsewhere

This release decision sets priority and measurable gates. [Planner vocabulary](https://github.com/dvcol/planner/issues/3), [Duration and search](https://github.com/dvcol/planner/issues/8), [Itineraries and scheduling](https://github.com/dvcol/planner/issues/9), [Offline conflicts and recovery](https://github.com/dvcol/planner/issues/10), and [URL and share capture](https://github.com/dvcol/planner/issues/11) must settle their exact semantics. [Core architecture](https://github.com/dvcol/planner/issues/12) and [Shared command contracts](https://github.com/dvcol/planner/issues/13) define the confirmed public boundaries. The three prototypes supply runtime and human-review evidence before [Specification handoff](https://github.com/dvcol/planner/issues/17).

The approved exclusions remain: shared planning, embedded Google Maps, Google billing/API-key requirements, Apple Calendar export and bidirectional sync, LAN/cloud MCP access and permanent servers. Production delivery remains beyond the map's specification destination.
