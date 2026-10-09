# Native navigation prototype qualification

Work for [Navigation prototype](https://github.com/dvcol/planner/issues/14) on `prototype/navigation`. Q34 accepts the native UI journeys and fixtures. Q35 requires confirmation before deleting a Category/Tag with any association. The user delayed signing and physical setup while authorizing simulator and local Mac work.

The latest qualified source and screenshots are in [Useful Item details and roomier referenced Lists](#useful-item-details-and-roomier-referenced-lists). Earlier sections preserve the outcomes and presentation of previous revisions.

The human accepted Q38 A, Q39 B, Q40 A, Q41 A and Q42 A, then accepted Q43 A, Q44 A, Q45 A and Q46 A. The [accepted row decisions](../navigation-prototype-review.md#accepted-review-answers) and [row contract review](../navigation-row-contract-review.md) record the exact declarations and required tests. Native rich rows, completion writes, drag-and-drop and provider lookup remain unimplemented. These documentation amendments add no runtime qualification to the seven-journey presentation evidence below.

## Owned Item row foundation

The [real-store Core row slice](core-local-qualification.md#generation-bound-owned-item-rows) now preserves owned locations/estimates and a fixed query presentation context across moving windows. Two executable red/green pairs establish reopening and stale-generation rejection after another facade archives an Item. Seventeen package store functions and four native row functions pass; generic iOS test bundles compile. The affected MCP regression exposed and then qualified a separate [accepted-socket shutdown fix](mcp-http-qualification.md#accepted-socket-lifecycle-correction).

This is the existing Item-only schema. The full graph, link/schedule selection, native rich-row rendering, completion writes and MCP row wire path remain future slices. The prior seven-journey screenshots qualify their recorded UI source, not the changed Core dependency. Navigation prototype remains open.

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

The app can be launched with `./scripts/navigation-prototype.sh phone`, `tablet` or `mac`. The script requires installed Xcode 27 and the named simulator runtime, builds only the navigation scheme and scopes the developer directory to Xcode. The original shell syntax and equivalent direct operations passed. The later end-to-end phone launcher check and its UI availability limit are recorded below. It does not configure paid signing, App Groups or CloudKit.

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

Q36 is accepted: live List entries appear as named expandable groups, initially expanded, with direct Item entries kept separate. Group progress uses its child appearances in this itinerary; source List completion remains independent. Collapse changes visibility only. Q37 remembers expansion per device and itinerary/List-entry identity across relaunches. The user requires native/pre-made components and modern minimalist Liquid Glass, with a possible subtle outline or tint to distinguish groups. The screenshots above show the earlier flat presentation. The [native component revision below](#native-component-revision-and-live-list-groups) records the implemented groups and actual evidence; final layouts remain subject to human review.

## Expanded appearance identity correction

The next agreed journey opens Nezu Museum through Tokyo Food inside Tokyo Weekend. Its detail must show Local Todo / Global Todo even though the standalone List membership is locally Done. The inspector must expose entry 452 and membership 401 together, because membership 401 can occur under multiple itinerary List entries.

The [executed red](evidence/navigation/expanded-identity-red.json) reached that detail and failed at its incomplete displayed identity. The inspector showed only membership 401. The [focused green](evidence/navigation/expanded-identity-green.json) passes after displaying the complete appearance address. The [actual phone screenshot](evidence/navigation/layouts/phone-expanded-appearance.png) shows the unchanged source identity 101, independent Todo flags and full address. The redundant single association ID was removed from the temporary projection.

Raw bundles are `/private/tmp/PlannerNavigationExpandedIdentityRed.xcresult` and `/private/tmp/PlannerNavigationExpandedIdentityGreen.xcresult`. Each executed one test, with one failure before the correction and zero afterward. These focused runs took about 266 seconds overall, including substantial native test startup/teardown time; their action logs span about 12 seconds. They are correctness checks, not the accepted 300 ms physical-device query measurement.

The updated native Mac app and four-journey UI runner compile. A standalone local Mac app process was also launched from its derived products. Process launch does not establish rendered Mac layout, interaction or keyboard/accessibility behavior; the earlier automation startup failure still leaves those gates open. [Source hashes](evidence/navigation/layout-comparison-source.json) identify the corrected comparison code, tests and unchanged fixture.

## Local build reproduction while signing is deferred

Committed source `90dd8cf` was exported with `git archive` and built with fresh derived products. The narrow `PlannerNavigation` Mac build-for-testing passed and produced the arm64 app and UI runner. The archived source hashes match the comparison manifest. This is clean compilation evidence, not a successful Mac UI run.

The same committed app also compiles for `generic/platform=iOS` with `CODE_SIGNING_ALLOWED=NO` and fresh device products. The executable is arm64, its SDK is iphoneos27.0, and codesign confirms the app is unsigned. It is ready for later signing configuration, not installed or launched on a physical device. [Build evidence and limits](evidence/navigation/local-builds.json) record both outcomes. Raw logs remain `/private/tmp/PlannerNavigationCleanMacBuild.log` and `/private/tmp/PlannerNavigationUnsignedDeviceBuild.log`.

Reproduce the device compilation with the scoped developer directory, resolved-package options above, destination `generic/platform=iOS`, a separate derived-data directory and `CODE_SIGNING_ALLOWED=NO build`. No team/account choice, provisioning, App Group or CloudKit setup was performed.

## Current four-journey qualification

All four public navigation journeys pass on iPhone and iPad portrait, with zero failures or skips. The fourth opens the expanded itinerary List appearance and checks its complete identity and independent completion. [Phone results](evidence/navigation/current-phone.json) use the current source. [iPad results](evidence/navigation/current-tablet.json) reproduce committed `90dd8cf` from an archive with fresh products; the [iPad expanded-appearance screenshot](evidence/navigation/layouts/tablet-expanded-appearance.png) shows the full entry/membership address.

Raw bundles are `/private/tmp/PlannerNavigationFourJourneysPhone.xcresult` and `/private/tmp/PlannerNavigationFourJourneysCleanTablet.xcresult`. Both suites take about 565 seconds, and Xcode reports about 698 seconds overall. Action logs remain much shorter; substantial native startup/teardown delays are unresolved. Xcode still reports incomplete simulator diagnostic collection under the machine's default Command Line Tools selection. These runs establish the stated read-only journeys, not query latency or a reviewed landscape layout.

The clean iPad summary retains four runtime warnings about declaring all supported orientations. The built app lacked orientation keys; the native UI runner already had the expected phone/iPad arrays. The original `67dfb50` app configuration also lacks these keys. This is an identified app configuration gap, not an assumed SDK fault. The correction now declares phone portrait/landscape and every iPad orientation through Apple's [supported-orientation property](https://developer.apple.com/documentation/bundleresources/information-property-list/uisupportedinterfaceorientations). The actual generated plist contains the three phone and four iPad values. The affected [iPad selection journey passes again](evidence/navigation/orientation-tablet.json), with zero runtime warnings. The updated unsigned device build also passes and emits those arrays. This fixes the declaration; it does not establish landscape selection or resizing behavior. Existing warnings remain in the historical evidence.

## End-to-end launcher check

`./scripts/navigation-prototype.sh phone` builds, installs and launches the app in the simulator runtime and returns zero. Its initial attempt passed those steps but failed while opening Simulator by name. The expected bundled Simulator UI app is also absent in this selected Xcode bundle. The launcher now opens that app when present and otherwise explicitly reports successful runtime launch with unavailable GUI. It does not conceal a failed build, installation or runtime launch.

[Launcher evidence](evidence/navigation/launcher-phone.json) records the exact command, script hash and observed UI limit. Raw attempts remain `/private/tmp/PlannerNavigationLauncherPhone.log`, `/private/tmp/PlannerNavigationLauncherPhoneFixed.log` and `/private/tmp/PlannerNavigationLauncherPhoneRuntime.log`. The shell syntax passes. The tablet and Mac launcher variants were not rerun end to end; their equivalent native build/test or process-launch outcomes above remain the evidence for those paths.

## Native component revision and live List groups

The user's Mac review showed raised navigation buttons and a small detail form centered in a large empty column. The app already used native SwiftUI components, but their composition failed the intended Mac presentation. The revision uses native sidebar selection and NavigationLinks, selectable Item rows, bounded split-column widths, window toolbar filter menus and a grouped Form anchored at the top of its detail column. Notes and prototype identity inspection have separate system-grouped sections. The Mac scene supplies native SidebarCommands and a default size for new windows; existing window restoration can retain its earlier size.

The user asked for inspiration from Reminders, Notes and Calendar. Apple's [Reminders sidebar guidance](https://support.apple.com/en-sg/guide/reminders/remnd854fc47/mac) and [Notes three-column presentation](https://support.apple.com/guide/notes/view-your-notes-apd8b73d28be/mac) inform the composition. [Explore SwiftUI](https://exploreswiftui.com/) supplies visual component examples. The implementation uses the installed native SDK, with no added UI dependency or custom glass content cards. It preserves the accepted Planner domain behavior.

Native DisclosureGroup presents each live List entry, with all child appearances in its itinerary progress. AppStorage remembers its expansion locally by itinerary and entry IDs; new preferences default to expanded. Planner content remains read-only. A collapsed Tokyo Food still shows 0/2 and leaves direct Nezu Museum visible; Tokyo Weekend remains 0/3. Expansion restores entry 452/membership 401 with its own Todo state, independent of standalone membership 401 Done. These preferences sit outside the backup/domain records; full native backup integration is still a later gate.

The public UI journey [first failed](evidence/navigation/native-group-red.json) because the group was absent, then [passed](evidence/navigation/native-group-green.json) after rendering, disclosure-header identification and relaunch memory were implemented. An intermediate accessibility probe put the identifier on the whole mobile DisclosureGroup, hiding the child's distinct identifier; assigning it only to the header preserved both addresses. Native Mac disclosure triangles and combined header text require platform-appropriate public UI queries.

Mac automation now executes. Earlier shared touch-tap actions did not activate Mac controls; the test adapter now uses native mouse clicks and appropriate element roles. A subsequent [five-journey run](evidence/navigation/native-keyboard-red.json) passed three and failed two: keyboard selection lost focus, and the group-progress probe assumed separate static text. Keeping native List focus after selection and observing the combined accessible header produced [two focused passing journeys](evidence/navigation/native-focus-green.json). The keyboard journey selects archived appearance 402 with Down, then returns to 401 with Up, retaining their independent local states. Sheet Close has a distinct public identifier so the test cannot choose a window/menu Close action.

All five affected UI journeys now pass against the [same final source hashes](evidence/navigation/native-ui-source.json), with zero failures or skips:

| Destination | Counts | Results |
| --- | --- | --- |
| iPhone 18 Pro simulator, portrait | 5/5 | [Phone](evidence/navigation/native-phone.json) |
| iPad Air 11-inch M4 simulator, portrait | 5/5 | [iPad](evidence/navigation/native-tablet.json) |
| Native arm64 Mac | 5/5, including arrow-key selection | [Mac](evidence/navigation/native-mac.json) |

| Actual native presentation | Evidence |
| --- | --- |
| Mac library, selected appearance and top-aligned detail | [Mac library](evidence/navigation/layouts/mac-native-library.png) |
| Mac live List expanded and collapsed | [Expanded](evidence/navigation/layouts/mac-native-groups.png), [collapsed](evidence/navigation/layouts/mac-native-group-collapsed.png) |
| Mac itinerary-first and selected-appearance map comparisons | [Planning](evidence/navigation/layouts/mac-native-planning.png), [map](evidence/navigation/layouts/mac-native-map.png) |
| Live List after relaunch on phone and iPad | [Phone](evidence/navigation/layouts/phone-live-list-groups.png), [iPad](evidence/navigation/layouts/tablet-live-list-groups.png) |

Raw final bundles are `/private/tmp/PlannerNavigationNativePhoneComplete.xcresult`, `/private/tmp/PlannerNavigationNativeTabletComplete.xcresult` and `/private/tmp/PlannerNavigationNativeMacComplete.xcresult`. Use the existing focused scheme/command above without `-only-testing`, and the corresponding platform destination/derived-data directory. Mac uses native mouse actions and its window-scoped screenshots. Strict Swift format lint and affected app/UI-runner compilation pass. No unit tests were added for private fixture projection or styling; these behaviors use Q34's accepted public native UI seam. Full-graph Core/store tests remain separate obligations.

The [source manifest](evidence/navigation/native-ui-source.json) records the exact final commands. Use a fresh result-bundle path when repeating them. `./scripts/navigation-prototype.sh mac` also builds and opens the revision, returns zero, and its compiled standalone process is confirmed running. [Mac launcher evidence](evidence/navigation/native-mac-launcher.json) records that outcome and script hash. Raw launcher output is `/private/tmp/PlannerNavigationNativeMacLauncher.log`.

The earlier Mac automation startup failure remains historical evidence, superseded for these five executed journeys. These checks establish selection, disclosure memory, contextual identity and navigation, including the stated Mac arrow-key journey. They do not establish every keyboard shortcut, VoiceOver, Dynamic Type, resizing/rotation, the physical performance gate, durable Planner writes, Share or CloudKit. Native composition and any additional group border/tint still require the user's actual layout review.

## Native chrome, cumulative filters and inline maps

The next Mac screenshot review exposed a map occupying the entire detail column, a separate Inspect Item sheet, plain-text progress, truncated independent filter buttons, sidebar diagnostic text and an unexplained layout selector. This revision keeps the selected appearance's details in the third pane and embeds a compact native MapKit map in the Map alongside list comparison. It removes the inspection sheet/action. An Item without coordinates still has its full detail and a No location view. The other comparisons retain their ordinary detail form; no address lookup or new provider policy is implemented.

Nonempty containers and live List groups now use a native determinate linear ProgressView with their full completion count. Empty containers show No items without an indeterminate spinner. A single native filter menu has independent Completion and Archive selections, applied cumulatively. Its label is All when both are unrestricted, or the selected restrictions, such as Todo · Active, Active or Done. Filtering never changes full-container progress or appearance state.

iPhone uses native TabView and NavigationStack. Regular iPad uses native top tabs with NavigationSplitView content; portrait presents the catalog as a native sidebar overlay. Mac uses native sidebar selection and three split columns in every comparison. Prototype information and comparison choices live in the Mac menu bar's named Prototype menu or the mobile information sheet. The visible window no longer has sidebar diagnostic text or an unexplained right-hand layout menu. The information sheet explicitly states that Planner data is read-only and only local view preferences are saved. No custom navigation, glass cards or new UI package was added.

The accepted Q34 public native UI seam observes literal fixture outcomes. The inline-map journey [first failed](evidence/navigation/chrome-inline-map-red.json) because Local Done was unavailable until inspection, then [passed](evidence/navigation/chrome-inline-map-green.json) with membership 401's details and map visible together. The cumulative-filter journey [first failed](evidence/navigation/chrome-filters-red.json) at the absent native progress indicator, then [passed](evidence/navigation/chrome-filters-green.json): List A stays 1/2 while Todo/Active becomes Active, All and Done, and appearance visibility changes accordingly. The separate prototype-menu journey [failed](evidence/navigation/chrome-menu-red.json) when the native Mac menu was absent, then [passed](evidence/navigation/chrome-menu-green.json). The final suites include that menu/information path in their layout journeys.

Intermediate setup and accessibility probes did not all pass. The Mac focused-binding and conditional toolbar compilation errors were corrected before behavioral runs. Mac MenuButton exposes its visible title through AX title rather than label. iPad's native floating tabs expose both a cell and child Button with the same label, and its information toolbar must belong to the sidebar within the tab's split content. Switching tabs also required reopening the collapsed catalog in the portrait journey. Phone progress exposes a localized percentage with a nonbreaking space; the test now reads it using Foundation's native percent formatter. These changes observe actual native controls and retain the independently specified expected fraction 0.5; they do not derive expected results from private fixture projections.

All six affected public journeys pass against the [same final source hashes and exact commands](evidence/navigation/chrome-source.json), with no failures or skips. They cover cumulative filtering/progress, appearance-to-source identity and Mac Down/Up selection, independent direct itinerary completion, full expanded appearance identity, disclosure memory after relaunch, and inline map/details with a generic Item fallback.

| Destination | Passed | Failed/skipped | Results |
| --- | --- | --- | --- |
| Native arm64 Mac | 6/6 | 0/0 | [Mac summary](evidence/navigation/chrome-mac.json) |
| iPhone 18 Pro simulator, portrait | 6/6 | 0/0 | [Phone summary](evidence/navigation/chrome-phone.json) |
| iPad Air 11-inch M4 simulator, portrait | 6/6 | 0/0 | [iPad summary](evidence/navigation/chrome-tablet.json) |

| Actual native presentation | Evidence |
| --- | --- |
| Mac third-pane detail with embedded map | [Mac inline details](evidence/navigation/layouts/mac-inline-map-details.png) |
| Mac cumulative filter and full progress; live List group progress | [Filters](evidence/navigation/layouts/mac-cumulative-progress.png), [groups](evidence/navigation/layouts/mac-native-progress-groups.png) |
| iPad native top tabs, split details and cumulative filters | [Map/detail](evidence/navigation/layouts/tablet-native-tabs-map-details.png), [filters](evidence/navigation/layouts/tablet-native-tabs-filters.png) |
| Phone native detail and cumulative progress | [Map/detail](evidence/navigation/layouts/phone-inline-map-details.png), [filters](evidence/navigation/layouts/phone-cumulative-progress.png) |

Mac evidence captures the owned application window, not the desktop. The iPad map screenshot still has a loading/grid basemap and a native pin; it does not prove live basemap availability or offline rendering. Every map uses the fixture's synthetic owned coordinate, not geocoding of the museum's address.

Strict affected Swift formatting, app/UI-runner compilation through these test runs, shell syntax, affected Markdown lint and diff checks pass. No private fixture unit tests or Core mutation seam were added. Raw final result bundles are `/private/tmp/PlannerNavigationChromeMacQualified.xcresult`, `/private/tmp/PlannerNavigationChromePhoneQualified.xcresult` and `/private/tmp/PlannerNavigationChromeTabletQualified.xcresult`. Their logs use the same basenames with `.log`. Use the source manifest's focused commands with fresh result-bundle paths to reproduce.

The Mac launcher now requests a fresh instance with `open -n` so a running older process cannot conceal the rebuilt UI. `./scripts/navigation-prototype.sh mac` builds and opens the current source, returns zero, and a new standalone process was verified. It leaves existing instances alone. [Launcher evidence](evidence/navigation/chrome-mac-launcher.json) records the script hash and limits; raw output is `/private/tmp/PlannerNavigationChromeLaunch.log`.

Planner content remains a read-only fixture projection. At this qualification, Q38-Q42 still awaited answers for row ordering/drop/date/website/address behavior; the later accepted choices are linked at the top of this report. Rich metadata, completion writes, drag-and-drop and preview enrichment are not established by these checks. Full-graph persistence, physical/signing/sync/Share, broader keyboard/accessibility, orientation/resizing, long-list performance and final human review remain required. This revision records the requested presentation corrections without closing Navigation prototype.

## Useful Item details and roomier referenced Lists

The next screenshot review requested more room around referenced List groups, useful detail content and removal of the prominent Open source Item button. The starting detail form exposed Global, Local and Effective flags plus source/appearance UUIDs. The requested end keeps normal Item information in the third pane or phone navigation stack and preserves explicit prototype inspection for the accepted Q34 public UI seam.

The existing native DisclosureGroup now has more header spacing and vertical padding, with additional indentation for child rows. Its native icon, title and full-scope ProgressView distinguish the referenced List from an ordinary Item. Collapse memory, Manual order, appearance identity and completion rules are unchanged. This presentation does not add arbitrary List nesting.

Normal details show the Item title, Completed or To do, the containing List/Itinerary name, notes and owned location text. The existing Map comparison retains its compact map. Technical flags and UUIDs are available only through Item actions → Prototype diagnostics. The source transition is Item actions → View Item, retaining the source identity and explicitly opening its global view. No form button or inspection sheet interrupts normal Item selection.

The new public UI journey [first failed](evidence/navigation/content-details-red.json) at the missing In Tokyo Weekend context, then [passed](evidence/navigation/content-details-green.json). It opens expanded appearance 452/401 and requires To do, Original notes and Meeting point A while technical fields and Open source Item are absent. Explicit diagnostics must still expose Local Todo, Global Todo and the full appearance identity; closing diagnostics removes those fields again. The existing journeys now inspect literal technical values through that same visible diagnostics action. No private fixture unit tests or new production testing seam were added.

All seven affected public journeys pass against the [final source hashes and exact commands](evidence/navigation/content-source.json). They cover the new clean-details journey, cumulative filtering and progress, contextual-to-global Item navigation, Mac Down/Up selection with native list focus, independent direct/expanded itinerary state, remembered disclosure and inline map/details with a generic Item fallback.

| Destination | Passed | Failed/skipped | Runtime warnings | Results |
| --- | --- | --- | --- | --- |
| Native arm64 Mac, macOS 27.0.1 | 7/7 | 0/0 | 0 | [Mac summary](evidence/navigation/content-mac.json) |
| iPhone 18 Pro simulator, iOS 27, portrait | 7/7 | 0/0 | 0 | [Phone summary](evidence/navigation/content-phone.json) |
| iPad Air 11-inch M4 simulator, iOS 27, portrait | 7/7 | 0/0 | 0 | [iPad summary](evidence/navigation/content-tablet.json) |

| Actual native presentation | Evidence |
| --- | --- |
| Mac referenced List and useful third-pane detail | [Expanded group/details](evidence/navigation/layouts/mac-roomy-list-clean-details.png), [collapsed group](evidence/navigation/layouts/mac-roomy-list-collapsed.png) |
| Explicit global Item view and compact map detail | [Item view](evidence/navigation/layouts/mac-item-view.png), [map/detail](evidence/navigation/layouts/mac-clean-map-details.png) |
| iPad native tabs and split details | [iPad details](evidence/navigation/layouts/tablet-clean-details.png) |
| Phone native navigation and details | [Phone details](evidence/navigation/layouts/phone-clean-details.png) |

The Mac, iPad and phone captures were visually inspected. The Mac capture contains only the owned app window. The referenced List has a taller title/progress area and indented children, and the normal details contain no prototype identifiers or state jargon. Native Form and navigation retain their platform presentation. Final layout approval, landscape/resizing and broader accessibility remain open.

Strict affected Swift lint, app/UI-runner compilation through the passing test runs, affected Markdown lint and diff checks pass. Raw red/green bundles are `/private/tmp/PlannerNavigationContentDetailsRed.xcresult` and `/private/tmp/PlannerNavigationContentDetailsGreen.xcresult`. Raw final bundles are `/private/tmp/PlannerNavigationContentMacQualified.xcresult`, `/private/tmp/PlannerNavigationContentPhoneQualified.xcresult` and `/private/tmp/PlannerNavigationContentTabletQualified.xcresult`; their logs use the same basenames with `.log`. The source manifest records the narrow scheme/destinations and resolved-package commands.

`./scripts/navigation-prototype.sh mac` rebuilt this source and returned zero. A new standalone app process was confirmed after the launcher requested a fresh instance. [Launcher evidence](evidence/navigation/content-mac-launcher.json) records the script hash and qualification limits; raw output is `/private/tmp/PlannerNavigationContentLaunch.log`.

Planner content remains a read-only fixture projection. At this runtime qualification Q43-Q46 awaited human answers; the later accepted amendment linked above records them without changing the app. This presentation introduces no Core commands, provider requests, rich row metadata or drag writes. Maps still use synthetic fixture coordinates. Physical/signing, CloudKit, Share, full-graph persistence, long-list performance and final human review remain required. Navigation prototype stays open.

## Remaining gates

The first read-only UI slice cannot establish completion writes, query generation/window completeness, ordinary import, recovery, capture, schedules, CloudKit or Share feasibility. Those journeys must use their approved public seams and truthful outcomes as implementation proceeds. Further comparison must cover Calendar content, iPad tab/sidebar adaptation, persistence/reopen, orientation/resizing, keyboard/focus, Dynamic Type, VoiceOver and final human layout decisions. Physical-device long-list latency and memory, signed Share and account/sync tests remain deferred rather than waived.
