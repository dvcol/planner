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

At `b6bb0b8`, the first review slice was bounded to new owners and matching live lifetimes in a dataset without deletion markers. The subsequent slices below extend that boundary. Overwrite restoration and projected cross-owner graph/identity reconciliation retain their implementation gates. Q73 A is accepted in the [decision register](../open-decisions.md); its omitted-owner classification is qualified below. The review fingerprint currently covers the complete selected dataset. Precise stale-review binding, operation replay, atomic apply/recovery and native import forms remain separate implementation gates.

## Qualification and limits

The execution record retains functional red logs, the qualified source epoch, the package log and actual native result summaries/test trees. Red-source hashes were not captured and are not reconstructed. Mac package and iOS 27 simulator Core qualify 12 functions in 7 suites, 18 invocations, with zero failures/skips. Nine affected Swift files pass strict lint.

The initial scoped HTTP run executed only two bulk-review functions; its method-only selector omitted the parameterized administration test. The corrected three-suite run qualifies 14 functions, 19 invocations, with zero failures/skips, including all six native administration attempts. The actual Mac app/host compiles and executes authenticated HTTP; native Mac UI runtime remains zero. Schema 14 and portable format 1 remain unchanged.

The full preview Definition of done remains open. These read-only classifications do not prove import apply, faithful restore, independent recovery after importing, stale-review execution or physical convergence. Execute explicitly returns unavailable and applies no import. Native file import/recovery presentation, Calendar/estimate/archive-progress amendments and whole-app polish remain ahead.

## Deleted-data Skip review

Context and goal: At `b6bb0b8`, any current deletion marker prevented review. Accepted A13/A16 require keeping deleted X closed, skipping a complete new B requiring X/Z, and importing independent Z. This applies to owned Schedules and transitively dependent Itineraries. The goal is a truthful preview of those selected identities, without changing current content, markers or recovery acknowledgement.

DoR: Skip dependency handling, invalid-file rejection, minimal source/reference closures and the existing public Core/store/file seams are settled. Q73's omitted-owner mutation policy is separate: a declared new List using a known deleted external Item is a dependency case, rather than owned records mutating an omitted source.

DoD for this slice: a deleted incoming Item appears in skippedConflicts with deletedSource and no fabricated current content; complete new dependent Lists/Itineraries appear in skippedDependents with deletedDependency; independent sources remain imports. A closed owned Schedule blocks its entire new owner. Known deleted external bindings are distinguished from missing/wrong lifetime bindings. Review publishes no data, marker or checkpoint change.

Required /tdd and execution: actual public commands create/delete X before reviewing its older backup plus independent Z and new B/C. The initial unavailable marker gate supplies functional red. The unchanged declared-X tracer passes after dependency classification. A second tracer exposes a closed Schedule proposed under a new owner; indexing owned identity kinds/IDs prevents its addition. An external-X variant then exposes known deletion being reported as unknown; exact retained lifetime bindings now permit dependency classification, while an incorrect lifetime rejects the whole review at `/memberships/0/item/lifetimeId`. Transitive closure excludes every blocked owner's references, including its otherwise valid children. Matching live owners stay available to their dependents.

The deleted-data execution record retains those red logs, the captured external-red source epoch, qualified source epoch, package log and actual native summaries/test trees. Mac package and iOS simulator qualify 11 functions in 6 suites, 17 invocations; HTTP qualifies 14 functions in 3 suites, 19 invocations, including six administration attempts. All have zero failures/skips. Two affected Swift files pass strict lint; Mac app/host compiles, with zero native Mac UI runtime.

Schema 14 and portable format 1 remain unchanged. Overwrite into a dataset with deletion metadata still returns unavailable; explicit restoration/deletion impact, lineage persistence, projected cross-owner reconciliation, execute/replay/recovery and native forms remain open. These local read-only tests do not prove deletion wins against returning offline devices. Calendar/estimates, pending question choices, physical sync/account/Share and whole-app polish retain their gates.

## Incoming deletion conflicts under Skip

Context and goal: At `98e66a3`, an incoming source marker against live data returned unavailable. Live Schedule/reference/context targets could also appear as independent closures because lookup covered ordinary sources only. Accepted A16 requires Skip to preserve current live data and report the incoming deletion conflict. This manual-import rule does not replace R15's deletion-wins requirement for native synchronization.

DoR: A16, the complete-owner Skip rule, exact deletion-target/lifetime grammar and the existing public Core/store/file seams are settled. No choice from the pending question register is inferred.

