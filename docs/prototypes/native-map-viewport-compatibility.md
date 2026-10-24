# Native collection Map viewport compatibility

Status: the represented iPad rotation and phone Map navigation pass locally, with matching Mac compilation. Q134 A already specifies a preferred wider, resizable native collection pane and exact third-pane details on wide layouts. It does not require one fixed point width. Actual Mac divider interaction and physical acceptance remain separate.

## Existing boundary and expected outcome

Extend the existing production-app Map journey on iPad. Create one Item with its original Google coordinate-search URL and one Item without a location. Open Map, select the exact pin, rotate landscape then portrait, and verify the Map stays within the actual app window, Locations remains reachable, and the same saved bookmark remains in the neighboring detail pane. Use native detail scrolling when necessary. Then use Locations to open the unlocated Item without reusing the old bookmark. The ordinary phone path remains unchanged.

This uses the existing native UI seam, native orientation and gesture APIs, and the published Map/Item controls. No production interface, test hook, target, package or signing setup is added. Compile the matching Mac source separately; compilation does not qualify Mac window resizing.

The production Map roots request a flexible preferred width of 320/560/800 points. Apple's [column-width documentation](https://developer.apple.com/documentation/swiftui/view/navigationsplitviewcolumnwidth(_:)) says presentation support can result in a different width, and only some platforms enable column resizing. Record actual native frames; do not require exactly 560 points or infer a defect merely from a 340-point iPad pane.

## Retained diagnostics

The [first dark-iPad execution](evidence/native-map-viewport-compatibility/map-viewport-dark-tablet-rotation/boundary-validation.json) fails in 68.466 seconds at an immediate bookmark-hittability assertion. Its native frames show an actual landscape window of 1180 × 820 points, the Map within that window at width 340, and the retained bookmark starting at y=823.5 below the detail viewport. Map, pin and Locations remain reachable. This result is failed and does not prove a product clipping defect.

The [second diagnostic](evidence/native-map-viewport-compatibility/map-viewport-dark-tablet-scroll-qualified/boundary-validation.json) fails in 67.570 seconds because the existing generic detail-scroll helper cannot identify a hittable collection-view container in that presentation. Its result remains failed. Both epochs retain complete input/product validation and their original attachments. The final test instead scrolls inside the observed detail pane using native window-relative gestures; shipping production remains unchanged.

The [third diagnostic](evidence/native-map-viewport-compatibility/map-viewport-dark-tablet-detail-gesture/boundary-validation.json) fails in 73.501 seconds at bookmark visibility. Its four center-of-detail drags pan the embedded map instead of scrolling the Form; the bookmark frame stays below the viewport. The original captured map center changes, while the Map collection and selected Item remain intact. The next test places the scroll gesture in the native detail margin outside that embedded map. This is a test-interaction correction, not a production change or a passing result.

## Passing iPad rotation journey

The [native-margin execution](evidence/native-map-viewport-compatibility/map-viewport-dark-tablet-margin-scroll/boundary-validation.json) passes in 76.094 seconds. Portrait and landscape retain the exact pin and bookmark; scrolling the Form outside its embedded map makes the bookmark reachable. Locations then opens the unlocated Item and removes the old Item's bookmark from details. All three final original captures are inspected, including the real embedded map and full link row in each orientation.

The recorded native Map width is 340 points in both orientations. Its rectangle remains inside the 820 × 1180 portrait and 1180 × 820 landscape windows, with Locations hittable and the exact Item detail to its right. This qualifies the represented responsive containment and selection, not a guarantee that SwiftUI uses the requested 560-point ideal. Source/product validation covers 1,094 inputs and four native products. Phone regression and matching Mac compilation continue separately.

## Final local checkpoint

The [light-phone regression](evidence/native-map-viewport-compatibility/map-viewport-light-phone-regression/boundary-validation.json) passes in 69.096 seconds with compact pin/detail/Back and unlocated-Item navigation. Its original capture is inspected. Together with the iPad pass, two native executions of the existing journey succeed. Four final captures are retained and inspected; all three earlier attempts remain failed and separate.

The [matching Mac build-for-testing](evidence/native-map-viewport-compatibility/map-viewport-mac-compiler/boundary-validation.json) passes in 9.610 seconds. The [final reconciliation](evidence/native-map-viewport-compatibility/final-reconciliation.json) verifies identical 1,094 inputs across both accepted mobile runs and Mac compilation, and verifies all nine retained Mac product hashes before reuse. Strict Swift lint, Markdown and whitespace checks pass. No shipping production code changes.

This closes the represented collection Map orientation/containment check. Other collection contexts, native Mac window/divider interaction, physical behavior, accessibility combinations and final whole-app polish retain their own gates. A successful compiler result supplies no Mac runtime or protected-storage credit. Developer signing remains deferred.

## Current narrow-iPad title recheck, 25 October 2026

The earlier Map captures recorded an ordinary narrow-iPad Items title truncated beside its toolbar controls. Re-run the existing pin, exact bookmark, rotation and unlocated-Item journey against the current committed app before changing its layout. This uses the already approved native UI boundary without adding a test, production control or declaration.

The [first attempt](evidence/native-map-viewport-compatibility/map-title-current-dark-tablet/exit.json) exits 74 during package resolution because its old package-cache checkouts were cleaned up. It starts zero test functions. Retain that failed epoch without UI or compilation credit. A terminal runner result precedes the next attempt, which reuses the complete package cache used by the latest affected Core/adapter builds.

The [current dark-iPad execution](evidence/native-map-viewport-compatibility/map-title-available-cache-dark-tablet/test-summary.json) passes the one unchanged function in 80.617 seconds. All three original captures are inspected: the [initial Map](evidence/native-map-viewport-compatibility/map-title-available-cache-dark-tablet/20C4CEE4-11F0-4342-B826-5CCDAC1CD9A6.png), [portrait selection](evidence/native-map-viewport-compatibility/map-title-available-cache-dark-tablet/9AD7CB3F-7DCD-409A-8C7A-4CA7620CC4C6.png) and [landscape selection](evidence/native-map-viewport-compatibility/map-title-available-cache-dark-tablet/AA940E59-D7BF-4E82-9742-273A73D41AD6.png) each show the full Items title beside the native Filters, Add and More controls. These are rendered-pixel observations; an untruncated accessibility label alone would not establish them. The observed Add wait completes successfully and is not a product failure.

Actual geometry retains a 340-point Map pane in both 820 × 1180 portrait and 1180 × 820 landscape windows. The pin and Locations action remain within the window, the neighboring details retain the exact saved Google Maps URL through rotation, and Locations then opens the unlocated Item without retaining the previous bookmark. Dark appearance, ordinary Large text and disabled Increase Contrast are observed; the original appearance is preserved.

The [source/product reconciliation](evidence/native-map-viewport-compatibility/map-title-available-cache-dark-tablet/boundary-validation.json) verifies all 1,150 current inputs and four actual Simulator products. Those inputs exactly match the earlier successful Mac app/Share/fixture compilation and seven HTTP checks; their nine actual products are independently rechecked. That reuses the earlier compiler epoch rather than claiming another Mac run. Production and test sources remain unchanged.

The specific ordinary Items Map title truncation is no longer reproduced in this current layout. Other titles, text sizes, light mode, compact multitasking widths, VoiceOver, Mac runtime, physical devices and whole-app visual acceptance remain open. This checkpoint needs no signing or new product decision and makes no red/green production-fix claim.
