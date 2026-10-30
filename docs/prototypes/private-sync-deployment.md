# Native private-sync deployment

30 October 2026. Source wiring is implemented; the installed Planner Development
app is unchanged. Final integrated synchronization acceptance remains open.

## App and Share

Normal main-app and Share configurations use the same App Group paths and
`privateCloud` container configuration. Core selects the verified account's
local store. Share uses the retained selection and writes locally without
starting a CloudKit worker. The existing local-prototype launch option and
explicit local configurations remain device-only.

The main app declares the approved CloudKit container, silent push entitlement
and mobile remote-notification background mode. App and Share declare their
CloudKit environment. Debug uses Development; distribution configuration uses
Production. The signed Debug Mac product verifies its existing team, exact
container and matching declared/signed environment. The prepared device build
also verifies its existing development signature, container, environment,
silent-push entitlement and mobile background mode; it is not installed yet.
Distribution still requires
its own signature/environment verification before release.

## Existing device-only plans

Opening a verified private account does not move or upload the original unbound
store. Settings offers **Copy device-only plans to iCloud** when that store
exists. This reads its ordinary export and opens the existing native review
screen. Only **Copy to iCloud** applies the reviewed import. Existing matching
private records are kept; the complete device-only original remains unchanged.
No new migration, backup format or automatic merge workflow is introduced.

A different account still invalidates the previous session. The UI requires
quitting and reopening Planner to select that account's data; it cannot retarget
an existing draft. Same-account reconnect preserves the existing draft context.

## Qualification

Mac and iOS Simulator app/Share compilation pass. Built property lists contain
the expected container/environment, and the mobile main app has the required
remote-notification array. The installed app's three baseline hashes remain
unchanged. All six focused signed app-hosted storage checks pass in 6.081
seconds. They verify App Group selection, main/Share reads and writes, original
local-data preservation and the reviewed device-only copy. Opening and preparing
the copy save nothing; confirmation copies the represented Item and leaves the
original complete export unchanged. The copied synthetic Item is removed through
Core afterward. These are production-interface checks, not evidence of every
native control or integrated sync.

The independent [already-deleted-record check](evidence/private-sync-deployment/already-deleted-record.json)
passes: a queued local removal finishes syncing after another writer deletes
that same synthetic record on the server.

Before normal-app qualification, cleanup verifies all 216 remaining records in
the exact `Planner-v1` Development private zone against the test-owned local
graphs and source names. It removes only that disposable zone, then removes 26
selected UUID probe directories in a second process after SQLite readers exit.
The audit and both cleanup results are retained in
[the evidence folder](evidence/private-sync-deployment/cleanup-audit.json).
No installed, original Planner or legacy managed-cloud data is removed.
After the copy test, one remaining synthetic cloud-history record is also
verified against its owned local graph and removed; unrelated records would
reject that cleanup.

Final acceptance still includes actual two-device live delivery, local
read/edit/relaunch during one combined Planner-only iCloud off/on cycle,
same-account resumption, quota/network/local-I/O failure behavior and native
status/draft interaction. The unresolved already-open-peer outcome from the
[transport checkpoint](private-sync-engine.md) remains explicit.

## Bounded account verification and normal first launch

A fresh account-free iPhone Simulator exposed a real startup delay: normal
launch stayed on **Opening Planner** beyond the native check's 30-second limit.
A temporary trace separately showed account-status lookup still pending after
nine seconds, before local-store selection. That trace is removed from source.

Account verification now has a five-second deadline. An unavailable or delayed
account selects the existing local fallback; a late SDK result cannot adopt an
owner or start synchronization. A subsequent retry verifies the account again.
Already-bound plans retain their existing account selection. New device-only
plans explain that later private access requires reopening and explicitly
reviewing their copy, rather than promising an automatic upload.

Normal app launches on two fresh, account-free simulators pass: light iPhone
and dark iPad. Each exercises the actual unavailable status and Sync now,
creates an Item with notes, terminates/relaunches Planner and reads the same
public Item identity and notes. Settings hit-region and element-description
audits pass; both Settings and Item captures are inspected. These launches use
no local-prototype argument or production test hook. Test bodies take 72.518
and 50.927 seconds respectively. The affected six signed Mac storage tests
also pass, in 7.184 seconds, including the available-account reviewed copy.
[Compact results](evidence/private-sync-deployment/account-deadline.json)
retain the original result-folder paths. This is not the actual Planner-only
off/on or two-device test; both remain in the final integrated session.
