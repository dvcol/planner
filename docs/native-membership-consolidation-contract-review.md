# Native membership consolidation contract

Status: proposed for Q155 review, 24 October 2026. Q153 A and Q154 A are accepted. This document declares the next implementation and existing test seams; it supplies no executed implementation evidence. Signing stays deferred.

## Scope and shared interface

Implement one canonical membership/context resolver and coordinated maintenance path behind existing Core bootstrap, query/read, Map rows, export, review and command interfaces. Native views, Share and agents consume those same results. Status/recovery inspection and historical operation replay do not trigger normalization. A no-op scan writes nothing and publishes no checkpoint. No new package, target, agent administration command or production test hook is proposed.

The [retained real-store failure](prototypes/native-membership-consolidation-readiness.md) is the first tracer. Two native memberships for one exact Item/List lifetime pair must yield one contextual appearance, with accepted completion history, rather than readUnavailable. This contract does not implement general incoming restoration-family adoption or claim live CloudKit convergence.

## Minimal portable provenance

Portable version 3 retains every version-2 field and adds two required root arrays. Empty arrays are valid; unknown fields and malformed records reject with their actual JSON Pointer paths. Continue accepting versions 1 and 2, preserving their original format/absence information through decode, preview and replay.

| Array | Exact record fields |
| --- | --- |
| membershipProvenance | membershipId: UUID, membershipLifetimeId: UUID, list: BoundSource of kind list, item: BoundSource of kind item, observedRemovalIds: UUID set. |
| membershipRemovals | deletionId: UUID, referencing an existing membership-target deletion marker. |

The targeted membership's retained provenance supplies a strict removal's exact pair. A recovered old binding never turns an old marker into a new strict removal. A new user removal records the ordinary closure, retained pair binding and strict declaration together. This includes Move's source removal and an explicitly reviewed Overwrite that removes a current membership while its sources survive. Container/source deletion retains its existing closure semantics and exact historical bindings; it does not invent a user Remove of another live pair.

A live membership with no explicit provenance supplies its actual binding and an empty attested removal set. Empty means no retained positive observations, not a claim about an old writer's knowledge. Explicit provenance is required when its basis is nonempty or its binding must survive removal/alias retirement. It contains no title, notes, rank, completion copy or extra generation UUID. Original identity/lifetime closure still wins independently of pair eligibility.

Ordinary Add records every currently known strict removal for that exact Item/List lifetime pair and starts Todo. A contribution is eligible only when it observes every known applicable strict removal. Validate every observed ID against a declared strict removal for that pair. Unknown endpoints, conflicting immutable bindings, duplicate provenance keys, cross-pair claims and causal cycles reject. Partial native relationship delivery remains unresolved; it never authorizes deletion or invented bindings.

## Canonical identity, order and completion

Apply eligibility before alias/completion reconciliation. Group eligible contributions by exact Item/List lifetimes and their normalized removal basis. That basis defines the generation. Root baseline contributions have an empty basis; suppressed generations never redirect into an informed re-add.

Choose the smallest eligible membership UUID as canonical and retain that record's rank. Existing rank/UUID ordering handles the containing List. Physically duplicated copies of one membership identity/lifetime must agree on immutable bindings; use the lowest supplied rank among those copies and reconcile completion separately. Different lifetimes sharing one public membership identity must first satisfy existing closure/restoration authority; this contract does not choose between unproven competing lifetimes. A single native record retains the values Apple supplies. No membership addition is discarded merely because rank ties or a competing reorder exists.

Retain losing bindings and original contexts before retiring physical duplicates. Retirement creates aliases, not a user Remove marker or strict barrier. A later copy of a retired member is reconciled idempotently, not treated as a new addition. Exact old membership identities resolve only within their proven eligible pair/generation. They cannot select a new ordinary re-add or a global Item action. If a smaller eligible UUID arrives later, normalize alias roots consistently before history comparison; preserve original context, initial contribution and explicit-change identities.

Reuse accepted A17 completion semantics: initial contributions combine with OR; explicit Complete/Reopen supersedes initial contributions, including late seeds. Causally later changes supersede observed predecessors; incomparable changes across aliases use the existing stable change-UUID winner. Never infer an explicit change from a scalar flag. For physical duplicate completion rows without their own record UUID, stable initial seed aliases derive from the exact original context and initial Bool. Use the existing SHA-256/tagged-value UUID pattern with domain PlannerInitialCompletionAlias-v1; keep seed identities and initial values immutable. Ordinary explicit changes retain their own saved identities.

Standalone List completion and each exact expanded List-entry lifetime are separate groups. Repeated List entries and direct itinerary appearances retain independent state. Rebinding a losing membership inside one expanded context does not copy standalone completion or another branch's state. Global Done precedence remains unchanged. Consolidation preserves source/container content and user-edit timestamps; it is not a new user edit. Original-association Undo and accepted explicit restoration keep their existing fresh-lifetime authority and saved flags, recording the new lifetime's current strict-removal basis; ordinary Add never becomes Undo.

## Validation, migration and manual import

