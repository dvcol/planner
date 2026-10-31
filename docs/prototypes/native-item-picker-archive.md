# Existing-Item picker after Archive and Unarchive

Status: corrected native journey passes on both simulators. Mac compilation passes. Q94 label presentation and Q95 catalog-window review remain independent and unanswered. Signing remains deferred.

## Context and starting state

The [on-demand picker](native-item-picker-loading.md) removed the persistent candidate cache and qualified successful membership, cancellation and state-mutation workflows. Its report explicitly leaves archived-candidate exclusion outside native runtime qualification. The separate Archive test operates on the Item catalog, not the candidate picker. Those results do not establish the picker's empty result or its fresh candidates after Unarchive.

## Goal and expected end state

Create a shared Item with notes through native controls and archive it. A new empty List's loaded Add existing Item picker excludes that source, shows its loaded empty state and disables Add. Cancel keeps the List empty. Find the original Item through the Archived catalog filter and unarchive it. Reopening the picker then offers that Item, without restarting Planner or creating another source. Explicit selection enables Add. Relaunch preserves one source, one List and one membership, their observed identities and the original notes.

## Definition of ready

Use the already approved production native UI seam, a disposable local dataset and the accepted active-only candidate and independent archive rules. Existing New Item, New List, native Add menu, filter, Archive/Unarchive, Add/Cancel and relaunch controls supply the inputs and observations. There is no new production seam, public contract, schema, dependency or signing requirement. This qualifies existing behavior; it does not manufacture a missing-feature red.

## Required tests and definition of done

- Exclude the archived source only after the empty-result description appears, so a transient loading state cannot satisfy the absence assertion.
- Verify Add disabled before selection in both empty and populated pickers. Cancel creates no membership.
- Select the actual original archived source identity through the native catalog filter, then Unarchive and reopen the picker without relaunch.
- Add once and compare the observed source, List and membership identities through relaunch, with one source, one membership and unchanged notes.
- Build affected app/UI targets for Simulator and Mac, run the focused journey separately on iPhone and iPad, inspect the original native captures and run affected strict Swift/report lint.
- Preserve failed/controller epochs, source/product hashes and the exact native function outcomes. Mac compiler success supplies no runtime credit.

Core and HTTP behavior are unchanged. Broader failure/Retry, delayed result, dataset-transition, loading performance and accessibility qualification remain separate. The picker still accumulates the complete active candidate result while open; Q95 has not been implemented.

## Native observation and copy correction

The original workflow passes on iPhone in 127.596 seconds and iPad in 115.624 seconds, each with one function and zero failures or skips. These are pre-copy workflow results, not final-source qualification. Their original own-window captures show that the archived source is absent, Add is disabled, the source becomes selectable after Unarchive, and retained contextual details show its notes after relaunch.

Inspection also exposes a misleading empty state: the picker says No Items yet even though the fixture contains an archived Item, and its remedy mentions only creating another Item. The correction changes the native title to No active Items and mentions Unarchive alongside creation. Filtering, commands, persistence and loading stay unchanged. The test's existing loaded-state wait uses the corrected description; no new test-only control is introduced. This is a direct text correction supported by the actual native captures, not a claim of a newly failing functional or performance regression.

Final-source compiler and native workflow results are recorded separately from those original observations. Q94/Q95 remain unanswered and unchanged.

## Final source qualification

The corrected iPhone journey passes in 120.747 seconds, with one function and zero failures or skips. Its three original named captures were inspected individually. They show the No active Items title and Unarchive guidance with Add disabled, the previously archived source in the reopened picker before selection, and retained contextual notes after relaunch. The corrected iPad journey passes in 115.698 seconds, also with one function and zero failures or skips. All twelve original named captures were inspected individually, with six pre-correction captures distinguished from the six final captures. The final iPad screenshots show the same corrected empty state, native candidate selection and retained List/details layout.

| Boundary | Result | Scope |
| --- | --- | --- |
| Corrected iPhone native journey | Passed, 120.747 seconds | Final source, one function, zero failures/skips. |
| Corrected iPad native journey | Passed, 115.698 seconds | Same final source and checks, zero failures/skips. |
| iOS Simulator app/UI compiler | Passed | 945 inputs and six products; no physical-device credit. |
| Mac app/UI compiler | Passed | 945 inputs and six products; compiler evidence only. |

Each final native invocation freezes 469 source/configuration inputs and six products. Both original and corrected epochs remain indexed independently. No Core command, query, schema, HTTP or import behavior changes, so no Core/HTTP suite is rerun or credited by this slice.

Both corrected app/UI compiler targets pass, including the local ad hoc Mac build. Compiler success supplies no Mac runtime credit. Final source records include the two-string production correction and the one native test function; source reviews found no remaining source/controller finding. The decision-register review also corrected Q89's selected-entity and unselected-row qualifiers, preserving ordinary reference-removal behavior.

## Evidence and remaining gates

The evidence packet retains exact exits, logs, original named captures, observed identity attachments and source/product hashes. Before and after the text correction are separate source epochs. Current compiler inputs and final runtime inputs are compared with the repository before commit. Original workflow passes are not substituted for the final native invocations.

This successful workflow closes the specifically recorded archived-candidate exclusion and reopen-after-Unarchive gap. It does not qualify a candidate becoming archived while an already open picker has a selected row, delayed cancellation, read failure/Retry, dataset transitions, performance or accessibility. The picker still reads all active candidates while open. Mac runtime, signed physical devices, CloudKit/account/Share and whole-app native polish remain open. No issue or whole-map gate closes here.

The [decision register](../open-decisions.md) now distinguishes accepted Q88-Q93 from pending Q94/Q95, retaining selected/unselected deletion and ordinary reference-removal rules. The [previous picker report](native-item-picker-loading.md) links earlier completion, creation, estimate and resizing evidence. Calendar inspector resizing can proceed independently of the two pending decisions.
