# Native source-origin persistence

Native imports now retain declared `independent` and `appFallback` origins for Items, Lists, Itineraries, Categories and Tags. Storage schema 17 uses separate optional String attributes for supported content fields. Earlier models remain frozen; portable format remains 2.

## Context and goal

Import decoding accepted fallback origins, but native snapshots reconstructed every origin as independent. Import then rejected the mismatching readback. Recovery also lost origins when some operations rebuilt source snapshots.

The completed behavior preserves the declared origins through native save, export, recovery and reopen. Explicitly supplying a field makes it independent, even when its displayed value stays the same. Other fields retain their origins. Optional nil fields have no portable origin entry. Ordinary commands expose no writable origin flag.

## Readiness and completion

The public Core import/review/read/recovery boundaries and portable origin declaration were already agreed. This step adds no test-only injection. Native scalar attributes have nil defaults; the main app owns migration before Share can use the new store.

Completion requires full native/recovery graph fidelity for declared origins, correct explicit-edit behavior and preservation of genuine earlier data and receipt evidence. Provider-reference persistence, capture admission and native import forms remain open.

## Tests and findings

Two new public-boundary functions cover six invocations:

- A five-source-kind matrix imports fallback origins for every populated supported field. Its native export and independent recovery match an independently modified full backup. Global Item completion preserves origins. List/Itinerary bulk completion also preserves them; a scheduled Itinerary keeps its booked Schedule. Explicitly supplying the same title/name changes only that field's origin to independent. Reopen retains the resulting export.
- A genuine schema-16 dataset produced through public Planner APIs at `8672650` migrates without changing its full exported graph or original import receipt/summary. Share first requires main-app migration. Original-operation replay remains idempotent; a later completion action, recovery and reopen pass under schema 17. Earlier committed migration fixtures remain qualified.

The initial tracer reproduced rejection of valid fallback origins. Later regressions reproduced completion/recovery origin loss and failure to recognize explicit own content. Both review axes found an Itinerary bulk snapshot that omitted origins; its public regression also exposed the omitted Schedule. The snapshot now retains both.

The first draft incorrectly compared differently formatted recovery/export bytes. Qualification compares their full JSON values; canonical native exports are separately compared after reopen. The draft compile diagnostic and corrected traces are retained.

## Qualification

Mac and iPhone Simulator each passed 129 affected Core functions in 59 suites, covering 356 invocations. Native HTTP passed 16 functions in four suites, covering 22 invocations. Failures and skips were zero. Thirty-one affected Swift files passed strict lint. The native Mac app and navigation test host compiled successfully. Both read-only review rechecks found no remaining confirmed issues.

[Evidence](evidence/navigation/core-native-import-origins/execution.json) contains exact commands, source hashes, red/green logs and completed result summaries. The [schema-16 producer record](../../Packages/PlannerCore/Tests/PlannerCoreStoreTests/Fixtures/SchemaV16/producer.json) identifies the original native seed and its file hashes.

No native UI runtime, physical CloudKit convergence, account transition or Share execution is claimed. Incoming candidate/family consolidation, broader rebinding, provider persistence, complete generated/affected results, native forms, direct database-save failure, Calendar, large-data performance and whole-app polish remain open.