A canonical full export has one live membership per pair. Historical aliases/changes may resolve through retained provenance after a loser is removed. Closed source lifetimes remain historical bindings, supported by retained closure/family evidence; they are not fabricated live dependencies. Unresolved or contradictory history rejects rather than silently dropping references.

Native schema 19 keeps the frozen V1 through V18 declarations and adds two optional/defaulted models without uniqueness constraints or required relationships:

- MembershipProvenance stores optional membershipId, membershipLifetimeId and recordData. Data encodes the exact portable provenance record; decoded identities must match the stored composite key. Missing fields mean unresolved delivery, not empty authority.
- MaintenanceCommit stores optional maintenanceId and evidenceData. Its immutable evidence is declared below. Strict membership-removal declarations use the existing typed LineageRecord storage, keyed by their deletionId with a newly declared membershipRemoval kind.

Main app owns the genuine V18 to V19 migration. Share asks to open Planner until setup/migration completes. Publish schema/control metadata only after native migration succeeds; old binaries/sessions must fail the version gate rather than write without provenance. Structural migration and coordinated baseline/recovery establishment are separate steps. Do not rewrite historical receipt results or acknowledged files as if they were new commands.

Q154 preserves current memberships, order, flags and explicit completion history. Backfill old pair bindings only from matching native receipt operation IDs and exact lifetimes. Retain unknown legacy closures as original-ID protection; never infer an observation set or retroactively promote them to strict pair barriers.

Skip retains matching owners' complete contents, order, completion and current provenance. A legacy file lacking new metadata cannot erase already proven metadata for the same member identity/lifetime. Conflicting explicit version-3 bindings/bases reject. Old data with no applicable strict barrier can enter as baseline data. Faithful empty-dataset restore retains represented IDs/state/history.

A different incoming membership behind a post-upgrade strict pair barrier needs a proven causal basis or an already accepted exact restoration path. Bare Overwrite or a missing legacy field supplies neither. Reject the whole selected action, including dependent owners, rather than shorten its contents or stamp invented observations onto it. This contract adds no new authority for ambiguous foreign membership restoration. Existing reviewed restoration families retain their own authorization and state rules.

## Coordinated maintenance and independent recovery

Run admission under the existing control-file coordinator. Canonical bootstrap/reads/export and genuinely new mutations must use the same resolver. Revalidate the dataset/namespace/epoch/ownership and input graph before committing. Historical receipt/preparation lookup comes first for replay; it must not re-resolve the old action against current canonical identities.

A new maintenance attempt has a fresh maintenanceId, separate from all command operation IDs. Persist `maintenance-<id>.json` atomically before native save. Its exact fields are format: planner-maintenance-preparation, formatVersion: 1, maintenanceId, namespaceId, datasetId, epochId, ownershipBinding, kind: membershipConsolidation, ruleVersion: 1, proposedBackup, evidence: preparedUnverified. proposedBackup is the complete validated portable-v3 graph. preparationDigest is sha256: plus the lowercase digest of those exact durable file bytes.

The native MaintenanceCommit evidence has exactly maintenanceId, namespaceId, datasetId, epochId, ownershipBinding, kind, ruleVersion and preparationDigest. Insert it in the same native save as the complete normalized graph. It has no command result, fake operation ID or copied deleted content. Unknown/malformed identity or ownership evidence never authorizes publication.

Recovery envelope version 2 retains its existing root fields and adds required maintenanceReceipts. Each receipt contains the stored maintenance evidence, commitState: applied and its original checkpointGeneration. Version 1 reads as having no maintenance receipts and remains preserved. Continue the existing checkpoint sequence. Carry forward acknowledged command/maintenance entries and each original generation unchanged; a later maintenance checkpoint must not rewrite the generation returned by old command replay.

| Failure/evidence | Required result |
| --- | --- |
| Preparation or native save fails | Roll back the isolated context. No partial alias, closure or completion write. Retain any surviving preparation as unverified. Do not claim the requested user command ran. A graph needing uncommitted maintenance reports maintenanceRequired/readUnavailable, never Saved. |
| Native save commits; independent publication fails | Keep the complete canonical graph and MaintenanceCommit. Reads/search/export of that coherent graph remain available. Report pending maintenance recovery and block new user mutations. A waiting user command remains unapplied. |
| Process dies with only a preparation | No applied claim or checkpoint retry. Reinspect current live data before a new maintenance attempt. Independent use of proposal data requires the existing fresh manual review. |
| Unique native commit matches the durable preparation | Recovery can acknowledge that committed maintenance snapshot without reapplying consolidation. Never regress an acknowledged head or drop later data/evidence. If newer inputs prevent a coherent safe publication, retain incomplete recovery rather than fabricate success. |
| Maintenance already acknowledged | Return its original checkpoint generation; do not publish again. |

Declare native-only retryMaintenanceRecovery(session:maintenanceId:), returning PlannerMaintenanceRecoveryResult.complete(checkpointGeneration: Int64), incomplete(reason: PlannerFailure), or rejected(reason: PlannerFailure). incomplete requires a verified committed maintenance; unknown, foreign, malformed or prepared-only IDs reject. Keep retryRecovery(session:operationId:) for real commands unchanged. Neither method becomes an MCP/Intent administration action.

