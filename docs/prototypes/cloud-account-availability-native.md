# Native Planner-only iCloud availability

Native checkpoint, 29 October 2026. The user resumes the previously deferred
Planner-only off/on test, then requires private-user storage with no developer
cloud fallback.

## Read-only observation

A signed diagnostic uses the approved Planner identifier and private Development
container. It has no PlannerCore/SwiftData dependency and opens no Planner store.
It observes `CKAccountChanged`, reads account status, and requests private-zone
metadata and the current opaque user record only while status is Available.
The account comparison stays in memory; logs contain only comparison booleans,
status and counts, without account identifiers, record content or zone names.

The user manually disables only Planner in iCloud settings, then restores it.
Two actual account-change notifications accompany Available → No account →
Available. Fourteen samples observe No account and skip private database and
identity requests. Thirty-nine samples observe Available; restored private
metadata access and the same initial account are verified before stopping.
The native launch exits 0 after 299.297 seconds. Planner is left enabled.

The evidence
retains structured samples, signed configuration, source hashes and scoped
commands. It qualifies the actual per-app availability signal, not whole-account
sign-out, a different account, SwiftData reset behavior, Planner command/recovery
ownership or production synchronization. The isolated managed-store interruption
is a separate follow-up.

## Private-only storage requirement

The user's [storage boundary](../release-goals.md#private-cloud-storage-boundary-29-october-2026)
requires explicit user-private CloudKit or device-local offline operation.
Unavailable access and quota errors must not select public/shared databases or
another developer-funded service. Development/Production environment selection
is separate from private/public database scope.

An audit of 189 production Swift sources finds no public/shared CloudKit client
or automatic cloud configuration. Production still opens SwiftData with
`cloudKitDatabase: .none`; integration remains unimplemented. The new diagnostic
uses only `privateCloudDatabase` and performs no cloud writes. These source and
runtime observations do not replace future unavailable-account and quota-error
tests of the production integration.

## Isolated managed-store off/on and cleanup

A separate signed probe uses all 16 entities of actual PlannerSchemaV19, with
an explicit private database and a unique disposable App Group store. All 90
Core sources match the current native build inputs. The synthetic Item saves
and completes private export before each manual switch-off is requested.

Two eight-minute manual-action windows end before a disabled-account event is
captured. Each retains 93 enabled samples with the exact fixture and records
`PlannerCloudStoreTransitionTimeout`. Neither is reported as a passing
interruption check. The first attempt's
evidence remains unchanged;
the retry's timeout and subsequent successful cleanup are retained with the
attended run below.

The first fixture is freshly read, deleted and confirmed absent, then its nine
scratch files are removed as previously recorded. The retry fixture is likewise
read, deleted and confirmed absent before another fixture is issued.

A rebuild extends only the observation deadline to 30 minutes, with a matching
external timeout. The user manually turns Planner off and on within the fresh
window. Seventeen native samples include five No account observations. All five
find zero synthetic Items in the cloud-managed local store: SwiftData clears its
cache when this app loses access. No fixture write is requested while disabled.

After re-enabling, the opaque account comparison matches the initial account.
The first enabled sample still has zero Items; then the exact public identity,
lifetime, title, notes and global state reappear for three consecutive samples.
The transition passes in 87.266 seconds. This qualifies native cache reset and
reimport, not uninterrupted local preservation or a completed production sync.

A fresh store imports and verifies that Item, deletes only it and completes
export in 5.402 seconds. Another fresh store completes initial import and proves
its absence in 4.906 seconds. After every store-owning process exits, scoped
cleanup removes the retry and attended-run scratch directories: 18 regular files
and 6,414,632 nominal bytes. The
attended evidence includes the
successful phases, prior retry, source/build records and matching hashes for all
90 current Core inputs.

The two temporary app registration mentions fall to zero. Unregister commands
return 1; the final registry observation establishes removal. Installed Planner
retains three mentions and unchanged inspected file hashes; canonical
registration returns 0. Reusable build products remain. Planner is left enabled,
and no diagnostic is waiting for a setting change.

Both native availability and managed-store off/on checks have passed. Production
integration must preserve device-local plans independently of the cloud cache's
reset before enabling sync. Production CloudKit integration, ownership/recovery,
quota handling and two-device synchronization remain open. No public or
developer-funded cloud fallback is introduced; production remains local-only.
