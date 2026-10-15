# Native container catalog sorting

## Context and starting state

Core and MCP HTTP now implement the approved Q85, Q86 and Q87 catalog sort contract. Native Lists and Itineraries still read alphabetical catalogs and have no catalog sort controls. Item/List-content sorting already uses native Menu and Picker controls with local preferences.

## Goal and definition of ready

Use the shared Core ordering in native catalog menus for Title, Created, Last updated and Full estimate, with ascending/descending selection. Remember independent choices per catalog and local dataset ownership namespace. Preserve valid selected source identities and reject late results for older sort, filter, revision or dataset inputs. These presentation preferences never enter portable data or rewrite route order.

Use the accepted production native UI boundary with disposable local stores and existing fixture launch configuration. A new fixture supplies four Lists and four Itineraries. In creation order they are Zulu plan, Alpha plan, Missing plan and Manual plan. Their full estimates are 180, 60, incomplete with no known minutes, and manual 240 minutes. Missing is edited last in each catalog so Last updated differs from Created. Relaunch reopens the same real store; a different fixture dataset uses an independent store and production namespace.

## Required TDD and definition of done

The first phone/tablet journey requires alphabetical defaults, Full estimate ascending Alpha/Zulu/Manual/Missing, descending Manual/Zulu/Alpha/Missing, and Created descending Manual/Missing/Alpha/Zulu. Lists retain Created descending while Itineraries retain Full estimate ascending. Relaunch preserves both choices. A separate local dataset starts both catalogs at Title ascending; returning to the original dataset restores both choices. Retain raw red/green results and original screenshots.

Last updated ascending must give Zulu/Alpha/Manual/Missing, independently of Title and Created. A second journey selects Zulu, changes sort beside its retained contents on a wide layout, then removes the shared Alpha Item estimate through its native edit form. Both catalogs must move Alpha into the incomplete group, giving Zulu/Manual/Alpha/Missing ascending. Itinerary Last updated descending remains Missing/Manual/Alpha/Zulu. An Archived-only empty result followed by All, Full estimate and Active must settle at Manual/Zulu/Alpha/Missing descending. These native actions verify successive choices; they do not by themselves prove an out-of-order I/O completion. These checks use the same public UI boundary. Do not claim timing or out-of-order completion coverage without observing it. Compile affected Mac targets and run focused Swift/Markdown checks. Physical account transitions, Mac UI runtime, large-catalog performance and whole-app polish remain separate map gates.

## Execution

The evidence directory retains every source revision and raw log. Earlier driver failures are separate from the behavioral red and final production checks.

| Phase | Result | Interpretation |
| --- | --- | --- |
| phone-red | 1 failure, 12.283 s | Navigation ran before the fixture was ready. Not a feature red. |
| phone-clean-red | 1 failure, 23.657 s | The catalog has no Sort control. Behavioral red. |
| phone-green | 1 pass, 103.115 s | Initial estimate/creation-order and persistence journey. |
| phone-extended | 1 pass, 1 failure, 163.768 s | Button-only test query missed the native estimate switch. |
| phone-qualified | 1 pass, 1 failure, 177.731 s | Despite its phase name, this failed. The native back label is Planner, not Lists. |
| phone-live | 1 pass, 95.891 s | Correct accessibility roles and native BackButton navigation. |
| phone-final | 2 passes, 214.799 s | Earlier combined phone source revision. |
| tablet-final | 2 failures, 73.863 s | The initial sidebar was collapsed. |
| tablet-adaptive | 2 failures, 60.288 s | The narrow native toolbar placed New List in More. |
| tablet-toolbar | 1 pass, 1 failure, 226.385 s | The second journey reached the final archive sequence, but a toolbar tap left the menu open. |
| tablet-live | 1 pass, 110.523 s | A blank-content dismissal and toolbar hit-test check fix the controller. |
| phone-final-current | 2 passes, 217.831 s | Combined phone qualification before the additional tablet-only assertion. |
| tablet-final-current | 2 passes, 236.653 s | Combined tablet qualification on the identical seven-file source revision. |
| tablet-selection-qualified | 1 pass, 119.229 s | Repeats the affected tablet journey after strengthening the selection assertion. |

The fixture's later revision edits Missing last to distinguish Last updated from Title and Created. Corrected helpers use the native tab and visible Sort control for readiness, query the estimate switch across accessibility roles, reveal catalogs through native navigation, and dismiss retained iPad menus by tapping inspected blank fixture content. These corrections do not change production behavior.

The strengthened wide-layout assertion observes the actual descending catalog before checking that Zulu's selected contents remain. Standards review found the prior assertion could run before refreshed rows published. The focused tablet journey now passes with that correction. This is the only source difference after the combined phone/tablet runs and Mac build, recorded in `selection-assertion.patch`. Production and fixture source hashes match across all three qualifications. The added assertion runs only on wide layouts, so only the affected tablet journey was repeated.

## Result and limits

Both combined simulator bundles execute two functions in one suite, with zero failures or skips. The final focused tablet bundle executes the affected function once with zero failures or skips. Native Sort menus implement all approved modes and directions through Core, retain independent catalog choices through relaunch and local dataset changes, preserve valid selected contents, and refresh both catalogs after a shared estimate edit. The filter/sort sequence ends in the expected final order. Source guards cover changed sort, archive, revision and ownership namespace; these UI journeys do not control out-of-order I/O timing.

The affected Mac fixture app/test host builds with signing disabled. It compiles the same production/fixture sources as the simulator runs and executes no Mac UI tests. Strict Swift lint passes all seven changed files. This slice adds no schema change, provider service, production dependency or test-only public parameter. Sorting uses per-device UserDefaults under the current dataset ownership namespace, outside portable backups.

The host is macOS 27.0.1 build 26A434, Xcode 27.0 build 27A266a and Swift 6.4. Simulators are iPhone 18 Pro and iPad Air 11-inch M4 on iOS 27.0. Commands set DEVELOPER_DIR per process. Raw logs retain optional controller diagnostic and remote accessibility messages; a passing xcresult is not a claim that every diagnostic succeeded. Disposable native fixture datasets remain in the simulator, with no fixture-removal claim.

Physical account transitions, signed sync/Share, Mac UI runtime, large-catalog performance, keyboard/VoiceOver/resizing, deterministic overlapping-query publication and whole-app polish remain open map gates. Separate local fixture datasets exercise preference isolation, not a real iCloud account switch. The existing missing-estimate subtitles remain wordy and belong to the broader polish review.

## Evidence

The [evidence packet](evidence/navigation/native-container-catalog-sorting/) retains phase commands, source snapshots/hashes, raw losslessly compressed logs, exit records and all three required product hashes per build: app launcher, production debug dylib and test executable. Combined and final focused result summaries come from xcresulttool. Nineteen original PNGs were inspected: seven from the combined phone bundle, eight from the combined tablet bundle and four from the final focused tablet bundle. Catalog orders and native controls match the expected states; existing missing-estimate subtitles wrap without truncation in these captures. The tablet sidebar overlays part of the selected content, whose unique activity is separately asserted by the journey. Original screenshots remain unchanged; the manifest and inspection record identify their phases and intended states. The report and adapter contract pass focused Markdown lint. Source review has no remaining findings after the selection assertion correction. Standards and Spec artifact reviews verify all 236 packet hashes, source epochs, required products, results and scope, with no remaining findings.
