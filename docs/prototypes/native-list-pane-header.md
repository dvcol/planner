# Native List pane header

## Context, starting state and goal

The user's Mac captures show a repeated List title, different empty/populated estimate alignment, cramped button labels and controls crossing the middle pane's divider. A long-title reproduction confirms that the global toolbar title ends at x=534 while the List pane ends at x=440. Hiding that title alone leaves Add extending to x=474.

The Mac List now uses one shared native top toolbar. Its system navigation title stays leading aligned and uses available window space. Filters, Sort, List actions, Add and the selected Item's actions share that toolbar owner. The main window supplies a continuous system-material background. Estimates/progress remain directly below it, using the same summary for empty and populated Lists.

The first correction pinned a separate title/control block beneath the native toolbar. Although it contained the title and controls, the user's follow-up correctly identified the remaining empty strip and duplicate header structure. The unified-toolbar follow-up below supersedes that intermediate layout. iPhone/iPad keep their accepted native navigation and action placement. Saved identities, completion, estimates, filters, ordering, creation destinations and draft decisions retain their existing meaning.

## Definition of ready and done

The existing public native UI boundary is approved. Reproduce containment using an actual long List name and an 860-point window. Compare the visible title and controls with the actual List pane bounds; do not assert padding constants or SwiftUI structure. Use the existing rich-editor resize/save/relaunch, guarded navigation, sorting and mobile first-List journeys for affected behavior.

This slice is done when the shared-toolbar, available-space and empty/selected-title regressions pass, their original captures are inspected, affected interaction journeys and platform compilation pass, and strict Swift/Markdown checks pass. Physical devices, system Intents, signed storage and the final feature-complete whole-app review remain separate map gates.

## Executed qualification

These first six runs record the intermediate pane-containment correction. The later shared-toolbar results below supersede its layout acceptance.

The original [title regression](evidence/navigation/native-itinerary-window-compatibility/native-list-title-pane-regression-red/) fails at the measured 534 > 440 containment check. The subsequent [control regression](evidence/navigation/native-itinerary-window-compatibility/native-list-pane-header-red/) fails at 474 > 440. The initial screenshot-only locator proved reachability rather than pane containment; its passing result does not qualify the overflow.

The [intermediate Mac invocation](evidence/navigation/native-itinerary-window-compatibility/native-list-pane-header-final-mac/) passes three cases with zero failures/skips: long-title/control containment in 34.661 seconds, actual rich-editor 860/1200-point resizing and relaunch in 157.986 seconds, and guarded draft navigation in 62.097 seconds. Original narrow/expanded captures were inspected. Title and controls remain inside the pane, and the editor retains its fields and original List destination.

Earlier iterations and failures remain recorded. Increasing native control size did not visibly improve toolbar insets, so the final change adjusts label insets. One rich-editor run timed out synthesizing location input; two later retries failed at restored-window overflow before editing. The existing native Fill helper now establishes the rich journey's initial Mac geometry while preserving every later narrow/wide check. The title-only layout's first query looked for an AX value, while its content heading already exposed the full accessible label. The corrected locator accepts either public native representation; no accessibility-name production change was needed.

The [native Mac sorting journey](evidence/navigation/native-itinerary-window-compatibility/native-list-pane-header-sort-native-mac/) passes in 257.856 seconds. It exercises the relocated control, Title/Created/Manual ordering, ascending/descending choices, two Lists' independent preferences, contextual completion, stable appearance identities and relaunch. Two preceding invocations fail on locator assumptions: the Menu button exposes its selected sort through its native title, and ProgressView owns its accessible progress label. Their original captures establish those representations. The corrected assertions read those public native properties; production sorting and progress behavior are unchanged.

The first-List landscape journey passes on [iPhone](evidence/navigation/native-itinerary-window-compatibility/native-list-pane-header-phone/) in 19.692 seconds and [iPad](evidence/navigation/native-itinerary-window-compatibility/native-list-pane-header-tablet/) in 21.156 seconds. Their original light-mode captures were inspected. Both show the ready empty List and its Estimate/Remaining metrics, with the established mobile navigation retained. Mac captures supply dark-mode evidence for this slice, not complete appearance/accessibility acceptance on every platform.

Final validation checks matching production/configuration inputs across the Mac and mobile epochs, all six passing native cases and affected strict Swift/Markdown lint. No padding/color constant or internal layout test was added. No broader map issue closes with this slice. The separate [storage cleanup](native-local-storage-cleanup.md) reclaims completed temporary results while retaining their evidence.

## Unified top-toolbar follow-up

The user's running-app captures confirm that containment alone left a second header beneath an empty toolbar strip. The List title and its actions now share the native macOS window toolbar. The main window requests the system [unified toolbar style](https://developer.apple.com/documentation/swiftui/windowtoolbarstyle), with a visible regular-material background applied at the window root. This makes the top band continuous across the pane dividers. The old lower title/control block is removed; the same estimates/progress summary remains beneath it in both List states.

