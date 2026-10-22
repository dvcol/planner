# Bulk completion database-save rollback

## Context, starting state and goal

The accepted local all-or-nothing bulk rule covers a List, an Itinerary and one exact referenced-List entry. Existing admission tests reject an obstructed recovery directory before saving and retain a complete applied action after a post-save recovery failure. Neither establishes rollback when the native database save itself fails. The earlier SQLite trigger/lock experiments remain unqualified.

A genuine failed-save check exposes a separate defect. Bulk completion rolls back its database context but retains its prepared recovery proposal. Reopening then reports `preparedUnverified`, and an unchanged reviewed retry cannot complete. Item creation and association restoration already clear their prepared evidence after a known failed save.

The goal is complete rollback with truthful operation evidence and a safe unchanged retry. It does not change an actually applied action's incomplete-recovery behavior.

## Definition of ready

Use the accepted public Core review/execute/read/export/recovery boundary and disposable real storage. The existing `NativeSaveFileSizeObstruction` arms a real process file-size limit at the matching store's `ModelContext.willSave`. Run it only in an isolated Mac child process and restore the limit immediately after execution. No production injection, test callback, schema or public-contract extension is added.

## Required tests and definition of done

For all three scopes, prepare the real review, export the complete initial graph and retain the acknowledged recovery. Force an actual database-save failure. Reopen, require unchanged exported data, no surviving operation evidence and no changed child progress or recovery. Retry the exact original operation/review, require the complete expected contextual progress and preserve other contexts. Reopen reads must observe the committed result. Replay must return the original result without another data change. The recovery graph must match the saved graph.

Rerun both affected bulk suites, including existing stale/canceled review, global/local precedence, repeated appearance, archive, empty-container and applied-incomplete checks. Compile and execute mobile-compatible regressions on the dedicated iPhone Simulator. Strictly lint the affected Swift files and this report. Report Mac-only fault limits separately from native mobile and physical evidence.

## Diagnosis and correction

The [unchanged baseline admission class](evidence/navigation/core-bulk-native-save-baseline/execution.json) passes its three functions. The first genuine-fault tracer fails with a generic guard error; explicit public-outcome reporting then identifies the retained `preparedUnverified` proposal. The database error is `NSSQLiteErrorDomain` code 778. No SQLite trigger or writer lock is introduced.

Bulk completion now retains its prepared proposal identity and discards that proposal after database rollback. If proposal removal itself fails, the existing structured persistence failure tells the caller to resolve operation status before retrying. It never advertises a successful save or silently reapplies uncertain evidence.

The first corrected run reaches the final recovery comparison but fails because it compares pretty-printed export bytes with compact recovery JSON. Inspection establishes equal decoded graphs in all three cases. The final assertion compares complete public JSON objects; exact before/after export and replay-byte comparisons remain. These diagnostic failures are retained and are not additional product defects.

The [final regression against pre-fix production](evidence/navigation/core-bulk-native-save-final-red/execution.json) still fails at the retained proposal. Its packet explicitly records the `bd25816e` production override and unchanged final test. The following final-source runs use the workspace production implementation. No claim is made that the red override matches workspace production bytes.

## Execution and limits

The [first complete Mac run](evidence/navigation/core-bulk-native-save-final-mac/execution.json) passes five functions across two suites, with seven top-level executions after parameter expansion, zero failures/skips and zero SQLite unlink diagnostics. Its isolated fault function additionally runs once in the child and checks the three scopes sequentially; these loop iterations are not advertised as separate discovered tests. The wrapper finishes in 20.122 seconds and the test body completes in 0.670 seconds.

The [first iPhone run](evidence/navigation/core-bulk-native-save-final-ios/execution.json) passes its four mobile-compatible functions, six executions after parameter expansion, but emits five SQLite unlink diagnostics. All five name the companion `BulkCompletionTests` fixture, which still deletes its store during test teardown. Its directory allocation/removal code is unchanged from the starting revision. This run receives assertion credit but no safe-lifecycle credit. The affected tests now both use the existing marked fixture namespace and defer disposal until the actual test host has exited. This changes test lifetime only, without a production storage change.

The [final Mac epoch](evidence/navigation/core-bulk-native-save-lifecycle-final-mac/execution.json) passes five functions/seven top-level executions in 19.299 seconds, with test bodies completing in 0.636 seconds. The [final iPhone epoch](evidence/navigation/core-bulk-native-save-lifecycle-final-ios/execution.json) passes four functions/six executions in 140.013 seconds. Neither has failures, skips or SQLite unlink diagnostics. The Mac-only genuine-fault function remains excluded on mobile.

The [qualification record](evidence/navigation/core-bulk-native-save-lifecycle-final-mac/qualification.json) reconciles all 740 Core and 1,062 native inputs, retained product hashes, the unchanged final regression's pre-fix failure, and actual child-log save failures. Closed-host disposal removes nine marked fixtures from the final Mac run, six from iPhone, eight from the earlier complete Mac run and three from the successful tracer. Failed diagnostic fixtures remain separate; no failed log is presented as a successful cleanup authorization.

Strict formatting, affected Markdown lint and whitespace checks pass. Mac fault qualification does not prove iOS filesystem-failure behavior, physical performance, native confirmation, signed storage or cloud/account convergence. The independent filtered-map, embedded-browser, change-stream and Share-presentation work remains on the map.
