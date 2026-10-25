# Restored target-reference implementation

Q159 A and the [Q160 contract](../native-restored-target-reference-contract-review.md) are approved. Implementation is in progress through the existing modules and test boundaries. This is not a completed native maintenance or upgrade checkpoint.

## Portable admission slice

The public import decoder now admits portable5. Existing provenance validation accepts an original sibling Item binding beside its proven open-family live binding only under v5. Version4 retains the original exact-endpoint rule. One shared historical Item-pair key validates actual removal observations without rewriting provenance or joining predecessor families; List lifetimes stay exact.

The [first corrected runtime tracer](evidence/native-membership-consolidation/native-restored-target-portable-five-runtime-red-mac/execution.json) fails before the change and [passes afterward](evidence/native-membership-consolidation/native-restored-target-portable-five-green-mac/execution.json). The earlier attempt fails test compilation because it used the wrong decoding-result case; it provides no runtime evidence. The [removal tracer](evidence/native-membership-consolidation/native-restored-target-removal-observation-red-mac/execution.json) detects both incorrect unaware admission and rejection of a real sibling observation, then [passes with shared authority](evidence/native-membership-consolidation/native-restored-target-removal-observation-green-mac/execution.json). The [affected legacy decoding/encoding cohort](evidence/native-membership-consolidation/native-restored-target-portable-admission-regressions-mac/execution.json) passes five functions across three suites without SQLite unlink warnings.

Only decoding/admission is qualified here. Native v5 writes, aggregate atomic rebinding/consolidation, writer gate23, historical replay/closure, migration/recovery, native UI and HTTP still need implementation and qualification under the approved contract. Signing stays deferred. The implementation preference is the smallest existing path that meets these concrete requirements, with no general candidate-owned collection or label-collision framework.
