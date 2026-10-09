# Native navigation prototype qualification

Work for [Navigation prototype](https://github.com/dvcol/planner/issues/14) on `prototype/navigation`. Q34 accepts the native UI journeys and fixtures. Q35 requires confirmation before deleting a Category/Tag with any association. The user delayed signing and physical setup while authorizing simulator and local Mac work.

## Starting state and first goal

The inherited app was a placeholder. The first slice opens Lists → Tokyo Food, shows its unfiltered 1 of 2 progress under the ordinary Todo/Active filter, switches both filters to All and opens Nezu Museum's membership 401. Its detail must retain that appearance and show Local Done / Global Todo. Opening its source explicitly shows Item 101 in global context. Tokyo Weekend retains 0 of 3 progress.

The app links the existing PlannerCore package. This first layout experiment reads the committed full-graph backup through a temporary, read-only fixture projection. It resolves source references by identity and reads independent appearance flags from that file. It does not import into the existing Item-only Core store, mutate saved records, validate a general backup, or acknowledge a durable save. Unrendered backup fields remain in the original resource. Core/store tests and integration with full-graph persistence remain separate required evidence. This prototype must not be promoted to production.

## Native configuration

`PlannerNavigation` builds the multiplatform app and a native XCUITest target, without adding the Mac-only MCP test target to simulator testing. The existing pinned packages remain authoritative. Debug builds use the active architecture so the app and its local Swift package agree on the selected simulator architecture. The fixture JSON is an explicit app resource referenced from its existing location.

Phone navigation uses native tabs and stacks. Regular-width iPad and native Mac initially use a three-column NavigationSplitView with a catalog, container contents and selected Item. Filter controls are native menus. The prototype identity inspector exposes source and appearance separately, with readable, selectable values. On iPad portrait the system presents the sidebar as an overlay. The journey opens it with the native Show Sidebar button; selecting a container closes the overlay so it cannot intercept filter taps. Layout comparison and human review remain open.

## Executed evidence

Setup, failing behavior, passing journeys and screenshots are recorded here as they finish. Build failure and simulator installation failure are setup outcomes, never behavior-test red evidence.

The initial simulator build exposed an architecture mismatch: the app attempted x86_64 while its Swift package built arm64. The Debug active-architecture setting corrected this. The next build-for-testing passed. Initial UI startup then failed in the simulator install service with a missing placeholder promise. A direct simulator boot, completion of boot status and app installation succeeded; the subsequent UI test executed against the placeholder and failed because Lists navigation was absent.

The first implementation attempt exposed native TabView accessibility behavior: the identifier applied to a tab's root did not identify its button. The test now uses the visible Lists label on every platform. A later attempt reached the local detail and exposed combined LabeledContent accessibility. The identity inspector now presents separate label/value elements. These findings are retained in the local logs and result bundles.

### First slice results

| Destination / run | Outcome | Evidence |
| --- | --- | --- |
| Placeholder on phone, behavior red | One executed journey failed at missing Lists navigation. | [Red summary](evidence/navigation/selection-red.json) |
| iPhone 18 Pro simulator, complete first journey | One journey passed, zero failures/skips. | [Phone summary](evidence/navigation/selection-phone.json), [appearance](evidence/navigation/phone-list-appearance.png), [source](evidence/navigation/phone-source-item.png), [itinerary](evidence/navigation/phone-itinerary.png) |
| iPad Air 11-inch M4 simulator, portrait | One journey passed, zero failures/skips after sidebar correction. | [Tablet summary](evidence/navigation/selection-tablet.json), [appearance](evidence/navigation/tablet-list-appearance.png), [source](evidence/navigation/tablet-source-item.png), [itinerary](evidence/navigation/tablet-itinerary.png) |
| Native arm64 Mac | App and UI runner build passed. UI runner initialization failed before the journey could execute: timed out enabling automation mode. | [Startup failure summary](evidence/navigation/selection-mac-setup-failure.json). Xcode reports one failed planned test; this is no executed behavior proof. |

The phone screenshot run preceded the iPad-specific overlay correction and addition of the test's normal sidebar-opening helper. The fixture and phone path are unchanged. Subsequent layout work will run the affected journeys again. Raw result bundles remain in `/private/tmp/PlannerNavigationSelectionPhoneFinal.xcresult`, `/private/tmp/PlannerNavigationSelectionTabletAllColumns.xcresult` and `/private/tmp/PlannerNavigationSelectionMacAttempt.xcresult`. Committed summaries remove device identities while retaining reported counts, OS and hardware model.

The app can be launched with `./scripts/navigation-prototype.sh phone`, `tablet` or `mac`. The script requires installed Xcode 27 and the named simulator runtime, builds only the navigation scheme and scopes the developer directory to Xcode. Its shell syntax passes; equivalent build/install/launch operations above were executed directly. It does not configure paid signing, App Groups or CloudKit.

Reproduce the first journey with the existing resolved package cache:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Planner.xcodeproj -scheme PlannerNavigation \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' \
  -derivedDataPath /private/tmp/PlannerNavigationDerivedData \
  -onlyUsePackageVersionsFromResolvedFile \
  -clonedSourcePackagesDirPath /private/tmp/PlannerMCPSourcePackages \
  -parallel-testing-enabled NO \
  -only-testing:PlannerNavigationUITests/NavigationJourneyTests/testListAppearanceKeepsItsIdentityWhenOpeningTheSourceItem \
  test
```

Substitute `platform=iOS Simulator,name=iPhone 18 Pro` for phone. Use `platform=macOS,arch=arm64` and a separate derived-data directory for Mac compilation. Mac UI execution remains unqualified. Xcode's unsuccessful simulator diagnostic collection reported that its subprocess could not locate simctl under the global Command Line Tools selection; the executed test logs and result summaries still exist. No global toolchain setting was changed.

## Three layout comparisons

The layout selector now offers Library first, Itinerary first and Map alongside list. On phone it is a native navigation toolbar menu; Itinerary first initially selects the Itineraries tab. On iPad regular width it is a clearly marked menu row in the native sidebar. Mac uses the native toolbar. The earlier global inset chooser interfered with phone tab or iPad sidebar taps; regression checks exposed this and the chooser was moved into platform controls.

Library first presents the catalog, contextual contents and detail columns. Itinerary first uses a two-column itinerary catalog/ordered-child view on larger screens. Map alongside list replaces selected appearance detail with native MapKit and opens its unchanged appearance in a native inspection sheet. An Item without owned coordinates has a No location view and remains available. The map renders the fixture's owned coordinate, not a geocoded position for the museum's name. It currently shows the selected appearance; a full filtered map of all places remains unqualified. This is a presentation comparison over the same read-only fixture, with no completion, archive or saved-content writes.

| Public journey | Phone | iPad portrait | Observable outcome |
| --- | --- | --- | --- |
| Library filter/selection/source | Pass | Pass | 1 of 2; membership 401 Local Done / Global Todo; explicit source 101; itinerary 0 of 3. |
| Itinerary-first selection | Pass | Pass | Direct entry 451 Local Todo / Global Todo, independently of membership 401; itinerary 0 of 3. |
| Map pin and generic Item | Pass | Pass | Pin opens membership 401 with retained local/global flags; archived generic membership 402 remains visible under All and shows No location. |

The complete affected UI target executes three journeys on each simulator, with zero failures/skips: [phone summary](evidence/navigation/layouts-phone.json), [tablet summary](evidence/navigation/layouts-tablet.json). The new slices each started with an executed failing test: [itinerary-first red](evidence/navigation/planning-red.json), [map red](evidence/navigation/map-red.json). The chooser accessibility probes were adapted to native controls and collapsed iPad sidebars; the agreed observable identities, completion flags and progress did not change.

| Comparison | Actual phone | Actual iPad |
| --- | --- | --- |
| Library detail | [Phone](evidence/navigation/layouts/phone-library.png) | [iPad](evidence/navigation/layouts/tablet-library.png) |
| Itinerary first | [Phone](evidence/navigation/layouts/phone-planning.png) | [iPad](evidence/navigation/layouts/tablet-planning.png) |
| Map alongside list | [Phone](evidence/navigation/layouts/phone-map.png) | [iPad](evidence/navigation/layouts/tablet-map.png) |
| Generic Item | [Phone](evidence/navigation/layouts/phone-no-location.png) | [iPad](evidence/navigation/layouts/tablet-no-location.png) |

Raw current UI bundles are `/private/tmp/PlannerNavigationThreeJourneysPhone.xcresult` and `/private/tmp/PlannerNavigationThreeJourneysTablet.xcresult`. Use the same focused scheme/destinations above without the single `-only-testing` argument to run its three UI journeys. The current native Mac app and UI runner also compile with local ad hoc signing; Mac UI automation remains unqualified because runner initialization timed out. The updated app host's two existing public MCP read/command suites pass four test methods, with [reported counts and outcome](evidence/navigation/mac-host-regression.json). That verifies the affected host still supports those local routes, not every MCP feature or client.

MapKit uses Apple's [native Map and Annotation API](https://developer.apple.com/documentation/mapkit/map). Fixture location values use the existing shared PlannerCore owned-location type. No additional package, provider enrichment, location permission or Calendar export is introduced.

Q36 asks how a live List entry should appear inside an itinerary. The current two identically titled Nezu Museum rows expose the issue. Expanded named List groups, flat rows with source-List subtitles and compact navigable List rows have different scanning/navigation costs; none changes independent appearance state or child-based progress. The user has not yet selected that presentation. Final layouts remain subject to actual human review.

## Expanded appearance identity correction

The next agreed journey opens Nezu Museum through Tokyo Food inside Tokyo Weekend. Its detail must show Local Todo / Global Todo even though the standalone List membership is locally Done. The inspector must expose entry 452 and membership 401 together, because membership 401 can occur under multiple itinerary List entries.

The [executed red](evidence/navigation/expanded-identity-red.json) reached that detail and failed at its incomplete displayed identity. The inspector showed only membership 401. The [focused green](evidence/navigation/expanded-identity-green.json) passes after displaying the complete appearance address. The [actual phone screenshot](evidence/navigation/layouts/phone-expanded-appearance.png) shows the unchanged source identity 101, independent Todo flags and full address. The redundant single association ID was removed from the temporary projection.

Raw bundles are `/private/tmp/PlannerNavigationExpandedIdentityRed.xcresult` and `/private/tmp/PlannerNavigationExpandedIdentityGreen.xcresult`. Each executed one test, with one failure before the correction and zero afterward. These focused runs took about 266 seconds overall, including substantial native test startup/teardown time; their action logs span about 12 seconds. They are correctness checks, not the accepted 300 ms physical-device query measurement.

The updated native Mac app and four-journey UI runner compile. A standalone local Mac app process was also launched from its derived products. Process launch does not establish rendered Mac layout, interaction or keyboard/accessibility behavior; the earlier automation startup failure still leaves those gates open. [Source hashes](evidence/navigation/layout-comparison-source.json) identify the corrected comparison code, tests and unchanged fixture.

## Local build reproduction while signing is deferred

Committed source `90dd8cf` was exported with `git archive` and built with fresh derived products. The narrow `PlannerNavigation` Mac build-for-testing passed and produced the arm64 app and UI runner. The archived source hashes match the comparison manifest. This is clean compilation evidence, not a successful Mac UI run.

The same committed app also compiles for `generic/platform=iOS` with `CODE_SIGNING_ALLOWED=NO` and fresh device products. The executable is arm64, its SDK is iphoneos27.0, and codesign confirms the app is unsigned. It is ready for later signing configuration, not installed or launched on a physical device. [Build evidence and limits](evidence/navigation/local-builds.json) record both outcomes. Raw logs remain `/private/tmp/PlannerNavigationCleanMacBuild.log` and `/private/tmp/PlannerNavigationUnsignedDeviceBuild.log`.

Reproduce the device compilation with the scoped developer directory, resolved-package options above, destination `generic/platform=iOS`, a separate derived-data directory and `CODE_SIGNING_ALLOWED=NO build`. No team/account choice, provisioning, App Group or CloudKit setup was performed.

## Remaining gates

The first read-only UI slice cannot establish completion writes, query generation/window completeness, ordinary import, recovery, capture, schedules, CloudKit or Share feasibility. Those journeys must use their approved public seams and truthful outcomes as implementation proceeds. All three structural alternatives, persistence/reopen, orientation/resizing, keyboard/focus, Dynamic Type, VoiceOver and human layout decisions remain required. Physical-device long-list latency and memory, signed Share and account/sync tests remain deferred rather than waived.