DoD for this slice: every live source kind, Schedule, membership, route entry, owned link, label association and reachable expanded context resolves to its current owner. Skip reports matchingRecordConflict, before/after current summaries and exact marker input paths; it proposes no source/reference deletion. Independent new sources and absent-target closure metadata remain separately reviewed. Repeated markers or a represented-owner conflict consolidate into one owner entry without duplicated retained references. Saved graph and checkpoint remain unchanged.

Required /tdd and execution: a real Item with a saved link/Schedule meets incoming deletion metadata plus an independent Tag/absent-target marker. The unavailable live-source branch supplies red. Additional tracers expose a live Schedule treated as absent, an expanded context without a resolved owner and repeated-marker double counts. Lookup now indexes owned identities and verifies both parent lifetimes for expanded contexts, including logically reachable Todo contexts without stored flags. Owner conflict indexes merge every marker path while retaining current references once. Actual public-command fixtures cover all five ordinary source kinds and all declared reference-target kinds. A represented Item plus a Schedule marker preserves the full current owner and reports both source/marker paths.

The incoming-conflict execution record retains four functional reds, the captured first-red epoch, final source epoch, package log and actual native summaries/test trees. Mac package and iOS simulator qualify 14 functions in 7 suites, 31 invocations, with zero failures/skips. HTTP qualifies 14 functions in 3 suites, 19 invocations, including six administration attempts. Two affected Swift files pass strict lint; Mac app/host compiles, with zero native Mac UI runtime. The final Todo admission changes tests only; production hashes remain identical to the qualified HTTP run.

Overwrite deletion impact/restoration, full projected graph reconciliation, execute/replay/recovery, native forms and physical convergence remain open. Schema 14 and portable format 1 remain unchanged. This is a read-only review slice, not an applied import. No pending question choice is treated as accepted.

## Incoming deletion impact under Overwrite

Context and goal: At `61303c3`, Overwrite rejected incoming closures against live records because their deletion impact was unavailable. Accepted A16 requires an explicit impact before replacing live data with incoming deletion metadata. The goal is to show the actual source/reference closure and surviving owner, using the same current dataset as native Delete. Review remains read-only; this slice does not implement import application.

DoR: confirmed source deletion, container-only deletion, reference/context lifetimes, whole-owner Overwrite and the public Core/store/file test seams are settled. Q73's omitted-owner mutation policy and the other eight open choices remain pending. Incoming closure metadata is distinct from importing owned records with an omitted source owner.

DoD for this slice: every live Item/List/Itinerary/Category/Tag, Schedule, membership, itinerary entry, owned link, label association and reachable expanded context has explicit incomingDeletions impact. Root deletion reports its owned/dependent removals and preserves shared sources. Association deletion preserves its owner and reports dependent saved expanded contexts. A logical Todo expanded context remains reviewable without a stored flag. Repeated exact targets merge their input paths; overlapping source/reference impacts appear once. A surviving owner's after summary reflects both the incoming replacement and selected deletion. Saved export bytes and the acknowledged recovery checkpoint remain unchanged.

Required /tdd and execution: the Item tracer first failed at the unavailable live-deletion gate. Native deletion resolvers now supply the complete closure. A shared Item/List/Itinerary/label graph then exposed the remaining named-source gate; the same resolvers cover each kind while literal counts verify three List, seven Itinerary and two label removals. Schedule and reference tracers exposed their unavailable paths. The current validated store projection resolves those exact lifetimes and their dependent expanded contexts. Repeated/overlapping markers exposed doubled sources/references and a surviving-owner summary after root deletion. Native identity sets now retain each removal once and derive the complete selected owner outcome. A combined title replacement/Schedule deletion exposed the old title in the after summary; that summary now uses the selected incoming owner content.

One initial reference tracer failed to compile because it nested Swift Testing require macros. The corrected fixture reached the functional unavailable failure. The compilation failure is not counted as a red behavior test or runtime qualification.

The Overwrite execution record retains six functional red logs, the qualified source epoch, package log and actual simulator/HTTP summaries and test trees. Red-source hashes were not captured and are not reconstructed. Mac package and iOS simulator qualify 17 functions in 8 suites, 47 invocations. HTTP qualifies 14 functions in 3 suites, 19 invocations, including all six administration attempts. All have zero failures/skips; four affected Swift files pass strict lint. The final checkpoint assertions change tests only, with production hashes identical to the qualified HTTP run. Mac app/host compiles; native Mac UI runtime remains zero.

At `8e3ae98`, Overwrite review still required a current dataset without deletion metadata. The refinement below removes that broad gate while retaining explicit restoration boundaries. Complete projected cross-owner identity reconciliation, precise stale-review execution, atomic apply/recovery, replay and native import/recovery forms remain open. Schema 14 and portable format 1 remain unchanged. Local read-only review does not prove native synchronization's deletion precedence or physical convergence. Calendar/estimates/archive-progress amendments and whole-app polish remain ahead.

