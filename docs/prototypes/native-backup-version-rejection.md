# Native unsupported backup version

## Context and starting state

The [native import checkpoint](native-backup-import.md) qualifies malformed JSON, cancellation and represented Tag Skip/Overwrite/restoration. Its unsupported-version presentation remains an explicit local gap. Core already rejects unsupported portable versions before an import review.

## Goal and expected end state

Select a syntactically valid version-3 file through the real native file picker. Require a useful unsupported-version alert before any import confirmation exists. Dismiss the error and review an actual valid export containing the current Tag as unchanged. Cancel that review and verify the original Tag name and identity after relaunch.

## Definition of ready

The accepted reject-together and useful-error rules and existing native UI/real-file test boundary apply. Stage only the independent [version-3 input](../fixtures/native-unsupported-backup.json.invalid) in the disposable simulator's local Files location. Test assertions observe native controls, not private storage. No new test boundary, production parameter, package, target, data format or signing change is proposed.

## Required tests and definition of done

- Run the new production native journey on phone and tablet, recording actual results and any failures. Existing behavior may already pass; do not manufacture a failing production change for a qualification-only test.
- Verify the exact unsupported-version message, absent import confirmation, enabled retry, valid backup's one unchanged Tag and retained source identity/name after relaunch.
- Preserve fixture bytes and provenance, commands, frozen inputs and original named captures. Inspect the captures individually.
- Run affected strict Swift/Markdown lint and Mac app/UI-target compilation. Compile-only checks supply no Mac UI runtime credit.
- Keep graph-invalid/dependency failures, full-graph restoration, stale reviews, recovery/save/termination, actual Mac interaction, physical sync/account/Share and final whole-app polish open.

## Execution

The initial phone journey passes in 79.030 seconds and its three original captures were inspected. It shows the unsupported-version alert, a valid review with one unchanged Tag, and the same Tag after relaunch. This is qualification of existing production behavior, with no manufactured red or production change.

Two tablet attempts remain failed. First, Files leaves a native Name Contains suggestion without a document result. After the controller accepts that suggestion, its broad Any query taps the resulting search token rather than the actual file cell. The failed hierarchy contains both elements and proves that misselection. The controller now matches a native document Cell using the complete filename, including its extension. Both failures happened before Planner received the selected file; they establish no import defect. Their later diagnostic-collection errors remain separate from the assertions. Each run restores the tablet's original light appearance.

The corrected iPad dark-mode bundle passes both selected functions with zero failures/skips. Malformed JSON takes 70.090 seconds and unsupported version takes 88.060 seconds. The three original version-check captures were inspected for the alert, unchanged review and retained Tag. Both functions use the final frozen source, and appearance restoration is verified.

The final phone bundle passes both functions with zero failures/skips. Malformed JSON takes 79.757 seconds and unsupported version takes 60.109 seconds. Its three original version-check captures were inspected. The final phone and tablet epochs each match all 1041 current frozen source/configuration/fixture inputs. This is four final passing invocations of two functions, separate from the initial phone pass and the two failed tablet attempts.

## Final checks and limits

The Mac app and native UI-test target compile successfully with the existing local ad hoc configuration. No Mac UI journey starts in this compiler-only check. Affected strict Swift lint, Markdown lint and whitespace checks pass. Source review confirms that only the native test, its document-selection controller and external input fixture change; production behavior, Core/MCP contracts, dependencies, schemas and signing/account setup remain unchanged.

The 317-byte input and both staged copies were verified against the same SHA-256. After qualification, only those two hash-verified temporary Files inputs were removed. The source fixture and evidence remain; no Planner dataset was removed. The evidence directory retains packets prefixed `native-backup-version-`, including original commands/logs, actual result summaries, frozen input hashes, inspected captures and failed-picker diagnoses. Simulator appearance is restored after each dark run. Native UI datasets use the existing unique local prototype path; this report does not claim the separate App Intent fixture-disposal procedure applies to them.

This qualifies the represented native unsupported-version error, retry and Tag preservation. It does not establish graph-invalid/dependency handling, full-graph import, stale review, save/termination or incomplete-recovery presentation. Actual Mac interaction, installed Share, CloudKit/account transitions, physical-device performance and final whole-app polish retain their map gates. Signing remains deferred; no prototype issue is closed.
