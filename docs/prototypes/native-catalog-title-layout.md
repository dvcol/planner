# Native catalog title layout

## Context and starting state

The large-collection journey's original iPad images show the Items heading clipped beneath its native toolbar actions. The same production catalog serves Items and Inbox. The app uses SwiftUI TabView and NavigationSplitView with native toolbar items; this defect concerns their arrangement.

## Goal and expected end state

Keep each catalog's full navigation title readable beside its actions on phone and tablet. Preserve native search, filters, sorting, creation, capture and detail selection. This is a focused defect repair; whole-app polish remains open.

## Definition of ready

The accepted native UI test boundary and dedicated fixture scheme exercise production views with disposable local data. The existing catalog-overflow fixture supplies Items without requiring a new production interface. Use XCTest's native title/button frames and original screenshots to reproduce and verify the problem. No signing or physical account setup is needed for this local check.

## Required tests and definition of done

The native journey opens Items and Inbox, requires a title at least as wide as the platform headline rendering of its full text, and rejects overlap with visible native navigation-bar buttons. Retain the native frames and original images. Observe a failing assertion before changing production layout, then run the corrected journey on phone and tablet. Verify that native catalog controls still work, compile the affected Mac target and run focused formatting checks. Record the result and remaining device/layout limits before committing.

## Execution

The first iPad run reproduced a 6.5-point title width. Forcing a native large title did not change that result. A Capture-placement attempt using the catalog's local size class also left the action in the top toolbar. Passing the root view's existing placement instead moved Capture into the native bottom bar and made the full Items title visible. Filters, sorting and New Item stay in the top toolbar. The renamed private placement property still gives labels and settings their previous placement. Phone and Mac continue to use automatic placement.

The root-placement attempt measured 44.5 points for the complete title, but the test initially rounded its expected headline width up to 45. That was a test calibration error. The corrected check uses the platform's unrounded 44.409601-point measurement. With the production files restored to the unfixed base, the corrected assertion again failed at 6.5 points. This is the functional baseline for final qualification. The earlier 44.5-versus-45 failure receives no product-defect credit.

This uses native toolbar placement to relieve the crowded title area, consistent with [Apple's toolbar guidance](https://developer.apple.com/videos/play/wwdc2022/110343/). Search, source data, completion, query generations and their retention policy are unchanged. The large-title attempt and the ineffective local-size-class property are absent from final source.

The final title journey passes one function on each simulator, with zero failures or skips. iPad measures Items at 44.5 points and Inbox at 44 points, exceeding their respective unrounded headline widths of 44.409601 and 43.575249 points. Phone measures 88.666667 and 87 points. Neither title overlaps a visible native navigation-bar button. Four original final screenshots show both catalogs.

The ordinary-app Capture regression also passes one function on each simulator. It cancels a reviewed draft without saving, saves owned notes and the original link, then reopens the one retained Item from Inbox after relaunch. Its two screenshots show the saved content. Both native runs together execute two distinct functions across two suites, four invocations total.

The current-source Mac fixture/test-host compilation and ordinary app build pass with signing disabled. Strict formatting passes all three affected Swift files; the report passes focused Markdown lint. No Core, HTTP or Mac runtime check is credited. This slice does not qualify every window size, orientation, accessibility setting or the separate whole-app polish gate.

The [evidence packet](evidence/navigation/native-catalog-title-layout/execution.json) retains the calibrated baseline, earlier diagnostic attempts, eleven original images, native frames, exact commands, compressed raw logs and source/product hashes. The report distinguishes a real clipped title from the corrected test-rounding error.
