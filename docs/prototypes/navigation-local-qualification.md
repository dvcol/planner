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

## Remaining gates

The first read-only UI slice cannot establish completion writes, query generation/window completeness, ordinary import, recovery, capture, schedules, CloudKit or Share feasibility. Those journeys must use their approved public seams and truthful outcomes as implementation proceeds. All three structural alternatives, persistence/reopen, orientation/resizing, keyboard/focus, Dynamic Type, VoiceOver and human layout decisions remain required. Physical-device long-list latency and memory, signed Share and account/sync tests remain deferred rather than waived.
