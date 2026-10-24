# Portable membership provenance

Q155 A approves the [membership consolidation contract](../native-membership-consolidation-contract-review.md). This checkpoint implements portable-v3 decoding and native preservation. Automatic consolidation, new per-action removal evidence and independent maintenance recovery remain open.

## Implemented boundary

The existing public `decodeImport` interface accepts versions 1, 2 and 3 and retains their original format version. Version 3 requires membershipProvenance and membershipRemovals. Exact Item/List lifetime bindings, retained membership identity, strict-removal observations and causal dependencies are validated before admission. Invalid input rejects as a whole at its actual property path.

Native schema 19 now stores the provenance records and typed strict-removal declarations. Import graph copies, native snapshots, full export and recovery publication preserve those fields. Current exports use portable version 3. The native importer compares its complete staged graph with the projected graph before saving. Existing source timestamps and flags survive faithful import; ordinary edits retain the membership authority.

New portable-v3 import fingerprints use sha256-payload-v3 with the original graph and ordered resolved membership evidence. Legacy v1/v2 canonical encoding and fingerprint branches remain separate. Backups import history as data; an incoming removal operation ID never becomes an applied local command receipt.

## Red-to-green evidence

The [first public decode](evidence/native-membership-consolidation/portable-v3-informed-readd-red/execution.json) rejects membershipProvenance. The [cross-pair failure](evidence/native-membership-consolidation/portable-v3-cross-pair-removal-red/execution.json) then demonstrates that accepting fields alone is insufficient. The [integrity failure](evidence/native-membership-consolidation/portable-v3-history-integrity-red/execution.json) records wrong lifetime/endpoint paths, an unaware addition, causal cycles and an orphan binding before their guards are implemented.

The first native test needed its review method name corrected before execution. The [qualified native failure](evidence/native-membership-consolidation/portable-v3-native-roundtrip-qualified-red/execution.json) actually saves a disposable graph, then finds its provenance missing from both export and recovery. The corrected pipeline passes complete literal graph comparisons, original replay and reopen.

The new native cases also preserve the complete graph after notes/global-completion writes. A real filesystem obstruction after native save produces incomplete recovery; actual retry publishes all provenance and retains the original import's checkpoint. Imported removal history produces no fabricated applied operation. The test captures only the newly allocated edit timestamp when applying the independently specified edit to its expected graph.

## Final local checkpoint

The [Mac cohort](evidence/native-membership-consolidation/portable-v3-import-migration-final-mac/execution.json) and [iPhone simulator cohort](evidence/native-membership-consolidation/portable-v3-import-migration-phone/test-summary.json) each pass 97 functions across 52 suites, comprising 374 executed invocations. They cover the existing import/restoration matrix, genuine and skipped migrations, old replay, format-origin preservation, native recovery failures and the new provenance cases. Neither final run has failures, skips or SQLite lifetime diagnostics.

The [reconciliation](evidence/native-membership-consolidation/portable-v3-checkpoint-reconciliation.json) checks matching signatures and argument counts, all 797 Core inputs, all 1,134 project inputs used by the phone run and two actual test products per platform. Workspace and staged sources match. Every affected Swift file passes strict formatting. Frozen V1–V18 declarations, original fixtures and independent wire literals remain unchanged.

The earlier affected run fails four restoration arguments because their expected literals use the older header. Inspection of the [actual complete initial/final recovery artifacts](evidence/native-membership-consolidation/portable-v3-import-migration-affected-mac/legacy-header-comparison.json) proves that only formatVersion and the two empty arrays differ. Expected-grammar conversion is updated; original input fixtures and historical recovery-byte checks remain intact. Earlier failures retain their original status.

After verified host and SQLite closure, 423 marked fixtures from passing Mac phases and 367 from the final simulator phase are removed. Their original logs/results and frozen fixtures remain retained. The Mac cleanup records 259,740,055 nominal bytes; simulator reclaimed bytes are not measured. Failed fixtures remain available for diagnosis.

## Remaining contract work

- Qualify the nonempty-provenance combinations with Skip, legacy Overwrite, restored associations and historical aliases. Existing legacy restoration tests do not prove all new-metadata combinations.
- Implement shared canonical membership resolution, observed removal issuance for new Add/Remove/Move/Overwrite/Undo paths, and the approved legacy binding baseline. The original duplicate-membership query remains unresolved.
- Implement separate automatic-maintenance preparation, native commit evidence, recovery-envelope v2, status/retry/inspection and native recovery controls. This slice still publishes envelope v1 containing the new portable-v3 payload.
- Execute the frozen fingerprint vectors and implement the remaining affected-command fingerprint and versioned result/preparation evidence. Existing replay tests do not constitute execution of every new literal vector.
- Continue native refresh/compatibility and the broader map. Signed/shared storage, CloudKit convergence, physical interruption/performance, actual Mac UI, final whole-app polish and user acceptance retain their separate gates. Signing stays deferred.

No new policy answer blocks these local follow-ups. This checkpoint does not close Q155 or the implementation map.
