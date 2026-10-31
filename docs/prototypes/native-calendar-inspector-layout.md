# Calendar inspector through layout changes

Status: final iPad layout journey and visual review pass. Mac compilation passes; Mac runtime, Q94/Q95 and signing remain separate.

## Context and starting state

Q79 accepts a wide Calendar with optional native inspector details on iPad and Mac. The [existing inspector journey](native-calendar-inspector.md) hides and reopens one selected Schedule and checks its saved caption. Its earlier invocations do not rotate or resize the window while selection is active. The map requires actual compact/expanded layout and selection checks.

## Goal and expected end state

Create one Item with notes and a start-only Schedule through native controls. In a wide layout, select that Schedule and exercise existing Hide/Show Details actions. Narrow the layout while its details are visible and retain the selected Schedule identity, saved caption and Item notes. Hide details, then widen the layout. Keep the inspector hidden with usable Calendar selection and Show Details controls. Reopening must show the same selected Schedule and unchanged caption/notes.

## Definition of ready

The existing native UI seam, Q79 inspector behavior and retained valid-selection rule are approved. Extend the production native journey with actual iPad orientation or own-window Mac resizing, using the already established frame predicates and drag controls. No production seam, command, schema, provider or dependency changes are proposed. The phone's pushed details remain a separate workflow; this regular-width inspector journey deliberately skips phone and supplies no phone runtime credit.

## Required tests and definition of done

- Start iPad in landscape and verify actual window orientation. Restore portrait during teardown. Mac uses its own window at 1,200 points and restores the original width.
- Preserve the existing hide/reopen and entry-reselection assertions before testing layout changes.
- Narrow to iPad portrait or an 860-point Mac window, waiting for the actual frame change. Verify unchanged selected Schedule identity/caption and notes, with nonempty hittable content fully inside Planner's window.
- Hide the inspector, widen again, and verify hidden details plus hittable Show Details and selected-entry controls. Reopen the original selected details and compare their saved values.
- Compile the affected app/UI targets on Simulator and Mac, run the focused iPad journey serially, inspect original native captures and record actual function outcomes and source/product hashes.
- Run affected strict Swift/report lint and source/specification review. Record failures and controller changes separately. A successful compiler or skipped phone invocation never supplies runtime credit.

This qualifies existing behavior and does not invent a missing-feature red. Mac UI runtime remains open because its automation startup is unqualified; do not blindly retry it without changed conditions. Signing, physical devices, CloudKit/account/Share, accessibility, measured performance and whole-app native polish remain separate gates.

## Controller review before runtime

The first source review found two oracle/cleanup gaps. Existence and value checks alone could accept offscreen inspector content. The Mac width restoration also used defer despite abort-on-failure assertions. Before native execution, the controller now requires notes and Schedule content to be hittable, nonempty and fully within Planner's window after narrowing and reopening. Mac restoration uses async XCTest teardown with a window-exists guard. Exact identity/caption comparisons remain. Both reviewers verified the corrections and report no remaining source findings.

The initial two compiler-only epochs are retained separately. They do not qualify the revised controller or any runtime outcome. No production changes are involved.

## Screenshot correction

The first iPad invocation passes in 62.416 seconds, including the actual rotation and viewport assertions. Its six original named images are inspected. Five landscape exports from the newly chosen application screenshot method are clipped and cannot qualify the layout; the portrait image is usable. This is retained as a passing controller observation with incomplete visual evidence, not final-source qualification.

The original iOS inspector journey used XCUIScreen for complete Simulator captures. Restore that existing iOS capture method while retaining own-window capture on Mac. Native assertions and product behavior stay unchanged. Rebuild and rerun the same journey, retaining the original result and images separately.

## Recorded results

| Boundary | Result | Scope |
| --- | --- | --- |
| Final iPad Calendar layout journey | Passed, 62.434 seconds | One function, zero failures/skips; actual landscape/portrait/landscape sequence. |
| Final iOS Simulator app/UI compiler | Passed | 945 compiler inputs and six products. |
| Final Mac app/UI compiler | Passed | Same affected targets; no Mac UI runtime execution. |
| Earlier iPad controller observation | Passed, 62.416 seconds | Clipped landscape exports; diagnostic only, no final-source credit. |

The six final original Simulator-screen captures were inspected individually. They show the selected Month entry with its native inspector, hidden/reopened details, retained visible notes and saved Schedule caption in portrait, hidden details after widening, and the same details reopened in landscape. The earlier six originals remain, with five clipped landscape images explicitly excluded from visual qualification. Mac capture remains limited to Planner's own window when that branch can run.

The recorded entry widths are 724 points both before and after hiding the native inspector. These values do not prove a width increase; the native presentation can overlay existing content. This journey proves hidden/visible state, usable controls and retained selection through actual layout changes. It does not assert a different frame policy.

Final compiler manifests each contain 945 inputs and six products. The final runtime freezes 469 source/configuration inputs and six products. The audit checks current source and products before commit, verifies the exact function outcome and separates the earlier capture-source observation. Source reviews and affected strict Swift/Markdown lint pass. Core, HTTP and saved data behavior did not change and receive no new suite credit.

## Evidence and remaining work

The evidence packet retains actual exits, logs, source snapshots/hashes, compiler products, original images, observed Schedule identity/caption and width attachments, and the bounded audit. The [picker qualification](native-item-picker-archive.md) links on-demand selection, earlier rich-draft resizing, estimates and creation evidence, each with its own source epoch.

The recorded Calendar view is Month. Day/Week resizing, compact phone navigation, actual Mac window dragging/runtime, split-screen/Stage Manager, keyboard/accessibility, physical-device performance and human layout acceptance remain separate. No production change, scheduling mutation, signing work or whole-app polish is included. Q94 label presentation and Q95 native catalog windows remain unanswered. No issue or whole-map gate is closed.
