# Reviewed recovery restoration

## Context, before and goal

Native recovery can inspect and export immutable Core-issued selections, but the approved `restoreRecovery(selection:mode:)` command is absent. Calling ordinary file import would lose the command's binding to its selected recovery evidence.

The goal is explicit reviewed restoration into the operation session's target dataset. Review and cancellation apply no changes. Confirmation uses the selected snapshot or unverified proposal, Skip/Overwrite policy, ordinary graph validation and the existing durable import/checkpoint path. Empty-target restore preserves identities and the complete supported graph. Source data remains separate.

## Definition of ready

The [approved portable contract](../portable-data-contract.md#native-import-delete-and-recovery-forms) declares this command, target binding and fresh operation for unverified proposals. Q33/Q36 accept the public Core facade and real configured storage/recovery I/O as test boundaries. Recovery administration remains absent from agents and App Intents. No schema or portable-format change is needed.

## Required /tdd and definition of done

- Functional red at the missing recovery review, followed by an unchanged full-graph empty-target tracer. Review applies nothing; execution requires its token; confirmation preserves IDs, records, references and state; replay/reopen retain the original result and checkpoint.
- Bind review and operation receipts to the exact selected evidence, target dataset, mode and current graph. A changed target/mode/selection cannot use an earlier review or receipt.
- Skip preserves matching current data and imports independent records. Dedicated Overwrite restoration lists replacements/restorations before execution. Unverified proposals use a new operation identity and remain explicitly unverified until the new action is applied and checkpointed.
- Reject stale review, payload mismatch and invalid proposal retry without partial data changes. Preserve existing file-import behavior and HTTP rejection of native administration.
- Run affected lint/type checks, focused real-store tests and native Core compilation/runtime qualification. Record counts and limits exactly. Native review forms, checkpoint-retry UI, physical account/sync/Share, Mac UI runtime, broad scale/accessibility and polish remain separate gates.

## Execution

The full-graph tracer first failed because the recovery command had no reviewable impact. It then passed without changing that tracer between the functional red and first green. Later qualification added conflict/admission/proposal/deletion cases. One compile-only test setup mistake used a nonexistent portable Tag projection; the test now inspects the public source enum. Review removed per-function live-store unlinking from the new suite. The first wider iOS run then exposed SQLite vnode-unlink warnings in existing ordinary-import regression teardown. Those six fixtures now also retain named directories through process exit, with assertions unchanged. Final Mac/iOS reruns pass without those warnings. Initial failures and pre-correction warning logs remain separate from final qualification.

`restoreRecovery` now normalizes into the existing reviewed import writer. It retains the Core-issued decoded backup and binds the fingerprint to the selected namespace, recorded dataset/owner, evidence, checkpoint or proposal/original-operation identities, mode, target ownership and reviewed current graph. Transient selection-read IDs are excluded so equivalent reselection can replay an existing receipt. The command type distinguishes restoration from ordinary file import. Unverified proposals reject their original operation identity before application.

Skip keeps matching or deleted current identities while importing eligible independent data. Dedicated recovery Overwrite explicitly authorizes the restorations listed by its review. Both reuse graph validation, all-or-nothing local save, prepared evidence, applied summary, receipt replay and completed/incomplete checkpoint behavior. No new schema, portable version or account-selection path is introduced.

| Qualified boundary | Functions | Suites | Invocations | Failures/skips |
| --- | ---: | ---: | ---: | ---: |
| Mac Core package | 12 | 3 | 26 | 0/0 |
| iOS 27 Core host | 12 | 3 | 26 | 0/0 |
| Mac authenticated HTTP routing | 12 | 1 | 17 | 0/0 |

The new restoration suite has six functions and fifteen invocations. Its empty-target workflow restores the existing complete portable fixture, compares the public target export with the source export, preserves the source, and verifies replay/reopen. Remaining cases cover Skip/Overwrite with independent current records, changed mode/selection/target/current data, file-command substitution, receipt mismatch, equivalent reselection, real post-save proposal obstruction and fresh operation identity. Deleted identities remain deleted under Skip; reviewed recovery Overwrite restores the same source ID with a new lifetime and restoration family.

Existing ordinary-import and deleted-data review assertions provide the other six Core functions and eleven invocations. HTTP's native administration case exercises six rejected command kinds, including restoreRecovery. Production HTTP/Intents interfaces are unchanged. The actual Mac app compiles as part of that HTTP run; no native Mac UI runtime is credited. HTTP ran before the final test-only fixture correction; its production and test-host sources/products remain unchanged, so it was not repeated.

Affected strict Swift/Markdown lint and whitespace checks pass. [Execution evidence](evidence/navigation/core-reviewed-recovery-restoration/execution.json) retains commands, functional red/green and later qualification logs, terminal native summaries/trees, final source/product hashes and review outcomes. Final compiled hashes describe the final qualification, not an independently retained source snapshot of the earlier red.

## Remaining gates

The reviewed native restoration form and its selected/target dataset presentation are not implemented yet. Native cancellation/stale-review/failure/relaunch journeys, checkpoint-retry UI, physical iCloud ownership/cutoff and sync/Share remain open. Broader lineage/migration, adaptive/accessibility/scale and whole-app polish retain their owning gates. This slice proves local Core restoration and agent exclusion, not an account transition. Q83 Calendar alignment is still unanswered.
