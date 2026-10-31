# Native Apple place-reference persistence

Native imports retain an allowed `applePlaceId` on Item- and Itinerary-owned Apple Maps links. Storage schema 18 adds one optional String attribute to OwnedLink; schemas 1–17 remain frozen. Portable format stays 2. This extends [source-origin persistence](core-native-import-origins.md).

## Context and goal

Portable decoding accepted a stable Apple place reference, but native link snapshots and recovery discarded it. Import consequently rejected an otherwise valid backup because native readback differed from the reviewed graph.

The completed behavior preserves the original URL, link identity and declared reference through native import, source reads, export, recovery, reopen and operation replay. Skip retains matching current data. Reviewed Overwrite can replace or clear a retained reference. Ordinary link-label and order edits preserve a reference when the original URL stays identical; replacing that URL clears the old reference, including when the new URL is another Apple Maps URL.

## Readiness and completion

The portable provider declaration and public native/import/read/recovery test boundaries were already agreed. Ordinary commands still accept original URLs and labels, without writable provider flags. Provider descriptions, images, addresses and cache snapshots are not added to saved data or backups.

Completion requires exact imported graph fidelity, native/recovery agreement after subsequent operations, correct retained-link edits and migration of a genuine earlier dataset. The main application owns schema migration before Share can open the updated store. Capture admission and actual Apple provider resolution remain separate work.

## Tests and findings

Two public-boundary test functions cover three invocations:

- The Item/Itinerary matrix imports an independently modified complete backup with fallback origins and an Apple place reference. Native export and independent recovery match its entire graph. Public reads expose the reference. Reopen and original-operation replay preserve data and receipt evidence. Skip keeps current metadata; Overwrite changes, clears and restores it. Item global completion and Itinerary bulk completion retain it. Label/order edits retain the reference; replacing the URL clears it, with native/recovery agreement and reopen after each edit.
- A genuine schema-17 dataset produced at `0bbeb80` retains all fallback origins, the complete exported graph and the original import result/summary after migration. Share first requires main-app migration. Receipt replay, subsequent completion, schema-18 recovery and reopen preserve the dataset.

The first tracer reproduced rejection for both link owner types. The edit regression then exposed two different failures: Item edits dropped the reference, while Itinerary native storage retained a reference omitted from recovery. Both paths now use the updated snapshot and persist its reference. Provider validity is shared by decoding, native readback and recovery; existing whole-import admission tests still reject contextual values such as `parked-car`.

The initial test draft used an incorrect session type; a subsequent compilation exposed the current-schema row extension that still needed to move to schema 18. Those diagnostics and the corrected red/green traces are retained with the evidence.

## Qualification

Mac and iPhone Simulator each passed 139 affected Core functions in 66 suites, covering 367 invocations. Native HTTP passed 16 functions in four suites, covering 22 invocations. Failures and skips were zero. Twenty-eight affected Swift files passed strict lint. The native Mac app and navigation test host compiled successfully. Both read-only review axes found no remaining confirmed issues.

Evidence records commands, source hashes, completed result summaries and red/green traces. The [schema-17 producer record](../../Packages/PlannerCore/Tests/PlannerCoreStoreTests/Fixtures/SchemaV17/producer.json) identifies the original native seed and file hashes.

No native UI runtime, capture execution, live provider resolution, physical CloudKit convergence, account transition or Share execution is claimed. Incoming candidate/family consolidation, broader rebinding, complete generated/affected results, native forms, direct database-save failure, Calendar, large-data performance and whole-app polish remain open.
