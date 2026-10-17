# On-demand existing-Item picker loading

Status: on-demand loading and the targeted state regressions pass on both simulators within the source epochs below. Mac compilation passes. Signing, Mac runtime and Q94 labels remain separate.

## Context and starting state

The main native store retains a complete active-Item candidate array used only by Add existing Item. Opening Planner fills it before readiness finishes. Ordinary Item creation, global completion, Archive/Unarchive and import refresh that array even when the picker is closed. The actual Item catalog issues its own query, and itinerary selection already loads its own candidates. This eager cache performs unnecessary reads and retains a second full candidate collection.

## Goal and expected end state

Move candidate loading into the existing native Add Item Form. Opening the picker queries current active Items, shows native loading or a truthful failure/retry state, and permits Add only for a surviving candidate from that loaded result. Cancel creates no membership. Candidate ownership is scoped to the Form rather than the persistent store. App opening and unrelated mutations no longer read or retain that candidate array. The native catalog's separate complete-result accumulation remains a later moving-window task.

## Definition of ready

The native UI and public Core query/read seams are already approved. The existing membership journey uses a disposable local dataset and the actual New Item, New List, Add menu, picker, Cancel, Add and relaunch flows. The change introduces no Core command/query, persistence schema, agent contract, query-generation eviction, dependency or test-only production parameter. Candidate selection remains active Items with the existing sorting policy.

## Required tests and definition of done

Run the existing native membership journey before and after the change. It creates a source and List, selects then cancels, relaunches with an empty List, adds the existing source, repeats Add without duplication, and relaunches with one membership and one global source. Compile affected app/UI targets on Simulator and Mac, run strict changed Swift/report lint and inspect original own-window evidence. Check every cache/refresh caller before deleting it. Source reviews must preserve mutation outcomes and matching UI behavior.

This is a read/retention optimization preserving the user-visible successful workflow, so an invented missing-feature red is inappropriate. Record actual baseline and changed-source outcomes separately. Do not infer a RAM reduction, latency guarantee, full catalog moving-window implementation or physical performance acceptance from source deletion or function duration. Read-failure, cancellation and ownership/history guards remain required; any unqualified adversarial native branch is stated explicitly.

## Baseline controller observation

The original phone membership function fails in 27.982 seconds before opening the picker. Its helper requires Show Sidebar after selecting Lists; it does not support the compact Back path already handled by the newer native journeys. This is an original-controller result with unchanged production loading, not an optimization red. The helper is updated to use the established native section selector and bounded sidebar/Back navigation. Required membership outcomes remain unchanged. The corrected-controller phone baseline passes in 90.343 seconds before production changes. It retains the original membership assertions; the later strengthened identity checks receive their own changed-source qualification.

## Applied change and regression scope

Candidates now belong to the native Form. A lifecycle-bound query uses the dataset namespace, saved revision and explicit Retry identity; canceled or superseded results cannot publish. Add requires a surviving selection from that loaded result. Native loading, empty and failure/Retry presentations remain distinct. The persistent store no longer owns this candidate array, and all five refresh callers are removed without changing saved-mutation results, recovery handling or changeRevision publication. The ordinary catalog, itinerary picker and label/List paths retain their existing reads.

The membership journey now also records and compares the original global source identifier and contextual membership identifier through repeated Add and relaunch. Because the removed cache was also refreshed after global completion and Archive, run the existing native global/contextual completion and Archive/Unarchive catalog journeys as targeted regressions. This remains a read/retention optimization, with no Core/schema/HTTP or query-generation-lifetime change.

## iPad toolbar compatibility

The first changed-production iPad batch passes both state-regression functions, then fails membership setup in 33.653 seconds before opening the picker. Its own-app hierarchy shows the Lists catalog and a native `OverflowBarButtonItem`, with no direct New List or Back button. The test's sidebar/Back-only helper cannot open the compact toolbar action. Use the observed native overflow and require its exact New List menu action, following the already qualified estimate journeys. This changes only the test controller. The three production files and the executed state-regression source remain byte-identical.

The failed whole invocation remains failed in the evidence index. Its two literal function passes are retained as scoped regression evidence, never represented as an all-pass batch. The final membership controller receives its own phone and tablet invocations. There is no retry that silently replaces the failed result.

## Recorded results

| Boundary | Result | Source and scope |
| --- | --- | --- |
| Original phone controller | Failed, 27.982 seconds | Unchanged production; cannot reach picker. |
| Corrected phone baseline | Passed, 90.343 seconds | Before production optimization and before stronger identity assertions. |
| Earlier on-demand phone membership | Passed, 87.040 seconds | Current production, stronger identity assertions, prior overflow controller. |
| Final iPhone membership | Passed, 90.875 seconds | Final source and overflow-aware controller, zero failures/skips. |
| Final iPad membership | Passed, 104.442 seconds | Final source and overflow-aware controller, zero failures/skips. |
| Phone Archive/Unarchive | Passed, 60.185 seconds | Current production and unchanged executed regression source. |
| Phone contextual/global completion | Passed, 206.163 seconds | Same production epoch; whole two-function invocation passes. |
| iPad Archive/Unarchive | Passed, 57.771 seconds | Same production and unchanged executed regression source; initial batch also has the controller failure above. |
| iPad contextual/global completion | Passed, 198.576 seconds | Same qualified function scope, not an all-pass batch claim. |
| Final mobile and Mac app/UI compiler | Passed | Mac compilation only. |

Each membership pass checks cancellation without a membership, repeated Add without duplication, one global source and one contextual membership through relaunch. The strengthened final controller also compares the actual original source identifier and membership identifier across those operations. Native state regressions exercise the mutation paths whose unnecessary refreshes were removed. Import refresh removal is source-reviewed only; this slice supplies no new native import runtime qualification.

## Evidence and remaining gates

[The evidence packet](evidence/navigation/native-item-picker-loading/) preserves original exits, logs, compiled/current source hashes, compiler products, controller failures, actual observed identities and original own-window PNGs. The final builds record 945 inputs and six products per platform. Each runtime records 469 source/configuration inputs. The audit distinguishes final-source membership runs from earlier state runs, whose only current-source difference is the unexecuted membership controller file. It verifies that production and the executed state-regression source match exactly.

Twelve original named PNGs were inspected individually, including the historical baseline capture. Final-source membership captures and production-identical regression captures are marked separately in the visual index. Original captures show the single retained membership, local/global completion presentations, and valid selected details through archive filtering. These are workflow observations, not a whole-app visual acceptance pass. The [Capture qualification](native-capture-estimate-shortcuts.md) links Itinerary shortcuts, rich-draft rotation/relaunch, Item/List estimates and earlier layout evidence, each retaining its own source epoch.

No Core command, schema, agent or HTTP behavior changed. No Core or HTTP suite is rerun or credited here. The Form's provider failure/Retry, delayed cancellation/supersession and archived-candidate exclusion have source guards but are not adversarially qualified by these successful journeys. No measured memory or latency improvement is claimed. The picker still reads its complete candidate result while open. Native catalog moving windows remain proposed in [Q95](../native-item-window-contract-review.md); Q84 Core generation lifetime remains unchanged.

Mac runtime, physical devices, signing, account transitions, CloudKit convergence, Share, accessibility, large-catalog memory, scroll hitches and physical latency stay open. Q94 label presentation still needs a human choice. Whole-app polish with native SwiftUI components follows feature completion. No issue or whole-map gate is closed by this slice.
