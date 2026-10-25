# Native source-restoration maintenance

Q157 A approves the [bounded contract](../native-source-restoration-maintenance-contract-review.md). The first implementation now retires unreferenced losing native candidates across Item, List, Itinerary, Category and Tag. It preserves the actual declared winner, content, timestamps, flags, family candidates, deletion history, unrelated data and original command receipts. This checkpoint is local qualification, not completion of broader restoration reconciliation.

## Implementation

`PlannerSourceRestorationConsolidation` identifies the actual smallest declared candidate lifetime and requires it to be present exactly once. Undeclared candidates, duplicate bindings, missing winners, conflicting authority and losing rows with relationships remain unavailable. The admission check reads persisted membership, entry, bookmark, Schedule and label bindings as well as relationship arrays. A nil SwiftData relationship does not authorize deleting a referenced source.

Ordinary Core maintenance first normalizes source rows, then runs existing membership maintenance. Both use the same durable preparation/native commit/recovery publication sequence. Source retirement declares sourceRestorationConsolidation rule1. Its complete proposed portable-v4 graph must validate before preparation; staged native data must match it before saving. Retirement does not issue source Delete or close a restoration family.

The logical writer gate advances to21. Physical model19, its migration plan and portable4 remain unchanged. Upgrade derives the source projection without retiring native rows, publishes the coherent baseline and metadata, then activates control21. Physical retirement follows in its separately prepared transaction. An interrupted activation no longer rewrites the newer recovery metadata back to the old control version before validating the projection.

## Executed checks

- The unchanged retained Item tracer fails under the previous production implementation and passes with this implementation. The successful export equals the entire original graph, including both candidate declarations.
- The five-kind checks preserve full exported data and original command receipts, declare the exact new evidence kind/rule, avoid repeated maintenance for unchanged reads, and issue distinct truthful maintenance after redelivery. Reopening preserves the same result.
- Unknown candidates, a missing winner, a bookmark scalar binding with a nil owner and a membership scalar binding with a nil Item all leave native lifetimes, control and every recovery byte unchanged.
- Real control20 inputs with duplicate source rows qualify ordinary activation, blocked recovery publication, blocked control activation and unproven projection. Share waits for main activation. A coherent published baseline has no retirement receipt and leaves both native rows present before activation. Retry preserves historical files and the exported graph.
- A failed durable preparation preserves both candidates. A committed retirement followed by an actual filesystem recovery obstruction blocks new commands; explicit maintenance Retry establishes recovery without rewriting old receipts, then the original waiting command can save.
- The affected Mac cohort passes [69 test functions across thirteen suites](evidence/native-membership-consolidation/native-source-restoration-recovery-final-mac/execution.json). The [remaining six affected migration suites](evidence/native-membership-consolidation/native-source-restoration-migration-regressions-mac/execution.json) pass six more functions. The [iPhone Simulator cohort](evidence/native-membership-consolidation/native-source-restoration-recovery-iphone/exit.json) passes52 functions across five suites. All complete without SQLite unlink warnings.
- A [genuine compatibility20 executable](evidence/native-membership-consolidation/native-source-restoration-old-writer-mac/execution.json) first writes successfully, retains its active session while current Core activates21, then rejects writes/query/export as staleDatasetSession. Cold older main/Share Core instances reject unsupportedVersion. Rejected attempts preserve canonical export and all control/recovery bytes. Frozen sources and both actual executables are verified. This is Core role qualification, not installed Share invocation.

The older-writer probe uses two ordinary Items; source-specific projection is qualified separately through actual native-input tests. Test inputs, frozen source roots, product digests, commands, logs and failures are retained in the linked packets. The initial sandbox cache refusal and two test-compilation errors are not passing runs. One intermediate recovery assertion incorrectly required an explicit empty maintenance array where the compatible baseline could omit it; the corrected assertion permits absence while still proving that no retirement preparation or physical retirement preceded activation.

## Remaining qualification

Source-specific actual process interruption before/after native save and around compatibility publication/activation is next. The shared membership transaction's existing process/save-failure tests pass, but they do not alone establish every new source-specific failure state. Matching native adapter builds/real HTTP, additional reference forms and independent-writer refresh remain to qualify.

Broader owned/inbound-reference rebinding, closed-family arrivals, authority reconciliation and other unresolved restoration graphs remain required on the map. Actual Mac interaction, installed Share, protected signed storage, CloudKit/account convergence, system Shortcuts and physical-device checks remain separate. Signing stays deferred.
