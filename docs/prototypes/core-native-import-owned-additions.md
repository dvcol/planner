# Add owned records while overwriting an existing owner

## Context and goal

At `7751e6f`, Overwrite can replace source fields and retained owned-record values, but rejects an incoming owner that adds references or completion history. Native insertion already supports those records; the merge requires identical binding sets. A backup that adds a second Hotel stop or a bookmark therefore cannot apply to an existing plan.

Overwrite should apply additive whole-owner changes while preserving every current identity, lifetime and binding. Skip keeps the current owner and all its owned data. An omitted owner also remains unchanged. Reference removals and rebinding still require closure reconciliation and remain gated.

## Definition of ready

- Whole-owner Skip/Overwrite, omitted-owner protection, live references and all-or-nothing local application are accepted.
- Existing restore, new-owner additions, retained-record Overwrite and closed-history import have qualified public native evidence.
- Tests use an independent fixture and actual decode/review/execute/export/recovery/reopen boundaries, without a production test hook.

## Definition of done and required /tdd

- Reproduce rejection for valid additions in 12 cases: membership, repeated direct route entry, repeated List route entry, expanded local completion, Item Category, Itinerary Tag, Item/Itinerary bookmarks, Item/Itinerary schedules, context alias and explicit completion change.
- For each case, test a complete backup and one that declares only the changed owner; resolve omitted source dependencies from current data.
- Skip preserves the complete current graph. Overwrite adds the incoming records with their original identities, bindings, order and local completion. Existing sources are affected without being reported as newly generated.
- Verify full export and acknowledged independent recovery, then reopen, replay the original operation and freshly reimport without duplicates or graph changes.
- Retain negative removal/rebinding gates and history-collision coverage; requalify affected native migration/recovery/import and HTTP checks, strict lint and app/test-host compilation.

## Proof and limits

The public tracer first failed all 12 addition cases at the binding-set gate. The implementation now requires current bindings to be a subset of incoming bindings, allowing additions without permitting removal or rebinding. The expanded tracer passes 24 cases, including omitted owners, across both import modes. Standards and spec reviews found no confirmed defects in this scope.

Final qualification passes 58 Core functions in 27 suites on Mac and iOS Simulator (156 invocations each), plus 16 Mac HTTP functions in four suites (22 invocations). Strict Swift lint passes for both changed Swift files; Mac app and navigation test-host compilation passes. [Commands, source hashes, result summaries and logs](evidence/navigation/core-native-import-owned-additions/execution.json) preserve the red and final candidate evidence.

Native UI execution, reference removals, deletion/restoration families, origin/provider persistence, import summaries/forms and direct local-save failure proof remain open. Local graph and recovery tests do not qualify physical sync/account/Share behavior. The [closed-history proof](core-native-import-closed-history.md) retains the prior import evidence chain.
