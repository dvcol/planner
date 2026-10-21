# Native List pane header

## Context, starting state and goal

The user's Mac captures show a repeated List title, different empty/populated estimate alignment, cramped button labels and controls crossing the middle pane's divider. A long-title reproduction confirms that the global toolbar title ends at x=534 while the List pane ends at x=440. Hiding that title alone leaves Add extending to x=474.

The Mac List now has one pinned header inside its own pane. It contains the title, full-scope estimates/progress and native Filters, Sort, List actions and Add controls. `safeAreaInset` keeps it outside scrolling contents. `ViewThatFits` uses one control row when space permits and two rows in a narrow pane. The default toolbar title is removed only for the Lists destination. Other destinations keep their current navigation.

The same header supplies empty and populated Lists. Long headings use two lines, native truncation and the complete accessible name/help. Save, Cancel, Filters and Add link retain system controls with additional horizontal label insets on Mac. Mobile retains its accepted toolbar workflow, using the shared full-width summary layout. Saved identities, completion, estimates, filters, ordering, creation destinations and draft decisions retain their existing meaning.

## Definition of ready and done

The existing public native UI boundary is approved. Reproduce containment using an actual long List name and an 860-point window. Compare the visible title and controls with the actual List pane bounds; do not assert padding constants or SwiftUI structure. Use the existing rich-editor resize/save/relaunch, guarded navigation, sorting and mobile first-List journeys for affected behavior.

This slice is done when the containment regression passes, its original captures are inspected, affected interaction journeys and platform compilation pass, and strict Swift/Markdown checks pass. Physical devices, system Intents, signed storage and the final feature-complete whole-app review remain separate map gates.

## Executed qualification

The original [title regression](evidence/navigation/native-itinerary-window-compatibility/native-list-title-pane-regression-red/) fails at the measured 534 > 440 containment check. The subsequent [control regression](evidence/navigation/native-itinerary-window-compatibility/native-list-pane-header-red/) fails at 474 > 440. The initial screenshot-only locator proved reachability rather than pane containment; its passing result does not qualify the overflow.

The [final Mac invocation](evidence/navigation/native-itinerary-window-compatibility/native-list-pane-header-final-mac/) passes three cases with zero failures/skips: long-title/control containment in 34.661 seconds, actual rich-editor 860/1200-point resizing and relaunch in 157.986 seconds, and guarded draft navigation in 62.097 seconds. Original narrow/expanded captures were inspected. Title and controls remain inside the pane, and the editor retains its fields and original List destination.

Earlier iterations and failures remain recorded. Increasing native control size did not visibly improve toolbar insets, so the final change adjusts label insets. One rich-editor run timed out synthesizing location input; two later retries failed at restored-window overflow before editing. The existing native Fill helper now establishes the rich journey's initial Mac geometry while preserving every later narrow/wide check. The title-only layout's first query looked for an AX value, while its content heading already exposed the full accessible label. The corrected locator accepts either public native representation; no accessibility-name production change was needed.

The [native Mac sorting journey](evidence/navigation/native-itinerary-window-compatibility/native-list-pane-header-sort-native-mac/) passes in 257.856 seconds. It exercises the relocated control, Title/Created/Manual ordering, ascending/descending choices, two Lists' independent preferences, contextual completion, stable appearance identities and relaunch. Two preceding invocations fail on locator assumptions: the Menu button exposes its selected sort through its native title, and ProgressView owns its accessible progress label. Their original captures establish those representations. The corrected assertions read those public native properties; production sorting and progress behavior are unchanged.

The first-List landscape journey passes on [iPhone](evidence/navigation/native-itinerary-window-compatibility/native-list-pane-header-phone/) in 19.692 seconds and [iPad](evidence/navigation/native-itinerary-window-compatibility/native-list-pane-header-tablet/) in 21.156 seconds. Their original light-mode captures were inspected. Both show the ready empty List and its Estimate/Remaining metrics, with the established mobile navigation retained. Mac captures supply dark-mode evidence for this slice, not complete appearance/accessibility acceptance on every platform.

Final validation checks matching production/configuration inputs across the Mac and mobile epochs, all six passing native cases and affected strict Swift/Markdown lint. No padding/color constant or internal layout test was added. No broader map issue closes with this slice. The separate [storage cleanup](native-local-storage-cleanup.md) reclaims completed temporary results while retaining their evidence.
