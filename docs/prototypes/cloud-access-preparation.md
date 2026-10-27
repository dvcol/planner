# Private CloudKit access check preparation

A disposable native app now compiles against the actual 90-source PlannerCore
package and `PlannerSchemaV19`. Its requested bundle, App Group and private
container are the approved `dvcol.planner`, `group.dvcol.planner` and
`iCloud.dvcol.planner`, using the Development environment.

The check resolves its App Group, reads iCloud account availability and, if
available, attempts synchronous native ModelContainer initialization at a unique
`PlannerCloudAccessProbe/PROTOTYPE-<UUID>` scratch path. It inserts no Items and
does not open Planner's normal store. This is an access diagnostic, not a sync,
save/recovery or account-transition test.

Both the initial build and final incremental build succeed with
`CODE_SIGNING_ALLOWED=NO`. Strict Swift-format lint and plist/project syntax
checks pass. The final build adds no provisioning resources and is not launched.
The linker may apply an ad hoc binary signature; this supplies no selected-team
provisioning or capability proof. Actual products, inputs, source and commands
are retained in [the evidence](evidence/cloud-access-preparation/result.json).

## Required setup approval

The following describes the original preparation gate. The user has since
approved both setup requests; the [subsequent provisioning attempt](cloud-access-provisioning.md)
records the actual result and pending execution-Mac registration permission.

Automatic approval review originally rejected the signed-build command because
`-allowProvisioningUpdates` can create or update Apple-account profiles, App IDs
and certificates. Xcode's installed help explicitly documents these effects.
The approved identifiers exist, but development signing-resource management
needs explicit authorization before the provisioned build can run. Prefer the
existing Apple Development certificate; do not revoke existing certificates.

For the subsequent automatic-sync work, Apple also requires
[remote-notification background delivery](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices?language=_6).
This silently informs SwiftData about server changes. Enabling the main app's
Push Notifications capability remains a separate approval; it was rejected as
outside identifier registration. No Push capability or notification entitlement
has been added by this preparation.

Production storage remains local-only. After execution-Mac registration, the next
run still needs actual private-key access and an available iCloud account.
Installed Share, ownership cutoffs during native cloud delivery and physical
two-device synchronization remain open.
