# Native List Intents

Status: Create List, Get List, Add Item to List and the List entity/query are locally qualified. All 28 focused Item/List tests pass; Mac, iPhone/iPad Simulator and unsigned iOS device compilation and eight-action metadata pass. Actual system invocation and physical-device testing remain separate gates.

## Context and starting state

The approved Q33 ordinary Intent catalog includes List creation/read, organization and archive. Q112 A approves production App Intent invocation and EntityQuery tests with Apple's dependency manager and disposable real Planner storage in the existing app-hosted target. The current app exposes five Item actions but no List entity or action. Core already owns List content, derived progress, membership identity, ordering and local completion.

## Goal and expected end state

Add a native List entity with its stable source identity, live name and archive state. It must not invent a stored List Done state. Create List accepts a name and optional notes, using the existing Core command and recovery outcomes. Resolve/Get use current values rather than a cached shortcut name; unavailable identities stay unavailable. List choices use the canonical List catalog, include archived sources, preserve its search/order behavior and read beyond one page without an application cap.

Then add the ordinary Add Item to List action using Item and List identities and Core's existing addMembership command. A new relationship starts local Todo; repeating Add retains the existing membership and local state. Source content and other List/Itinerary references remain live and unchanged. Source Delete, backup/export/recovery administration and association Undo remain outside Intent authority.

## Definition of ready

- Q33 ordinary authority and Core List/membership semantics are accepted.
- Q112 A confirms the public production Intent/EntityQuery and real storage/recovery failure test boundaries. No new seam, target, package, test hook or injected adapter is introduced.
- The current Mac app-hosted tests execute after the user session refresh. Signing and account setup remain deferred.

## Required tests and definition of done

Work one vertical slice at a time through public `callAsFunction(donate: false)` and EntityQuery methods. First require Create List to return its single saved identity, name/notes and empty derived progress after reopening, recording an executable missing-implementation red. Follow with live identity/search resolution, archived choices, page boundaries, unavailable/missing/deleted input and actual recovery-save failure. Add Item to List must retain source/reference identities, independent local completion, idempotent existing membership and relaunch state, without resetting other contexts.

Run the affected List and Item Intent classes, compile the actual mobile app/native test target, inspect extracted metadata, and run strict Swift/Markdown lint and diff checks. Preserve exact source epochs and original results. Actual system discovery/invocation, system confirmation, locked/background behavior, shared/account-bound storage and physical qualification remain separate gates. This slice does not claim complete List editing, all Intent coverage or map completion.

## Executed vertical slices

| Behavior | Executable red | Following green |
| --- | --- | --- |
| Create List, canonical identity/content and empty progress after reopen | Missing creation implementation throws through public invocation, 0.337 s | 0.163 s |
| Live identity lookup after rename/archive, deduplicating requested identities and omitting missing ones | Missing resolution implementation throws, 0.261 s | 0.048 s |
| Canonical search and suggestions across 65 Lists, including archived sources and empty results | Missing search implementation throws after real fixture creation, 5.354 s | 5.006 s; both pages and requested identity order retained |

The choices implementation reads Core's generation-bound 64-row pages and returns the complete system EntityQuery result. It adds no custom search, ordering, result cap or full-detail read per row. Core still retains its identity sequence and the system interface returns an array, so this is not a bounded-total-memory claim. Missing/stale/unavailable reads fail explicitly rather than returning partial choices as success.

| Further behavior | Executable red | Following green |
| --- | --- | --- |
| Get List resolves a changed live name and rejects a missing identity | Missing read implementation throws through public invocation, 0.387 s | 0.217 s |
| Add a shared Item with independent local completion; repeated Add retains the same relationship | Missing Add implementation throws, 0.495 s | 0.286 s; global Reopen reveals retained local Todo, later local Done survives repeated Add, and shared note edits remain live in both Lists after reopen |

## Failure and preservation qualification

The following required cases pass on first execution against the implemented commands and query; no new production correction or new executable red is claimed for them.

- Unavailable storage throws for suggestions, text search, identity lookup and creation instead of returning empty choices or acknowledging a List, 0.027 s.
- Blank-name rejection and cancellation before invocation leave no saved Lists, 0.029 s.
- Native confirmed deletion of a List or Item makes its cached identity unavailable. Get and Add reject deleted or never-existing sources. Reopening retains only the untouched survivor, with no implicit source resurrection or partial membership, 0.210 s.
- Repeating Add for an existing first membership keeps its exact identity, position before another Item and local Done state after reopen, 0.250 s.
- Real recovery-copy failure after List creation returns the applied identity, permits reads and blocks another creation. Native retry acknowledges the original operation and retains one List before a subsequent explicit creation, 0.188 s.
- Real recovery-copy failure after Add retains that membership, blocks Add into another destination and leaves that destination empty. Native retry preserves the original relationship; a subsequent explicit Add into the second List succeeds without copying the Item, 0.080 s.