The existing system navigation title owns its leading placement and available width. A manual cap initially left its accessible frame at 158.5 points even after widening from 860 to 1200 points. A principal-placement probe centered the title and hid it with its actions at narrow width. Both are removed. No custom title view, width measurement or new dependency remains.

A separate fixed-window reproduction exposes the selected-Item issue: the title region collapses from 1698 to 160 points when a detail-column toolbar appears. Removing only the detail navigation title does not fix it. The Mac Item actions now live with the List's actions in the content toolbar. The existing view supplies the same menu and command closures; phone/tablet retain their detail navigation title and toolbar. This changes presentation ownership without changing the selected source, appearance or action scope.

The existing native UI seam checks actual title/control frames against the native toolbar, leading alignment, growth on widening, nonoverlap and the summary's distance below the bar. It creates an Item in the same List and repeats the narrow/wide checks with selection. A second case compares empty/selected title space without resizing, allowing the added Item action's native width and spacing instead of forcing equal frame widths.

The [qualified header baseline](evidence/navigation/native-itinerary-window-compatibility/native-list-top-header-qualified-red/) fails at the misplaced-title assertion against the prior production layout. The [title-space baseline](evidence/navigation/native-itinerary-window-compatibility/native-list-top-title-space-red/) fails at unchanged width. The [selection baseline](evidence/navigation/native-itinerary-window-compatibility/native-list-selection-title-budget-red/) fails at the 160-point title region despite room for at least 1603.5 points. Earlier locator, menu, resize and startup failures retain their actual outcomes. Native resize gestures now activate Planner first; the existing Fill setup closes its menu when Fill is disabled rather than clicking an unavailable action. Every reported narrow/wide journey still asserts the window's actual width.

Moving creation into the native bar also exposes a real narrow-editor regression: Save becomes unavailable behind overflow while the List controls consume the toolbar. Merely assigning secondary-action placement does not fix it; the [failed native probe](evidence/navigation/native-itinerary-window-compatibility/native-list-editor-toolbar-priority-mac/) retains that outcome. During a New Item draft, the Mac bar now shows Filters as an icon and groups Sort, List actions and Add in one native List options menu. Save and Cancel remain directly available. Browsing retains the direct controls, and the existing accessible filter summary remains complete.

The final source passes six actual Mac cases, with zero failures/skips:

| Invocation | Executed checks | Result |
| --- | --- | --- |
| [Rich editor](evidence/navigation/native-itinerary-window-compatibility/native-list-editor-options-mac/) | Real 860/1200-point resizing, sidebar collapse/show, retained rich fields and original List destination, Save and relaunch | 1 pass, 154.214 seconds |
| [Header and draft guards](evidence/navigation/native-itinerary-window-compatibility/native-list-shared-header-final-revalidation-mac/) | Long-title narrow/wide empty and populated states; Save/Discard/Keep editing and invalid draft protection; unchanged-window title space after Item selection | 3 passes, 55.987 / 61.117 / 31.668 seconds |
| [Affected native actions](evidence/navigation/native-itinerary-window-compatibility/native-list-shared-header-actions-mac/) | Contextual details and explicit View item; Title/Created/Manual sorts, direction, per-List preferences, order, local completion and relaunch | 2 passes, 52.493 / 260.182 seconds |

The final wide empty/populated, narrow populated, fixed-window before/after-selection and narrow/expanded rich-editor captures were inspected. They show the continuous top band, leading title and usable native controls. The selected Item retains its contextual detail and menu; its global navigation remains explicit. These captures establish the represented dark Mac states rather than a whole-app appearance audit.

The same contextual-detail/View item/relaunch case passes on [iPhone](evidence/navigation/native-itinerary-window-compatibility/native-list-shared-header-phone/) in 63.419 seconds and [iPad](evidence/navigation/native-itinerary-window-compatibility/native-list-shared-header-tablet/) in 67.691 seconds. Both original light-mode captures were inspected. This gives eight passing executions of six distinct cases across the three platforms, with no failed or skipped tests in these final invocations. All 1,061 source/configuration inputs match the current workspace across the final Mac build/runtime and mobile epochs. Affected strict Swift formatting, Markdown lint and whitespace checks pass.

Superseded compiler/locator/resize probes retain their actual outcomes in a [compact iteration record](evidence/navigation/native-itinerary-window-compatibility/native-list-header-iterations/outcomes.json). Their raw unpublished diagnostics remain local; this relocation makes no disk-reclamation claim. No production domain contract, package, target or test-only control was added. Physical-device, system Intent, signed storage and final whole-app review gates stay open.
