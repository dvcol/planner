# Adaptive native label selection during Item creation

Status: Q94 A implemented; six focused mobile journey invocations pass. Mac compiler qualification and final checks are recorded below. Q95/Q96 are independently approved. Signing and whole-app polish remain deferred.

## Context and starting state

The current New Item Form pushes Categories and Tags within its column's NavigationStack. The [earlier diagnosis](native-new-item-labels.md) reproduces an unwanted leaving prompt after returning from Categories and retains unsuccessful pushed-navigation experiments. The human now approves a native popover on larger layouts with sheet adaptation on compact layouts. The Item editor's own column/page placement is unchanged.

## Goal and expected end state

Select existing shared Categories/Tags inside the same unsaved Item draft without a leaving prompt on picker return. Only actual navigation away invokes Save/Discard/Keep Editing. Discard creates nothing; explicit Save creates one Item with those exact label identities, retaining them through layout changes and relaunch.

## Definition of ready

Q94 A confirms this presentation and carries forward the existing production native UI seam. The real local dataset, Manage Labels controls, Item draft and guarded save commands remain the implementation path. There is no Core command, schema, package, target, test-only parameter or new unit seam. Q95/Q96 do not block this slice.

## Required tests and definition of done

- Reproduce the unwanted prompt on the current source through the complete creation-label lifecycle before changing presentation.
- Create one Category/Tag, select both in a new draft, return without a leaving prompt, then explicitly Discard and verify no Item exists.
- Select both in another draft, retain the same draft through actual landscape/portrait windows on mobile, Save once and verify one source and both shared label identities after relaunch.
- Requalify the existing guarded-navigation and rich-draft resizing/relaunch journeys on both simulator form factors. Mac compiler qualification remains distinct from its unresolved automation startup gate.
- Run affected strict Swift/Markdown lint, both app/UI compiler checks, focused serial native journeys, separate source/specification reviews and inspect the original captures. Preserve every failed invocation separately.

The required behavior is exposed through the existing native UI boundary. No new domain behavior calls for Core unit or HTTP tests. Broader label management, physical sync/account/Share, accessibility/performance and final whole-app UI acceptance retain their owning gates.

## Implementation and regression evidence

`SavedNewItemForm` presents the existing `SavedItemLabelPicker` in a native popover, adapting to a large sheet in compact mobile layouts. Both use the same draft UUID bindings. The editor itself remains a detail column or pushed page. Item editing, domain commands, schema and save/navigation guards are unchanged.

The new journey first reproduced the unwanted leaving prompt after Categories on the unchanged production form: one failure in 51.897 seconds, exit 65. Its [original capture](evidence/navigation/native-new-item-label-picker/phone-label-red/A9CD7973-1EF0-42FE-9062-AA65569859C1.png) shows Save/Discard/Keep Editing. The final test adds strict-format whitespace and diagnostic picker screenshots after that red epoch; its behavioral assertions are unchanged. Source archives distinguish the epochs.

| Invocation | Result | Scope |
| --- | --- | --- |
| `mobile-label-red-build` | Compiler pass | Unchanged production; new regression journey |
| `phone-label-red` | 1 failure, 51.897 s | Genuine picker-return regression |
| `mobile-label-green-build` | Compiler pass | Presentation fix before additional diagnostic captures; no runtime credit |
| `mobile-label-captures-build` | Compiler pass | Final affected mobile app/UI source |
| `phone-label-green` | 1 pass, 114.238 s | Complete shared-label draft/Discard/rotation/save/relaunch lifecycle |
| `tablet-label-compatibility` | 3 passes, 414.605 s | Same label lifecycle plus existing guarded-navigation and rich-draft layout/relaunch journeys |
| `phone-label-compatibility` | 2 passes, 313.895 s | Existing guarded-navigation and rich-draft layout/relaunch journeys |

Every runtime packet retains its command, exit, compressed log, source and executable hashes, and a link to its compiled epoch. Runtime wrappers check source/products before and after execution. The tablet lifecycle took 124.644 seconds; its rich-draft layout and guarded-navigation regressions took 209.010 and 80.951 seconds respectively. These are test durations, not responsiveness measurements.

## Original capture inspection

All fourteen named phone lifecycle/compatibility captures and fourteen named tablet lifecycle/compatibility captures were inspected individually. The selected-captures manifests map original PNGs to their executed tests. The [iPad Categories capture](evidence/navigation/native-new-item-label-picker/tablet-label-compatibility/1D88955E-42B3-482A-AD6A-EFD11ED25FE1.png) shows the native popover over the same draft; [picker return](evidence/navigation/native-new-item-label-picker/tablet-label-compatibility/AFB49BC5-7A8C-4D3F-9305-01A5F575A50E.png) shows its selected-count summary without a leaving prompt. The iPad landscape/portrait frames keep both selections visible. The phone landscape frame shows the top fields with labels below its viewport; final saved identity assertions, rather than that frame alone, establish retention through rotation.

Post-relaunch assertions inspect the selected Category and Tag toggles using their original shared identities. Those Edit Item pickers retain their existing navigation; this change concerns New Item only. The compatibility frames show the originating List, rich fields, and explicit navigation choices. They do not qualify Mac runtime, physical-device layouts, VoiceOver, keyboard operation, split-screen widths or final visual acceptance.

Separate Standards and Spec source reviews found no confirmed issues. The final phone compatibility regressions took 243.585 and 70.310 seconds, with no failures or skips. Mac compilation and final lint/evidence checks are recorded below. List-origin creation with label selection remains a separate follow-up journey; the existing rich List-origin creation regression does not select labels.

## Final checks and limits

The final Mac app/UI-test-host compiler pass succeeds with the previously authorized local ad hoc signature; account/team signing is unchanged. Affected strict Swift formatting, Markdown lint and whitespace checks pass. The [execution record](evidence/navigation/native-new-item-label-picker/execution.json) retains validation commands and inspected capture hashes. No Mac UI retry was attempted.

The creation-label regression is fixed within the qualified mobile lifecycle. Q95 loading windows and Q96 clock input remain implementation work. Signing, physical sync/account/Share, broad accessibility/performance qualification and whole-app native polish retain their owning map gates.
