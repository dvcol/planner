# Native Itinerary editing and archive Intents

Status: Edit Itinerary and Archive/Unarchive are implemented. All 51 affected adapter tests pass. Mac, Simulator and unsigned device builds pass; metadata extraction and source/product verification pass. System invocation and physical acceptance remain open.

## Context and starting state

At `0c545d92`, App Intents can create, resolve and query basic Itinerary identities. Title/notes editing and Archive/Unarchive are missing from this adapter, although Core and native/MCP workflows already implement them. Shared Item content, independent appearance completion, label associations, owned links/locations, manual estimates and schedules must survive those ordinary data changes.

## Goal and expected end state

Add optional title/notes edits using current canonical field hashes and container-only Archive/Unarchive. Omitted fields stay unchanged; empty notes explicitly clear; invalid required titles reject together. Cached entity metadata must not replace live content or archive state. Retain source/lifetime, route entries/order, each repeated appearance's local completion, shared source data, schedules and other owned metadata.

Archive does not rewrite Done flags or mutate referenced Items/Lists. The archived itinerary keeps its child-based progress and full estimate while its own remaining estimate is zero; Unarchive restores remaining time from retained states. Missing/deleted targets reject without resurrection. Applied changes with incomplete recovery remain saved and block further mutation until the existing native retry acknowledges the original operation. No source Delete, recovery administration or global Item completion action is added.

## Definition of ready

- Q33 accepts existing read/edit/archive encodings and Q27's changed-field hashes. Q8 governs retained contextual/global completion; Q68/Q69 keep archive retirement separate from Done flags.
- Q112 A confirms public production `callAsFunction(donate: false)`, actual dependency management, disposable Core storage and real recovery-filesystem faults in the existing app-hosted target.
- Core editItinerary/setArchive and source/appearance/schedule reads already exist. No new Core contract, package, target, test hook or persistence format is needed.
- Local app-hosted tests and unsigned platform builds are available. Signing, actual system invocation and the separately pending Mac UI reservation retain their own gates.

## Required tests and definition of done

Record executable missing-edit and missing-archive reds, then implement the canonical commands. Reopen a rich archived itinerary to verify title/notes changes while preserving unrelated fields, labels, order, repeated local/global states, progress/estimates and schedule form. Qualify omitted/clear fields, container-only Archive/Unarchive, invalid/missing/deleted targets, actual incomplete recovery and unavailable storage.

Run the affected Intent classes together, compile actual Mac/Simulator/unsigned device products, inspect extracted metadata and run affected strict Swift/Markdown lint and Git whitespace checks. Retain exact source/results and qualified limits. Broader rich-field/organization/completion/scheduling Intents and the other map gates remain open.

## Executed edit and archive slices

| Behavior | Executable red | Following green |
| --- | --- | --- |
| Rich title/notes edit | Missing edit throws after valid real graph setup, 0.670 s | 0.390 s; preserved metadata, source/lifetime, repeated route states, shared Item and inclusive all-day schedule |
| Container-only Archive/Unarchive | Missing archive throws after valid real graph setup, 0.553 s | 0.464 s; retained three appearances, standalone List context, other route and start-only timed schedule |

The rich edit preserves color/icon, owned link identities, shared labels, owned location, manual estimate, archive state and ordered references. One repeated appearance stays locally Done and the other Todo; the shared Item's content hashes and Last updated stay unchanged. No parent Done field appears.

For archive, full estimate stays 210 minutes. Own remaining changes 150 to 0 to 150 across Archive/Unarchive. Child progress remains one Done out of three, with zero child archive flags. Shared Item/List and another itinerary keep their original data, references, timestamps and independent completion; no schedule end is filled from the estimate.

All packets are under the compatibility evidence with `app-intent-itinerary-edit-*` and `app-intent-itinerary-archive-*` names. Each retains its actual original source epoch, command, log and result.

## Failure and preservation qualification

These required cases pass on first behavioral execution against the implemented actions, without another production correction or fabricated executable red.

- Omitted title/notes stay live, and empty notes persists as nil after reopening, 0.266 s.
- Invalid/empty patches preserve content, hashes and Last updated. Edit/Archive/Unarchive reject missing/deleted identities without resurrection, 0.282 s.
- Actual post-save edit recovery failure retains the applied title/notes and blocks the next edit. Native retry acknowledges the same operation without changing applied hashes; later explicit edit succeeds, 0.214 s.
- Actual archive recovery failure retains the applied archive and blocks Unarchive. Native retry acknowledges the original operation; later Unarchive preserves content and the empty No items state, 0.188 s.
- Actual unavailable storage makes Edit and Archive throw, leaves the store unavailable and preserves the obstructing file, 0.165 s.

The original first rich-test compile incorrectly compared a non-Equatable Item content value; its corrected assertions use public fields/hashes. The first edit implementation compile catches a copied List variable, and the first unavailable-test compile catches the List entity's initializer label. These failed compiler invocations are retained separately and provide no feature-execution credit. The corrected subsequent invocations above establish the behavioral results.

## Combined and platform qualification

All 51 affected Item/List/Itinerary tests pass together with zero failures or skips in 19.646 seconds, including seven new edit/archive cases. The actual final XCTest summary is retained. Mac metadata extracts fourteen actions, three entities and three queries, including Edit Itinerary and Set Itinerary archive state. This is compilation/extraction evidence, not system invocation. The production app and native UI target compile for the generic iPhone/iPad Simulator destination. The generic unsigned iOS device app also builds and embeds one mobile Share extension, with arm64 in both executables. Mobile/device metadata matches the Mac fourteen-action, three-entity, three-query catalog. All 986 frozen source/configuration inputs in each final platform packet match this checkpoint. Affected strict Swift/Markdown lint passes, and the final Mac invocation reports no compiler warnings. Team/account configuration and entitlements are unchanged; existing local ad hoc Mac signing is reused. No physical device is installed or launched. Timings above are XCTest durations, not physical performance measurements. No native UI, Core/schema, backup format, entitlement, package or target changes are introduced.

Actual Shortcuts/Siri discovery/invocation, background/locked behavior, system confirmation, native capture invocation, shared/account-bound CloudKit, installed Share, signed Agent Control/reader/real clients, physical convergence/recovery/performance and final whole-app polish remain open. The [compact toolbar checkpoint](../native-list-toolbar-review.md) records the separately pending Mac UI retry.

Explicit unverified-outcome fault qualification remains open. Existing test-fixture cleanup can unlink temporary SQLite files while SDK-retained stores still have connections; original logs retain those warnings. These tests do not establish clean shutdown or a production integrity defect. No whole-map completion is implied.
