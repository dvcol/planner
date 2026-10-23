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
