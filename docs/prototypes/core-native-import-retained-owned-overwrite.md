# Overwrite retained owned records and history

## Context and goal

At `797c769`, Overwrite applies source fields only when owned data is unchanged. This stage applies incoming values to retained owned records and existing completion history. Lists can change their saved order/local completion, itineraries their order/expanded completion, and Items their bookmarks or schedules through the same reviewed import transaction.

Every existing reference identity, lifetime and binding must remain the same in this stage. Reference additions/removals, new history identities, deleted-data restoration and live deletion stay gated, with no partial source-field update.

## Definition of ready

- Whole-owner Overwrite and independent completion scopes are accepted.
- Native source-field replacement, Skip additions, replay and independent recovery have qualified evidence.
- Public native decode/review/execute/export/recovery/reopen remain the test boundaries.
- Source/reference identities and history-context bindings are preserved; broader closure reconciliation remains separate.

## Definition of done and required /tdd

- Start with the full independent graph and review changes to retained membership/route order, expanded completion, bookmark labels, schedule spans, alias contribution and explicit completion history.
- Replace source fields and selected owned values together, preserving every binding, source/reference lifetime and unrelated owner.
- Verify complete expected native export and acknowledged recovery, reopen, same-operation replay and fresh identical reimport for each case.
- Verify that reference identity/removal and history-identity changes reject before mutation or receipt.
- Retain actual functional red/final source epochs; qualify affected native Core/HTTP checks, strict lint and native app/test-host compilation.

## Proof and limits

The changed public tests require the seven previously gated retained-record/history cases to execute. Their first run rejects at the owned-data gate. Native models and lineage records must update in place without recreating their identities.

All seven cases now preserve their full expected graph/history through export, acknowledged recovery, reopen, same-operation replay and fresh reimport. Three negative cases reject reference removal, changed alias identity and changed completion-change identity without altering the exported graph or creating an import receipt. Reopen retains that unchanged graph.

Final qualification: 49 Core functions in 22 suites, 97 invocations, pass on Mac and the native iPhone simulator. Mac HTTP passes 16 functions in four suites, 22 invocations. No failures or skips. Four affected Swift files pass strict lint; the Mac app and navigation test host compile. Standards and spec reviews have no confirmed findings. Native model reuse was reviewed; no separate persisted SwiftData-identity test or new UI runtime ran.

Reference additions/removals, live deletion/restoration, origin/provider persistence, import summaries, native forms and direct save-failure proof remain open. No physical synchronization or new UI journey is implied.

[Execution evidence](evidence/navigation/core-native-import-retained-owned-overwrite/execution.json) retains commands, native results, functional red, source epochs and qualification. Earlier [source-field Overwrite evidence](core-native-import-source-overwrite.md) remains applicable.
