# Native Itinerary toolbar compatibility

Status: local qualification in progress. Signing remains deferred.

## Scope and existing test boundary

The contextual Map captures show an absent Itinerary title in portrait and an aggressively truncated title in landscape. Apply the existing narrow collection pattern consistently: Filters and Add stay direct, while native More holds secondary actions. Wide layouts and Mac keep their direct controls. Preserve source and appearance identities, route order, completion, filters and all current validation.

Use the already approved native fixture and production-app UI boundaries. Start with a real saved City trip, require its native title and primary actions, and actually open/cancel Add. Qualify the secondary actions and contextual Map workflows after the minimal correction. Mac compilation remains separate from unavailable Mac UI execution. No Core/MCP interface, target, package, provider or production test hook is proposed.

## Diagnosis

Ranked predictions:

1. Excess direct actions crowd the title. Grouping only secondary actions in native More should restore the title and direct Add in narrow panes.
2. Native overflow is controlled by the actual pane width, rather than the device size class. Measuring that width should cover narrow regular-size-class iPad panes too.
3. The title is missing independently of toolbar crowding. If grouping restores Add but the same short title remains absent, investigate its navigation ownership before changing the title rendering.

The first tracer records the actual navigation hierarchy and an original screenshot before requiring the title. Its production inputs remain unchanged until the result and products are retained.

## Initial native outcomes

The original iPad tracer fails in 18.956 seconds because the navigation title is absent. Grouping secondary actions restores the native title but leaves only 40 points for a 63.405-point headline in the resulting 340-point pane. Automatic placement does not change that outcome. Neither diagnostic receives passing credit.

The initial tracer incorrectly required the whole short inline title to fit on wide devices even when their actual pane was narrow. Align the supported expectation with the existing List qualification: the native title remains present, and the full content heading is readable in the collection. Phone still requires the whole short inline title to fit. Also require the full collection heading in Map mode, where it was missing. On original production, this corrected tracer fails at the absent native title in 17.878 seconds.

The minimal correction measures the actual pane, groups secondary actions with native ToolbarOverflowMenu, and shares the same native Text heading between List and Map. No title width, custom navigation bar, color or system font override is introduced. The corrected tracer stays unchanged for its first passing attempt.

## First passing title and Add journey

The unchanged supported tracer passes on dark iPad in 37.333 seconds. It actually opens and cancels Add, then enters Map and finds the full City trip heading. Both original captures are inspected. The narrow inline title remains truncated; the full collection title is readable in both representations. This is scoped qualification, not final title-tier or whole-app acceptance.

The tracer comparison verifies identical test bytes across the corrected red and first green, with only SavedItineraryViews changing among all 1,094 captured inputs. Existing native test callers of relocated Itinerary Edit, Reorder and actions now use named menu controls, preserving actual accessibility interaction rather than assuming direct toolbar placement. Separate secondary-action and relaunch journeys remain in progress.

## Secondary-action diagnostic

The first expanded tablet cohort fails: its secondary-action test reaches Edit, canceled Schedule and Map, then the test's dismissal tap lands on the View submenu instead of outside the native popover. The retained original shows that submenu still open. The next title test also fails while finding its fixture row; the capture alone does not establish the cause of that second outcome.

Correct only test interaction: dismiss through an outside point in the owned window, reacquire transient More controls after their menu closes, and explicitly terminate the owned fixture app before each new journey. Preserve the original failed results. Production remains unchanged from the first passing title checkpoint.

## Passing native controls and actual filtered drag

The corrected dark-iPad cohort passes both functions: secondary actions/relaunch in 140.732 seconds and title/Add/Map in 37.910 seconds. Light iPhone passes the same functions in 115.662 and 35.501 seconds. Original captures confirm direct Filters/Add and native More. The short phone inline title fits; the narrow iPad inline title can truncate while its full collection heading remains readable.

The existing filtered-entry drag journey passes on dark iPad in 99.503 seconds. It actually enables native editing through More, drags a visible entry around a hidden completed appearance, then reopens More for Done. Full order, original appearance IDs and hidden completion survive relaunch. No gesture implementation was changed in this slice.

The current Mac build-for-testing passes in 11.289 seconds with 1,094 matching inputs and nine retained app/Share/test products. This supplies compiler credit only. Production repeated-context Map and largest-text follow-ups remain in progress.

