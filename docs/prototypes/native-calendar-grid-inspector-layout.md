# Day and Week inspector layout checks

Status: three iPad inspector layout journeys pass, with original captures reviewed. Mac compilation passes; Mac runtime and signing remain separate.

## Context and starting state

The [Month inspector resize check](native-calendar-inspector-layout.md) preserves a selected Schedule through iPad landscape, portrait and landscape. Day and Week use a different time grid. Their prior ordinary-layout checks do not establish the same behavior while the inspector is visible during a layout change.

## Goal and expected end state

In each Calendar mode, create an Item with notes and a start-only Schedule through native controls. Select its actual Calendar entry. Retain its Schedule identity, saved caption, Calendar caption and visible notes when the layout narrows. Hide details and widen again, keeping the Calendar entry and Show Details control usable. Reopen the same selected details without changing saved scheduling data.

## Definition of ready

Q60 accepts Day, Week and Month. Q79 accepts native inspector details in the wide Calendar. The production native UI journey is an existing approved test boundary. Reuse that journey and its actual orientation/window-frame checks for Day and Week. No new testing seam, dependency, production input or saved-data contract is proposed. Signing remains deferred.

## Required tests and definition of done

- Share the existing inspector qualification controller across Month, Day and Week, with separate named test functions. Select the one saved Schedule's observed civil date through Month's native date controls, then select the required mode through its native Picker. Resolve and reveal the actual timed Schedule identity in Day/Week.
- Require the selected entry to be hittable and inside Planner's window before opening details. After narrowing and reopening, require unchanged source and Calendar captions and visible notes/Schedule content within the window.
- Retain the existing Hide/Show and reselect behavior, actual iPad orientation predicates, own-window Mac width predicates and guarded teardown restoration.
- Compile the affected mobile and Mac targets. Run the focused three-function iPad inspector class serially against frozen sources/products and inspect its original captures.
- Run strict affected Swift and report lint. Review Standards and Spec separately. Record controller failures, product defects and source epochs separately rather than assigning earlier results to later code.

These checks qualify existing native behavior. They do not require an artificial failing test when the behavior already works. Phone pushed navigation, Mac runtime startup, split-screen/Stage Manager, accessibility, measured performance, physical-device services, Q94/Q95 and whole-app polish remain separate work.

## Controller review before runtime

Source review found that the generic button selector cannot resolve the native mode/grid containers. It also found a midnight assumption in the default current-minute Schedule setup. Before execution, use the established any-role container queries, observe the one saved Schedule's calendar-date marker and select that date through native controls. If setup crossed a month boundary, browse back one month to find the saved marker. Bounded native scrolling reveals the retained timed entry before checking its viewport. These controller corrections do not change a saved Schedule or product behavior.

## Environment and execution status

The current host is macOS 27.0.1 with Xcode 27.1. The selected iPad Air 11-inch Simulator runs iOS 27.0. Configuration still requires iOS/macOS 27.0; successful compilation does not establish runtime behavior on every supported version. Both affected mobile and Mac compiler invocations pass.

The first runtime invocation exits successfully but executes zero functions because a class-only argument was passed to a runner accepting function paths. It provides no runtime credit. A separate invocation names all three functions explicitly against the same sources and products.

## Recorded results

| Boundary | Result | Scope |
| --- | --- | --- |
| Month inspector layout | Passed, 71.166 seconds | Revised shared controller and actual landscape/portrait/landscape sequence. |
| Day inspector layout | Passed, 72.903 seconds | Exact saved timed entry and retained details through the same sequence. |
| Week inspector layout | Passed, 75.397 seconds | Retained selected Schedule and captions with the horizontal time grid. |
| Focused iPad invocation | Three functions passed, zero failures/skips | The separate zero-function setup invocation contributes no coverage. |
| Mobile and Mac affected targets | Both compiler invocations passed | 945 inputs and six products per platform. Mac runtime was not invoked. |

All 18 original captures were inspected individually, six per mode. Each sequence shows visible selected inspector notes and the original saved Schedule caption, portrait adaptation, hidden details after widening, and the same details reopened in landscape. The inspector overlays part of the underlying Calendar. In Week, its overlay can cover the selected Saturday card; the hidden-inspector captures show that card again. This checks retained selection and usable Calendar controls when details are hidden. It does not claim that both the entire Calendar and details remain uncovered simultaneously.

Entry widths before/after hiding are 724/724 points in Month, 1,116/1,116 in Day and 116/116 in Week. Those measurements establish no width increase. The native inspector's overlay behavior is retained.

The final runtime freezes 469 source/configuration inputs and six products. Source, product, capture and lint hashes are checked before commit. Strict affected Swift/report lint and separate Standards/Spec reviews pass. No production source, Core command, provider boundary, schema or package changed. No new Core/HTTP or phone runtime credit is claimed.

## Evidence and remaining work

[The evidence packet](evidence/navigation/native-calendar-grid-inspector-layout/) retains literal exits and function durations, both compiler invocations, the zero-function setup command, the qualified runtime command, source/product manifests, original captures and observed identities/captions. The [earlier Month report](native-calendar-inspector-layout.md) links prior picker and rich-draft compatibility evidence.

This is an ordinary one-Schedule iPad inspector qualification. Actual midnight/month-rollover execution, dense overlap/all-day layouts during resizing, split-screen/Stage Manager, phone pushed navigation, Mac window runtime, keyboard/VoiceOver/Dynamic Type and measured physical performance remain separate. Q94 label presentation and Q95 native catalog windows still await human answers. Signing, physical CloudKit/account/Share validation and whole-app native SwiftUI polish remain deferred or open under their existing gates. No whole-map issue is closed.
