# Competing restored values under a current live owner

Status: Q149 A has a local real-store implementation checkpoint. Native administration, matching iOS execution and remaining lineage qualification are still open. [Approved contract](../import-competing-candidate-values-contract-review.md).

## Behavior

Explicit manual Overwrite can now copy a competing restored source's represented values onto the current live source. A new represented List, Itinerary or label association can bind to that retained source. The complete current restoration family remains; the incoming candidate and competing family are not admitted. Skip, omitted-owner state and other import authorization rules retain their behavior.

The internal review projection verifies the authorized closed predecessor, known candidate/family provenance and source-closure metadata before normalizing the selected bindings. Other incoming family history must match retained history. A new closure of the current source is rejected. Owned references and contextual histories still pass through their existing collision, restoration and persistence guards. No public type, wire format, schema, package, target, agent administration action or test hook is added.

## Executed local evidence

The first tracer creates an Item, actually deletes/restores it, creates a separate locally Done List appearance and imports a competing candidate plus Tour and an independent Tag. The valid backup first fails at `/sources/0/lifetimeId` with `unavailable`. After the review projection correction, the same test bytes pass. Complete export, acknowledged recovery, omitted membership/history, reopen, exact operation replay and unchanged reimport are checked. [Original red](evidence/native-import-competing-values/competing-values-real-store-red/execution.json), [first green](evidence/native-import-competing-values/competing-values-real-store-green/execution.json).

The next [four-case matrix](evidence/native-import-competing-values/competing-values-family-order-matrix/boundary-validation.json) qualifies both candidate orders with shared and competing family IDs. A valid shared-family backup whose canonical source is already current B still binds its explicitly represented D-dependent Tour to B without admitting D.

The [all-kind matrix](evidence/native-import-competing-values/competing-values-source-kind-qualified/boundary-validation.json) passes twenty cases across Items, Lists, Itineraries, Categories and Tags. It checks membership, route, label, bookmark and Schedule bindings against complete expected graphs. Known-provenance disagreement, an omitted source's unknown external binding and newly closing the current source each reject the whole action. Real unwritable recovery storage rejects before application; an actual post-save obstruction returns applied/incomplete, then repairs to the same result and exact graph. Reopen, replay and duplicate-free reimport also pass. An earlier unsupported three-sequence Swift Testing macro fails compilation and starts zero tests; its failed packet is retained.

The [affected Mac cohort](evidence/native-import-competing-values/competing-values-affected-mac/boundary-validation.json) passes 80 functions in 38 suites, including 316 marked fixture invocations. All 757 Core inputs match the frozen source, both product hashes are verified before reuse, and no SQLite lifetime diagnostic appears. The existing verifier removes only those 316 marked disposable stores after the test host and handles close. It separately removes the four-case and twenty-case matrix stores. User datasets and native UI datasets are retained.

## Remaining gates

Qualify the same affected functions on the iPhone Simulator and the representative native file review/apply/export workflow on phone/dark iPad. Extend the explicit competing-value workflow through older retained lineage before closing that part of Q149. Actual Mac interaction, automatic family synchronization/consolidation and physical account/CloudKit convergence retain their separate gates. No signing or account setup is performed for this checkpoint.
