# Account-bound local storage for private synchronization

Q164 A implementation checkpoint, 29 October 2026. This establishes local
ownership before adding CKSyncEngine record transport. The installed app still
selects `localOnly`; production synchronization is not activated.

## Implemented behavior

`StorageMode.privateCloud(containerIdentifier:)` resolves the real account in
the main application. Core derives separate store, control and recovery paths
from the container, signed build environment and opaque account identity.
The account identity is hashed locally; callers supply no account selector.
SwiftData always uses `cloudKitDatabase: .none`.

Core durably retains the selected account. If private access is unavailable,
bootstrap reopens that account's local plans. An account notification invalidates
old sessions, queries, capture drafts and Undo capabilities. A changed selection
from another process also invalidates the session; changing it back cannot
reactivate that session. Malformed ownership metadata fails closed.

Share only uses the main app's retained binding and writes locally. It does not
open a CloudKit connection, establish a new account or claim a live account
observation. Before main-app setup it requests setup. This prepares host-closed
capture without giving the extension responsibility for synchronization.

Existing unbound local plans remain in their original store. Establishing a
private account opens a separate account-bound store and does not silently
upload, move or delete those plans. The later
[deployment slice](private-sync-deployment.md) adds an explicitly reviewed copy
while preserving the original store.

The offline Share follow-up
now proves that a private-configured extension opens an initialized unbound
local store when no private owner has been selected. It reads the original
Item and saves another Item without starting CloudKit. Main-app setup is still
required for a new store. If account-specific control storage exists but its
selection file is missing, access rejects with `ownershipUnverified`; it cannot
silently fall back to unrelated device-only data. The original local Item is
preserved. The earlier failing outcome is retained beside the passing result,
and the affected Core cohort passes 22 tests across seven suites. No account
switch, new format or remote fixture is needed for this check.

Private builds must provide `PlannerCloudEnvironment` in their actual Info.plist.
The diagnostic verifies that this matches its signed Development entitlement.
App activation still needs matching build configuration and signature checks on
both platforms. Local-only mode requires no cloud configuration or SDK access.

## Verification

The focused real-Core cohort reports 19 passing tests in five suites, including
invalid cloud configuration, exact preservation of local plans, recovery
failures, independent-writer observation, dataset presentation scope and atomic
creation into a List. Runtime is 6.755 seconds after compilation. Strict Swift
format lint and whitespace checks pass.

The isolated signed Mac diagnostic passes in 1.104 seconds using the approved
team, App Group and private container. It exercises public Core operations and
verifies:

- Share cannot establish a new ownership binding.
- Unbound plans remain separate and retain their original values.
- Main and Share-role Core instances reopen the same account-bound dataset,
  preserving exact source fields, hashes and timestamps.
- Both roles save locally into that dataset with complete recovery.
- Changed and corrupt account selections reject access; an invalidated session
  stays invalid after restoring the selection.

The Share-role instance runs inside the signed diagnostic. This is not an
installed extension journey or proof of host termination. No CloudKit record
write is requested; account availability alone does not qualify synchronization.

An initial test assertion incorrectly compares a non-Equatable content type;
the corrected test compares fields and their complete hashes. An initial native
preflight also finds that an arbitrary generated Info key is missing. Supplying
an actual Info.plist fixes that configuration, and the final signature check
verifies both declared and signed environments. Failed logs remain separate.

The evidence manifest retains
source/configuration hashes, exact native commands, signing verification,
runtime results and the focused test log. Production activation, actual per-app
Off/On preservation, different-account isolation and transport remain open.

The owning signed diagnostic removes its 17 synthetic local/recovery files
(503,687 nominal bytes). The shell cannot remove protected App Group content,
so cleanup runs through that signed app rather than changing privacy settings.
The three focused cohorts' 63 marked fixture directories are also removed
(23,571,306 nominal bytes). Temporary app registration is removed and the
installed Planner's three inspected files remain unchanged.

## Next gates

The signed diagnostic includes an attended Off/On mode with a 30-minute window
per transition. It must observe actual SDK NoAccount, keep existing plans
readable, save and reopen new local Items, allow Share-role local saves, then
retain all of them when the same account returns. No setting changes happen
automatically. This gate has not run for the new storage implementation yet.

Then implement private CKSyncEngine mapping, durable pending changes, state and
record metadata. Qualify actual round trips, failures, field conflicts,
deletion, two-device operation and account isolation before activating the app.
No public/shared/developer-funded fallback is permitted.
