# Native narrow-List toolbar compatibility

Status: the narrow-pane correction and represented native control/drag journeys pass locally. Intermittent gesture stability, actual Mac UI and final polish remain open. Q113 A already keeps Filters and Add direct in compact layouts, with View, Sort, Edit and List actions in native More. The new Items/Inbox correction uses actual pane width. A regular-size-class iPad can still have a narrow List pane, where the selected List currently uses too many direct controls.

## Existing boundary and expected outcome

Extend the existing native title/Add journey to require the published Add control to be directly hittable before opening any overflow. Reproduce the failure on dark iPad before changing production. Reuse native ToolbarOverflowMenu when the actual List pane is narrow, preserving the ordinary direct controls in wide panes and Mac. Keep the accepted content title, filters, source/appearance identities, local completion and saved order.

Qualify title/primary-action visibility and real More-menu interactions through the existing production-source fixture boundary on phone/tablet, then run the affected native drag/selection journey and Mac compiler checks. No Core/MCP contract, target, package, test hook or account signing setup is introduced. Whole-app polish and actual Mac/physical acceptance remain separate gates.

## Reproduction and minimal correction

The [initial dark-iPad function](evidence/native-list-toolbar-compatibility/list-toolbar-dark-tablet-direct-add-red/boundary-validation.json) fails in 21.166 seconds because the published Add control is not directly hittable. The captured 340-point List pane displays Filters, View and Sort, while Add is hidden in automatic overflow. The original capture is inspected. The initial test also assumed that a wide device always has direct Sort/Edit controls. Remove that assumption; their existing dedicated native More-menu journey verifies reachability independently.

The [final tracer before production changes](evidence/native-list-toolbar-compatibility/list-toolbar-dark-tablet-pane-contract-red/boundary-validation.json) fails at the same direct-Add assertion in 20.092 seconds. The minimal production correction measures the actual selected-List pane with SwiftUI `onGeometryChange`. A narrow pane reuses the existing native More group, keeping Filters and Add direct. Wide panes and Mac retain their existing ordinary controls. No content title, command or data behavior changes. The final tracer's bytes stay unchanged for the first green execution.

## First passing pane qualification

The [dark-iPad cohort](evidence/native-list-toolbar-compatibility/list-toolbar-dark-tablet-pane-green/boundary-validation.json) passes the unchanged title/direct-Add tracer in 24.782 seconds and the dedicated native More-menu journey in 122.075 seconds. Add-existing opens and cancels; Sort changes order, non-Manual disables Edit, Manual restores Edit, Edit/Done preserves the original row identities/order, and List editing cancels. Both original final captures are inspected. The complete content title remains readable; the compact inline title still truncates, a separate final-polish observation.

The [tracer comparison](evidence/native-list-toolbar-compatibility/tracer-comparison.json) verifies identical tracer bytes and only one changed production input between the final red and first green. It also verifies matching Mac inputs and all nine retained compiler products. Mac build-for-testing passes in 21.356 seconds, with compiler credit only. Phone regression and filtered production drag/relaunch qualification remain in progress.

## Phone controls

The [light-phone cohort](evidence/native-list-toolbar-compatibility/list-toolbar-light-phone-pane-green/boundary-validation.json) passes the same two functions in 93.443 and 49.711 seconds. The complete inline title fits beside direct Filters/Add and native More, including after actual app relaunch. All three original phone captures are inspected. This retains the accepted separate content heading and does not close the final duplicate-title/spacing polish observations.

## Production drag diagnostic

The [first production filtered-drag journey](evidence/native-list-toolbar-compatibility/list-toolbar-phone-filtered-drag/boundary-validation.json) fails at the required Cafe-before-Museum order in 136.545 seconds. Its inspected before/after captures show visible native reorder handles, a closed More menu and unchanged row order. This is not a passing reorder result or proof of a toolbar cause. The earlier [local continuation report](native-local-continuation.md) also retains intermittent native gesture failures, but that history does not establish this execution's cause.

Use the native test API's explicit slow velocity and one-second endpoint hold instead of its default drag velocity. Keep the same source handle, destination, saved-state assertions and operation semantics. This changes the test gesture only. The whole filtered workflow must pass before it supplies drag/relaunch credit; broader gesture stability remains a separate qualification limit.

## Final local checkpoint

With the explicit native gesture, the [filtered production phone workflow](evidence/native-list-toolbar-compatibility/list-toolbar-phone-deliberate-drag/boundary-validation.json) passes in 174.440 seconds. Hidden Done Hotel remains first; Cafe moves before Museum; all original appearance identities, local completion and full progress survive relaunch. The [other production drag-helper caller on dark iPad](evidence/native-list-toolbar-compatibility/list-toolbar-tablet-manual-drag/boundary-validation.json) passes in 295.480 seconds, including several before/after moves, retained selection/notes/completion and relaunch. Both final iPad originals and two representative phone originals are inspected. These passing results do not establish the failed default-velocity gesture's cause or permanent drag stability.

The accepted runs total six native executions across four functions. Eleven original final captures are retained and nine inspected. The [final reconciliation](evidence/native-list-toolbar-compatibility/final-reconciliation.json) verifies identical production inputs across the mobile epochs; the sole later input difference is the deliberate drag-test helper. The final [Mac build-for-testing](evidence/native-list-toolbar-compatibility/list-toolbar-final-mac-compiler/boundary-validation.json) passes in 9.712 seconds with the same 1,094 inputs as both production drag runs. All nine retained Mac products are verified before reuse; native runtime products are checked separately before each mobile output reuse. Strict lint, Markdown and whitespace checks pass.

This closes the represented direct Add/native More correction for narrow List panes, while preserving phone behavior, saved order and contextual state. Current phone duplicate title tiers, compact iPad inline-title truncation, top spacing, broader gesture stability, actual Mac interaction and final whole-app polish remain separate. Native preferred Map width and its orientation/divider qualification are tracked separately. No Core/MCP declaration or account/team signing setup changes.
