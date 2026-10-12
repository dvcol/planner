# Overwrite source fields while retaining their native references

## Context and goal

At `27ea048`, native import restores an empty dataset and adds new owners under Skip. A reviewed Overwrite still rejects every replacement. The next stage applies incoming source fields when the owner's references and completion history are unchanged. Existing native source models are updated in place, preserving the graph that references them.

This is a limited whole-owner case. An owner whose incoming memberships, entries, links, schedules, labels or completion history differ still rejects before writing. It must never receive a partial field update while the rest of its represented data is skipped.

## Definition of ready

- Skip/Overwrite whole-owner review and omitted-owner preservation are accepted.
- Additive native import, faithful empty restore, replay and independent recovery have qualified evidence.
- Source lifetimes remain unchanged; deleted-identity restoration and live deletion have separate gates.
- Use public decode/review/execute/export/recovery/reopen boundaries and actual native storage.

## Definition of done and required /tdd

- Begin with the independent full graph, including all five source kinds, references and completion history.
- Overwrite titles/names, optional text, locations, estimates, color/icons, source timestamps, global completion and archive values. Then clear optional fields through a second Overwrite.
- Preserve stable source identities/lifetimes and all current references, saved order and contextual completion history. Report affected sources without reporting them as generated.
- Verify the full exported graph, acknowledged recovery, reopen, same-operation replay and fresh identical reimport after each change.
- Reject changed owned data before mutation, retaining the previous export and operation status.
- Requalify affected import/recovery/migration and HTTP checks, strict Swift/Markdown lint and native app/test-host compilation.

## Proof and limits

The first fixture omitted origins for newly populated optional text, then incorrectly supplied origins for non-origin fields. Both were rejected by decoding and are excluded from implementation-red evidence. Corrected fixture and execution results are recorded with their actual source epochs.

All five source kinds now replace their incoming fields in existing native models. The public test sets and clears optional fields and preserves the complete expected graph/history through export, acknowledged recovery, reopen, replay and fresh reimport. A parameterized check covers all eight owned-data groups: changed records/history reject with no changed export or import receipt, including after reopening.

Final qualification passes 48 Core functions in 22 suites, 95 invocations, on Mac and the native iPhone simulator. Mac HTTP passes 16 functions in four suites, 22 invocations. No failures or skips. Four affected Swift files pass strict lint; the Mac app and navigation test host compile. Standards and spec reviews have no confirmed findings. These checks add no UI runtime or separate persisted SwiftData-identity test.

Owned-data replacement, deletion/restoration, origin/provider persistence, import summaries, native forms and direct save-failure proof remain open. This stage does not complete the import ticket or qualify physical synchronization.

Commands, native results, source hashes and retained failures are in [execution evidence](evidence/navigation/core-native-import-source-overwrite/execution.json). The earlier [additive import evidence](core-native-import-additions.md) remains applicable.
