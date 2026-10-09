# Planner adapter contract

Accepted declaration for [Shared command contracts](https://github.com/dvcol/planner/issues/13). The [approved facade](architecture-review-packet.md), [accepted policies](shared-command-contracts.md), [content values](content-and-reader-review.md) and [field hashes](field-edit-contract.md) govern this packet. Q31 is withdrawn as repeating Q27; Q32 A uses authenticated SDK ping; Q33 A accepts this complete packet on 2026-10-09. This document specifies encodings and observations, not another conflict policy or executed code.

## Context, starting state and expected end

The preceding documents settle behavior but leave transport variants, catalog reads and result payloads incomplete. This packet makes those forms concrete. Every allowed mutation constructs the existing `PlannerOperation` and calls `Planner.execute`; every read/review uses the same facade. SwiftData models, account selection and transport concerns remain private. The end is one reviewable contract with exact scenarios for implementation, followed by prototype compilation and runtime proof.

## Common grammar and authority

Adapter format version is `1`. Every tool arguments/result object includes `formatVersion: 1` in addition to its fields below. MCP tool schemas advertise that exact version, with no caller-selectable account, dataset, session, lifetime, origin flag or capability grant. Native code retains its authorized `PlannerDatasetSession`; MCP obtains one from the already enabled app. Review and operation bindings validate it again at the writer boundary.

UUIDs use native UUID parsing and canonical hyphenated output. Case variants identify the same UUID. Int64 values, ranks and result counts are canonical decimal strings, checked into their native type. Dates are finite JSON numbers containing native Double seconds since 2001-01-01 UTC under Q12, not ISO strings. Coordinate/color values are finite Double numbers. Integers used for format tags and small enum values are JSON numbers. Full optional reads use explicit null; content patches retain Q10 missing/null/value semantics. Unknown domain argument fields/cases, malformed types and unsupported format versions return a property-path error. JSON-RPC envelope validation remains the SDK's responsibility.

| Surface | Initial exposed operations |
| --- | --- |
| Native app | All ordinary data operations and reviewed source/label Delete, backup export/import and account recovery. Destructive native presentation follows the recovery and navigation tickets. |
| Share | Capture loading/preparation, review/apply and operation status for its own authorized draft. Main-app setup/migration gates apply. Internal save/checkpoint work remains Core-owned. |
| App Intents | Ordinary read/create/edit/completion/archive/organization/scheduling flows and native capture review. Bulk requires system confirmation. The initial candidate catalog does not add a permanent Delete Intent; source/label Delete stays in Planner's native confirmed workflow. Backup/export/recovery administration is absent under Q4/Q5. |
| Enabled MCP | Ordinary reads and commands below, exact reviewed capture and full-context bulk, and scoped operation status. Permanent source/label Delete and backup/export/recovery administration are absent and rejected at admission, including indirect attempts. |

The initial Intent inventory follows the original candidate journeys and accepted authority. It is part of this complete review, not a claim that the human separately prohibited every possible future Delete Intent. Ordinary Intent authentication still follows accepted Q6. Removing a membership, entry, owned link or selected Schedule is ordinary planning and never grants source Delete. No tool can enable Agent Control or retrieve the credential; `--mcp-headers` remains a separate non-UI executable mode.

## Shared identity values

| Value | Exact JSON form |
| --- | --- |
| Source reference | `{ "kind": "item\|list\|itinerary\|category\|tag\|schedule", "id": UUID }`, with one actual enum string. Core binds its authorized lifetime. |
| List appearance | `{ "kind": "listMembership", "listId": UUID, "membershipId": UUID }`. |
| Direct itinerary appearance | `{ "kind": "directItineraryItem", "itineraryId": UUID, "entryId": UUID }`. |
| Expanded List appearance | `{ "kind": "expandedListItem", "itineraryId": UUID, "listEntryId": UUID, "membershipId": UUID }`. |
| Completion scope | `{ "kind": "globalItem", "itemId": UUID }` or `{ "kind": "appearance", "appearance": Appearance }`. |
| Bulk scope | `{ "kind": "list", "listId": UUID }`, `{ "kind": "itinerary", "itineraryId": UUID }` or `{ "kind": "itineraryListEntry", "itineraryId": UUID, "listEntryId": UUID }`. |
| Placement | `{ "kind": "first" }`, `{ "kind": "last" }`, `{ "kind": "before", "associationId": UUID }` or `{ "kind": "after", "associationId": UUID }`. Anchor must belong to the exact destination. No scalar rank supplied by an agent. |
| Itinerary source | Source reference restricted to Item or List. Repeating it in a new operation creates a distinct entry. |

The `\|` notation in this table denotes alternative enum spellings, not a literal valid value. Schema declarations enumerate those spellings. A malformed/missing appearance never falls back to global Item completion. Source IDs remain distinct from association IDs. Placement validation, rank calculation and rebalance use the approved Core rules; reorder changes no completion values.

## Commands

`planner_execute` takes `{operationId: UUID, command: Command, reviewToken: String?}`. Omission of the optional review token means none. The token is a Core-issued opaque handle to the approved bound review value; callers cannot manufacture authority by modifying it. It has no time-only expiry. Changes to payload, dataset/session/lifetime or reviewed targets invalidate it. An unknown handle is rejected rather than treated as consent.

`Command` is a discriminated object with required `type` and exactly the variant fields below. Creation defaults and content validation are in the content catalog. The native counterpart is the corresponding typed `PlannerCommand` case inside `PlannerOperation`; no additional domain implementation exists in the adapter.

| `type` | Required variant fields | Result identity and exact scope |
| --- | --- | --- |
| `createItem` | `content: PlannerItemContentInput` | One generated Item; Todo/Active. |
| `createList` | `content: PlannerListContentInput` | One generated List; Active, No items. |
| `createItinerary` | `content: PlannerItineraryContentInput` | One generated Itinerary; Active, No items. |
| `createCategory`, `createTag` | Corresponding `content` input | One generated shared label. Duplicate names allowed. |
| `editItem`, `editList`, `editItinerary`, `editCategory`, `editTag` | `sourceId: UUID`, `changes: typed content patch`, `expectedFieldHashes: hash map` | Entire changed-field guard from Q9/Q10/Q27. Empty patch invalid. |
| `setCompletion` | `scope: CompletionScope`, `done: Bool` | Global source flag or exact local appearance flag. A subsequent appearance read returns local/global/effective observations. |
| `setBulkCompletion` | `scope: BulkScope`, `done: Bool` | Requires exact review. All contextual child appearances, hidden/archived included; global flags retained. |
| `setArchive` | `source: Item/List/Itinerary reference`, `archived: Bool` | Container-only state, references/content/completion retained. |
| `addMembership` | `itemId`, `listId`, `placement` | One effective membership per live Item/List pair. Existing effective membership is retained; addition cannot reset it or silently reorder it. |
| `removeMembership` | `listId`, `membershipId` | Remove selected association, retain shared source. |
| `moveMembership` | `listId`, `membershipId`, `destinationListId`, `placement` | Remove the original association and ordinarily add to destination together. Existing destination membership retains identity/local state; a new one starts local Todo. Source retained. Same destination is invalid; use reorder. |
| `reorderMembership` | `listId`, `membershipId`, `placement` | Same association/state, new saved order. Self-anchor invalid. |
| `addItineraryEntry` | `itineraryId`, `source: ItinerarySource`, `placement` | New distinct entry and local Todo contexts, including intentional repeats. |
| `removeItineraryEntry` | `itineraryId`, `entryId` | Remove selected entry/owned contexts, preserve source Items/Lists and other appearances. |
| `reorderItineraryEntry` | `itineraryId`, `entryId`, `placement` | Same entry and local contexts, new order. |
| `createSchedule` | `source: Item/Itinerary reference`, `form: ScheduleForm` | One generated Schedule; source retained. |
| `editSchedule` | `scheduleId`, `changes: {form: ScheduleForm}`, `expectedFieldHashes: {form: Hash}` | Complete Schedule form replacement guarded as one field; no source-content patch. |
| `changeScheduleZone` | `scheduleId`, `planningTimeZone: String`, `expectedFieldHashes: {form: Hash}` | Timed only, preserving both stored instants. Guard the read form; all-day rejects. |
| `removeSchedule` | `scheduleId` | Remove exactly this Schedule, retain source/other Schedules. |
| `applyCapture` | `draftId`, `draftGeneration`, `choice: CaptureChoice`, `listIds: [UUID]` | Exact reviewed create/reuse, discussed below. No automatic matching or replacement. |

All unqualified identity fields in the table are UUIDs. `placement` is required so adapter behavior does not choose a UI insertion default. `listIds` is a set by parsed UUID identity. Review/execute use one validated immutable command. Known identical operation replay returns the original result IDs and adds nothing. Modified payload under the same operation ID rejects that attempt as `operationPayloadMismatch`; it does not rewrite the earlier status. Generated UUIDs are assigned once to the proposal/operation, not regenerated on replay.

Native command cases use the table's field names as associated-value labels. Content changes are source-specific Sendable structs whose fields are `PlannerFieldChange<Value>`, defaulting to unchanged. Each editable field has its corresponding typed field enum; transport strings are validated into it. The native counterpart of the existing notes request is:

```swift
let command = PlannerCommand.editItem(
    sourceId: itemId,
    changes: PlannerItemChanges(notes: .set("Monday booking")),
    expectedFieldHashes: [.notes: originalNotesHash]
)
let result = await planner.execute(PlannerOperation(
    operationId: operationId,
    session: authorizedSession,
    command: command,
    reviewToken: nil
))
```

Here itemId/operationId are validated UUIDs and originalNotesHash comes from the prior source detail read. This is a declaration example, not compiled Swift. Bulk/capture prepare the same typed command with `planner.prepareReview(session: authorizedSession, command: command)`, then execute with its Core-issued token. `operationStatus(session: authorizedSession, operationId: operationId)` resolves interruption without automatically rerunning execute.

Native-only `deleteSource`, `applyImport` and `restoreRecovery` variants use the same operation envelope with required reviewed impact. Their shapes are in the portable contract. They are not part of the MCP advertised union. If an adapter nevertheless requests a known forbidden variant, admission returns `forbiddenOperation` before preparation/mutation. Allowed reference editing cannot smuggle one of those variants.

Native-only `restoreAssociation(snapshot:)` supplies the approved original-association Undo distinction. Core validates its issued snapshot and current bindings before restoring; it is absent from MCP/Intents. It does not grant source recovery or persistent Trash. Its exact snapshot is in the portable contract.

## Schedule form and guard

Timed is `{kind: "timed", start: DateNumber, end: DateNumber|null, planningTimeZone: String}`. All-day is `{kind: "allDay", start: CivilDate, end: CivilDate|null}`. CivilDate has exactly integer `year`, `month`, `day`, with valid Gregorian round-trip. All declared members of a supplied form are present; a missing end is represented by null. Timed supplied end is strictly later; all-day end is not earlier and is inclusive. Native pickers resolve gaps/repeats before producing the approved instant; transport does not silently normalize local components or infer an end from estimates.

Schedule reads return `fieldHashes.form`. Use the existing field-hash version with Schedule kind `06`, authorized Schedule lifetime and field name `form`. Canonical timed record has String `kind`, Date `start`, optional Date `end`, String `planningTimeZone`; all-day has String `kind`, required civil start record and optional civil end record. Civil components encode Int64 in the canonical value, after checked native conversion. This adds a declared field under version 1, not a new byte encoding. A changed form rejects a stale form/zone edit together. Zone-only command reconstructs the form with unchanged start/end after validation.

## Review and operation outcomes

`planner_prepare_review` takes `{command: Command}` and returns `{reviewId, reviewToken, command, targets, impact}` or a typed rejection. It maps to `Planner.prepareReview`. `command` is the normalized immutable command being authorized. `targets` lists complete source/appearance/association identities involved, including hidden/archived children. `impact` has `kind`, `targetCount: CountString`, `globalFlagsChanged: Bool`, `sourceDeletes: [SourceReference]`, `referenceRemovals: [ReferenceRead]`, and native import details when applicable. Review is not a domain save, receipt or R21 acknowledgement.

The MCP reviewable cases are setBulkCompletion and applyCapture. Native additionally reviews deleteSource, applyImport and restoreRecovery. A non-reviewable command passed to prepareReview returns invalidInput at `/command/type`; its ordinary execute path remains available without a token. A forbidden native case from MCP returns forbiddenOperation first. This keeps the review result's declared impact kinds exhaustive.

ReviewId is UUID and reviewToken is String. Each target is `{kind: "source", source: SourceReference}`, `{kind: "appearance", appearance: Appearance}`, or `{kind: "reference", reference: ReferenceRead}`. Impact kind is `bulkCompletion|capture|deleteSource|import|restoreRecovery`; `importDetails: ImportReview|null` is present and is null outside native import/recovery. Targets are a set of these typed identities. Read/query/review/capture failures use `{formatVersion: 1, state: "failed", reason: Failure}`; successful values use their declared form plus formatVersion. This failure envelope is separate from a rejected operation, which also identifies its operationId.

For bulk, each independently completed appearance occurs once in targets; repeated Item sources remain separate appearances. Global flags are false in the impact. A native Intent obtains system confirmation over that exact scope/count; an enabled agent may apply the exact preview under Q3. Changed target sets require a new review. Empty containers have zero targets and remain No items; no percentage or completed override is fabricated.

Every operation result has `operationId` and one discriminator:

| `state` | Required payload |
| --- | --- |
| `rejected` | `reason: Failure`. This attempt made no domain changes. A previous applied operation with the same ID can still have an applied status. |
| `applied` | `result: {generated: [SourceReference or ReferenceRead], affected: [SourceReference or ReferenceRead], progress: [ContainerProgress], importSummary: ImportSummary\|null}`, `recovery: RecoveryResult`. Import summary is native-only and null for ordinary operations. The complete domain action committed. |
| `unverified` | `proposal: {proposalId, originalOperationId, evidence: "preparedUnverified", requiresFreshReview: true}`. Prepared data does not establish commit or rollback. Native recovery inspection owns the proposal contents. |

RecoveryResult is `{state: "complete", checkpointGeneration: CountString}` or `{state: "incomplete", reason: Failure}`. Incomplete is an applied outcome and cannot be presented as ordinary failed/unapplied. No checkpoint generation is fabricated before complete recovery. The MCP result carries this structured outcome even when recovery is incomplete; text must explain applied data and pending recovery. `isError` may describe a rejected call, never imply rollback of an applied result.

For the notes fixture, an example complete domain outcome is below. It assumes Core established checkpoint generation 2; the adapter echoes the observed generation rather than generating a number. Native `PlannerOperationResult.applied` carries the same UUIDs, affected source and `PlannerRecoveryResult.complete` value. MCP transports this declared JSON outcome through the official SDK tool result.

```json
{
  "formatVersion": 1,
  "operationId": "00000000-0000-4000-8000-000000000901",
  "state": "applied",
  "result": {
    "generated": [],
    "affected": [{"kind": "item", "id": "00000000-0000-4000-8000-000000000101"}],
    "progress": [],
    "importSummary": null
  },
  "recovery": {"state": "complete", "checkpointGeneration": "2"}
}
```

The corresponding request is:

```json
{
  "formatVersion": 1,
  "operationId": "00000000-0000-4000-8000-000000000901",
  "command": {
    "type": "editItem",
    "sourceId": "00000000-0000-4000-8000-000000000101",
    "changes": {"notes": "Monday booking"},
    "expectedFieldHashes": {"notes": "sha256-v1:514218da3ebca004857b8063cf5c59a50a25b02eb99b293bc9c4bc17fcca90dd"}
  }
}
```

`planner_operation_status` takes `{operationId}` and maps to `Planner.operationStatus` in the authorized dataset. Exact status variants are `knownUnapplied` with reason; `preparedUnverified` with proposal summary; `appliedRecoveryIncomplete` with recorded result/reason; `appliedRecoveryComplete` with recorded result/checkpoint; `noReliableEvidence`; or `unavailable` with reason. Status is read-only. Missing evidence is not `knownUnapplied`. Neither clients nor adapters automatically replay an uncertain operation.

Each status object has formatVersion, operationId and `state`. knownUnapplied/unavailable adds `reason: Failure`; preparedUnverified adds `proposal: ProposalSummary`; appliedRecoveryIncomplete adds `result: AppliedResult` and `reason: Failure`; appliedRecoveryComplete adds `result: AppliedResult` and `checkpointGeneration: CountString`; noReliableEvidence adds no payload. The enclosing dataset is authorized internally and cannot be selected in the wire result.

Failure has required `code: String`, `propertyPath: String|null`, `message: String`, and `details: FailureDetails|null`. Declared codes are `invalidInput`, `unsupportedVersion`, `unknownField`, `missingReference`, `unresolvedReference`, `staleEdit`, `staleReview`, `staleSnapshot`, `staleDatasetSession`, `forbiddenOperation`, `operationPayloadMismatch`, `persistenceFailure`, `recoveryIncomplete`, `mutationBlocked`, `captureInputFailure`, `captureDraftUnavailable`, `readUnavailable`, `accountUnavailable`, `recoveryIntegrityFailure`, `ownershipUnverified`, `setupRequired`, `migrationRequired`, `unavailable`. Property paths use JSON Pointer with standard `~0`/`~1` escaping; root is the empty String. Human message is useful and does not change machine classification or fabricate a cloud-error cause.

FailureDetails is exactly one of these discriminated records. staleEdit is `{kind: "staleEdit", conflictingFields: [String], currentValues: field-value map, currentFieldHashes: field-hash map}` for those fields. staleReview is `{kind: "staleReview", requiresNewReview: true, currentImpact: Impact|null}`. staleSnapshot is `{kind: "staleSnapshot", requestedGeneration: UUID, currentGeneration: UUID|null}`. missingReference is `{kind: "missingReference", requested: SourceReference|Appearance|ReferenceRead}`. mutationBlocked/recoveryIncomplete use `{kind: "mutationBlocked"|"recoveryIncomplete", operationId: UUID|null}` for permitted known evidence. All other failures have null details. Unknown/unavailable values are null, never invented zero/empty success.

## Queries, catalogs and reads

`planner_query` takes `{query: Query}`. Native typed queries use the same declared variants through `Planner.query`, not a second search engine.

Item query has `kind: "items"`, required `scope`, optional `text` default empty, `completion` default `todo`, `archive` default `active`, `categories`/`tags`/`lists` default null, `duration` default null, `scheduled` default `all`, `hasAddress`/`hasLinks` default false, and `sort` default `{mode: "title", direction: "ascending"}`. A null group is inactive. Scope is `{kind: "global"}`, `{kind: "inbox"}`, `{kind: "list", listId}` or `{kind: "itinerary", itineraryId}`. Inbox is unlisted retained Items, not unscheduled Items. Completion is `todo|done|all`; archive is `active|archived|all`. Native Done/Archive views initialize the accepted alternatives explicitly.

Accepted Q43 adds optional `rowPresentation: RowPresentationContext` to an Item query. Omission captures Core's current instant and device timezone once when creating the generation; explicit native/adapter values use the same validation. This controls read presentation only, never stored Schedules or per-device preferences.

Identity groups are `{ids: [UUID], match: "any"|"all"}`; omitted match defaults any and an empty ID selection is inactive. Duration is `{minimumMinutes: Int64String|null, maximumMinutes: Int64String|null, includeUnknown: Bool}` with checked nonnegative bounds and max not below min. Scheduled is `scheduled|unscheduled|all` under any retained direct/itinerary schedule, including past dates. Address/links and all active groups narrow cumulatively. Global/Inbox completion uses the global flag; List/Itinerary uses effective global OR local. Approved literal matching, fields, fixed locale and exact result sequences remain unchanged.

Item sort modes are `title|created|lastUpdated|duration|manual`, directions `ascending|descending`. Manual is only a standalone List query and rejects descending rather than rewriting saved ranks. Unknown estimates remain last in both directions. Native per-view remembered choices are presentation state; MCP requests state their desired sort and never write UserDefaults.

Catalog query is `{kind: "catalog", sourceKind: "list"|"itinerary"|"category"|"tag"|"schedule", text: String, archive: "active"|"archived"|"all"}`. This concretizes identity selection already needed by the approved query/read facade. Containers use native insensitive name/title matching; labels permit only archive all because they have no archive state. Schedules permit empty text/archive all and enumerate source-bound schedule identities; calendar viewport presentation belongs to Navigation prototype. Catalog order is name/title ascending with UUID tie for named sources and UUID ascending for Schedules. Catalog reads never guess identity from a duplicate name. Native UI can present its approved sorting without changing this selection query's stable default.

Query snapshot has `generation: UUID`, `rows: [RowIdentity]`, `matchingCount: CountString`, `unresolvedReferences: [ReferenceRead]`, `progress: [ContainerProgress]`, `rowPresentation: RowPresentationContext|null`. Item snapshots return the resolved context; catalogs return null. RowIdentity is source or exact appearance identity plus its Item source. All matching lightweight identities are discoverable, including beyond a rendered window. Progress is computed over complete scope, not current filters. Internal session ownership is validated, not caller-selected wire data.

RowIdentity is exactly `{kind: "source", source: SourceReference}` or `{kind: "appearance", source: ItemReference, appearance: Appearance}`. Successful read envelopes are `{formatVersion: 1, kind: "source", value: SourceRead}`, the corresponding appearance/value envelope, or `{formatVersion: 1, kind: "rows", generation, offset: CountString, matchingCount: CountString, rowPresentation: RowPresentationContext|null, rows: [RowRead]}`. Every window repeats its snapshot's resolved context. Read failure returns the typed Failure envelope, never a successful empty value.

`planner_read` request is `{request: {kind: "source", source: SourceReference}}`, `{request: {kind: "appearance", appearance}}` or `{request: {kind: "rows", generation: UUID, offset: CountString, limit: CountString}}`. Range values are checked nonnegative native integers; limit must be positive, without an extra arbitrary row cap. Out-of-range starting offset returns no rows within the same valid snapshot; a changed generation returns staleSnapshot. No stale-window identities mix with current data.

Source read has `source`, `content`, `createdAt`, `updatedAt`, `fieldHashes`, `state`, `labels`, `references`, `progress`. Absent concepts are null, not false invented state. State is `{globalDone: Bool|null, archived: Bool|null}`, applicable as declared for each kind. LabelRead is exactly `{reference: Category/TagSourceReference, name: String, color: PlannerColor|null, iconName: String|null}`; `labels: [LabelRead]` remains separate from content ID selections. `references` enumerates owned/membership/entry/Schedule identities necessary for authorized actions. Schedule content is its source reference and form, with only form hash; its absent source timestamps are null. List/Itinerary progress is derived; labels/Schedules have no progress.

Appearance read has `appearance`, `source`, `content`, `globalDone`, `localDone`, `effectiveDone`, `archived`, and `fieldHashes`. It does not copy the Item or make completion a content field. RowRead has `identity`, `title`, `subtitle`, `estimate`, `globalDone`, `localDone`, `effectiveDone`, `archived`, `hasLocation`, `hasLinks`, `ownedLocation: PlannerOwnedLocation|null`, `previewLink: PlannerOwnedLinkRead|null` and `scheduleSummary: RowScheduleSummary`. Inapplicable optional fields are null; non-Item catalog rows use scheduleSummary none. Presence flags retain their complete-content meaning, so a Maps-only Item can have hasLinks true and previewLink null. It excludes full notes, all links and hash maps. ReferenceRead for membership, itineraryEntry, ownedLink, labelAssociation or schedule is `{kind, id, owner: SourceReference|null, source: SourceReference|null, appearance: Appearance|null}`. The expandedCompletion variant is `{kind: "expandedCompletion", appearance: ExpandedListAppearance}` with no invented scalar completion ID. Core validates its composite entry/membership lifetime bindings.

The implemented native `PlannerSourceRead.references` uses the Sendable `PlannerReferenceRead` union. Its current ownedLink case binds the owned link ID to its Item owner; the wire source and appearance are null. Its current schedule case binds the Schedule ID to its planned source; the wire owner and appearance are null. Item reads enumerate owned links in their saved logical order followed by Schedules in UUID order. This metadata ordering is for stable reads; it never defines itinerary order or copies Schedule form/content. Other declared reference variants remain required as their graph is implemented.

ContainerProgress has `container: SourceReference or BulkScope`, `state: "empty"|"complete"|"partial"|"unresolved"`, `doneCount: CountString|null`, `totalCount: CountString|null`. Empty has 0/0 counts with no percentage and is not completed. Complete means nonempty all effectively Done. Unresolved gives null counts and identifies missing references in the enclosing read/snapshot; it never masquerades as empty/completed. Percent is a presentation derivation only when total is positive and counts are established.

## Row presentation context and schedule summary

Q43-Q46 A are accepted in [Navigation prototype's row review](navigation-row-contract-review.md). These declarations amend the shared read boundary; the current limited Item-only Core package and MCP route do not yet implement them.

Native `PlannerRowPresentationContext` has `referenceInstant: Date` and `displayTimeZone: String`. Wire RowPresentationContext is exactly `{referenceInstant: DateNumber, displayTimeZone: String}`. The instant must be finite and the zone must be a valid native timezone identifier. This is query context, excluded from content, field hashes and backups. The native view supplies its display-zone override or current device zone. Core resolves any omitted context once and binds it to the immutable generation. Row windows never recapture the clock/zone. Native time/day/zone changes affecting the projection rerun the query; relevant graph changes invalidate the old generation under staleSnapshot. Changing a query context cannot combine old-window identities with new summary values.

Native `PlannerRowScheduleSummary` is a Sendable union with the corresponding wire variants:

| Variant | Exact wire members and meaning |
| --- | --- |
| none | `{kind: "none"}`. No applicable retained assignment in this summary scope. It is not a substitute for an unresolved graph. |
| directItem | `{kind: "directItem", schedule: SourceReference, owner: ItemSourceReference, form: ScheduleForm, additionalCount: CountString}`. schedule has kind schedule and its validated lifetime; form is one actual retained direct assignment for that Item. |
| itinerarySpan | `{kind: "itinerarySpan", schedule: SourceReference, owner: ItinerarySourceReference, form: ScheduleForm, additionalCount: CountString}`. One actual assignment belonging to the current itinerary, labeled as a plan span. No combination across gaps or other itineraries. |
| inScheduledPlan | `{kind: "inScheduledPlan"}`. The global/Inbox/standalone List Item has retained inherited planning but no direct assignment; no invented appointment date is supplied. |
| unresolved | `{kind: "unresolved", references: [ReferenceRead]}`. Required unresolved references prevent a truthful summary. The nonempty reference list also appears in the snapshot's unresolvedReferences; none or a zero additional count cannot hide the uncertainty. |

Select the appropriate owner pool under Q40, then apply Q45 within that pool: ongoing first; otherwise the earliest future start; otherwise the latest past start. Several ongoing Schedules choose the latest start. Equal-start candidates use Schedule UUID ascending. additionalCount is the count of other retained Schedule records in this owner pool, including past records; one inclusive three-day span is one record. Item estimates never determine a Schedule end.

For these comparisons, a timed span is ongoing when start is at or before referenceInstant and its supplied end is strictly after it. A start-only timed Schedule has no ongoing span; a start exactly at referenceInstant remains eligible as the next start. All-day activity uses the reference instant's Gregorian civil date in displayTimeZone, inclusive of both selected dates; a null all-day end covers its start date only. Mixed-form start comparisons use a transient native calendar start-of-day comparison key for all-day values in this display zone. This key is never saved, hashed or exported in place of their civil dates. The original ScheduleForm, fixed timed instants/planning zone and inclusive all-day dates are returned unchanged.

previewLink is the first eligible non-Maps web bookmark in saved logical order with the existing identity tie rule. Existing website/tabelog/booking/generic classifications remain eligible under the supported web-link validation; appleMaps/googleMaps are excluded from the website-thumbnail choice. Return its stable linkId, exact originalUrl, label, classification and retained reference. Return null if none qualifies, including Maps-only Items. Read/query performs no network lookup. Native lazy preview I/O targets only that chosen link; image absence or failure retains its useful link fallback and does not try every other link. Full source details still return all links.

Q44's native contextual circle displays effectiveDone. When globalDone is true it is disabled, exposing Completed globally in help/accessibility without changing localDone. Item-view global Reopen later reveals the retained local flag. Local bulk Undone remains allowed and only clears local targets under Q8. No native container affordance adds a global completion command. Temporary preview/map results never enter these row values, owned content, field hashes or backups.

## Capture preparation and apply

Capture input is immutable ordered lanes. Direct agent input is `{inputs: [{kind: "url", value: String}|{kind: "text", value: String}]}`. A typed URL is retained before detected links in the same input. Native provider loading produces the same immutable ordered lane records plus Core-owned classification evidence; provider/generated strings are held rather than relabeled as independent text by the adapter. NSItemProvider loading remains a genuine native I/O boundary, not a caller-writable provenance dictionary. No arbitrary binary/file lane is accepted.

Native `PlannerNativeCaptureLoader.load(providers:)` is a Core-owned I/O helper on the native provider owner, returning immutable Sendable `PlannerLoadedCaptureInputs`. Its construction/classification evidence is internal; an adapter cannot fabricate it. The facade's `PlannerCaptureInput` is direct URL/text values or this loaded value. Raw NSItemProvider/MKMapItem objects never cross the Core actor as arbitrary Sendable values. Loader inputs/outputs have ordered source indices, typed URL, independent text, held provider text/map candidate or typed loading issue. Test at the real native loading boundary, including actual registered NSItemProvider fixtures; this is not a test-only injected loader seam or another domain service.

`planner_prepare_capture` takes direct input and returns a draft read through Core-owned capture preparation. Native app/Share use the same preparation after their accepted provider loader. The helper returns no saved entity or receipt. Draft read has `draftId`, `generation`, `content: PlannerItemContentInput`, `links`, `inputIssues`, `preview`, `reuseCandidates`, `saveAllowed`. Draft IDs/generations are UUIDs scoped to the authorized dataset; a changed generation cannot silently apply an older review. Discarded/relaunched preparation must be rereviewed; this is not an automatic Agent Control timeout.

DraftLink has exactly `linkId: UUID`, `originalUrl: String`, `label: String|null`, `kind: PlannerLinkKind`, `providerReference: PlannerProviderReference|null`; its draft identity is not an already saved owned-link identity. ReuseCandidate has `itemId: UUID`, `title: String`, `globalDone: Bool`, `archived: Bool`, `matchingLinkIds: [UUID]`, `matchingOriginalUrls: [String]`. PreviewCandidate has `provider: appleMaps|googleMaps`, `displayName: String|null`, `formattedAddress: String|null`, `coordinate: PlannerCoordinate|null`, `providerReference: PlannerProviderReference|null`, `uncertaintyReasons: [String]`, `attributionText: String|null`. All candidate descriptive values are temporary held data, not independently owned Item content. `links` and `reuseCandidates` are arrays of these exact values. Preview is `{state, linkId, candidate: PreviewCandidate|null}`.

Native facade preparation methods are `prepareCapture(session:input:) -> DraftRead or Failure`, `updateCapture(session:draftId:generation:edit:) -> DraftRead or Failure`, `lookupCapture(session:draftId:generation:linkId:) -> DraftRead or Failure`, `readCapture(session:draftId:) -> DraftRead or Failure`, and `cancelCapture(session:draftId:generation:) -> CaptureCancelResult or Failure`. They are async and return immutable Sendable values. PlannerCaptureEdit contains the typed Item changes plus remove/retry input-index sets. CaptureCancelResult is `{state: "cancelled"}` or `{state: "notCancellable", operationId: UUID}` when an existing saving operation must instead be resolved. These helpers prepare transient values; only reviewed execute applies domain data.

InputIssue has `inputIndex: Int64String`, `lane: "url"|"text"|"mapItem"|"unsupported"`, `state: "failed"|"oversized"|"unsupported"|"held"`, `message`, `blocksSave: Bool`. Accepted Q16 limits are enforced before claiming complete preparation. Failed/oversized supported lanes block Add until explicit removal/retry; unsupported/held values are reported. Preview has `state: "notRequested"|"loading"|"available"|"unavailable"`, `linkId: UUID|null`, and transient provider candidate data when available. It is never an owned saved location/content field.

`planner_update_capture` takes `{draftId, generation, changes: ItemContentPatch, removeInputIndexes: [Int64String], retryInputIndexes: [Int64String]}` and returns the new immutable draft read. Collections default empty; changes may be empty when an input action exists. Core applies explicit field edits/classification, not a writable origin flag; preview acceptance alone cannot promote held values. Original links remain exact. Changed input invalidates pending lookup/review; native saving disables repeated Add/Cancel until the operation settles.

`planner_lookup_capture` takes `{draftId, generation, linkId}` for the explicitly selected Maps original and returns its draft/preview observation. HTTPS documented-host/hop/time/size rules from Q18/Q19 apply. It does not block ordinary Add, fetch ordinary page bodies or retry automatically. Late results cannot mutate a changed/discarded/saved draft. `planner_read_capture` takes `{draftId}`; `planner_cancel_capture` takes `{draftId, generation}` and discards only a still-unsaved preparation. Neither is source Delete. An in-flight applied operation is resolved through operation status, never undone by canceling preparation.

CaptureChoice is `{kind: "createNew"}` or `{kind: "reuse", itemId: UUID}`. `applyCapture` uses required review and exact draft generation. Review returns the proposed new content or precise missing-link/membership additions to existing X. Reuse never overwrites existing title/notes/location/completion/archive or resets an existing local context. Multiple exact-original-URL candidates require explicit chosen UUID; names do not resolve ambiguity. Create new remains available and retains the edited draft. Archived/deleted targets or changed account refresh review rather than silently retargeting/recreating.

## Native status and administration

The portable contract specifies data-only export, immutable import validation, review/apply and separate recovery inspection/restore. None is an MCP tool or App Intent. `retryRecovery` remains Core checkpoint work, not reexecution of a command.

Native `Planner.changes` observations carry typed `dataChanged`, `recoveryStatusChanged`, `accountStatusChanged` or `cloudActivityChanged` payloads in the validated dataset session. DataChanged requires rerunning canonical queries. Core's native status read contains last acknowledged checkpoint generation or known applied/recovery-incomplete operation evidence. A native editor additionally knows its own unsaved draft/in-flight operation. Its presentation combines those facts into `unsaved`, `saving`, `savedOnThisDevice(checkpointGeneration)` or `appliedRecoveryIncomplete(operationId, reason)`. Core cannot infer every editor's unsaved text from store events. Only complete durable independent recovery authorizes savedOnThisDevice.

Account observation is `available`, `unavailable(reason)` or `unknown`; it does not expose account credentials. Cloud activity is store-scoped `unknown`, `idle`, `inProgress` or `error(reason)` with optional observed event identity/date. Native event reason is generic unless established; an observed completed event can return to idle but never means every save uploaded or all devices current. No Sync now button or completion deadline is added. Core's current status read is a native `read` status request over these same observations, not a second business service. Ordinary MCP operation-status calls return their local outcome; they do not grant account-recovery administration.

The native status request is `{kind: "status"}` through `Planner.read(session:request:)`. It is absent from the MCP read union. NativeStatusRead has `recovery`, `account`, `cloud`. RecoveryObservation is `{state: "known", checkpointGeneration: CountString|null, incompleteOperationIds: [UUID], mutationBlocked: Bool}` or `{state: "unavailable", reason: Failure}`. AccountObservation is `{state: "available"|"unknown", reason: null}` or unavailable with a Failure. CloudObservation has exactly `state`, `storeIdentity: String|null`, `eventId: String|null`, `observedAt: DateNumber|null`, `reason: Failure|null`. Unknown context has null identifiers/date; only observed matching-store activity has a store binding, and error has a useful reason without guessed cause.

Each `PlannerChange` has `notificationId: UUID` and one payload: `dataChanged {affected: [SourceReference or ReferenceRead]|null}`, `recoveryStatusChanged {value: RecoveryObservation}`, `accountStatusChanged {value: AccountObservation}`, or `cloudActivityChanged {value: CloudObservation}`. Null affected identities mean unknown affected records, so rerun relevant canonical queries; no query generation or cloud freshness is fabricated. Account/store ownership is validated before publishing these scoped values. Unrelated-store events cannot update the dataset projection.

## Required /tdd and other evidence

The [operation expectations](fixtures/adapter-operation-expectations-v1.json), [three Schedule hash vectors](fixtures/schedule-field-hashes-v1.json), existing search/progress/scheduling fixtures, seven notes and six compound hash vectors are independent expected inputs/results. New identity generation is checked through public result binding and replay equality, not test-only UUID injection. Transport decoding is verified against the typed request handed to the real facade; parity asserts observable state/outcomes, not an internal call count.

- Decode every command/query/read/appearance variant and reject wrong enum/property/type/path before any write. Native UUID case variants and canonical Int64 extremes round-trip; malformed or overflowing values fail. Compound patches include all declared nested fields.
- Create/replay, stale edited/unrelated fields, global/local precedence, repeated appearances, bulk stale review, all-or-nothing precommit failure and applied-incomplete checkpoint observations use real disposable stores and reopen.
- Query exact accepted identity sequences, catalogs with duplicate label names, complete result generations and stale row-window failure. Hidden/archived progress and unresolved references differ from empty reads.
- Schedule read/edit/zone guards retain exact native values; independent civil/DST fixtures and physical calendar controls still apply. Hash version 1 byte layout is unchanged.
- Capture typed provider lanes, limits, Unicode/order, held versus owned content, reuse, stale targets and operation interruption use genuine external I/O mocks plus actual OS 27 app/Share execution.
- Default MCP rejects direct/indirect source Delete and administration while permitting ordinary association/Schedule removal. Intents use system bulk confirmation and native capture review; canceled confirmation changes nothing.
- Native status fixtures include no-change export, overlapping saves, unrelated-store events, unknown error cause, account transitions and relaunch. No false uploaded/all-current claim is permitted.
- Qualify the official SDK and accepted Q32 reader in all four real clients, including initialization/request-ID collision, Stop/quit, locked Keychain and reader output. Documentation does not count as these tests.

## Definition of ready and done

- [x] Accepted A21/A22 facade and Q1-Q30/Q32 behavior carry forward; Q31 is not reopened.
- [x] Concrete command/query/read/result/capture/status forms and derivative native counterparts are declared.
- [x] [Native portable/recovery forms](portable-data-contract.md) and independent whole-backup fixture are linked with this packet; document checks are recorded in its publication comment.
- [x] Human accepts the complete contract under Q33 A; prior approval carries forward and new changed declarations require review before their tests.
- [x] Reconcile requested changes, publish verified source/ticket pointers and close the contract ticket only when its applicable criteria pass.

Runnable configuration, Swift 6 compilation, affected-target lint, unit/store/UI/device/client execution and discovery/executed counts belong to the prototype tickets. Follow `/tdd` one failing independently specified behavior and its minimum implementation at a time; mock actual I/O and do not add production test seams.
