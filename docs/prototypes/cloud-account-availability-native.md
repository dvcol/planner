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

The [evidence](evidence/cloud-account-availability-native/observation-result.json)
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

## Isolated managed-store window and cleanup

A separate signed probe uses all 16 entities of actual PlannerSchemaV19, with
an explicit private database and a unique disposable App Group store. All 90
Core sources match the current native build inputs. The synthetic Item saves
and completes private export before the second manual switch-off is requested.

No disabled-account event is observed during that bounded window. All 93 enabled
samples retain the exact fixture. The native phase records
`PlannerCloudStoreTransitionTimeout`, and the runner preserves that unqualified
result. It does not establish store reset/reimport behavior or account fencing.
The earlier Off request is explicitly cancelled; Planner is to remain enabled.

A fresh store then imports and verifies the exact synthetic Item before deleting
only it. Cleanup export succeeds, and another fresh store completes initial
import and confirms its absence. Those processes pass in 6.186 and 4.321 seconds.
After all store-owning processes exit, the scoped native cleanup removes nine
regular files and 2,653,176 nominal bytes from only this run's scratch directory.

The [store evidence](evidence/cloud-store-transition-native/result.json) keeps the
timeout, fresh-read/deletion successes, source and signing checks separate.
Temporary diagnostic registration mentions fall from three to zero. Unregister
commands return 1; the final registry observation establishes removal. The
installed app retains three mentions and unchanged inspected file hashes;
canonical registration returns 0. Reusable build products remain.

The read-only availability check has passed. The managed-store interruption
still needs a future attended off/on cycle, and production CloudKit integration,
ownership/recovery and two-device synchronization remain open. No public or
developer-funded cloud fallback is introduced.
