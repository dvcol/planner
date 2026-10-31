# Native labels during Item creation

Status: the human approved Q94 A on 17 October 2026, choosing adaptive native popover/compact-sheet selection. The failures below predate that approval; no production fix is qualified at this approval epoch. Signing remains deferred.

## Context and starting state

New Item already offers native Category and Tag selection, but existing native label journeys save the Item before selecting its labels through Edit. Those results do not prove label selection before the first save. The new journey exposes an unexpected leaving prompt immediately after returning from Categories on iPhone.

## Goal and expected end state

Choose existing shared labels in an ordinary New Item draft without a leaving prompt when returning from its picker. Explicit navigation away still offers Save, Discard and Keep Editing. Discard creates no Item. Save creates one Item with the chosen label identities. Relaunch retains that Item and those selections without copying the labels. Layout changes preserve the same draft.

## Definition of ready

The accepted shared-label model and approved production native UI test boundary define this check. It uses a disposable local dataset, real Settings and label management, native selection controls, Save, Discard and relaunch. It introduces no public API, persistence schema or test-only production seam. Q94 A now authorizes adaptive native popover/compact-sheet presentation; the existing native UI seam remains unchanged.

## Required tests and definition of done

- Create one Category and one Tag through Manage Labels, recording their visible stable identities.
- Select both in New Item, discard the edited draft and verify no Item was created.
- Returning from the Category picker must not present a leaving dialog or block the next Tag selection.
- Select both in another New Item and save. Verify exactly one matching Item and its complete row label summary.
- Relaunch, retain that Item identity and inspect both saved label selections against the original label identities.
- Compile the affected app/UI targets on both platforms, lint the affected files, and record actual native runtime outcomes and named Planner-window captures.
- Recheck explicit guarded navigation and the existing draft-resizing journey because a compact-column binding participates in both paths.

## Recorded diagnosis

The first iPhone invocation fails after 55.425 seconds when the Tag row produces no valid hit point. A bounded native Form-scroll probe also fails after 58.224 seconds. Inspection of that invocation's simulator recording shows the Save / Discard / Keep Editing dialog already present after Categories returns, before any attempted scroll. The speculative scroll helper is removed.

The sharper regression fails at the unwanted-sheet assertion after 47.578 seconds. Ignoring compact-column writes removes that prompt but fails Discard after 62.028 seconds. A direct native column binding also fails Discard after 62.699 seconds. A typed label-navigation path fails the complete lifecycle after 62.999 seconds. Moving the stack into a stable detail-column owner removes the draft but leaves the compact view on Choose an Item, with no New Item catalog control; two complete invocations fail after 60.311 and 63.652 seconds. None of these experiments qualifies the lifecycle.

The minimized global New Item → title → Back → Discard journey passes in 22.309 seconds on an intermediate diagnostic source without opening a label picker. That is diagnostic evidence only. The label-free minimized path did not reproduce the failure. It also omits Settings and label creation, so this comparison does not establish child navigation as the sole cause. Apple documents [data links and destinations for a stack inside a split-view column](https://developer.apple.com/documentation/swiftui/navigationsplitview); the observations do not establish an Apple-confirmed framework defect or a prohibited API use.

All experimental production changes and the pending regression source are restored to committed `16e0c66`. The pending-decision record retains the test source and the required Q94 choice. The options are an adaptive native label picker, inline disclosure groups, or continued repair of pushed label pages. The existing full New Item page/column remains accepted. No alternative presentation has been implemented while that decision is pending.

The recorded failing invocations receive no full-lifecycle pass credit. Compiler-only Mac checks receive no runtime credit. Historical source and product hashes identify their attempts; later builds may replace the live products. Independent List estimate qualification proceeds on restored production navigation.

This qualification does not close Mac runtime, List-specific creation-label coverage, physical sync/account/Share, accessibility, performance or whole-app polish gates.