## Largest-text failures and responsive correction

The first phone accessibility cohort fails before reaching Map: repeated route rows are below the enlarged content summary, and the standalone List checkbox is not hittable. Original hierarchies and two recording-derived frames are retained with hashes and extraction provenance. These are failures, not accessibility acceptance.

Correct native test setup to reveal each exact appearance separately and scroll back to full progress. The unchanged-production scrolling cohort still fails: direct stops reach Map but its pin is unavailable, while the List checkbox remains covered after eight actual native scrolls. Its hierarchy gives the Map collection only 198.3 points including its enlarged footer, leaving no usable pin area. The original List capture shows the pinned summary covering the checkbox. These establish app layout failures independently of the earlier test setup assumption.

Use native flowing content for the List summary, with selection disabled for that summary row. Keep ForEach move offsets, saved identities, full metrics and command semantics. For both List and Itinerary Map summaries, reuse one small app-internal SwiftUI layout: ordinary text keeps the existing summary; accessibility text gets a native ScrollView capped at half the available height. The native Map remains outside that ScrollView, retaining its own gestures and footer. This adds no font cap, hidden metadata, Core contract or production test seam.

The corrected scrolling tests stay unchanged for the first app-layout rerun. Normal-size, drag/relaunch, enlarged-summary scrolling and matching compiler regressions will follow its outcome.

The first responsive-layout rerun gets both routes through native completion setup, but both still fail at the required Map pin. Its retained hierarchy shows a 520.7-point summary and a 12-point native canvas, with the full location footer still present. The flexible height limit did not give the Map sufficient space. Keep that failure and the recording-derived canvas frame. Constrain the layout to the actual viewport, use an explicit one-third-height summary at accessibility sizes, and make Map content fill the remaining space. The next focused run tests that layout against the same direct-stop workflow.

The strict viewport direct-stop run passes in 353.858 seconds after long native idle waits during a pre-Map scroll. It finishes before the inspected interruption could be sent; the retained interruption record has signal null. The stack sample and delays remain a runtime/stability observation. This is passing functional evidence, not an ordinary timing baseline.

Remove only unnecessary test scrolling when the updated progress label already exists; keep the count, exact identities and independent local/global completion assertions. Add an explicit native accessibility check that scrolls the summary to its missing-estimate warning while the pin and Locations stay hittable. The first direct-stop execution with that added check passes in 122.117 seconds. Repeated List branches and tablet qualification remain in progress. Current Mac build-for-testing passes in 52.699 seconds with matching 1,094 inputs and nine products; its runtime credit remains false.

The final enlarged-phone cohort passes both functions: direct stops in 122.117 seconds and repeated List branches in 154.084 seconds. Both explicitly scroll the summary to the missing-estimate warning while the pin and Locations remain hittable. Exact selection, independent completion and original bookmarks remain verified. The wrapper observes largest accessibility text, dark appearance and Increase Contrast, then restores the original settings. Tablet and ordinary-layout regressions remain in progress.

Fourteen completed duplicate attachment-export directories are removed after auditing and rechecking originals, retained copies and open handles. This removes 375,875,652 nominal bytes while preserving original xcresults, packet captures, input/product evidence and user data. Physical APFS gain is not measured.

## Largest-text tablet follow-up

The matching iPad cohort fails twice. Direct stops pass the portrait summary/selection checks but lose their pin after landscape resize. The actual hierarchy leaves only 128 points for the native canvas while the enlarged full-text footer dominates the remaining Map area. The repeated-List case fails earlier, during native scrolling to the second child; its original capture cannot establish the gesture or layout cause alone.

Three recording-derived frames retain the scroll diagnosis with original-video and frame hashes. The content moves between those frames. A focused repeated-List probe changes only the helper from slow to ordinary native swipes, leaving production unchanged. A compact accessibility footer is the next independent app correction; preserve full spoken counts and the native Locations action.

The ordinary-swipe probe reaches both exact repeated-List children and their independent completion assertions, then reproduces the same landscape pin failure in 150.398 seconds. Production remains unchanged for that probe. Keep the natural gesture; this result does not establish an app scrolling defect.

At accessibility sizes, use a compact numeric location count with the complete spoken count, and the native Locations icon with its full accessibility label. A native ViewThatFits keeps a vertical fallback for counts too wide for the pane. Ordinary text keeps the original full footer. No font size is capped and no saved or unresolved locations are removed. The existing failed landscape journeys remain unchanged for the footer rerun.

