# Native Itinerary archive workflow

## Context and goal

Before: Core supports container-only Itinerary Archive/Unarchive and active/archived/all catalog queries, but native details offer neither action. The catalog always requests active Itineraries. An archived source therefore has no ordinary native discovery workflow.

After: archive or unarchive an Itinerary through its native actions menu. The catalog defaults to Active and offers Archived and All through the same pre-made menu/picker pattern as Lists. Rows and details identify archived containers. Archive preserves identity, content, references, child Done settings and schedules. It does not archive or complete shared source Items/Lists. Valid detail selection survives a filter excluding its row.

## Definition of ready

R1 and R14 establish container-only Archive/Unarchive without Trash. Q8 preserves contextual completion scopes; Q72 preserves an archived container's own child-based progress. The existing public Core command and catalog support these rules. Tests use the accepted native UI seam in the dedicated production-view fixture app, with its existing pinned-Itinerary dataset and real local stores. No new schema, public API or test-only production parameter is needed.

## Definition of done and required TDD

- Execute a native red showing the missing Archive action before changing production behavior.
- Add native Archive/Unarchive actions, active/archived/all catalog selection and visible/accessibility archive state. Reuse the existing List archive menu rather than building a custom control.
- One native journey archives, finds the same source under Archived and All, relaunches, unarchives and relaunches again. Content, owned map, child appearance identity and Todo state survive; the shared Item remains active and globally Todo. Progress remains child-based.
- Recheck the List archive menu after sharing its component. Run affected public Core archive/catalog regressions and the new native journey on phone/tablet. Inspect original captures, compile the Mac app/test host and pass affected strict lint.
- Keep native Mac runtime, moving-window scale, physical sync/account/Share, broad accessibility/adaptive behavior and whole-app polish gates open. Q84 C remains unchanged.

## Implementation and qualification

The shared native archive menu preserves the List titles and accessibility identifiers. The Itinerary catalog binds each load to its archive selection and store revision, discarding canceled or superseded loads. Native actions use the existing Core container command and durable-save path. No schema, public Core/HTTP contract or retention behavior changes.

The executed native red reaches the action menu and fails because Archive Itinerary is absent. An earlier test-helper compilation error executes no native function and is excluded from product red evidence. Subsequent implementation runs expose test-controller problems: scrolling away from a virtualized heading above the viewport, querying the global completion Toggle as a Button, and taking the sidebar fallback before observing main navigation after relaunch. The controller now scrolls explicitly toward the known heading, finds the actual Toggle role and waits for main navigation. Production code is unchanged through those corrections.

The public Core regressions pass three functions in three suites, including two archive-admission argument cases, for four case invocations. They cover container-only preservation, invalid/missing targets, recovery admission failure, replay, catalog identities and filtering. The actual Mac app and final fixture/test host compile; no native Mac function is executed. The new Itinerary journey and existing List regression each pass once on phone and tablet, with zero failures or skips in all four separate bundles. There is no combined two-function bundle claim. The final five affected Swift files pass strict lint.

Original missing-action, archived-state, catalog and List-branch captures from both simulators are retained and inspected. The execution record records exact commands, summaries, trees and source/product/artifact hashes. Logs are stored as lossless gzip, with controller revisions separated from qualified source. Core, HTTP, storage schema 18 and portable version 2 are unchanged; this slice adds no HTTP test credit. Broad native loading/scale, accessibility/adaptive layouts, live providers, native Mac runtime, physical sync/account/Share and whole-app polish remain open.