Extend PlannerRecoveryObservation.known with incompleteMaintenanceIds alongside incompleteOperationIds. Either pending collection blocks mutations. Status reads stay read-only. Uncommitted required maintenance reports unavailable with a maintenanceRequired reason. Extend native recovery inspection with a maintenanceProposal(namespaceId:maintenanceId:) request and separate preparedMaintenance summaries containing maintenanceId, evidence: preparedMaintenanceUnverified and requiresFreshReview: true. Selected data uses the existing selection type with new preparedMaintenanceUnverified evidence and optional maintenanceId; command proposal/originalOperationId are nil. Existing reviewed restore policy remains required. Update native status/retry/copy/selection UI and change-stream recovery invalidations consistently.

## Exact operation replay and fingerprints

Freeze both existing payload-v1 and existing restoration payload-v2 algorithms. Use sha256-payload-v3 for affected new membership commands and portable-v3 graph imports; unrelated commands retain their current fingerprints. Version 3 uses the existing tagged-value encoding and PlannerOperationPayload domain with big-endian version 3. Hash the normalized command, original dataset/ownership/lifetime bindings and resolved membership evidence. That evidence is an ordered-by-binding set of exact membership binding, Item/List bindings and observed strict-removal IDs. New removes capture their original target/basis; new Adds capture their original applicable-removal set. Graph imports include the complete version-3 graph and existing reviewed-current-data inputs.

Keep the Receipt model and old stored bytes unchanged. New affected resultData uses an evidence wrapper version 2 containing the original result, lifetime bindings and resolved membership evidence. Affected prepared-command proposals likewise use a versioned wrapper carrying those original replay inputs. Preserve unversioned legacy evidence and existing result-only fallback for supported old records.

Dispatch replay from saved evidence/prefix before current target resolution. Preserve decoded input format origin so old imports use their frozen legacy encoding, including its original version-2 canonical tag. Actual version-3 metadata cannot be stripped merely to match an old operation ID. Already-applied replay returns the exact recorded identities/result/checkpoint; a prepared-only retry returns unverified evidence, not an applied action. Missing old bindings after reset remain missing; this contract does not reconstruct execution proof from a portable file.

## Literal fixtures and implementation sequence

Use fixed UUID suffixes with independent expected complete graphs. Fresh maintenance/change IDs and timestamps are captured only where the existing contract permits allocation.

| Input/action | Expected outcome |
| --- | --- |
| Hotel X101/I811, Tokyo A201/L821; M401/841 rank1024 Todo and M402/842 rank2048 Done, no strict barrier | One visible M401 at rank1024, local Done, global Todo. Both original bindings and initial contributions remain recoverable. |
| Explicit Reopen C901, then previously unseen initial-Done M403/843 | One Todo context after reopen/relaunch; late seed does not override C901. |
| Remove M401 with D891 declared strict, then unaware M404/844 with empty basis | No visible pair or revived appearance. No source/global changes. |
| Ordinary Add M405/845 observes D891 | One new Todo membership. No old Done, alias or expanded-state inheritance. |
| Two concurrent strict removals D891/D892; new Add observes only D891 | Add remains suppressed after D892 arrives. An informed Add observing both survives Todo. |
| Independent Add to List B202 | Survives; A201's removals do not apply. |
| Same List appears at itinerary entries E451 and E452 | Each branch consolidates only its own expanded contexts; their independent Done states and direct stops remain distinct. |
| Lower eligible M400 arrives later | Canonical identity/rank converges to M400; authorized aliases still resolve within that generation and explicit completion history survives. |
| Legacy unknown marker and current M402 Done | Q154 baseline retains M402 Done and original-ID closure without invented pair/causal history. |
| Legacy Overwrite proposes a different member behind strict D891 without an accepted restoration path | Whole import rejects; no partial owner, provenance erasure or manufactured observed ID. |
| Save obstruction, publication obstruction, process interruption, retry/replay | Observe the failure table through real storage, exact exports and independent recovery; no fake user receipt or duplicate maintenance. |

DoR: approve this concrete contract and retain the existing failing native diagnostic. Then use vertical slices through the existing native fixture/public bootstrap/query/read/execute/export, migration, actual filesystem failure, recovery and real MCP HTTP seams. No new direct internal test seam is requested. Freeze literal version-3 portable/envelope/fingerprint byte fixtures independently before their implementation tests.

DoD for the local slice includes exact List/Map/appearance reads, source/global/local timestamps, unrelated data preservation, Move/removal/bulk/Undo paths, old v1/v2 replay, full v3 round-trip/import, real V18/skipped migration and Share refusal, recovery admission/retry, independent-writer notifications and native refresh, with affected formatting/compiler checks. Source models V1 through V18 and old acknowledged files stay unchanged. Actual signed/shared storage, CloudKit partial delivery/convergence, physical memory/interruption and external Mac UI remain separate required gates; local compilation does not qualify them.
