# Production CloudKit deployment review

31 October 2026. Read-only CloudKit Console inspection finds only the built-in
`Users` type in Production. Development has the current `PlannerNode_v1` type
(65 fields), the older automatic-mirroring diagnostic `CD_Item` type (15 fields)
and `Users`. Selecting the Production Record Types list afresh avoids the
console retaining a previously selected Development type's details.

The actual Confirm Deployment dialog proposes two new types, 119 indexes for
`PlannerNode_v1`, 23 indexes for `CD_Item`, and default `_world`, `_icloud` and
`_creator` role definitions. The original preview and rendered
diff are retained.
Deploy has not been pressed. No record query, data transfer, schema edit or
reset was performed.

Apple documents that [deployment copies schema, not
records](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema).
Production types/fields cannot subsequently be removed, so the included legacy
type is part of the concrete approval scope. This operation does not publish the
app. Production sync still needs qualification in the eventual distribution build.

The schema's default role grants govern public database records; [private
databases remain private](https://developer.apple.com/icloud/cloudkit/designing/).
Current production code constructs CKSyncEngine with `privateCloudDatabase`
only, while local SwiftData uses `cloudKitDatabase: .none`. Schema deployment
adds no public/shared database transport or fallback. Disabling private access
does not select a developer-funded database.

An approved schema deployment, the final App Store name/record, distribution
signing/upload and manual review/unlisted release remain distinct release steps.
No further iCloud off/on or conflict stress session is requested by this review.

## Approved deployment

The owner approved deployment after reviewing Production schema permanence and
future versioned migrations. CloudKit Console reports “Changes Deployed” and
“The schema is deployed to Production.” The reviewed two types, indexes and
default role definitions are deployed; no record transfer or environment reset
was requested. The app continues to use private CloudKit only. Store-build
sync qualification remains separate from schema deployment. The temporary
confirmation capture is kept only for the active owner review, outside Git.
