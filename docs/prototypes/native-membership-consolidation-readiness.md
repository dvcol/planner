# Native membership consolidation readiness

## Question and approved boundary

Can the accepted one-membership/local-completion behavior handle actual native duplicate relationship records before CloudKit signing is available?

A17/A21/A22 already approve the native store/physical boundary in the [architecture packet](../architecture-review-packet.md#definition-of-ready-and-required-tdd-evidence). This diagnostic uses disposable real storage. Model access constructs persisted fixture inputs only; behavioral observations use public Planner bootstrap, query and read. It adds no production test hook, target, adapter or cloud event.

## First real-store failure

The existing public commands create Hotel and Tokyo. A separate native ModelContext then saves two Membership records bound to those same exact source lifetimes:

| Membership | Lifetime | Rank | Local completion |
| --- | --- | --- | --- |
| 00000000-0000-4000-8000-000000000401 | 00000000-0000-4000-8000-000000000841 | 1024 | Todo |
| 00000000-0000-4000-8000-000000000402 | 00000000-0000-4000-8000-000000000842 | 2048 | Done |

Reopen Planner and issue the ordinary List query filtered to Done. The expected accepted behavior is one canonical local Done appearance, with Hotel globally Todo. The actual query returns `readUnavailable`: `List memberships are duplicated and unresolved.` The [retained executed packet](evidence/native-import-fresh-local-values/native-membership-consolidation-red/execution.json) records one failed function in 0.173 seconds, 11.860 seconds including compilation. All 766 frozen Core inputs remain unchanged and the log contains zero SQLite unlink diagnostics. The original failing fixture remains owned and retained after the host exits.

This establishes a local implementation gap, not a Simulator/signing limitation or proof about live CloudKit. The diagnostic test is retained as source and execution evidence outside the shipping test target while the dependent reconciliation contract is prepared. No failure is relabeled as passing and no production consolidation is claimed.

The first source had two formatting warnings. After formatting the diagnostic, the [second executed packet](evidence/native-import-fresh-local-values/native-membership-consolidation-qualified-red/execution.json) reproduces the same public failure in 0.638 seconds, 10.057 seconds including compilation. Strict Swift formatting passes. Its [boundary validation](evidence/native-import-fresh-local-values/native-membership-consolidation-qualified-red/boundary-validation.json) verifies all 766 frozen/workspace input hashes, both actual test products, the exact retained diagnostic source and zero SQLite unlink diagnostics. Both failures remain recorded. The formatted diagnostic source is removed from the shipping test target after this preservation, leaving production and shipping tests unchanged while Q153 and the concrete contract are pending.

## Contract facts

- `PlannerStorageConfiguration.StorageMode` currently exposes localOnly; the production container uses cloudKitDatabase none. Signed integration remains future work.
- List queries explicitly reject duplicate membership identities or Item pairs. Other callers and full exports must share a coherent resolution, rather than fixing only one filtered query.
- Existing context aliases store original/canonical context IDs and completion provenance. They do not retain a removed losing membership's full owner/source binding. Portable graph validation rejects duplicate pairs and needs the raw membership binding to compare differing contexts. Deleting the loser and keeping only its current alias/tombstone is insufficient.
- The generic native LineageRecord can store typed bytes, but its loader currently accepts four declared record kinds. A new logical binding/generation must have a concrete native/portable contract and compatibility rules; generic byte storage is not permission to invent an undeclared portable record.
- Ordinary command recovery identifies incomplete saves through real command receipts. Prepared proposals require an original operation ID, and retryRecovery requires an actual applied receipt. A receiptless automatic normalization cannot safely claim the same failure/retry behavior merely by publishing a checkpoint with unchanged receipts.

A complete local follow-up must resolve the same-pair removal policy, define retained logical binding/provenance and define truthful coordinated maintenance/recovery before production integration. It must cover explicit Reopen, unseen initial aliases arriving later, removal versus old edits, ordinary re-add, replay, exact contextual reads, full exports and genuine save/recovery failure. Physical/native CloudKit qualification remains additional work.

## Current frontier

[Q153 A](../native-unseen-membership-add-decision.md), [Q154 A](../legacy-membership-history-decision.md) and [Q155 A](../native-membership-consolidation-contract-review.md) are accepted on 24 October 2026. Preserve current saved data as the upgrade baseline, backfill only proven bindings and enforce the new rule for newly recorded removals. The approved concrete contract declares portable/native provenance, canonical context handling, compatibility and separate maintenance/recovery evidence. Its literal cases and existing test seams are approved, not executed. Dependent implementation is now unblocked. Q16, initial completion/global precedence and the approved real-storage test boundary stay settled. Signing stays deferred.
