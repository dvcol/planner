# Signed private CloudKit access

Native checkpoint, 27 October 2026. This follows the
[first provisioning attempt](cloud-access-provisioning.md).

After explicit permission to register the execution Mac, Xcode builds the
disposable access app successfully in 25.562 seconds. It uses the existing valid
Apple Development certificate and a Mac Team Provisioning Profile covering this
Mac's provisioning UDID. No existing certificate is revoked or replaced.

## Verified artifacts and execution

Strict deep signature verification succeeds with macOS system trust access.
The signed team is `Y6HV37KJ2G`, bundle is `dvcol.planner`, App Group is
`group.dvcol.planner`, and CloudKit container is `iCloud.dvcol.planner`.
CloudKit uses Development; the macOS APNs entitlement uses `development`.
The embedded profile permits those capabilities and its leaf certificate matches
the app's actual signing certificate and the existing valid local identity.

The first sandboxed trust check fails, while the same read-only verification
outside the filesystem sandbox succeeds. The verifier also needed corrections
for Apple's profile wildcard, macOS provisioning UDID and the certificate-prefix
argument syntax. These were diagnostic assumptions, not changes to the app's
signature or the account's trust settings. Apple documents
[profile wildcards versus signed entitlements](https://developer.apple.com/library/archive/technotes/tn2415/).

The verified app then launches and exits normally in 1.516 seconds. It resolves
the App Group, reports an available iCloud account and synchronously initializes
all 16 entities of actual `PlannerSchemaV19` with an explicit private CloudKit
configuration. Its unique empty store lives under
`PlannerCloudAccessProbe/PROTOTYPE-<UUID>` in the App Group. It inserts no Planner
content and never opens the normal Planner store.

[Evidence](evidence/cloud-access-native/result.json) retains hashes of all 90 Core
sources, three probe inputs and seven actual bundle files, including the debug
library and embedded profile. A verified 17-member archive contains source,
commands, logs, signed entitlements and runners. It excludes profile contents,
device identifiers, certificate files and private keys. The executed
[runtime result](evidence/cloud-access-native/runtime.json) and
[signing checks](evidence/cloud-access-native/signing-verification.json) are
separately readable. The prior failed provisioning evidence remains unchanged.

## Remaining scope

This clears selected-team signing and basic native App Group/account/synchronous
private-store initialization for this disposable Mac app. Account availability
and successful initialization alone do not prove successful server access or
completed asynchronous mirroring. No sync, account-change cutoff, installed Share
or physical-device behavior is qualified by this run.

Next observe actual asynchronous CloudKit setup and private-database access,
then establish the accepted ownership and recovery cutoff before production
integration. Production Planner remains local-only; the user data path is
unchanged. Mobile background delivery, installed app/Share and two-device sync
retain their separate implementation and acceptance work.
