# Restore references within a self-contained incoming family

## Context and starting state

A complete backup can contain a restored Item, its closed predecessor and two authorized restoration candidates. Its live source uses the stable candidate lifetime, while a membership, label association or bookmark can still reference the other candidate. The portable contract permits those references within the same open family.

Decode accepts this valid backup, but applying it to an empty planner rejected the whole import with `readUnavailable`: “The label association has unresolved Item ownership.” Review normalized families already present in the planner and omitted families supplied only by the incoming backup. Native storage therefore received a dependency lifetime different from its actual source. The native fidelity check correctly refused that graph.

The required end state is a faithful complete restore with canonical live source bindings, original public identities, association lifetimes, order, completion and history. Recovery, reopen, exact operation replay and ordinary re-import must preserve that graph. The decoded input remains the original command payload.

## Definition of ready

Use the accepted portable-family rules and existing public Core test boundary: `bootstrap`, `decodeImport`, `prepareReview`, `execute`, `exportData`, `inspectRecovery` and reopen/replay. Reuse the existing complete portable fixture and its independent canonical expected export. No new public interface, test injection, package, target or format is needed.

This case has no competing current source. It does not require a choice about older-backup Overwrite or a newly delivered candidate competing with an existing live family. Q128 and Q129 remain pending.

## Correction

Review now considers both current and incoming families. When a source already exists, only the current graph can authorize its candidate resolution. When that source is absent, the self-contained incoming graph supplies that authorization. Existing graph resolution still rejects predecessor redirects and closed-family candidates. The existing normalization copies canonical dependency lifetimes into the import plan before projection and native storage.

No source selection rule, native fidelity guard, deletion policy or conflict mode is weakened. This does not consolidate competing family/history identities or adopt an unknown incoming candidate over a current owner.

## Required tests and definition of done

1. Reproduce rejection through the actual reviewed native import, without private storage inspection.
2. Restore the complete graph for each of Item, List, Itinerary, Category and Tag, under both Skip and Overwrite. Each case changes references to one nonselected authorized candidate while retaining the independently specified live source.
3. Compare the whole exported graph and acknowledged recovery copy with the canonical fixture. Reopen, replay the same operation and re-import without duplicate generation or graph changes.
4. Run the affected import and prior receipt-compatibility cohort on Mac and iPhone Simulator. Reconcile actual function/argument results, source inputs and products, then remove marked fixtures only after host/database closure.
5. Pass affected strict Swift, Markdown and whitespace checks. Keep native administration UI, physical convergence and broader reconciliation gates separate.

## Executed evidence

The [initial native-store tracer](evidence/navigation/core-incoming-family-empty-restore-red/) rejects the valid graph. Changing only family resolution makes the [same tracer pass](evidence/navigation/core-incoming-family-empty-restore-green/). The [expanded baseline](evidence/navigation/core-incoming-family-all-sources-red/) rejects all ten source-kind/mode cases. The [expanded correction](evidence/navigation/core-incoming-family-all-sources-green/) passes with identical test bytes. Storage and its fidelity guard are unchanged.

The final [Mac import run](evidence/navigation/core-incoming-family-import-regression-mac/) and [iPhone Simulator import run](evidence/navigation/core-incoming-family-import-regression-ios/) each pass 58 functions and 239 argument executions. The prior receipt cohort adds [two Mac functions](evidence/navigation/core-incoming-family-receipt-regression-mac/) and [two iPhone functions](evidence/navigation/core-incoming-family-receipt-regression-ios-xcode/), three executions per platform. Together, each platform passes 60 distinct functions and 242 executions, including the ten new cases, with no failures, skips or SQLite lifecycle diagnostics.

The first receipt follow-up's [preparation](evidence/navigation/core-incoming-family-receipt-regression-ios/) finds no retained xctestrun file and starts no test. The successful follow-up uses the ordinary existing Core Xcode scheme and cached products. That preparation failure receives no runtime credit.

The [qualification record](evidence/navigation/core-incoming-family-import-regression-mac/qualification.json) matches every function and argument count across platforms, all 740 Core inputs, all 1,062 native inputs and the executed products. The successful final runs dispose of 242 marked fixtures per platform after host/database closure. Focused green fixtures are also disposed safely. The eleven failed-baseline fixtures are separately disposed under the same ownership/closure checks; their original failures and logs remain retained.

These results complete the represented self-contained restore slice. They do not complete incoming-family consolidation, reference/history identity reconciliation, Q128/Q129, native import administration, signed storage or physical CloudKit acceptance. Whole-app visual review remains open.
