# Native Itinerary organization Intents

Status: both Add actions are implemented. All 57 affected adapter tests and Mac, Simulator and unsigned device builds pass. Signing and actual system invocation remain deferred.

## Context and starting state

At `8d26579b`, App Intents create, query, edit and archive Itineraries, but cannot add route entries. Core and native views already support ordered live Item/List references, repeated entries and independent contextual completion. Adding to a List is different: a List permits one membership per Item, while repeated itinerary entries are intentional.

## Goal and expected end state

Add ordinary Add Item to Itinerary and Add List to Itinerary actions using the canonical add-entry command. Each invocation appends a distinct live reference. Cached entity metadata never replaces current source content or completion. New local state starts Todo; global Item Done still determines effective completion. A List's standalone local state does not determine its itinerary appearances.

## Definition of ready

- Q33 approves ordinary organization actions and Q112 A approves the production App Intent invocation boundary with Apple's dependency manager and disposable real Core storage.
- Existing public Core source/appearance reads establish saved identities, order, shared content and completion without direct database inspection.
- The existing app-hosted target and platform build configurations are available. No new target, test-only production hooks, Core contract or persistence format is required.

## Required tests and definition of done

Work one executable missing-action red and following implementation at a time. Reopen real storage to prove repeated Item entries, repeated List branches, their local independence, global precedence and live content. Qualify missing/deleted sources and destinations, cancellation, unavailable storage and actual post-save incomplete recovery without duplicate retries. Preserve truthful rejected, unverified and applied recovery outcomes.

Run the affected adapter tests together, compile Mac, Simulator and unsigned device products, inspect extracted action metadata and embedded extension, and run affected strict Swift/Markdown lint and whitespace checks. Retain exact commands, source epochs, results and limitations. These adapter checks do not establish Siri/Shortcuts invocation, background/locked execution, physical performance, CloudKit or whole-map completion.

## Executed organization slices

| Behavior | Executable red | Following green |
| --- | --- | --- |
| Repeated Item entries | Missing Add Item action throws after valid real-store setup, 0.475 s | 0.252 s; original source, separate local states and live notes survive reopening |
| Repeated List branches | Missing Add List action throws after valid standalone membership setup, 0.602 s | 0.257 s; List, Item, List route order, live child additions and independent completion survive reopening |

The Item case starts with a globally Done source and cached Todo entity metadata. New local flags stay Todo. Completing the first appearance locally, adding again and globally reopening the source leaves only the first appearance Done. Both appearances read the updated shared notes and the Item catalog retains one source identity.

The List case starts with a standalone locally Done membership. Its first itinerary appearance still starts Todo. Repeated branches retain separate entry identities, and adding Lunch to the source List makes it appear in both branches. Global Museum completion finishes its three appearances; reopening restores one locally Done appearance out of five total Items. The standalone List keeps its separate Done membership.

Missing, wrong-kind and natively deleted source/destination qualification passes in 0.297 seconds. Rejected additions leave an unchanged surviving route with no entries; deleted Items, Lists and the deleted route remain absent. The cancellation test's first compile has an ambiguous Void-returning App Intent overload inside Task. That compiler failure provides no feature-red or execution credit.

## Failure and preservation qualification

Both precancelled additions reject without changing route hashes, Last updated or sources, 0.214 seconds. Real post-save recovery-file obstruction is exercised separately for Item and List additions, 0.371 seconds together. Each applied entry remains durable, another destination stays untouched while blocked, and native retry completes the original operation without replacing its identity or creating a duplicate. A subsequent explicit addition to the other route gets its own identity.

Unavailable storage rejects both actions, preserves the actual obstructing file and acknowledges no change, 0.005 seconds. These failure/preservation cases pass against the implemented canonical actions without further production changes or fabricated reds.

## Combined and platform qualification

All 57 affected Item/List/Itinerary adapter tests pass together with zero failures or skips in 22.007 seconds. The six new organization cases use the existing app-hosted target and production invocation interface. The actual XCTest summary is retained in the final qualification packet. Mac metadata extracts sixteen actions, three entities and three queries, including both Add actions. The production app and native UI target also compile for the generic iPhone/iPad Simulator destination, with the same extracted catalog. All 987 source/configuration inputs match the current source in both packets. These timings are XCTest durations, not physical performance measurements.

The generic unsigned iOS device build passes and embeds one mobile Share extension. Both executables are arm64. Device metadata matches the same sixteen actions, three entities and three queries, and all 987 device-build source/configuration inputs also match this checkpoint. Existing ad hoc Mac signing is reused; the mobile configurations remain unsigned. Affected strict Swift/Markdown lint and Git whitespace checks pass. No Core contract/schema, backup format, dependency, target or native UI changes are introduced.

All packets are under the compatibility evidence with `app-intent-itinerary-add-*` names. They retain actual commands, source epochs, original logs and result codes, including the missing-action reds and the unsuccessful cancellation-test compile.

Actual Shortcuts/Siri discovery/invocation, background/locked execution, native capture invocation, system bulk confirmation and explicit unverified-outcome fault qualification remain open. Existing temporary-store cleanup can unlink SQLite files while SDK-retained stores still hold connections; original logs retain those warnings. This establishes neither clean shutdown nor a production integrity defect. Richer Intent fields, contextual completion/organization/scheduling actions, Q100 B signed Agent Control/reader/real clients, account-bound CloudKit, installed Share, physical performance and feature-complete whole-app UI polish remain on the map. No signing/account/entitlement changes or physical installation are claimed.
