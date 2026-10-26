# CloudKit schema readiness

Read-only local checkpoint, 27 October 2026.

The actual production `PlannerSchemaV19` was reflected through SwiftData's public
Schema interface, using the currently compiled PlannerCore module and 90 Core
object files. The diagnostic opens no store and makes no account or CloudKit
request. It adds no production code, target, framework or migration.

The executed result contains 16 entities, 127 attributes and 30 relationships.
There are no uniqueness constraints, required attributes without defaults,
required relationships, deny deletion rules or relationships lacking declared
inverse metadata. These basic checks find no reason to change the schema before
the configured native prototype. They do not establish complete CloudKit model
compatibility or correctness during asynchronous remote delivery.

Apple describes the relevant restrictions in its
[SwiftData synchronization guidance](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
and [CloudKit model guidance](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit).
The diagnostic uses the installed SDK's actual Schema metadata rather than
guessing from property declarations alone.

[Evidence](evidence/cloud-schema-readiness/result.json) retains the result,
diagnostic source, compiler command, process exits and input hashes. The Core
source snapshot matches the qualified Mac build and current repository. This is
an executed diagnostic, not XCTest execution or a signed CloudKit store test.

## Next step and gates

The user approved `dvcol.planner`, `group.dvcol.planner` and
`iCloud.dvcol.planner`. The in-app developer portal currently requires sign-in;
registration has not occurred. The development identity now validates after the
missing official Apple intermediate was installed, but actual signing timed out
and the Keychain-prompt question remains pending.

After access is ready, use a configured, disposable native prototype to verify
real container initialization, account observations and the accepted ownership
cutoff during imports/resets. Do not activate production CloudKit or weaken the
writer/recovery guarantee based on this schema inspection. Production Core
remains local-only. Installed Share and two-device sync retain their separate
acceptance checks.
