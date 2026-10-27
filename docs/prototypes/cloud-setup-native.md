# Native asynchronous CloudKit setup

Native checkpoint, 27 October 2026, following
[selected-team signing and initialization](cloud-access-native.md).

The next signed disposable app performs an actual metadata request against
`iCloud.dvcol.planner`'s private database. That request succeeds. The native store
then reports completed successful setup, initial import and export events through
`NSPersistentCloudKitContainer.eventChangedNotification`. All 16 actual
production entities initialize. No Planner content is inserted.

The signed build passes in 13.956 seconds. Strict deep signature, exact signed
entitlements, profile coverage of this Mac and existing certificate checks pass
again before launch. The app exits normally in 7.686 seconds. The private database
reports one zone before initialization and two after observation. Zone names and
account/device identifiers are not recorded.

[Evidence](evidence/cloud-setup-native/result.json) retains 93 input hashes, seven
actual bundle-file hashes and a verified 16-member source/command/log archive.
The [runtime result](evidence/cloud-setup-native/runtime.json) includes the actual
event sequence. Its observer is installed before ModelContainer initialization,
and the container stays alive throughout observation. Events are supplied by the
real native framework; no synthetic event injection is used.

## Scope

This establishes real private-service access and native asynchronous empty-store
setup/import/export, beyond account availability alone. An empty export does
not prove that saved content reaches another store or device. No upload status
is inferred for production Planner.

Next qualify a uniquely identified synthetic content round trip and its cleanup
using separate fresh stores. Account changes, coherent recovery ownership,
production integration, installed Share and physical-device synchronization
remain open. Production Planner's local-only storage is unchanged. No production
schema deployment or normal user-store access occurs in this diagnostic.

The subsequent [content round trip](cloud-round-trip-native.md) now passes fresh
insertion, exact remote reads and confirmed fixture deletion through the final
native launch path. It retains separate command/recovery and ownership limits.
