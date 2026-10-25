# Discarded bookmark and booking history

## Local Core checkpoint, 26 October 2026

This follow-up completes ordinary owned-identity closure for the Q161
[bookmark](native-restored-owned-links.md) and
[booking](native-restored-owned-bookings.md) slices. Winning Item and Itinerary
contents stay intact. Maintenance records the discarded bookmark or Schedule's
exact identity and lifetime in existing deletion history, in the same durable
transaction that retires its native row and losing owner. Repeated delivery
reuses that closure.

The failing real-store tracer showed that an older, independently valid backup
could otherwise restore the discarded reference without authorization. Four
retained acknowledged checkpoints prove that the original bookmark871/872 or
Schedule873/874 became live on winning owner814 for both Item and Itinerary.
The [diagnosis](evidence/native-membership-consolidation/native-owned-reference-import-red/unauthorized-import-diagnosis.json)
records their exact bindings and retained checkpoint hashes.

The correction uses existing deletion targets, restoration families and import
authorization. It adds no public interface, model, format, rule version, writer
gate, package or test boundary. Portable5/model19/rule3/gate23 and recovery
envelope2 remain unchanged.

## Qualified behavior

- A reviewed Overwrite without restoration authorization rejects and changes
  neither saved data nor recovery files. Its operation has no reliable applied
  evidence, and review identifies the exact reference requiring restoration.
- A separately reviewed authorized import retains the public bookmark/Schedule
  identity, creates a fresh local lifetime and binds it to winning owner814.
  Incoming owner815 and its candidate operation are not adopted.
- The full graph comparison permits only represented source values, the restored
  reference and its new restoration family. Existing closures, families and
  independent data remain unchanged. The acknowledged payload matches export.
- Reopen and exact command replay retain the saved result and checkpoint.
  Reimporting the old closed reference still needs restoration authorization;
  authorized reimport retains the current restored lifetime and graph.
- Existing winner-content, stale-ID, redelivery and real unwritable-recovery
  tests now assert each exact new closure as the only permitted graph delta.
  Preparation failure leaves native and recovery data unchanged until Retry.

## Verification and limits

| Boundary | Final result |
| --- | --- |
| Mac Core storage | 45 functions in eight affected suites, no failures or skips |
| iPhone Simulator Core storage | 43 functions in eight affected suites, no failures or skips |
| Inputs | 813 Mac and 1,160 phone inputs match the workspace; all 813 shared inputs match |
| Products | Both recorded test products per platform match their executed files |
| Compatibility | 514 frozen fixture inputs and all 18 schema sources unchanged |
| Static checks | Strict Swift formatting, Markdown and whitespace checks pass |

Both platforms execute the genuine Schema18 and Schema12 migration functions.
Neither final cohort has SQLite unlink warnings. Counts describe test functions,
including parameterized functions, rather than individual assertions.

Packets under
[`native-membership-consolidation`](evidence/native-membership-consolidation/)
use the `native-owned-reference-*` prefix. The
[validation record](evidence/native-membership-consolidation/native-owned-reference-import-validation.json)
reconciles inputs, products and lossless manifest compression. Intermediate test
compile/assertion diagnostics remain retained and are not production-failure
evidence. The initial unauthorized-import tracer supplies the behavioral failure.

Verified cleanup removed eight passing Mac tracer fixtures and 137 passing phone
fixtures after their hosts and database handles closed. Failed and interrupted
datasets, original result bundles and the full Mac interruption cohort remain.

Mixed source families, pre-existing owned restoration families, broader
association/history reconciliation and reference-specific save/publication
interruptions remain open. This checkpoint adds no HTTP or native UI evidence.
Actual Mac/system, CloudKit/account, physical-device and whole-app acceptance
remain separate gates. Signing stays deferred.