## Overwrite review after unrelated deletion

Context and goal: At `8e3ae98`, deleting any record made every Overwrite preview unavailable. A current Tag change could not be reviewed after deleting an unrelated Item. The goal is to keep ordinary live-owner previews available while retaining the separate deleted-identity restoration gate.

DoR: whole-owner Skip/Overwrite, explicit deleted-identity restoration, preserving independent imports and complete dependency skips are settled. Current deletion metadata is data, not a reason to disable unrelated administration. The existing public Core/store/file seams remain sufficient; no pending choice is inferred.

DoD for this slice: a real unrelated Item deletion leaves a current Tag replacement reviewable, with its before/after names and retained closure metadata. A declared deleted source remains unavailable under Overwrite at its source path until restoration lineage/impact is implemented. A closed owned identity also requires restoration rather than being silently treated as a Skip conflict. File-external known deleted dependencies still skip complete new dependent owners while leaving independent imports reviewable. Missing/wrong lifetime admission remains unchanged. Data and recovery checkpoint remain unchanged by review.

Required /tdd and execution: the unrelated-deletion tracer reached the global unavailable gate. That gate is now scoped to represented deleted sources. A second tracer exposed Overwrite treating a closed Schedule as a skipped dependent owner; closed owned identities now report the unresolved restoration impact at their exact input path. The existing actual-deletion fixture also checks declared-source restoration admission and independent external-dependency review in Overwrite.

The admission execution record retains both functional red logs, the captured first-red source epoch, final source epoch, package log and actual native summaries/test trees. The second red epoch was not captured. Mac package and iOS simulator qualify 18 functions in 8 suites, 49 invocations; HTTP qualifies 14 functions in 3 suites, 19 invocations, including six administration attempts. All have zero failures/skips. Two affected Swift files pass strict lint. The Mac app/host compiles; native Mac UI runtime remains zero. Review changes neither exported bytes nor the acknowledged checkpoint.

This refinement implements preview admission, not restoration or import application. Restoration families, projected graph/identity reconciliation, exact execution/replay/atomic recovery and native forms retain their gates.

## Omitted-owner records under Skip and Overwrite

Context and goal: At `b479427`, the decision batch is settled, but incoming owned records whose source owner is omitted still make review unavailable. Q73 A requires keeping that owner and its owned data in both modes, reporting those incoming records as skipped and continuing to review independent sources. Replacing an owner requires its source record in the file.

DoR: Q73 A, whole-owner preservation, exact binding/lifetime admission and the public Core/store/file seams are settled. The accepted rule applies to links, schedules, label associations, memberships, route entries, expanded states and their completion history. A declared new List using a current external Item remains an independent accepted case.

DoD for this slice: one skippedConflicts entry per omitted owner has reasonCode omittedOwner, exact incoming paths and unchanged current before/after summaries. Identical partial records are also skipped because their owner is omitted. A known deleted owner stays closed, with no fabricated content summary. Incoming records for an omitted owner do not enter the restoration path. Independent sources and eligible declared owners keep their normal classifications. Current references, local/global completion, metadata, saved export bytes and recovery checkpoint remain unchanged. Missing/wrong bindings continue to reject the whole review.

Required /tdd and execution: the live-owner tracer failed at the pending-policy gate for both modes and identical/changed incoming values. Grouped omitted-owner classifications now preserve current records and retain their reference identities. A second actual-deletion tracer exposed the closed-Schedule restoration gate and the missing deleted-owner summary. Restoration admission now applies only to represented owners; already-validated external bindings identify closed omitted owners without restoring them. Actual Item/List/Itinerary fixtures qualify labels, links, schedules, memberships, route entries, expanded completion, aliases and explicit completion changes. Exact source/lifetime admission and represented restoration gates still pass.

The expanded-history fixture initially used an unsupported nested context property. The public decoder correctly rejected it at `/contextAliases/0/context/context`. The corrected flat context uses the declared grammar. Those fixture failures are excluded from functional red and runtime qualification.

The Q73 execution record retains both functional reds and captured source epochs, final source epoch, package log and actual native summaries/test trees. Mac package and iOS simulator qualify 21 functions in 9 suites, 61 invocations. HTTP qualifies 14 functions in 3 suites, 19 invocations, including six administration exclusions. All have zero failures/skips; two affected Swift files pass strict lint. The Mac app/host compiles; native Mac UI runtime remains zero. Schema 14 and portable format 1 remain unchanged.

Import application/restoration, complete projected graph reconciliation, execution/replay/atomic recovery and native administration forms remain open. The other eight accepted decisions unlock their implementation and qualification; this Core review slice does not complete those native UI, aggregate/calendar, loading or physical-device gates.
