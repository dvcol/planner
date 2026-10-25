# Restored target-reference implementation

Q159 A and the [Q160 contract](../native-restored-target-reference-contract-review.md) are approved. Implementation is in progress through the existing modules and test boundaries. This is not a completed native maintenance or upgrade checkpoint.

## Portable admission slice

The public import decoder now admits portable5. Existing provenance validation accepts an original sibling Item binding beside its proven open-family live binding only under v5. Version4 retains the original exact-endpoint rule. One shared historical Item-pair key validates actual removal observations without rewriting provenance or joining predecessor families; List lifetimes stay exact.

The [first corrected runtime tracer](evidence/native-membership-consolidation/native-restored-target-portable-five-runtime-red-mac/execution.json) fails before the change and [passes afterward](evidence/native-membership-consolidation/native-restored-target-portable-five-green-mac/execution.json). The earlier attempt fails test compilation because it used the wrong decoding-result case; it provides no runtime evidence. The [removal tracer](evidence/native-membership-consolidation/native-restored-target-removal-observation-red-mac/execution.json) detects both incorrect unaware admission and rejection of a real sibling observation, then [passes with shared authority](evidence/native-membership-consolidation/native-restored-target-removal-observation-green-mac/execution.json). The [affected legacy decoding/encoding cohort](evidence/native-membership-consolidation/native-restored-target-portable-admission-regressions-mac/execution.json) passes five functions across three suites without SQLite unlink warnings.

Only decoding/admission is qualified here. Native v5 writes, aggregate atomic rebinding/consolidation, writer gate23, historical replay/closure, migration/recovery, native UI and HTTP still need implementation and qualification under the approved contract. Signing stays deferred. The implementation preference is the smallest existing path that meets these concrete requirements, with no general candidate-owned collection or label-collision framework.

## Real-store v5 write slice

The [real-store import tracer](evidence/native-membership-consolidation/native-restored-target-store-v5-red-mac/execution.json) first rejects review. Its [structured diagnostic](evidence/native-membership-consolidation/native-restored-target-store-v5-diagnostic-mac/execution.json) shows that the existing incoming-values path had removed the already known family proof needed by original membership provenance. The v5 path now retains that current proof. It does not adopt competing incoming authority.

Fresh native snapshots and canonical imports use portable5, distinct import fingerprint5 and logical gate23. Existing storage fields, model19, recovery envelope2 and ordinary command evidence stay unchanged. New source/member maintenance declares rule3/portable5; original preparation rules retain their exact formats. The [first real-store green run](evidence/native-membership-consolidation/native-restored-target-store-v5-first-green-mac/execution.json) saves and replays the exact result while retaining the original815 attestation and live814 binding.

The [deliberate re-add tracer](evidence/native-membership-consolidation/native-restored-target-deliberate-add-red-mac/execution.json) then detects the existing Add path failing after a Remove attested against815. Reusing the shared historical-pair comparison in the existing provenance calculation fixes it for all its production callers. The [affected green cohort](evidence/native-membership-consolidation/native-restored-target-deliberate-add-green-mac/execution.json) passes seven functions across three suites. Re-add starts Todo and records the actual applicable removal. No SQLite unlink warning occurs.

This does not yet qualify aggregate native candidate rebinding, actual gate22-writer rejection, full migration/recovery, native UI or HTTP. Those remain the next work in the approved contract.