Both compact-footer tablet cases still fail at the landscape pin, in 111.114 and 139.063 seconds. The new hierarchy gives the native canvas 287.5 points, versus the earlier 128, and the footer control is 111.5 by 67 points. The inspected original capture shows the counted marker clipped behind the summary. Footer space was one defect but did not close rotation. A focused camera probe reuses the unchanged direct-stop journey and recenters only automatic cameras when geometry changes; user-positioned cameras remain untouched. This is a diagnosis, not passing credit.

Q152 A is accepted during this run. The fresh-restoration contract no longer waits for a policy answer; dependent implementation follows collection of the active UI epoch.

The automatic-camera geometry probe fails in 111.702 seconds and is removed. A shorter existing-fixture tracer first fails during catalog selection, before Map; selecting the visible native title and waiting for the Itinerary toolbar corrects its setup. It then passes rotation in 40.913 seconds with unchanged app layout. Adding the production journey's accessible summary scroll also passes, in 42.943 seconds. Both portrait/landscape captures and full native hierarchies remain retained. These fixture results do not close the production Maps-link failure.

The next production probe adds native pin/form frame attachments around the existing detail-scroll gestures. It changes no app behavior or assertions. This distinguishes a gesture moving the wrong pane from a pin that moves only during rotation; do not change the app camera or safe-area policy without that result.

The production detail-scroll diagnostic fails again at rotation in 115.992 seconds. Its attachment shows the pin at `(30, 750.333, 280, 93.5)` both before and after scrolling the correct detail form at `(341, 0, 479, 1180)`. That gesture does not move the Map pin. The next unchanged-journey probe replaces only the accessibility summary's sibling layout with a native top safe-area inset; ordinary text keeps its original VStack. Camera probing remains removed.

The native top-inset probe passes both rotation orientations and pane-boundary assertions, then fails later at the completion header after reselecting the same already-scrolled detail. Its hierarchy retains the original exact bookmark near the bottom and the original locally Completed appearance; the detail header is offscreen. Keep the app correction. Remove the temporary frame diagnostic and actually reveal the completion header through the selected native Form before asserting its saved state. The new test still requires the full completion value, original bookmark and independent second appearance.

Replace the older footer test's forced-stacking assertion with full spoken count/action labels, no overlap and at least 44-point action dimensions. Its provider, uncertainty, saved-link and visible warning checks remain unchanged. The fixture rotation test skips phone-only pane comparison and conditionally scrolls the accessible summary, so ordinary-size runs remain valid.

The corrected three-function iPad cohort passes: direct stops in 140.279 seconds, repeated List branches in 164.436 seconds and provider/count/uncertainty in 72.894 seconds. Largest accessibility text, dark appearance and Increase Contrast are observed and restored. Original captures and all 1,094 inputs/four products are retained. The earlier landscape original still shows a partly obscured marker despite hittability; functional passing results do not grant visual acceptance.

Strengthen the shorter fixture tracer to require the complete pin rectangle between the visible summary and Map edges. Seed its existing saved source at the same `35,139` coordinate as the failing Maps-search workflow, through the fixture app only. The ordinary fixture location stays unchanged. This isolates the coordinate from provider and source-identity behavior before probing the native map style. No production test control is added.

The first strengthened whole-marker trial fails during catalog selection, before Map, and grants no marker evidence. Waiting for the actual catalog row frame to settle before tapping the visible title corrects that fixture setup. The unchanged whole-marker test then passes in 55.141 seconds. Its inspected landscape original shows the full capsule below the scrolled summary at the same 35,139 coordinate. The marker text is still truncated. This rules out coordinate or terrain alone as the explanation for the production Maps-link journey's partially obscured marker. The production link/preview/detail-scroll sequence and final visual acceptance remain open; do not add a flat-map style on this evidence.

## Filtered List regression

The current ordinary iPad journey passes in 190.808 seconds. It performs an actual filtered native drag, retains the hidden completed membership, verifies full progress and visible counts, then relaunches Planner and checks exact appearance identities, saved Manual order and local completion again. All 1,101 inputs and four built products reconcile. This qualifies the flowing List summary's reorder offsets through the existing native boundary. The Map marker's production large-text clipping and final whole-app visual acceptance remain open.
