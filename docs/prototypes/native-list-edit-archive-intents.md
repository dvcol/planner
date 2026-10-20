# Native List editing and archive Intents

Status: List name/notes editing and Archive/Unarchive are locally qualified. All 35 affected adapter tests pass. Mac, Simulator and unsigned device builds pass. System invocation and physical testing remain separate gates.

## Context and starting state

At `b0065719`, native Intents can create/resolve Lists and add shared Items. List editing and archive still require native UI or the ordinary MCP/Core paths. Q33 approves those ordinary data actions. Q112 A already confirms production Intent invocation and EntityQuery tests with Apple's dependency manager, real disposable storage and actual recovery-filesystem failures in the existing app-hosted target.

## Goal and expected end state

Add Edit List for optional name/notes changes and Archive/Unarchive List using the current source identity and existing Core commands. Omitted fields remain unchanged; empty notes explicitly clear, and blank required names reject together. The edit reads current content/hash values, never copying a cached entity's name/archive over other saved data. Preserve color, icon, manual estimate, saved membership identities/order, source Items and local/global completion.

Archive changes only the container flag. Its branch in an itinerary becomes retired according to the accepted Q68/Q69 rules, while direct appearances of active Items remain unfinished. Unarchive restores retained contexts rather than rewriting Done flags. Missing/deleted identities fail without resurrection. Applied changes with incomplete recovery retain their real local outcome and block later mutations until native recovery retry. No backup/recovery administration, source Delete, new persisted parent Done or bulk/global Item completion action is introduced.

## Definition of ready

- Q33 ordinary authority, partial edits/field hashes and container-only archive are accepted; Q8 and Q68/Q69 govern retained completion and retired branches.
- Q112 A already approves the public production Intent and actual storage/recovery failure boundaries. No new Core seam, test hook, package or target is needed.
- Mac local execution and current mobile/device compiler configurations work. Signing/account setup and final whole-app polish remain deferred.

## Required tests and definition of done

Use public `callAsFunction(donate: false)` and canonical Core reads after reopening. First record an executable missing-implementation red for a rich List edit, then implement only that behavior. Follow with omitted/clear fields, invalid input, missing/deleted sources, archive/unarchive through live itinerary references and actual post-save recovery failure. Assert stable source/association identities and independent completion, unchanged other content and exact archive-derived progress/remaining outcomes.

Run the affected Item/List Intent classes, compile the real app for Mac, Simulator and unsigned iOS device, verify extracted metadata and run affected Swift/Markdown lint and diff checks. Retain original source epochs and results. These adapter checks do not prove Siri/Shortcuts discovery/invocation, background/locked behavior, system bulk confirmation, shared account storage or physical-device behavior. No whole-map completion is implied.

## Executed vertical slices

| Behavior | Executable red | Following green |
| --- | --- | --- |
| Name/notes edit of a rich archived List | Missing implementation throws through production invocation, 0.291 s | 0.087 s; identity, color, icon, manual estimate, references, progress and independent membership completion retained after reopen |
| Omitted fields and explicit notes clear | Final nil assertion fails on stored empty String, 0.416 s | 0.048 s; name-only and notes-only preserve live omitted values, empty notes clears; rich edit regression also passes |
| Archive/Unarchive a List used beside its Item directly in an itinerary | Missing implementation throws after the real graph is prepared, 0.430 s | 0.282 s; full estimate stays 120 min, remaining changes 120 to 60 to 120, only the branch is retired, no Done flags rewritten |

The commands use the existing app-owned mutation path. Editing reads the canonical source and its field hashes, supplies only requested fields and retains Core's writer-guard validation. Archive submits only the container's archive change; the adapter implements no separate progress or time calculation. Cached entity name/archive values never replace live data.

## Failure and preservation qualification

These required scenarios pass on first execution against the implemented actions, without a new production correction or fabricated executable red.

- Empty patch and blank-name-plus-notes edits preserve the original content, field hashes and Last updated. Edit/Archive/Unarchive reject deleted or never-existing identities; the reopened catalog stays empty, 0.058 s.
- Actual post-save recovery-copy failure retains the edited name/notes, blocks the next edit and keeps the original incomplete operation. Native recovery retry completes it without changing the applied field hashes; an explicit later edit then works, 0.190 s.
- Actual post-save archive recovery failure retains the archived source and blocks Unarchive. Native retry acknowledges the original operation, and later explicit Unarchive succeeds. The empty List remains No items rather than completed throughout, 0.188 s.

The existing real filesystem obstruction and public Intent/Store/Core boundaries are reused. Recovery administration is not registered as an Intent. Original commands, source overlays, results and logs are retained in [the compatibility evidence](evidence/navigation/native-itinerary-window-compatibility/) under the matching `app-intent-list-edit-*` and `app-intent-list-archive-*` packet names.

- A real storage-opening failure makes both actions throw, leaves the store unavailable and preserves the obstructing file, 0.146 s. No successful change or empty-data fallback is fabricated.

The archive graph deliberately starts with a locally Done standalone List membership but Todo contexts inside the itinerary. Before archive, both itinerary appearances remain unfinished. While the List is archived, one branch is counted Archived, not Done; the directly referenced Item stays unfinished. Unarchive restores the branch's local Todo. The Item's source flags and the standalone membership's retained local Done stay unchanged throughout, matching Q8 and Q68/Q69.

## Combined adapter qualification

All 35 affected Item/List tests pass together with zero failures or skips, in 12.266 seconds. The [actual final result](evidence/navigation/native-itinerary-window-compatibility/app-intent-list-edit-archive-final-qualification/) retains the XCTest summary, original log and frozen inputs. This adds seven new edit/archive cases to the prior 28; it is not a full app-hosted-target or repository test run.

Mac's extracted app metadata declares ten actions, including `EditPlannerListIntent` and `SetPlannerListArchiveIntent`, plus the existing two entities and two queries. The artifact hash and exact identifiers are retained. Metadata proves compilation/extraction only; actual Siri/Shortcuts discovery/invocation and system restrictions remain open. The tests keep using disposable real storage and public SDK invocation without donations.

No Core/schema/backup, native UI layout, package, target or entitlement change is introduced. The existing test-store cleanup warning limitation remains: temporary SQLite connections may outlive fixture-directory removal. Original logs retain those warnings; these checks establish neither clean shutdown nor a production integrity defect. Explicit unverified-outcome fault qualification and complete system/background/locked behavior remain separate acceptance work. No source Delete or recovery-administration action is registered.

## Platform compilation and source verification

The actual production app and native UI target compile for the generic iPhone/iPad Simulator destination. The unsigned generic iOS device app also builds, with one embedded mobile Share extension; both executable products contain arm64. Device installation and execution were not attempted. Both mobile metadata artifacts retain the same ten actions, two entities and two queries. Commands, compiler logs, metadata identifiers and product hashes are in the `app-intent-list-edit-archive-mobile-build` and `app-intent-list-edit-archive-device-build` packets, including the device embedding check.

All 983 frozen inputs in each final Mac, Simulator and device packet match the current repository source/configuration files. Affected strict Swift formatting, Markdown lint and Git whitespace checks pass. This does not claim repository-wide warning freedom or physical performance.

## Remaining map work

The broader ordinary Intent catalog, system invocation/confirmation/background/locked checks, native Agent Control and client routes, shared iCloud/account-bound storage, installed Share behavior and physical-device convergence/recovery/performance remain open. Richer List properties and other data workflows are separate slices. Signing remains deferred. Q113 A approves compact List toolbar grouping; [the native review](../native-list-toolbar-review.md) records its implementation and platform qualification. Final whole-app polish follows feature completion.
