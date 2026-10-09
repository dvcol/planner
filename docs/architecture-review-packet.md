# Architecture review packet

Approved architecture boundary for [Core architecture](https://github.com/dvcol/planner/issues/12). The human accepted A1-A20 and explicitly approved A21/A22 on 2026-10-08. Read this packet with the [blueprint](architecture-blueprint.md), [decision record](core-architecture.md) and linked behavior fixtures. The public field/method shapes, native schema/reference/value design and recovery candidate are approved for feasibility prototypes. They have not been compiled or demonstrated at runtime.

## Context, starting state and expected end

Planner currently has planning documents and verified platform facts, without a runnable project. The product outcomes are accepted. This packet names concrete public inputs/outputs, reference ownership, native value validation and prototype responsibilities so implementation does not invent another completion or recovery model.

The approval settles this architecture for feasibility prototypes. It does not establish runtime success. [Shared command contracts](https://github.com/dvcol/planner/issues/13) still owns exact transport forms, permissions, capture decoding/network limits and versioned JSON grammar. Native project commands and signing inputs are in the blueprint; runnable configuration arrives with code-producing prototypes.

## One shared implementation

Use one `PlannerCore` library and one public `Planner` facade. Its command/query/portability/recovery methods share the same implementation owner. Keep SwiftData models and contexts private. Native adapters exchange immutable Sendable values and Planner-owned UUIDs; they cannot mutate a model or save through SwiftUI autosave. No generic repository per entity, test-only dependency parameter or independent business-rule implementation is required.

Approved project paths are `Planner.xcodeproj`, `Packages/PlannerCore/Package.swift`, `Planner/`, `PlannerShareMobile/`, `PlannerShareMac/` and `PlannerUITests/`. Core source and test folders belong to the package. Shared schemes are `Planner`, `PlannerShareMobile`, `PlannerShareMac` and `PlannerCore`. The app embeds only its platform's Share product. Configuration explicitly supplies App Group, CloudKit container/environment and signing values from Apple test access; no identifiers are invented.

A command owner exists per process. It uses an isolated ModelContext with autosave disabled and a cross-process gate for participating app/Share writers. Actor isolation alone is insufficient. Native observation triggers canonical Core queries; adapters only present the returned meanings.

Use native UserDefaults for device presentation preferences. Sort keys include dataset/account and stable view/List identity; calendar display-zone override remains per device. Capture remembers successful destinations separately per entry point and validates their recorded dataset/target binding under C4/C15. These values do not enter shared SwiftData data or portable backups. A18's domain mutation block still permits search/sort/display controls.

## Public values and request fields

These named values are the approved concrete enum/struct shapes. Their transport encoding is downstream work, not an untyped dictionary in Core.

| Value | Required fields and cases |
| --- | --- |
| `PlannerDatasetSession` | Dataset UUID, session UUID and opaque ownership/epoch binding validated by Core. A session closes on an observed account/store ownership transition. Adapters do not select accounts by changing a field. |
| `PlannerEntityReference` | Entity kind and Planner UUID, bound to the current authorized lifetime by Core validation. Portable identities are independent of SwiftData PersistentIdentifier. |
| `PlannerAppearanceID` | `listMembership(listID, membershipID)`, `directItineraryItem(itineraryID, entryID)` or `expandedListItem(itineraryID, listEntryID, membershipID)`. Core also validates source/owner lifetimes. A source Item UUID is never interchangeable with this value. |
| `PlannerCompletionScope` | `globalItem(itemID)` or `appearance(appearanceID)`. Native List/Itinerary actions use appearance/container scope; there is no fallback to global scope. |
| `PlannerOperation` | Operation UUID, dataset session, typed `PlannerCommand`, optional Core-issued `PlannerReviewToken`. Retry of a known operation retains identical payload/binding. A modified draft gets a fresh operation after review. |
| `PlannerReviewToken` | Review UUID, dataset/session binding, canonical payload digest, exact target identities/lifetimes and impact/target-set revision. Core issues and validates it. Changed targets/payload/session require fresh review. |
| `PlannerOperationResult` | Operation UUID; `rejected(reason)`, `applied(result, recovery)` or `unverified(proposal)`. `applied` contains stable result references, affected identities and the checkpoint generation when complete. Recovery is `complete` or `incomplete(reason)`. Only complete recovery permits the R21 success acknowledgement. |
| `PlannerOperationStatus` | `knownUnapplied`, `preparedUnverified`, `appliedRecoveryIncomplete`, `appliedRecoveryComplete`, `noReliableEvidence` or `unavailable(reason)`, with the original operation/session/result evidence where known. Missing/read-failed receipts never imply rollback. |
| `PlannerRecoveryProposal` | Proposal UUID, original operation UUID, recorded dataset, proposed values/identities/lifetimes, evidence state and required fresh review. It is separate from acknowledged saved data. |
| `PlannerFieldChange` | `unchanged`, `set(value)` or `clear`. Clear is valid only for optional fields; absence from an edit never silently clears a value. Exact concrete field types are listed below. |

A rejected changed-payload replay describes this attempt only. It does not rewrite an earlier accepted operation as unapplied. Surface permissions still apply before direct or import-triggered deletion; a review token does not enlarge an MCP session's authority.

## Facade method shapes

Methods are asynchronous across the public actor boundary. Expected command failures return structured outcomes; observation/read failures remain distinguishable from an empty result. These shapes were approved in A21; they are not compiled Swift source.

| Method | Input | Output and responsibility |
| --- | --- | --- |
| `prepareReview` | Dataset session and typed command. | Immutable preview and review token, or typed rejection. Compute full-context targets from canonical data, ignoring UI filters. Import previews include skipped owners, replacements, restored IDs and incoming deletions. No domain mutation. |
| `execute` | `PlannerOperation`. | `PlannerOperationResult`. Validate binding, review, targets and replay; commit the complete local action, then establish independent recovery. |
| `operationStatus` | Dataset session and operation UUID. | `PlannerOperationStatus`; no mutation or inference from receipt absence. |
| `retryRecovery` | Dataset session and known-applied operation UUID. | Updated result/status after checkpoint work only. Never reexecute the command. |
| `query` | `PlannerQuery`. | `PlannerQuerySnapshot` or typed failure. Include complete ordered lightweight identities and full-scope progress, including matches beyond the first window. |
| `read` | Dataset session and source, appearance or snapshot-row-range request. | Immutable source/appearance/row values, missing-reference explanation, stale-snapshot result or read failure. Valid filtered-out selection remains readable. |
| `changes` | Dataset session. | Cancellable stream of dataset-bound change notifications. Consumers rerun canonical queries and discard obsolete query/session generations. No notification means every device is current. |
| `decodeImport` | Versioned data bytes. | Validated immutable backup or whole-file validation error. It makes no partial mutation and has no presentation state. The decoded value is used by import review/execute. |
| `exportData` | Dataset session. | Versioned portable data including A16 deletion metadata, or export failure. Reads remain available during incomplete recovery. |
| `inspectRecovery` | Existing local recovery namespace/proposal identity. | Read/export view with recorded ownership and evidence. Restoring/retrying a proposal uses a fresh reviewed import/recovery command to the explicitly selected dataset. |

Bootstrap returns `ready(session)`, `mainAppSetupRequired`, `mainAppMigrationRequired` or `unavailable(reason)`. The main app initializes/migrates; Share never does so independently. Store opening/configuration accepts real deployment/storage configuration, not test-only callbacks. Temporary real local stores are a legitimate configuration for feasibility work.

## Typed commands and queries

| Command family | Exact scope and required input |
| --- | --- |
| Create/edit source | Item/List/Itinerary identity or new source input. Item edits explicitly change title, optional subtitle, notes, owned links/location, estimate and Category/Tag associations. Container edits change its own metadata/labels. Global completion/archive use their separate commands. Creation generates stable IDs once per operation. |
| Completion | Set Done/Todo for a `PlannerCompletionScope`. Bulk sets local child completion for a List, Itinerary or itinerary List entry using a confirmed full target set. Empty containers stay No items; global source Done may still override local Todo display. |
| Archive/Delete | Archive/Unarchive Item, List or Itinerary. Delete supplies selected entity and confirmed impact. Container deletion preserves source Items/Lists; Item deletion removes its references/schedules. Referenced-label deletion follows R7 confirmation. No Trash or automatic expiry. |
| Organize | Add/remove/move an Item membership with explicit destination/order placement; add/reorder/remove Item/List itinerary entries. Replay of one addition retains one result; intentional repeated itinerary additions create distinct entries. Reorder retains identity/local states. |
| Labels | Create/edit Category or Tag; delete a selected shared label with required review. Duplicate names retain distinct IDs; rename never copies or fans out owner Item timestamps. |
| Schedule | Create/edit/remove an Item/Itinerary Schedule using the native forms below. Zone-only edit preserves both instants. Deletion preserves other Schedules and the source. |
| Capture | Commit the reviewed create/reuse choice, accepted independent content/origins, original links and selected List IDs. Provider previews never become persisted Item fields. Reuse adds reviewed missing links/memberships without overwriting existing source/global/archive/local state. Capture decoding/lookup is a Core-owned I/O responsibility; exact limits are confirmed in contracts. |
| Import/recovery | Apply a validated immutable backup using Skip or Overwrite and its exact review. Restore deleted IDs/incoming deletion require identified impact. Known-applied checkpoint retry is not this command; unverified proposal retry gets a new reviewed operation. |

`PlannerQuery` contains dataset session; global/Inbox/List/Itinerary scope; text; completion/archive choices; Category/Tag/List identity groups with Any/All; optional inclusive estimate bound plus Include unknown; scheduled/unscheduled choice; sort mode and direction. Enabled groups narrow cumulatively. Global Item queries use global completion; contextual queries use effective global OR local completion. Default scopes, matching fields and every sort mode follow the accepted search fixtures, without inventing an itinerary Manual-sort policy from an Item-list query.

Q43 A adds optional `rowPresentation: PlannerRowPresentationContext` to Item queries. It contains finite `referenceInstant: Date` and a valid `displayTimeZone: String`; Core captures an omitted default once per generation. Item snapshots and row-window reads return that same resolved context; catalogs return nil. The [native/wire row declaration](adapter-contract.md#row-presentation-context-and-schedule-summary) is authoritative for the context, typed Schedule summary and no-I/O projection. These are read/presentation values, excluded from stored Planner content and backups.

`PlannerQuerySnapshot` contains session, query generation UUID, ordered lightweight source/appearance identities, matching count, unresolved reference identities and separate complete-scope container progress. Item queries do not duplicate a shared source because it has several memberships. Itinerary queries preserve intentional appearances. Progress counts all contextual child appearances, including hidden/archived ones, rather than the currently filtered row count. If native delivery leaves required references unresolved, progress is temporarily incomplete rather than falsely completed or No items. This describes the local graph, not the latest state of every cloud peer.

Snapshot row requests specify generation and range. Native batching/lazy row realization avoids retaining all detail content. A changed generation returns stale snapshot rather than mixing windows; rerun the query and retain valid selection/scroll anchor. Task cancellation cannot promise interruption of synchronous I/O, so old output is discarded. Complete identity discovery, row realization and 300 ms responsiveness remain measured gates.

Accepted Q43 keeps `PlannerRowRead` at this existing public query/read boundary and adds `ownedLocation: PlannerOwnedLocation?`, `previewLink: PlannerOwnedLinkRead?` and `scheduleSummary: PlannerRowScheduleSummary`. The Sendable summary cases are none, directItem and itinerarySpan with one Schedule reference/owner/form/additional count, inScheduledPlan, and unresolved with required reference identities. No full notes/link collection/hash map or fetched provider data is loaded per row. Q45 selects ongoing, next future, then latest past within the appropriate owner pool; Q46 chooses one non-Maps website bookmark in saved order. Q44 keeps a globally Done contextual circle disabled without changing local flags. These are accepted declarations with [literal test obligations](navigation-row-contract-review.md#literal-beforeactionafter-expectations), not runtime qualification of the limited Core implementation.

## Native value validation

| Value | Representation and exact validation |
| --- | --- |
| Estimate | Optional positive Int64 whole minutes plus retained minute/hour/day/week/month/year unit. Use the accepted fixed conversions and checked arithmetic. Zero, negatives, fractional input or overflow reject without mutation. No estimate explicitly clears it. Int64 capacity is representability, not a new practical duration/picker cap. |
| Saved order | Signed Int64 scalar rank and immutable association/entry UUID tie ascending. Use checked arithmetic; rebalance ranks before overflow/gap exhaustion, retaining all identities/states. Descending presentation sort never rewrites saved Manual ranks. |
| Timed Schedule | Finite Date start, optional finite strictly-later Date end, valid planning-zone identifier. Local picker components resolve with full selected Gregorian date/time, strict gap rejection and explicit earlier/later repeated occurrence. Round-trip components to reject silent normalization or a match on a later date. Zone-only edit changes the identifier, never instants. |
| All-day Schedule | Valid Gregorian year/month/day, optional end not earlier than start. Retain inclusive civil dates without a midnight/timezone conversion. Validate native construction and exact component round-trip; no arbitrary supported-year interval is introduced. |
| Own coordinates | Finite Double latitude -90 through 90 and longitude -180 through 180, supplied together. Native coordinate validation plus explicit finite checks; invalid input is rejected, never clamped. Provider ambiguity retains the original link without guessing. |
| Original bookmark | Preserve supplied String; parsed request URL is separate. Exact permitted input/redirect schemes, provider hosts, size/hop/time budgets and malformed transport behavior are contract decisions. No fetch of ordinary page content. |
| Text/IDs | Preserve user text and Planner UUIDs; use accepted fixed-locale native comparison. No arbitrary character or planner-count cap is added. 5,000 Items/200 Lists is an acceptance dataset, not a storage limit. |

Native validation facts are grounded in Apple's [coordinate validity API](https://developer.apple.com/documentation/corelocation/cllocationcoordinate2disvalid(_:)) and [Calendar matching policies](https://developer.apple.com/documentation/foundation/calendar/dates(byMatching:startingAt:in:matchingPolicy:repeatedTimePolicy:direction:)). Full-component round-trip validation is the approved application rule that preserves the accepted gap/repeat outcomes; it is not a claim that native strict searching alone enforces them.

Contracts must define exact large-integer/date/coordinate encoding without precision loss, field/version grammar and bounded input/network loading. Navigation defines practical native picker interactions. These assignments are gates, not permission to leave validation implicit in code.

## Versioned schema and reference ownership

Use VersionedSchema from the first persisted version. Source defaults are empty optional metadata, false completion/archive and explicit initialization of IDs/timestamps by validated creation. Cloud-compatible storage fields have defaults or are optional. Partial cloud records are not new authorized entities; domain validation requires their identities/bindings before actions or complete logical export. An unresolved local graph produces a typed export failure instead of a silently shortened full backup.

The blueprint's source, membership, entry, Schedule, label/link, deletion and receipt records remain the base. Explicit UUID/lifetime bindings govern logical identity. Approved native traversal relationships are optional with the named inverses below, nullify deletion rules and no `.deny`/unique/ordered constraints. Inverse collections default nil and remain unordered; scalar ranks define order. Commands explicitly remove owned associations without cascading into shared sources. Relationship delivery is non-atomic, so a temporarily missing relationship never authorizes recreation or deletion.

| Record | Storage fields/defaults and optional relationship inverses |
| --- | --- |
| Item/List/Itinerary/Category/Tag | Logical UUID and lifetime UUID optional/nil until validated creation; title/name empty String; optional notes/color/icon nil; created/updated Date nil until assigned; archive/global Done false where applicable. No stored List/Itinerary completion. |
| Membership | Association UUID, owner/source UUID/lifetime bindings optional/nil until assigned; rank zero; local state Todo. `list` inverse `List.memberships`, `item` inverse `Item.memberships`. Domain creation assigns required bindings before commit. |
| Itinerary entry | Entry UUID, owner/source bindings and source-kind scalar; rank zero, direct local state Todo. `itinerary` inverse `Itinerary.entries`, `itemSource` inverse `Item.itineraryEntries`, `listSource` inverse `List.itineraryEntries`. Exactly one valid source kind/binding. |
| Expanded completion | Context key/bindings, local Todo and required reconciliation provenance. `listEntry` inverse `ItineraryEntry.expandedCompletions`, `membership` inverse `Membership.expandedCompletions`. Missing local state means Todo, without copying source completion. |
| Schedule | UUID/lifetime/target binding and explicit form; optional Date endpoints/planning-zone or civil components nil until valid form assignment. `item` inverse `Item.schedules`, `itinerary` inverse `Itinerary.schedules`. Exactly one source and one accepted form. |
| Label association | UUID/lifetime, owner/label kind and UUID/lifetime bindings. `itemOwner`/`itineraryOwner` inverses to owner `labelAssociations`; `category`/`tag` inverses to label `associations`. Exactly one owner and label binding. |
| Owned Link | UUID, owner binding, original String, optional label/allowed provider-reference fields, scalar rank. `itemOwner`/`itineraryOwner` inverses to owner `links`. One valid owner; provider previews absent. |
| Deletion, alias and completion provenance | Typed entity/context/family UUIDs, closed predecessor/alias/change identities and minimal scalar state. Nil/uninitialized metadata never authorizes an identity. No deleted content or reference to a mutable source as the sole deletion evidence. |
| Internal receipt | Operation UUID, payload digest, immutable dataset/ownership binding, result IDs/lifetimes, state and checkpoint generation. No portable relationship or raw capture content required. |

UUID collections/provenance have a validated versioned storage representation supported by the installed framework. Do not assume an unsupported CloudKit transformable or unordered native relationship defines a causal set. The prototype verifies field support and exact reopen/merge behavior; contracts define portable encoding.

Each membership owns standalone local completion/order. Each direct itinerary entry owns its local completion/order. An expanded child context is keyed by List-entry lifetime plus membership lifetime. Categories/Tags are shared records; owned Links belong to an Item/Itinerary. Source deletion closes the selected logical lifetime and cleans its owned references; container deletion closes only its container/associations. Marker records never store deleted content.

A17 adds narrowly scoped duplicate-context provenance. Preserve immutable initial completion contributions per alias and explicit completion-change identities/observed predecessor changes. Initial duplicate contributions consolidate with OR until a canonical explicit override supersedes them. Thereafter initial contributions, including previously unseen late aliases, do not participate. Later Complete/Reopen commands are explicit changes, never reclassified as seeds. Causally later changes supersede observed predecessors; incomparable changes across physical duplicates use a stable change-UUID tie. Native winning remains applicable to edits of the same actual record. This candidate is not a general replication framework or proof of convergence.

A20 adds restoration-family/predecessor binding and distinct candidate identity. Approved candidates restoring the same closed predecessor resolve to one deterministic initial candidate by stable UUID. References authorized by either restore resolve within that family; old predecessor references receive no redirect. Subsequent Delete closes the entire family, including late losing candidates. A later reviewed restoration creates a new authorized family. Independent imported entities and their owned state are not winner-selected alongside X.

Portable data includes the necessary completion/reference/deletion lineage to preserve accepted user state, with no operation receipts, account tokens or deleted content. Internal recovery retains minimal replay receipts and ownership/checkpoint metadata separately. Exact encoded fields and schema migration forms are contracts work.

Use additive CloudKit-compatible evolution and a main-app-owned SchemaMigrationPlan. Old-store fixtures and skipped-version upgrades must preserve IDs, native values, live references, order, local states and deletion lineage. Production schema publication requires the actual entitlement/container setup and verified migration evidence; this packet does not deploy a schema.

## Writer and recovery sequence

1. Resolve account observations outside the coordinated section. Bind draft/review to an immutable dataset session; no network request runs while holding the Planner writer gate.
2. Coordinate a write on the stable App Group control URL. Reload initialization/schema/account epoch, reject stale sessions and enforce A18's affected-dataset mutation block.
3. Use a fresh isolated context with autosave disabled. Validate operation/payload replay, review, exact target set, source/reference lifetimes and surface authorization.
4. Construct an immutable ownership-verified proposal and preserve it independently before domain commit. Prepared evidence is not acknowledged saved data.
5. Commit the complete domain action and minimal operation receipt together. Genuine validation/database failure leaves the action unapplied and unrelated drafts untouched.
6. Publish a complete independent logical recovery envelope with ownership, schema, generation, digest and completed receipt evidence. Only then report R21 success.
7. After commit plus archive failure, retain the complete action, report recovery incomplete, block further dataset mutations and retry only the checkpoint. Reads/search/export remain available.
8. On reopen, resolve surviving evidence. A database receipt alone means applied/recovery-incomplete. An independent completed receipt survives mirror reset in its recorded namespace. A prepared-only proposal without committed evidence is unverified and requires fresh review.
9. On account transition/mismatch, close the old session and retain its separate recovery envelope. Never automatically copy it into another account's active mirror.

The gate coordinates participating Planner writers, not Apple's account/reset/mirroring operations. Account notifications/history/store identifiers alone do not prove coherent snapshot ownership. The prototype must establish a consistent cutoff and immutable ownership during native imports/resets. If it cannot, preserve the previous good envelope, withhold success and reconsider architecture with evidence. No silent switch to a custom bridge or weakened save guarantee is approved.

## Definition of ready and required /tdd evidence

- [x] Accepted A1-A20 supply the product outcomes; named architecture blockers are closed.
- [x] Human explicitly approved the public boundary and schema/ownership packet through A21/A22 before code tests.
- [ ] Each prototype compiles its slice of the approved declarations and uses exact fixture inputs; contracts supply applicable transport/loader/network limits. Unchanged public approval carries forward; only changed boundaries require renewed review.
- [ ] Signed CloudKit/Share work has its Apple test-access prerequisites; local UI/domain work can use disposable native stores.

| Boundary and level | Required independent expected outcome |
| --- | --- |
| Command/query unit and real-store reopen | Hotel/Museum local Done is 1 of 3; global Hotel Done is 2 of 3; global Reopen reveals retained local flags. Repeated List fixture goes 1 of 10 to 1 of 12 after source membership addition. Hidden/archived contexts participate in bulk/progress. |
| Native comparison/query/store/UI | Exact search identity sequences under French/English/Turkish settings. Complete 5,000-Item/200-List results, including beyond the first window, with no omissions/duplicates and current results within 300 ms. Stale generations never publish; valid filtered-out details remain selected. |
| Portability unit/store | Exact Skip/Overwrite owner results; complete-owner dependency skips; invalid file rejects together; reimport has no duplicates; omitted sources survive. Restoring post-deletion backup then skipping older X retains deletion. Incoming Delete requires reviewed impact. |
| Duplicate-context store/physical | Done/Todo aliases yield one Done context. Reopen yields Todo after relaunch. Deliver previously unseen initial aliases after Reopen; none reasserts Done. Test independent consolidation, explicit competing toggles and operation replay without unrelated changes. |
| Restoration store/physical | Two approved restored X versions converge to one X while independent imports and authorized references survive. Old references never return. Delete restored X, then deliver an unknown losing candidate: X stays deleted. Reviewed later restoration still works. Both reconnect orders. |
| Save/recovery integration and host-closed Share | Inject genuine precommit failure versus postcommit archive failure separately. Former leaves zero changes; latter retains the entire action, blocks next dataset mutation and retries recovery without duplicate capture. Test concurrent app/Share writers and every preparation/commit/archive/receipt interruption. |
| Account-reset physical | Preserve acknowledged old-account data independently. Prepared-only lost-evidence outcome stays unverified; fresh reviewed retry has a new operation. No old-account automatic upload to new account and no new-account data in old archive. Large complete snapshots must fit actual extension lifecycle constraints. |
| Native date unit/store/UI | Accepted inclusive dates, fixed Tokyo/Paris instants, missing-time rejection, explicit repeated occurrence and coupled-endpoint validation. No guessed end, silent normalization or zone-only rescheduling. |
| Migration/native build/adapters | Commit runnable native project/package/schemes and correct embedded Share products. Focused compile/lint/unit/store/UI checks pass. Old/skipped-version fixtures preserve exact identities/state. Allowed adapters agree on Core outcomes; surface permissions can differ. |

Use /tdd one independently specified failing behavior and its minimum passing implementation per cycle. Mock actual external I/O boundaries and use real disposable stores. Record red/green, focused commands, discovered/executed counts, result artifacts, SDK/device versions and limitations. Declaration compilation uses the selected SDK and Swift 6 complete concurrency checks after approval; documentation does not substitute for compilation.

## Definition of done for this review

- [x] Human accepted the concrete packet, public scopes/outcomes and narrow reconciliation candidate through A21/A22.
- [x] Architecture record links this packet, accepted decision record, blueprint/build commands and exact downstream evidence owners.
- [x] Original ticket context remains intact; failed feasibility gates reopen the relevant design with evidence.

Tracker completion publishes/verifies the resolution, closes Core architecture and appends its named pointer to the map. Its completion evidence lives on the canonical ticket and map rather than being confused with completed runtime tests here.

A21 approved the facade/request/result/query/window and review/cancellation boundary. A22 approved native values, versioned references/provenance, process ownership and the recovery candidate. Documentation lint, local links/newlines, whitespace and publication readback are the applicable checks for this decision; runtime results and declaration compilation remain prototype work.