Both recovery cases reuse the existing `IntentRecoverySaveObstruction` through the actual `ModelContext.didSave`/filesystem boundary. Its visibility changes inside the test target so both Intent test classes can use it. No production parameter, injected save result, package or target is added. The native app performs recovery retry; no recovery-administration Intent is exposed.

Original logs, exact commands, frozen source overlays and exits are retained in [the compatibility evidence](evidence/navigation/native-itinerary-window-compatibility/) under `app-intent-list-*` packet names. First-red and later-green source epochs remain separate. These local adapter cases do not supply system discovery, background launch, locked-device, account-bound storage or physical-device evidence.

## Combined adapter qualification

The [initial combined result](evidence/navigation/native-itinerary-window-compatibility/app-intent-list-final-qualification/) executes all 28 Item/List tests with zero failures or skips in 12.039 seconds. The actual XCTest result summary confirms 17 existing Item cases and 11 List cases; this is not the entire app-hosted target or a full-repository run. Existing Item tests still pass after making the recovery obstruction reusable within that test target.

Mac's extracted app metadata contains eight actions, including Create List, Get List and Add Item to List, plus the Item/List entities and queries. The evidence records the artifact digest and exact identifiers. Metadata is compiler output, not proof of system discovery or invocation. The production actions stay in the main app, use the accepted background/ordinary authentication policy and call the existing app-owned command path.

No Core command, schema, backup format, target, entitlement or package changes are introduced. The entity currently exposes name and archive state; it has no synthetic stored Done property. List content editing, richer reads/properties, contextual and bulk actions, removal/move/reorder Intents and the wider source catalog remain work. Complete system confirmation/invocation, background/locked behavior and account-bound/physical testing retain their separate gates. Native whole-app UI polish remains after feature completion, and Q113's compact-toolbar choice is still pending.

## Mobile compiler qualification and limits

The [production mobile app/native-test build](evidence/navigation/native-itinerary-window-compatibility/app-intent-list-mobile-build/) passes for generic iPhone/iPad Simulator with signing disabled. Its extracted metadata contains the same eight actions, two entities and two queries as Mac. Both source/configuration manifests match all 506 recorded inputs at that initial qualification epoch; the final cleanup epoch follows below. This supplies compiler/metadata evidence only, with no mobile system-invocation or physical-device runtime credit.

Strict Swift formatting lint passes both new List files and the affected Item test helper; Markdown lint and diff whitespace checks pass. The logs retain the existing disposable-store cleanup warnings while test objects still hold temporary SQLite connections. These tests do not establish clean-shutdown behavior or a production data-integrity defect. The earlier Item qualification records the same cleanup limitation.

These three List actions complete this named local flow only. Rich List properties/content editing, other organization and completion actions, scheduling and wider entities still need implementation and their tests. System confirmation and actual Siri/Shortcuts discovery/invocation remain unqualified on the installed restricted Customer runtime. No account, signing, entitlement or security changes are made, and the parent prototype/map remain open.

## Final warning cleanup and device compiler check

The first unsigned device build succeeds but exposes an unnecessary mutable query in the new Get List action. The SDK dependency setter does not mutate the query value, so its local declaration and the new query test declarations use `let`. No action parameters or behavior change. The [final combined regression](evidence/navigation/native-itinerary-window-compatibility/app-intent-list-final-clean-qualification/) again passes all 28 tests with zero failures/skips, in 11.766 seconds. Its actual XCTest summary and current eight-action Mac metadata are retained separately from the earlier epoch.

The [final Simulator build](evidence/navigation/native-itinerary-window-compatibility/app-intent-list-mobile-final-build/) and [final unsigned device build](evidence/navigation/native-itinerary-window-compatibility/app-intent-list-device-final-build/) both pass on that same source. All three manifests match 506 current source/configuration inputs. Device output contains the main app and its single embedded mobile Share extension, both arm64. Extracted metadata contains the same eight actions, two entities and two queries on Mac, Simulator and device SDK. The source/build records retain the exact products, commands and hashes. No device is installed, launched or otherwise physically qualified by these compiler checks.

The introduced query warning is absent on the final device build. Other observed warning locations are outside this change; their three source files match base `f15d6db4` byte-for-byte, as recorded with the initial unsigned build. This is not an assertion that the whole repository is warning-free. Strict Swift formatting lint, Markdown lint and diff checks pass on the final affected files. Signing/account/security settings remain unchanged.
