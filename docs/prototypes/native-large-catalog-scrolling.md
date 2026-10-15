# Native large-catalog scrolling

## Context and starting state

The map requires useful native scrolling at 5,000 Items and 200 Lists. Earlier native journeys find Item 05000 through search. Core independently qualifies every ordered identity and page. Neither result establishes that the unfiltered native catalog can scroll to its far end and back without replacing source selection.

Native Item reads currently fetch cancellable pages of 64, then accumulate all matching rows before display. SwiftUI List provides native row presentation. This qualification first exercises the existing behavior. It does not introduce a row-retention limit or change the accepted Q84 query-generation policy.

## Goal, readiness and expected end

Use the accepted production native UI boundary, existing disposable large-collection fixture and public controls. Begin with the unfiltered Item catalog at Scale Item 00001. A touch swipe moves away from that first row. Repeated native touch swipes then reach Scale Item 05000 without entering a search. Open it and observe Far-end collection marker and Todo state. Return to the catalog, scroll to the beginning and require the original first source identity. Return to the far end, reopen the same last identity and verify its notes and Todo state again.

Use public XCTest touch-swipe gestures. Accelerated test velocity shortens traversal, without adding a product jump action or providing human scrolling-speed measurements. No private model inspection, test-only app parameter or jump button is permitted. The original pointer-scroll proposal remains in its failed source snapshot below.

## Required tests and definition of done

Run the focused journey on phone and tablet. Endpoint rows must be hittable on screen, rather than merely present in accessibility metadata. Retain raw results, source/product hashes, observed identities and original captures. Compile the affected Mac test host and run focused Swift/Markdown checks. Record any functional failure before changing production.

This is a qualification of existing behavior, so no artificial failing product assertion is required. Passing endpoint navigation does not prove that every intervening row rendered, bounded row-data memory, scrolling hitches or the physical 300 ms acceptance gate. Rendering and verifying every intervening Item, Mac runtime, physical devices and whole-app polish remain separate work.

## Execution

Production behavior stays unchanged. Early attempts calibrate the public native controller. Only completed functional journeys receive endpoint qualification credit.

| Phase | Result | Observation |
| --- | --- | --- |
| phone-scroll-probe | Failed, 54.941 s | The initial touch swipe works. XCTest rejects pointer scrolling on this iPhone. |
| phone-indicator-probe | Failed, 126.244 s | The indicator's wide accessibility rectangle overlaps rows; its center drag returns to the beginning. |
| phone-indicator-edge | Failed, 96.469 s | The edge drag also returns to the beginning; no far-end row is observed. |
| phone-touch-swipes | Interrupted, exit 75 | Custom velocity 100,000 does not advance beyond the recorded Item 00020 accessibility tail. |
| phone-standard-swipes | Interrupted, exit 75 | Standard Fast gestures advance through Item 00257; stopped to calibrate a shorter complete traversal. |
| phone-calibrated-swipes | Failed, 85.062 s | Velocity 10,000 does not advance. The checkpoint assertion detects the unchanged Item 00019 tail. |
| phone-measured-swipes | Passed, 2,514.964 s | One function, zero failures or skips. Two forward traversals and the return to the beginning preserve endpoint identities and the last source's notes/Todo state. |
| tablet-measured-swipes | Failed, 888.043 s | The last row is hittable and opens its correct notes/Todo state. During return scrolling, its retained offscreen accessibility entry trips the original stall guard. |
| tablet-return-diagnostic | Failed, 81.886 s | Tapping the lowest hittable row does not open its details. This stops before the return-scroll observations and receives no scrolling credit. |
| tablet-return-middle-diagnostic | Passed, 155.398 s | A central visible row opens. The list returns to Item 00001 while retaining its selected source's details. Original hierarchies establish the offscreen selected-row behavior. |
| tablet-hittable-checkpoints | Passed, 2,272.652 s | One function, zero failures or skips. The complete journey passes with the corrected checkpoint and unchanged endpoint assertions. |
| mac-build | Passed, exit 0 | The affected fixture app and test host compile with signing disabled. No Mac UI test executes. |
| mac-hittable-checkpoint-build | Passed, exit 0 | The same affected Mac targets compile the corrected test source. No Mac UI test executes. |

Source review found that the original collection query could also match the Item detail Form through its completion control. The query now requires actual Scale Item row labels together with the Item identifier prefix. Returning from details must retain the far-end row on screen before the return-to-start traversal.

The phone and tablet functional runs overlap on separate simulators. The tablet uses test-without-building, records the products before execution and requires unchanged hashes afterward. The Mac build uses a separate derived-data directory. Their durations cannot establish a product performance result.

The tablet's far-end original capture shows Item 05000 fully visible in the native catalog, followed by successful detail assertions in the raw log. The failure occurs during return scrolling after source selection. The short central-row diagnostic proves the list moves normally. Its final hierarchy retains selected Item 00083 at y=5216 while Item 00001 is hittable and the selected source's details stay visible. The original stall guard uses that retained accessibility tail and can therefore fail while the list advances.

The corrected checkpoint considers only hittable Item rows. The [exact two-line patch](evidence/navigation/native-large-catalog-scrolling/hittable-checkpoint.patch) changes no endpoint, source identity, retained-position, notes or completion assertion. The phone pass uses the preceding monitor revision; the completed tablet rerun uses the corrected revision. Production and fixture sources remain unchanged across both. Standards and Spec source reviews confirm the correction and source distinction, with no remaining findings. The temporary diagnostic is removed from build sources; its original source snapshots and observations remain in the evidence packet.

The side memory observation during phone-touch-swipes times out and supplies no memory evidence. Both interrupted test runs are deliberate controller investigations, not passes or functional product reds. Sixteen original PNG files were individually inspected: four qualified phone captures, four qualified tablet captures, two from the earlier tablet attempt and six from the successful short diagnostic. Two diagnostic files contain identical pixels, giving fifteen distinct PNG hashes. The qualified tablet captures show the first and last Items fully accessible and the selected last source's notes/Todo state retained alongside the returned catalog. Strict Swift lint passes the single new test file. Mac compilation supplies no Mac UI runtime credit. Standards and Spec artifact reviews verify all 244 hashes across thirteen epochs with no remaining findings.

## Outcome and limits

The [evidence packet](evidence/navigation/native-large-catalog-scrolling/) retains exact commands, source snapshots and hashes, original result summaries, compressed raw logs, capture manifests and required app launcher, debug dylib and nested test-executable hashes. The phone and tablet UI journeys each pass one function without failure or skip. The native fixture datasets remain in the simulators; no cleanup is claimed.

This is functional endpoint and selection evidence for the existing unfiltered 5,000-Item catalog. It adds no production dependency, command/query field, storage change or test-only application parameter. It supplies no new Core unit or HTTP qualification, no proof that every intervening Item rendered, no 200-List scrolling result, no bounded data-memory or hitch result, and no physical 300 ms acceptance result. Those checks, Mac runtime, physical sync/account/Share, adaptive accessibility review and whole-app polish remain open map gates.
