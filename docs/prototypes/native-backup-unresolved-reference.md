# Native unresolved backup reference

## Context and starting state

The [version-rejection checkpoint](native-backup-version-rejection.md) qualifies native malformed/version errors and valid-file retry. A structurally decoded backup can still refer to an Item absent from both the file and the selected dataset. Core already rejects that whole review; its native presentation and no-partial-import outcome remain open.

## Goal and expected end state

Select a backup declaring a new List with one membership to an unavailable external Item. The review must show a useful failure, disable Import and offer Retry/Cancel. After Cancel, an actual valid export remains reviewable with one unchanged Tag. Relaunch must preserve that Tag's name/identity and show no imported List.

## Definition of ready

Reuse the accepted reject-together, current-dataset binding and useful-error rules, plus the existing native UI/real-file boundary. The [independent input](../fixtures/native-unresolved-backup.json.invalid) uses a supported version and a declared List, but deliberately omits its referenced Item. Stage only those input bytes in the disposable simulator Files location. Outcomes are observed through native controls; no private-store inspection, new test hook, target, package or signing change is proposed.

## Required tests and definition of done

- Run the production native journey on phone and tablet with literal expectations for the error, disabled Import, available Retry/Cancel, valid-file review and unchanged Tag after relaunch.
- Require the List catalog's ready empty state and absence of the incoming List after relaunch, rather than asserting absence while it is still loading.
- Retain exact input provenance, commands, actual results, frozen inputs and original named captures. Inspect the phone/tablet captures individually and preserve genuine failures.
- Run affected lint/type checks and Mac app/native UI-target compilation. Keep actual Mac interaction, other invalid bindings, full-graph import, stale review, recovery/save/termination, physical sync/account/Share and final whole-app polish separate.

## Execution

The phone function passes in 83.963 seconds and the tablet function in 95.176 seconds, each with zero failures/skips. Both select the supported version-1 input, show the exact unresolved-reference message with Import disabled, offer Retry/Cancel, review the actual valid export as one unchanged Tag, and preserve the Tag's identity/name after relaunch. The ready List catalog remains empty and contains no incoming List. No confirmation was submitted for either file.

The tablet runs in dark mode and its original light appearance is restored and verified. Three original captures per device were individually inspected, covering the blocked review, valid-file review and empty catalog after relaunch. The portrait iPad empty-state capture also records a partially occluded middle-pane message beside its open sidebar; that visual observation belongs to the [final UI pass](../native-ui-polish.md), not this data-safety result.

The Mac app and native UI-test target compile with the existing local ad hoc configuration. There is no Mac UI runtime invocation. Final phone, tablet and Mac builds match the same 1042 frozen inputs. Only the new UI function, external fixture and reports change; earlier test/controller bodies and production source stay unchanged. Affected strict Swift/Markdown lint, whitespace, actual result reconciliation and source/product checks pass.

The evidence directory retains packets prefixed `native-backup-unresolved-`, including original commands, logs, results, source hashes and inspected captures. The exact 1276-byte input is retained in the repository. After qualification, the two staged Files copies are removed only after hash verification; no Planner dataset is removed. The existing unique local prototype datasets are not covered by the separate App Intent disposal procedure.

This qualifies one missing external Item binding in a declared List. Other kinds/lifetimes, full-graph restoration, stale review, recovery/save/termination, actual Mac interaction and signed physical gates remain open. No Core/HTTP test invocation, signing/account change, new schema or production behavior is attributed to this slice. The map remains open.
