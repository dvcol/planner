# Native Itinerary location

## Context and goal

Before: Core can save and guard an Itinerary's owned location, but the native Itinerary form cannot create, edit or clear it, and Itinerary details omit its address and map. Items already have staged location editing.

After: native Itinerary creation and editing expose Place name and Address. Existing coordinates remain unless Remove saved pin is explicitly saved. Cancel changes nothing. Details reuse the native owned-coordinate map and temporary address-preview component. Editing a location preserves the Itinerary identity, notes and live child references.

## Definition of ready

The [owned-content contract](../content-and-reader-review.md) already covers Item and Itinerary locations as one guarded compound field. Q51 B establishes staged Keep/Remove under Save/Cancel. Q42 and Q50 establish temporary native address previews. Tests use the accepted native UI seam in the dedicated production-view fixture app, with public Core commands supplying saved coordinates. No new public contract, persistence field or test-only production parameter is required.

## Definition of done and required TDD

- Reproduce missing location controls through the native New Itinerary form before implementation.
- Save a new owned location, cancel a changed address, clear the location and verify the same identity and notes after relaunch. Reopening the cleared editor must show empty fields and disabled Save.
- Verify the pinned Itinerary map, default pin retention during address edits, Cancel after selecting Remove, and explicit Save of removal. The address, notes, child appearance identity and local completion survive relaunch.
- Reuse native Form, TextField, Picker and Map controls. Preserve untouched optional values and the original pin until explicitly changed.
- Recheck both existing Item pin journeys after sharing their editor. Qualify affected phone/tablet journeys, inspect original captures, compile the shared Mac implementation and pass strict affected Swift/Markdown lint.
- Record failures separately from passing qualification. Native Mac runtime, physical sync/account/Share, broad accessibility/adaptive behavior and whole-app polish remain open gates.

## Implementation and qualification

The shared location draft retains the exact original value when untouched, including nullable or explicitly empty strings. Existing Item accessibility identifiers remain unchanged. Itinerary edits use the existing guarded location replacement or clear, while preview lookup uses the dataset namespace and source lifetime. Provider results remain outside saved content and backups.

The native red reaches New Itinerary and fails because the Place name control is absent. The first implementation run finds that control but fails to reveal it because the test drags a 44-point keyboard accessory scroll view. Targeting the actual native Form fixes the controller; the first phone journey then passes Save, Cancel, clear and relaunch. That initial pass precedes the stronger empty-field assertions and pinned-Itinerary journey.

Final phone and tablet bundles each pass four functions, with zero failures or skips: two new Itinerary journeys and both existing Item pin regressions. They execute the same final source. Original owned-map, staged-removal and retained-address captures are inspected on both devices. The actual Mac Planner app and Mac fixture/test host compile; no native Mac function is executed. Strict lint passes for the six affected Swift source/test files and this report. Standards and Spec reviews find no confirmed issues.

The [execution record](evidence/navigation/native-itinerary-location/execution.json) retains exact final commands, separate red/controller/initial-pass records, original filtered PNG/TXT exports, logs and source/product/artifact hashes. The earlier controller source is labeled separately from the qualified test. The red bundle exports no PNG; its actual failure and hierarchy remain in the logs and TXT attachments. Live provider behavior, moving-window performance, broad accessibility/adaptive layouts, native Mac runtime, physical sync/account/Share and whole-app polish remain separate gates. Q84 is still pending and its lifetime policy is unchanged.

Core, HTTP, storage schema 18 and portable version 2 are unchanged. This native slice receives no new Core or HTTP test credit.
