# Reviewed native import application

## Context and starting state

At cefa0ff, native decode and dataset-bound review classify complete backups, Skip/Overwrite conflicts, deletion impact and omitted owners. Execute still rejects applyImport as unavailable. Native schema 15 and recovery snapshots cannot preserve every accepted origin, provider reference, completion history or restoration-family value.

## Goal and expected end state

Apply the reviewed whole-owner plan through the coordinated native writer. Empty restoration preserves the complete versioned graph, supplied identities/lifetimes/timestamps, content, order, global/local states and necessary lineage. Skip preserves current matching owners; Overwrite replaces represented owners while preserving omitted owners and independent data. Structural invalidity or precommit failure leaves the action unapplied. A committed action retains truthful recovery and replay evidence, including its import summary. Agent administration remains unavailable.

## Definition of ready

- The accepted portable contract, Q73 omitted-owner rule, reviewed Skip/Overwrite modes and recovery acknowledgement semantics apply.
- Public native prepareReview/execute/read/export/status and real store/file I/O are approved seams.
- Extend versioned storage and snapshot/recovery representation where accepted values currently cannot survive; do not silently shorten a successful import.

## Definition of done and required /tdd

- Start with the independent complete portable fixture: reviewed empty restoration, faithful export, durable reopen and operation status.
- Cover origin/provider-reference/lineage preservation, complete graph dependencies, Skip/Overwrite/omitted owners, deletion/restoration impact, malformed/stale review and idempotent replay.
- Prove all-or-nothing local saves and applied/incomplete postcommit recovery using actual file I/O, then checkpoint retry and reopen.
- Run focused affected Core/native/HTTP checks, strict lint and native host compilation; retain exact commands, failures, source epochs and limits.
- Keep native administration forms, physical convergence/account/Share, large-data responsiveness, Calendar and whole-app polish open until their own evidence qualifies them.

## Empty-dataset restore stage

Before this stage, execution rejects every reviewed import. After this stage, the independent complete fixture can restore into an empty native dataset, publish independent recovery and reopen with the same portable graph. Schema 16 adds lineage records to Schema 15's existing models. It keeps supplied source/reference identities, lifetimes, order, completion and timestamps.

The writer verifies the review against the current dataset, checks prepared/receipt evidence and compares the inserted native graph against incoming canonical data before Save. It prepares recovery first, then saves the entire graph and receipt together. A later recovery publication failure reports applied with incomplete recovery. Retry publishes the complete saved graph. Replay uses the immutable command fingerprint and retains the original result/checkpoint; changing the mode with the same operation identity is rejected.

Ordinary edits retain imported history in recovery proposals and checkpoints. A local completion change appends a change observing the prior contributions and updates its alias in the same native save. Shared history evaluation is also used by the portable graph validator. Imported global Item completion stays separate.

Qualified proof includes exact comparison with the independently specified complete fixture, native export and reopen, actual post-save file obstruction and retry, receipt replay/mismatch, a notes edit and local reopen after import, unsupported origin/provider rejection, recovery-preparation write denial, the genuine version-15 store and all existing migration fixtures. The V15 fixture is generated through the committed `d5a47a5` public Core API, rather than relabeling an older store.

Mac package and native iOS each pass 45 functions across 21 suites, with 82 invocations and zero failures or skips. Actual Mac HTTP checks pass 16 functions across four suites, with 22 invocations, including administration exclusions. The initial HTTP run used an unsupported iOS destination and carries no runtime proof. The Mac app/navigation test host compiles. Nineteen affected Swift files pass strict lint. No new native UI journeys run in this stage.

A direct local-save failure remains unqualified. An SQLite INSERT trigger causes a fatal Core Data retry; an external write lock stalls and is terminated. Neither experiment reaches rollback assertions or counts toward passing proof. Their logs are retained. The final candidate uses the qualified preparation-write failure test; it has no SQL fault injection. Save-failure rollback remains an explicit full-import gate.

Import into nonempty datasets, the recorded import summary, native content-origin/provider-reference persistence, additional deletion targets, restoration-family execution, local-save failure proof and native import forms remain open. The pre-save fidelity check rejects any incoming fields the current native representation cannot preserve. This stage does not qualify every accepted portable backup or complete the map's import ticket.

Commands, actual results, source hashes, fixture provenance and failed experiments are recorded in execution evidence. Earlier [lineage snapshot proof](core-native-import-lineage-snapshot.md) remains separate.
