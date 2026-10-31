# Recovery snapshots preserve portable lineage

## Context and goal

Manual import must preserve a complete data backup. The public decoder and review already admit completion aliases, explicit completion changes and restoration families. At `cefa0ff`, recovery snapshots encode these groups as empty arrays and reject nonempty groups while reading. Import cannot safely publish a complete recovery proposal through that representation.

This slice preserves those typed groups in recovery files and validates their graph before selection. It does not apply an import or introduce native lineage persistence. The full-import tracer remains red at the explicit unavailable execution gate.

## Definition of ready

- Full versioned data backup, independent local recovery and explicit manual import are accepted. Backup administration remains outside agent interfaces.
- The portable context grammar, local/global completion precedence, restoration identities and independent complete fixture are already specified.
- Public import decoding, recovery inspection, actual store/file I/O and native test hosts are approved test boundaries.

## Definition of done

- Encode all three completion context shapes and retain explicit null current-change values.
- Select a prepared recovery file containing valid completion history and restoration candidates without dropping or rewriting its portable graph.
- Reject malformed lineage before returning a selection, with a useful property path.
- Preserve current source identity, lifetime, content, hashes, timestamps and incomplete-operation evidence during inspection.
- Keep existing acknowledged-snapshot, missing-store, retry and identity validation behavior.
- Pass affected Core checks, strict Swift lint, native iOS execution and Mac app/test-host compilation. Retain failed attempts and final source hashes.

## Required /tdd and execution

The complete prepared-file inspection tracer fails against the original snapshot reader, which cannot decode nonempty alias objects. The typed reader and encoder preserve the independent complete fixture. A second valid case includes restoration candidates for a closed predecessor. Exact portable JSON comparison covers the returned graph; source reads and operation status prove inspection changes nothing.

Spec review found two malformed shapes that the new Codable path could admit: an empty restoration candidate array and repeated observed completion-change identities. Both prepared-file cases first prove rejection through public import decoding, then fail when recovery incorrectly returns a selection. Shared graph validation now rejects both. A further failing check exposed a nonexistent property in the duplicate-history error path; the corrected diagnostic names the actual observed-change array.

The codec checks compare independently specified JSON for every completion context, including an initial contribution with a null current change. Regression checks cover acknowledged recovery selection, closure history, checkpoint retry and source identities. Initial test compilation errors carry no runtime evidence.

Mac package and native iOS execution each pass 19 functions across seven suites, with 40 invocations and zero failures or skips. Six affected Swift files pass strict lint. The Mac app and navigation test host compile; this slice executes no native UI journeys. Standards and Spec review findings are resolved. Storage schema 15 and portable format 2 remain unchanged.

Final commands, counts, logs and source epochs are recorded in execution evidence.

## Remaining work

Native storage still needs durable lineage, content-origin and provider-reference representation before complete import execution can pass. Execution must preserve reviewed bindings, whole-owner Skip/Overwrite behavior, atomic save, operation replay, recovery publication and faithful reopen. Native import forms and signed device recovery remain open.

The prior [manual review contract](core-native-import-review.md), [native loading journey](native-loading-fixture.md) and [delayed preview checks](native-delayed-link-result.md) retain their evidence. Large-data responsiveness, Calendar, filtered drag/group/duration interactions, broad Mac UI runtime, physical sync/account/Share and whole-app native polish remain open.
