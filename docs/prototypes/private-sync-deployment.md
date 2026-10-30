# Native private-sync deployment

30 October 2026. Source wiring is implemented; the installed Mac Planner
Development app is unchanged. The signed sync-checkpoint builds were installed
on the authorized iPhone and iPad. The normal same-account mobile journey now
passes creation, edits in both directions, deletion and relaunch, as recorded
[below](#unobstructed-two-device-live-sync). Off/on and broader failure checks
remain unqualified and deferred at the user's request.

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
silent-push entitlement and mobile background mode. Its later installed-device
qualification is recorded below.
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

## Integrated session prerequisite

The first attended Mac/iPad attempt creates its synthetic Item on the Mac but
does not find it on iPad. The iPad's native Settings and explicit Sync now both
report **Up to date with iCloud**. The user then confirms those two devices use
different iCloud accounts. This run cannot qualify same-account delivery and is
not evidence of a sync defect. Its [compact outcome](evidence/private-sync-deployment/different-account-diagnostic.json), exact source identity and result folders
remain retained at `/private/tmp/PlannerPrivateIntegrated-22b82e4d-88f9-49fe-b203-07d7bc6373c3`.

The speculative dedicated-subscription/scoped-fetch probe is reverted; no
transport change is retained from this mismatched-account run. An automatic
approval rejection prevents a second paired run from creating another test
Item. The user confirms iPhone and iPad share an account, so the next paired
native check uses those devices. Neither device needs to sign out. The actual
Planner-only off/on check remains combined with integrated sync acceptance.

A guarded signed app-hosted cleanup verifies that the mismatched run's exact
Item still has its original synthetic title and notes, then reviews and applies
only that Item's deletion. The check passes in 4.222 seconds and observes private
sync idle afterward. It touches no other Item or cloud zone; normal deletion
history remains. Its temporary test source and result are retained at
`/private/tmp/PlannerPrivateIntegratedFixtureCleanup.swift` and
`/private/tmp/PlannerPrivateIntegratedCleanup.xcresult`, rather than adding a
permanent one-off cleanup test to the app.

The replacement physical journey is prepared in the existing native UI target.
It uses normal installed storage and a fresh UUID in the synthetic Item's title,
searches that complete query on both devices, and retains exact row identities
through edits, deletion and relaunch. Only an explicit attended run enables it;
ordinary test execution skips it. Final affected iOS app/Share/UI-runner
compilation and strict Swift formatting pass. The iPhone/iPad pair has not yet
executed and requires the iPhone to be connected, unlocked and made available.

Both physical devices are now connected, unlocked and using Developer Mode.
The first iPhone-specific profile refresh is blocked by Apple's **PLA Update
available** response. The account holder then accepts the current Program
License Agreement and authorizes iPhone registration if needed. Existing app,
Share and runner profiles require an update to cover the iPhone. No iCloud
switch has changed during this preparation.

The combined transition journey is prepared in the same native UI target. Its
iPad role waits for the fixture's private-cloud acknowledgement, announces when
the human can disable only Planner, saves an edit while access is unavailable,
and checks the exact Item and notes after actual app termination/relaunch. It
then announces when to restore access. The iPhone role waits for the queued edit
and sends a verification edit back; final cleanup removes only that fixture.
Both roles use normal installed storage and the existing native controls, with
no production hook, new target or provider. The source compiles, but this
attended off/on journey has not executed. It follows the basic mobile sync run
in the final integrated session, rather than blocking implementation separately.

Provisioning subsequently succeeds under the existing development identity.
Strict signature checks and current profiles cover both physical devices for
the app, embedded Share extension and UI runner. The profile refresh leaves
stale seals on two cached products; regenerating only those temporary bundles
restores valid signatures. No production signing setting or installed Mac app
changes to address that build-cache issue.

The first same-account mobile attempt proves live creation: both native logs
report `saved.item.14B49CD8-08D6-4DBD-97D0-53AD2567CD68`. It then fails before the
iPad submits Save. The test taps the beginning of Notes, sends backspaces that
do not replace the original value, and inserts a prefix instead. Retained field
attributes show `Edited on iPadCrea…`; repeated native animation waits consume
the peer timeout. The incorrect draft is not saved. This run therefore supplies
no return-edit/deletion acceptance and does not establish a transport failure.
The [compact result](evidence/private-sync-deployment/mobile-editor-diagnostic.json)
and original input hashes remain at
`/private/tmp/PlannerPrivateMobilePair-c79e077e-d8f7-4305-ab33-12da2bf2ce02`.
The native test now uses Select All before replacement and has an exact-identity
fixture check before cleanup. Its physical iPad regression passes in 39.678
seconds, reading the exact complete replacement before deleting only that
fixture. The original screenshot is inspected, source hashes are unchanged and
the [compact native result](evidence/private-sync-deployment/native-editor-replacement.json)
retains the original result path. An earlier queued attempt loses its test
connection before any test starts while the device is locked; it supplies no
regression credit.

The subsequent paired retry stops before the iPhone test starts because iOS
reports **Developer App Certificate is not trusted**. Both signed bundles still
use `Apple Development: Dinh-Van Colomban (KX26Z8L8LW)` under team `Y6HV37KJ2G`.
The waiting iPad receiver is cancelled; that retry creates no new Item. Manual
device-only developer trust is requested. Full two-device edit/deletion and the
combined private off/on cycle remain open; no iCloud setting has been changed.
The user reports that no Developer App entry is shown on the iPhone. That
deployment issue needs investigation; the current priority moves to the reported
iPhone rotation and Calendar layout defects without additional security changes.

## Installed mobile update and trust retry

The user subsequently confirms that Planner opens normally on the iPhone, then
reports the installed UI differs from the rebuilt preview. Source commit
`e88f6e89` is compiled, signed and installed on both authorized mobile devices.
The iPhone's normal app launch succeeds. Its real native Calendar rotation
journey also passes in 57.032 seconds, preserving the exact Schedule and saved
description with 254 unchanged source inputs. The app returns to a normal
launch afterward. The
[physical Calendar record](evidence/native-calendar-shared-time-ruler/phone-landscape-2026-10-30/physical-iphone.json)
uses a disposable local dataset and supplies no private-sync credit.

Main app, Share and test runner signatures verify, with existing team profiles
covering both devices. No certificate, account or security setting is changed.
The earlier trust rejection no longer blocks this actual app/test-runner
execution. Both devices report unlocked before the paired live-sync retry.
Two-device edit/deletion and the combined private off/on cycle remain separate
qualification; no iCloud switch has been changed in this retry.

The resumed live pair creates Item
`E889940B-7A26-4235-B95C-60EF388F1474` on iPhone and reads that exact identity on
iPad. The iPad enters the complete replacement notes, but Save is covered by a
floating video while the device rotates. The native tap reports no valid hit
point; the editor remains open and no replacement Save is confirmed. The
waiting iPhone test is cancelled. The source snapshot is unchanged, and this
partial run supplies creation/receipt evidence only. Its synthetic Item remains
for exact guarded cleanup. Retained local path:
`/private/tmp/PlannerPrivateMobilePair-6e90dc3d-f94b-4a37-8d30-c0aa60674953`.
The user is asked to close the overlay and leave both devices stationary before
another physical interaction. Private off/on has not started.
The [partial result](evidence/private-sync-deployment/mobile-live-native-save-obstructed.json)
retains the creation/receipt and cancellation outcomes without committing the
unrelated video capture. The native edit helper now requires a hittable Save
before submission. Strict Swift formatting and device compilation pass; its
positive retry and exact fixture cleanup await idle, unobstructed devices.

## Unobstructed two-device live sync

After the user closes the floating video and confirms both devices are idle,
the native replacement and exact-fixture cleanup passes in 40.523 seconds.
It verifies the complete saved replacement before deleting only Item
`E889940B-7A26-4235-B95C-60EF388F1474`. The
[unobstructed native result](evidence/private-sync-deployment/mobile-native-save-unobstructed.json)
qualifies the Save-readiness check and closes that fixture cleanup.

The subsequent [live pair](evidence/private-sync-deployment/mobile-live-pair.json)
passes on both physical devices: iPhone 92.367 seconds, iPad 78.153 seconds,
with unchanged sources and no skips. iPhone creates Item
`CB1F083B-E796-41A8-91DF-8C6C1B1DA093`; iPad receives its exact identity and
changes its notes; iPhone receives those notes and changes its title. The open
iPad receives both values, preserves them through relaunch and deletes only
that Item. The open iPhone receives the deletion and confirms it after relaunch.
Both devices clear the test search afterward.

This establishes normal native-app private synchronization, bidirectional live
edits and deletion across the two same-account mobile devices. It does not
close the separate Mac already-open-peer diagnostic, conflict/failure cases or
the combined private-iCloud off/on check. The latter is prepared as the next
integrated session; no iCloud switch has changed in the live journey.

The user then asks to stop overtesting iCloud and prioritize Item-row UI. The
prepared off/on session is cancelled before its draft Save or any iCloud switch
change. Its unfinished test-owned draft is discarded by normal app relaunch;
both devices return to ordinary Planner use. The
[deferred-session result](evidence/private-sync-deployment/mobile-off-on-deferred.json)
records both cancellations separately from the successful live pair. Off/on
remains unqualified; no further run is planned in the current UI pass. Normal
two-device creation, bidirectional edits, deletion and relaunch are proven.
