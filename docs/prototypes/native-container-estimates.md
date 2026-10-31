# Native container estimates

## Context and goal

Q59–Q76 require separate full and remaining time for Lists and Itineraries, optional manual totals, exact native duration controls and useful uncertainty warnings. Core and actual HTTP already calculate manual and repeated List budgets under `1947215`. Native forms previously could not set or reset those totals, and container headers did not show the metrics.

The expected end of this slice is a saved List or Itinerary whose header shows its full estimate and remaining time separately. Native forms stage manual estimates with the existing unit/remainder editor. Cancel preserves saved content; Save uses the same Core field guards and recovery path. Reset returns to calculated values without rewriting completion or child estimates.

## Definition of ready

- Q64, Q66, Q67, Q70, Q74 and Q76 settle missing estimates, manual reset, remaining subtraction, zero/clamp warnings and exact duration controls.
- Core manual persistence/schema 15/portable 2 and budget calculations are qualified. The agreed seams remain public Core commands/reads, actual HTTP and native UI journeys.
- The existing SwiftUI duration editor provides Toggle, menu Picker, Stepper and exact smaller-unit remainders. No new numeric text input or duration authority is needed.
- Simulator/localOnly qualification can proceed while signing and physical iCloud/account/Share work remain deferred.

## Expected native behavior

List creation and editing, and Itinerary creation/editing, stage an optional manual estimate. Turning Use manual estimate off means calculation. The shared editor keeps exact minutes when display units change. Save applies only changed fields; unchanged notes, labels, links, source identities and completion remain intact. Save failure is presented through the existing native alert/recovery behavior.

Headers use native LabeledContent for Estimate and Remaining. Manual totals are labeled Manual; a differing calculated value is shown for comparison. Missing estimates show a known lower bound and warning. Missing finished estimates show an upper bound and one complete accessible warning message. Zero remaining with unfinished progress keeps the exceeded-total warning visible. Values use the primary text color; native warning labels keep their standard symbol and tint.

These controls do not fill a Schedule end or reschedule an entry. No derived counter is persisted. Calendar, catalog/group-row duration metadata and further UI polish retain their separate work.

## Definition of done and required /tdd

- A native List journey stages two hours plus five minutes, saves 125 minutes, cancels a reset, reopens the same List identity and explicitly resets to calculation. Empty progress stays No items.
- A native Itinerary journey saves four hours, cancels clearing, retains notes and identity through relaunch, then explicitly clears the manual total.
- A native Q76 journey starts with a too-small manual total and proves zero remaining still shows unfinished progress and a warning. It adjusts the total, completes an unknown-duration Lunch locally, and shows up to 240 minutes with one missing finished estimate. Supplying Lunch's 60 minutes resolves remaining to 180. Finishing Museum produces zero while full manual 240 remains saved.
- Run those journeys on phone and tablet. Recheck the shared Item duration editor and ordinary List creation/cancellation. Inspect actual native captures, including native toolbar overflow and tab selection.
- Run strict affected Swift/Markdown lint, whitespace checks and Mac app/UI-host compilation. Report Mac compilation separately from native Mac runtime.
- Keep the owning map issues open for catalog/group metadata, Calendar, administration/restoration, native scale, Mac runtime, physical sync/account/Share and whole-app polish.

## Execution

Six functions are qualified on iPhone and six on iPad. The phone bundle passes all six. The tablet mixed bundle passes five and fails the Itinerary test's catalog navigation; a separate corrected Itinerary run passes. The seven production Swift files are identical across those tablet runs. The execution record keeps the mixed bundle labeled Failed and identifies the corrected function rather than claiming an entirely green tablet batch.

The captures verify native unit/remainder controls, manual/reset state, lower/upper bounds, the exceeded-budget warning, and zero remaining with a retained manual total. The Q76 case resolves a missing finished estimate through the actual Item editor. Itinerary notes and container identities survive cancel/save/relaunch. The existing Item duration editor and ordinary List creation/cancellation also pass on both devices.

The executed red journeys exposed missing List/Itinerary controls, incorrect singular accessible wording and separate warning icon/text elements. Test-only navigation corrections handle the native toolbar overflow and visible tab selection. A recording proved the tablet was still on Items while a failed attempt read retained inactive List elements. Those attempts are excluded from qualification. Primary text color fixes the faint numeric captions seen during visual review.

Eight changed Swift files pass strict lint. Mac app and UI test host build-for-testing passes, with zero native Mac runtime functions. Core and MCP remain unchanged from `1947215`; their existing qualification is retained. Catalog/group-row estimate metadata, further native context fixtures, Calendar, full administration/restoration, native scale, Mac runtime, signed physical sync/account/Share and whole-app polish remain open.

## Contextual List-entry previews

Previously, nested List headers showed progress but no full or remaining duration. Reading the standalone List's remaining time would give the wrong result because itinerary appearances have independent completion. The goal of this slice is to display each List appearance's contextual budget using the public Core read, preserving those values when its children are filtered away.

Readiness consists of the accepted repeated-appearance, archive, Q57/Q75 filtering and Q71/Q76 budget rules, plus the qualified root duration component. The required /tdd interfaces remain public Core read/reopen, actual HTTP and native UI. Completion requires separate repeated-branch totals, matching-header filtering with hidden children, retained identities after relaunch, strict lint and affected app/test-host compilation.

One new native function passes on each simulator. It creates a 240-minute manual List containing a 120-minute Museum, completes Museum in the standalone List, then references that List twice in an Itinerary. Both branch previews initially show 240 remaining. Completing only the first itinerary appearance changes its remaining to zero; the second stays 240. Searching for the List name hides its unmatched Museum rows without reducing either summary. Relaunch preserves both branch identities and values.

The executed native red failed because the preview was absent. Intermediate phone attempts reached the correct numeric state but failed to reveal the collapsed native search drawer. The corrected test reveals search before typing; both final bundles pass. Captures show the native duration captions and independent progress. The filtered phone capture has the keyboard over the branch rows, so it is not visual proof of their numeric values; the executed assertions and tablet capture supply that evidence.

The existing filter regression exposed a zero-sized child StaticText beneath the native ProgressView. Its exported hierarchy retained the correct root ProgressIndicator label. The corrected phone journey passes cumulative header/child filters, independent Done/Todo branches and relaunch. It checks the actual progress component after bounded scrolling reveals its header, and chooses a visible native tab with verified selection. Three failed regression attempts are excluded from qualification. The 321-second fixture journey is functional evidence; it does not close responsiveness or scale gates.

The execution record retains exact bundles, counts, source hashes and exclusions. Twelve affected Swift files pass strict lint. Mac app/UI host compilation passes with zero Mac UI runtime. Catalog estimate previews, further uncertainty/archive UI fixtures, Calendar, administration/restoration, native scale, signed physical sync/account/Share and whole-app polish remain open.

The following [catalog slice](catalog-container-estimates.md) adds compact full/remaining captions to List and Itinerary catalogs, including manual and uncertainty information. It retains the broader context/scale, Calendar, administration/restoration, native Mac runtime, signed-device and whole-app polish gates.

The later [archived-Item manual-budget journey](native-container-estimate-archive.md) qualifies an unknown-duration archived child inside a partial manual List branch on phone and iPad. It preserves full progress and upper-bound warnings, retires the whole completed branch budget, and restores original local states and remaining time after relaunch/unarchive. The subsequent [global-Done journey](native-container-estimate-global.md) qualifies the shared-source path, retained local Todo after reopening, missing-estimate resolution and independent standalone List state after relaunch. These narrow the earlier mobile Q76 fixture gaps; broader platform/visual gates remain open.
