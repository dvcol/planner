# Dataset-bound import review

## Context, before and goal

At `d753e4e`, bytes-only decode validates complete portable files and records external bindings. Core has no native applyImport command or dataset-bound preview. The approved [portable contract](../portable-data-contract.md#native-import-delete-and-recovery-forms) defines Skip/Overwrite, eight impact categories, complete-owner preservation, explicit restoration/deletion impact and a fresh review after relevant changes.

The goal of this slice is a real selected-dataset review of the whole decoded graph, retaining source/reference lifetimes and exact input paths. Review applies no data, publishes no checkpoint and remains a native administration action. Application, restoration/lineage persistence and native import forms retain their implementation gates; this preview cannot stand in for a completed import.

## Definition of ready

- The existing Core prepareReview/read/export/status facade and actual store/file I/O are approved test seams. No private model query or test-only injection is added.
- Input is native applyImport with an immutable PlannerDecodedBackup and Skip by default, or explicit Overwrite. Impact has exactly the declared imports, unchanged, skippedConflicts, skippedDependents, replacements, restorations, incomingDeletions and referenceChanges arrays.
- Structural dependency failures reject the whole preview with useful input paths. Mode conflicts preserve whole current owners in Skip; Overwrite reviews represented replacements and retains omitted data.

## Definition of done and required /tdd

- The independent full portable fixture in an empty store reviews seven source owners, all fifteen ordinary/expanded references and one incoming closure without applying any source or changing recovery status.
- Valid file-external bindings resolve against the authorized current store; missing/wrong lifetimes fail at their input paths. Foreign/stale sessions, unreadable stores and changed current records receive scoped failures.
- Actual export/reopen fixtures prove unchanged owners, Skip/Overwrite conflict classifications, full association/order/local-state summaries, independent records and complete dependency skips. Deleted identities/restorations and incoming closures receive explicit impact.
- Native app/host compilation, focused Core/native/HTTP checks and affected lint pass. The map keeps write, migration, replay/recovery, physical convergence and native form gates open until their actual tests pass.

## Execution

Approved values and unavailable review/write declarations made the first failure executable behavior. The independent complete fixture then passed without any data or checkpoint change. A second tracer failed because a nonempty dataset could not be reviewed; identical actual exports now classify their complete owners as unchanged, including local membership state.

Skip/Overwrite tracers initially failed at the unavailable conflict branch. They now distinguish complete current-owner preservation from proposed whole-owner replacement, import an independent new Item, report retained/removed/added references and leave an omitted current Tag untouched. Completion aliases and changes belong to their context owner. An incoming alias with unchanged displayed completion initially went unnoticed; review now reports that history difference and its exact input path.

The global-impact tracer exposed Skip claiming to change a preserved global Done flag. Impact now follows the selected imports/replacements. Native tagged values compare source content, timestamps/origins, complete owned collections, ranks, local flags and completion history. They do not use JSON serialization as a fingerprint. Actual external-reference admission covers a new List using a current Item, a missing ID and a wrong lifetime, without shortening the owner or writing data.

An early added test referenced another file's private helpers and did not compile. Its corrected public-facade setup reached the genuine unavailable review failure. That compilation attempt contributes no runtime evidence.

At `b6bb0b8`, the first review slice was bounded to new owners and matching live lifetimes in a dataset without deletion markers. The subsequent Skip slice below extends that boundary. Overwrite restoration, incoming association/context closure impact and projected cross-owner graph/identity reconciliation retain their implementation gates. Q73 asks what to do with owned records whose source owner is omitted from the file; that decision remains pending in the [stable question register](../open-decisions.md). The review fingerprint currently covers the complete selected dataset. Precise stale-review binding, operation replay, atomic apply/recovery and native import forms remain separate implementation gates.

## Qualification and limits

The [execution record](evidence/navigation/core-native-import-review/execution.json) retains functional red logs, the qualified source epoch, the package log and actual native result summaries/test trees. Red-source hashes were not captured and are not reconstructed. Mac package and iOS 27 simulator Core qualify 12 functions in 7 suites, 18 invocations, with zero failures/skips. Nine affected Swift files pass strict lint.

The initial scoped HTTP run executed only two bulk-review functions; its method-only selector omitted the parameterized administration test. The corrected three-suite run qualifies 14 functions, 19 invocations, with zero failures/skips, including all six native administration attempts. The actual Mac app/host compiles and executes authenticated HTTP; native Mac UI runtime remains zero. Schema 14 and portable format 1 remain unchanged.

The full preview Definition of done remains open. These read-only classifications do not prove import apply, faithful restore, independent recovery after importing, stale-review execution or physical convergence. Execute explicitly returns unavailable and applies no import. Native file import/recovery presentation, Calendar/estimate/archive-progress amendments and whole-app polish remain ahead.

## Deleted-data Skip review

Context and goal: At `b6bb0b8`, any current deletion marker prevented review. Accepted A13/A16 require keeping deleted X closed, skipping a complete new B requiring X/Z, and importing independent Z. This applies to owned Schedules and transitively dependent Itineraries. The goal is a truthful preview of those selected identities, without changing current content, markers or recovery acknowledgement.

DoR: Skip dependency handling, invalid-file rejection, minimal source/reference closures and the existing public Core/store/file seams are settled. Q73's omitted-owner mutation policy is separate: a declared new List using a known deleted external Item is a dependency case, rather than owned records mutating an omitted source.

DoD for this slice: a deleted incoming Item appears in skippedConflicts with deletedSource and no fabricated current content; complete new dependent Lists/Itineraries appear in skippedDependents with deletedDependency; independent sources remain imports. A closed owned Schedule blocks its entire new owner. Known deleted external bindings are distinguished from missing/wrong lifetime bindings. Review publishes no data, marker or checkpoint change.

Required /tdd and execution: actual public commands create/delete X before reviewing its older backup plus independent Z and new B/C. The initial unavailable marker gate supplies functional red. The unchanged declared-X tracer passes after dependency classification. A second tracer exposes a closed Schedule proposed under a new owner; indexing owned identity kinds/IDs prevents its addition. An external-X variant then exposes known deletion being reported as unknown; exact retained lifetime bindings now permit dependency classification, while an incorrect lifetime rejects the whole review at `/memberships/0/item/lifetimeId`. Transitive closure excludes every blocked owner's references, including its otherwise valid children. Matching live owners stay available to their dependents.

The [deleted-data execution record](evidence/navigation/core-native-import-deleted-review/execution.json) retains those red logs, the captured external-red source epoch, qualified source epoch, package log and actual native summaries/test trees. Mac package and iOS simulator qualify 11 functions in 6 suites, 17 invocations; HTTP qualifies 14 functions in 3 suites, 19 invocations, including six administration attempts. All have zero failures/skips. Two affected Swift files pass strict lint; Mac app/host compiles, with zero native Mac UI runtime.

Schema 14 and portable format 1 remain unchanged. Overwrite into a dataset with deletion metadata still returns unavailable; explicit restoration/deletion impact, lineage persistence, projected cross-owner reconciliation, execute/replay/recovery and native forms remain open. These local read-only tests do not prove deletion wins against returning offline devices. Calendar/estimates, pending question choices, physical sync/account/Share and whole-app polish retain their gates.
