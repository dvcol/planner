# Native navigation prototype qualification

Work for [Navigation prototype](https://github.com/dvcol/planner/issues/14) on `prototype/navigation`. Q34 accepts the native UI journeys and fixtures. Q35 requires confirmation before deleting a Category/Tag with any association. The user delayed signing and physical setup while authorizing simulator and local Mac work.

The latest saved-data work is in [Shared subtitle editing and row preview](#shared-subtitle-editing-and-row-preview), [Shared Item title and notes editing](#shared-item-title-and-notes-editing), [Contextual and row-menu Add](#contextual-and-row-menu-add), [Add from global Item details](#add-from-global-item-details), [Native row-menu move](#native-row-menu-move), [Native membership move](#native-membership-move), [Native row-menu removal](#native-row-menu-removal) and [Native membership removal](#native-membership-removal). [Archive and cumulative saved filters](#archive-and-cumulative-saved-filters) records the preceding saved filters and hidden-member drag qualification. Other sections retain their recorded revisions.

The human accepted Q38 A, Q39 B, Q40 A, Q41 A and Q42 A, then accepted Q43 A, Q44 A, Q45 A and Q46 A. The [accepted row decisions](../navigation-prototype-review.md#accepted-review-answers) and [row contract review](../navigation-row-contract-review.md) record the exact declarations and required tests. The accepted amendment itself added no runtime qualification to the seven-journey presentation evidence below. Later sections qualify saved Item/List appearance completion and standalone List reordering. Native rich rows, cross-List drag-and-drop and provider lookup remain open.

## Owned Item row foundation

The [real-store Core row slice](core-local-qualification.md#generation-bound-owned-item-rows) now preserves owned locations/estimates and a fixed query presentation context across moving windows. Two executable red/green pairs establish reopening and stale-generation rejection after another facade archives an Item. Seventeen package store functions and four native row functions pass; generic iOS test bundles compile. The affected MCP regression exposed and then qualified a separate [accepted-socket shutdown fix](mcp-http-qualification.md#accepted-socket-lifecycle-correction).

This is the existing Item-only schema. The Item row wire path is now qualified through [real loopback HTTP](mcp-http-qualification.md#owned-item-row-windows-over-http), including fixed context, owned metadata, malformed-input paths and structured stale-generation failures. The full graph, link/schedule selection, native rich-row rendering and completion writes remain future slices. The prior seven-journey screenshots qualify their recorded UI source, not the changed Core dependency. Navigation prototype remains open.

## Global Item completion foundation

[Global Item completion and Reopen](core-local-qualification.md#global-item-completion-and-reopen) now save through Core with independent recovery. Completing an archived Item preserves its content/archive state, updates its effective row state and invalidates an old Todo window. No-op timestamp and identical/changed replay checks preserve the current state after Reopen. Nineteen store functions and two native completion functions pass; the affected 24-function MCP target passes and simulator Core test bundles compile.

The [global Item MCP route](mcp-http-qualification.md#global-item-completion-over-http) is now qualified with replay and strict scope rejection through actual HTTP. At this global-only revision, the native UI remained the recorded read-only fixture. That slice added no contextual flag, bulk action, provider I/O or simulated checkbox save. Those interactions still need full-graph persistence and their own native tests before Navigation prototype can complete.

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

## Saved native Lists and durable creation

The default app scene now opens the real local PlannerCore store and discovers saved Lists through the public catalog and row-window reads. A native three-column NavigationSplitView presents the sidebar, List contents and future Item detail. New List uses a grouped Form with an unsaved draft, Cancel and explicit Save. Save runs one Core command with a stable operation identity, refreshes the catalog and selects the saved List. An empty List shows No items without a completion percentage.

The process owns one shared facade/session; each window owns its selection and draft. Reads preserve the selected identity while showing loading, unavailable or Retry states. Save failures cannot produce a success acknowledgement. Applied actions with incomplete recovery remain distinguishable from rejected or unverified outcomes; the recovery controls and native failure presentation still need qualification.

The accepted public native journey first failed at the absent New List control. It now checks cancellation, explicit saving, the visible empty state and reopening the same local dataset after terminating the app. A stronger iPad assertion exposed an open sidebar covering the content. The native iOS column visibility now changes to two columns after selection; Mac retains its sidebar. The [execution manifest](evidence/navigation/saved-lists.json) records final source hashes, exact commands, actual behavior failures, intermediate build/startup corrections and the qualified regression revisions.

The final saved journey passes once on iPhone 18 Pro and once on iPad Air 11-inch M4, both using iOS 27 simulators, with no failures/skips. Their [phone](evidence/navigation/layouts/phone-saved-list-reopen.png) and [iPad](evidence/navigation/layouts/tablet-saved-list-reopen.png) captures were visually inspected. The earlier eight-function suites passed on both simulators before the later loading/visibility correction; those bundles include the seven unchanged comparison journeys. The final manifest distinguishes these revisions instead of counting repeated executions as new coverage.

The final native Mac app/UI-runner test build succeeds. Actual Mac UI startup timed out while enabling automation mode, so zero behavior functions executed there. The 55-function MCP regression passed with the saved default scene before the layout-only correction; Core and transport source hashes still match the catalog qualification. Strict lint of all six affected Swift files passes. Raw logs retain SDK/debugger/accessibility/cleanup diagnostics.

The earlier read-only comparison remains available through the Mac Prototype menu and `--navigation-prototype`; all existing fixture journeys launch it explicitly. The comparison launcher forwards that argument. Normal launch uses Application Support for local data. `--local-prototype-dataset <UUID>` selects an isolated app-owned temporary dataset for review; the same UUID reopens that dataset. A malformed identifier cannot open another dataset. Shell syntax passes; the changed comparison launcher was not rerun end to end.

At this List-only revision, native Item creation/details and tabs were still pending. These saved Lists are a localOnly prototype with CloudKit disabled. Contextual completion circles, valid selection during live refresh, the other source kinds, filters, progress for nonempty Lists, provider previews and drag actions remain open. This slice reads complete row windows, so it does not qualify moving-window memory or long-list performance. Physical signing/sync/Share, Mac UI execution, accessibility, orientation/resizing and final human review remain required.

## Saved native Items and global completion

Before this slice, saved native navigation could create Lists but had no Item library or saved Item detail. It now reads active Items through the public global query and compact row window. Both Todo and Done Items remain in this initial library. iPhone/iPad use native TabView for Lists and Items; Item navigation uses a native split view that collapses on phone. Mac retains three columns for primary navigation, Item library and selected details.

New Item is a grouped native Form with title, notes, Cancel and explicit Save. The draft owns a stable operation identity; one createItem command creates one source. Cancel never submits a command. Saved detail displays title/notes and a native Completed toggle. This toggle calls global Item completion from the Item view, without changing local membership flags. Technical identities, field hashes and Open source Item are absent. Container-local completion controls remain separate work.

Core outcomes remain authoritative. Rejection preserves the draft or current completion display. Unverified outcomes block further changes and require recovery review. Applied outcomes with incomplete independent recovery are presented as saved with recovery still needed, rather than as rolled back. Native failure/interruption/recovery presentation still needs its own runtime qualification. Loading/retry retains the selected source identity and discards cancelled or superseded detail reads.

The native journey first failed because Items navigation was absent. Its next run created the Item and displayed notes but failed after tapping the completion row's center. Exported native accessibility attachments show a wide parent Switch and its smaller visible switch; the final test targets that child control. The first corrected iPhone run passed creation, cancellation, global completion surviving relaunch and global reopening in detail. The later two-journey run caught an iPhone List regression: an empty sidebar returned a nonexisting Lists selection, opening a phantom detail and hiding New List. Empty iOS selection now stays nil.

Final qualification passes both saved journeys on iPhone 18 Pro and iPad Air 11-inch M4 simulators: two functions per device, zero failures/skips. It includes the previous List cancellation/save/relaunch behavior under native tabs. All four final Item screenshots were visually inspected: [phone completed](evidence/navigation/layouts/phone-saved-item-completed.png), [phone reopened](evidence/navigation/layouts/phone-saved-item-reopened.png), [iPad completed](evidence/navigation/layouts/tablet-saved-item-completed.png) and [iPad reopened](evidence/navigation/layouts/tablet-saved-item-reopened.png). The iPad library and detail remain visible together; the phone uses collapsed navigation and native floating tabs.

The [execution manifest](evidence/navigation/saved-items.json) preserves each actual failure/pass, final source hashes, exact commands and native attachments. The final Mac app/UI bundle compiles; no Mac behavior function executed for this slice, and the earlier test-daemon limitation remains open. Strict affected Swift and Markdown lint and diff checks pass. Raw logs retain SDK/debugger/accessibility diagnostics, including messages also present in the preceding saved List runs. Historical Core/MCP qualifications retain their recorded revisions; this UI slice changes neither Core nor transport and claims no new HTTP execution.

At this Item-only revision, membership UI was still pending. The foundation supports title/notes creation and global Item completion. Existing content edits, other Item fields, contextual completion/selection, filters, provider previews and drag remain open. It reads full row windows, so it does not qualify paging or large-library memory. Cross-window live refresh, native failures, accessibility and orientation/resizing also remain unqualified. Core schema 7 and portable format 1 are unchanged; CloudKit is disabled.

## Native existing-Item addition to Lists

Before this slice, native Lists could display saved memberships but could not add them. Add existing Item now opens a native selection List with explicit Cancel/Add. The draft retains the selected source identity, target List and one operation identity. Add submits one Core addMembership command at the end of saved Manual order, then refreshes that List's public row window. It creates a reference to the existing Item; it never submits createItem or copies shared fields. Adding the same source again retains the single membership. The picker currently offers active Items, including globally Done ones. An empty picker explains how to create an Item first and keeps Add disabled.

The initial test build failed because its count assertion used an element instead of an element query; zero behavior functions executed. After that correction, the native test failed at the absent Add existing Item control. The first green run proved addition, duplicate addition, membership retention after relaunch and one source in the Item library. Final qualification additionally selects then Cancels and relaunches before adding, proving no membership was saved by that cancelled draft.

All three saved native journeys pass on both iPhone 18 Pro and iPad Air M4 simulators: three functions per device, zero failures/skips. This retains the earlier Item/List creation and global completion journeys. The [phone](evidence/navigation/layouts/phone-saved-membership-reopened.png) and [iPad](evidence/navigation/layouts/tablet-saved-membership-reopened.png) membership captures were visually inspected. The [manifest](evidence/navigation/saved-memberships.json) records exact commands, actual counts and final source/screenshot hashes. Native Mac app/UI-bundle compilation, strict affected Swift/Markdown lint and diff checks pass; Mac UI runtime remains unqualified. Raw logs retain SDK/debugger/accessibility diagnostics and the red run's tooling diagnostic.

At this membership-only revision, the addition reuses the previously qualified Core membership command on schema 7/portable format 1. Core and transport are unchanged; no new HTTP admission/runtime proof is claimed. Native appearance selection/details, contextual completion controls, nonempty progress, live refresh, removal/move/reorder, bulk actions, other catalogs/filters and provider previews remain open. The displayed membership circle is still an indicator. Full-window reads, recovery failures/interruption, accessibility, orientation/resizing, physical signing/Share/CloudKit and final human review remain unqualified.

## Native List appearance details and completion

Before this slice, saved List rows were static indicators and the third pane stayed empty. Rows now select their exact List membership through native NavigationLink/List selection. Regular iPad and Mac use the detail column; compact iPhone navigation opens the same contextual Form. Details show the shared title, effective completion, containing List and notes. Technical flags, hashes and UUIDs are absent. Item actions → View Item explicitly changes to the source's global Item view; no dedicated source button or Inspect sheet is present. Choosing another List clears the former appearance selection.

The row's native circle button submits one Core appearance completion command. It changes only that membership's local state. Global Done disables the contextual circle with Completed globally, without clearing its retained local flag or offering global reopening in the List. Global reopening in Item detail reveals each List's retained local state. A nonempty List uses a native determinate ProgressView with Core's full-container counts; an empty List keeps No items without a percentage. Successful app-owned changes refresh retained List rows/progress, global Item detail and exact appearance detail. Cancelled or superseded reads cannot replace a newer selection or revision; refresh keeps previously loaded valid content visible.

The first native selection test failed at missing notes, then passed after exact appearance navigation. The next test failed at the absent contextual circle. Its two-List journey checks independent local completion, global Todo remaining unchanged, global Done disabling the local circle, global reopening restoring different retained local states, progress and local Done/Undone surviving relaunch. Mac diagnostics exposed an un-restored window, native Button rows and numeric checkbox values. The test adapter uses normal File → New Window when needed and observes the actual controls; default Mac window launch/restoration remains unqualified. An explicit scene-launch experiment did not resolve startup and was removed. The iPad run then caught an overlay covering rows when reselecting the same List. Every iOS sidebar List selection now reveals content, even when its identity is unchanged, and the journey checks actual row hittability.

Five saved journeys pass on each of Mac, iPhone 18 Pro and iPad Air M4 after the sidebar correction, with zero failures/skips. They cover Item/List creation, cancellation, adding references and both appearance journeys. Visual inspection then caught the contextual completion icon blending into an iPad selected row. The final one-line native plain button style has its own two affected appearance journeys per platform, recorded separately from that earlier five-journey pass. The [execution manifest](evidence/navigation/saved-appearances.json) retains actual failed/passed counts, exact commands, source revisions and screenshot provenance.

The final contextual and globally completed captures are linked for [Mac](evidence/navigation/layouts/mac-saved-appearance-completed.png), [Mac global Done](evidence/navigation/layouts/mac-saved-appearance-global-done.png), [phone](evidence/navigation/layouts/phone-saved-appearance-completed.png), [phone global Done](evidence/navigation/layouts/phone-saved-appearance-global-done.png), [iPad](evidence/navigation/layouts/tablet-saved-appearance-completed.png) and [iPad global Done](evidence/navigation/layouts/tablet-saved-appearance-global-done.png). Native test builds compile the affected app and UI tests on each platform. Strict affected Swift/Markdown lint and diff checks pass. SDK/debugger/accessibility diagnostics remain in raw logs.

This reuses qualified public Core commands and reads on schema 7/portable format 1, with CloudKit disabled. It adds no HTTP route, provider requests or new persistence model. The app-owned refresh revision is not an external Core/CloudKit observer. Cross-window runtime, external writes, contextual removal/deletion, filtering/paging, drag/bulk actions, recovery failures/interruption, broader accessibility, rotation/resizing, physical signing/Share/sync and final human layout review remain unqualified.

## Saved native List reordering

Before this slice, saved List appearances could be selected and completed locally but had no native saved-order controls. This slice submits the existing Core reorderMembership command for one exact membership. Move to Beginning/End is available in each row's native context menu. Mobile Lists use EditButton and List.onMove. macOS uses a native Table with row Transferable drag payloads and insertion destinations; its selection binding opens the contextual third-pane details. This uses Apple's [native Table row drag-and-drop](https://developer.apple.com/documentation/swiftui/adopting-drag-and-drop-using-swiftui). Drag payloads contain List/membership identities only. A different List's payload is not accepted by this reorder-only destination.

The app preserves the membership identity, local completion and shared Item content. It refreshes rows, progress and selected details after the durable command outcome. The selected Item remains attached to that same appearance. Busy controls and destinations refuse another change; errors use the existing save/recovery presentation. The current scope is one unfiltered standalone List in saved Manual order. Filtered Manual reordering, cross-List Move/Add, multi-selection, external writes and other sort modes still require separate work.

The native journey creates Hotel/Museum and their Tokyo List through normal UI, completes Hotel locally, moves it using the context menu, and checks exact appearance identity, notes and completion after relaunch. It then drags Hotel before, after and before Museum, checks literal row geometry each time, and relaunches again to check the final order and retained state. It reads no private persistence state. Existing Core reorder proof at 3fb72a5 covers rejected anchors/payloads, replay, recovery obstruction, rank rebalance and unchanged Item data; this UI slice changes no Core schema or command contract.

The initial red run failed at the missing Move to End action. Mobile qualification then caught a missing Edit control and an incorrect assumed reorder-handle label. The adapter now locates the actual native handle within the exact appearance's cell. Earlier Mac experiments incorrectly used XCTest's touch press-and-drag. A disposable plain SwiftUI probe failed with that gesture and passed with the native mouse click-and-drag API. That corrected gesture still failed in the Planner List/table experiments. A smaller native Table probe isolated a second cause: plain Text rows accepted mouse drags, while otherwise equivalent title Button rows did not. The final Mac table lets the native row select and drag; only the independent completion circle remains a Button. Probe source/tests are removed from the app.

Four affected Mac journeys passed after the Text-row correction, with zero failures/skips. The subsequent native inset style and formatting correction have a separately recorded final reorder journey on each of Mac, iPhone 18 Pro and iPad Air M4, all passing with zero failures/skips at the same frozen source hashes. Test builds compile the affected app/UI bundle on every platform. Strict affected Swift/Markdown lint, Info.plist validation and diff checks pass.

[Execution manifest](evidence/navigation/saved-reordering.json) records the failed and passed runs, separate source snapshots, exact commands and local result bundles. Earlier passes are not attributed to later source hashes. The phone capture shows retained contextual detail after drag; row order is established by native geometry assertions. The tablet and Mac captures show the List order and selected details together. Captures are exported from the named test attachments, checked by byte count/hash and inspected visually.

- [Mac saved List after drag](evidence/navigation/layouts/mac-saved-list-reordered.png)
- [Phone contextual detail after drag](evidence/navigation/layouts/phone-saved-list-reordered.png)
- [iPad saved List after drag](evidence/navigation/layouts/tablet-saved-list-reordered.png)

Mobile raw logs include context-menu animation/quiescence delays. These runs establish functional behavior, not interaction latency, long-list performance or every accessibility/keyboard path. macOS automatic window restoration, orientation/resizing, native failure/interruption, full-graph persistence, provider previews, physical signing/Share/CloudKit and final human review remain open. The Navigation prototype gate stays open.

## Clear counts and ordinary location maps

The user accepted Q47 A after noticing that full progress exceeded the visible rows, and requested archived-item visibility. The starting comparison showed 0 of 3 done for one direct Item plus a live List with two children, although Active hid one archived child. Its map was also restricted to the Map alongside list comparison.

Progress now names its item units, including singular item for one child. The Itinerary separately shows 1 direct item · 1 list. When cumulative filters hide children, the container shows Showing 2 of 3 items and the referenced List shows Showing 1 of 2 items. Full completion totals still include archived/filtered children and independent repeated appearances. Disclosure collapse changes presentation only. Active, Archived and All already existed in the native archive picker; the new journey explicitly exercises all three and verifies unchanged full progress. Saved flat Lists use the same clearer item units, while saved cumulative query-filter controls remain unfinished.

A shared native ItemLocationSection now displays owned name/address data and a MapKit marker whenever saved coordinates exist, in ordinary global and contextual details. Both saved detail adapters use this section. The map's identity follows its coordinates so selecting another place resets the initial region. The comparison retains its missing-location fallback. No coordinates are invented from an address, and no new provider lookup or metadata cache is implemented.

The accepted public native UI seam establishes two separate red/green pairs. The ordinary-map test failed at the absent map in normal Wishlist appearance details, then passed in both contextual and global Item detail without selecting the special layout. The count test failed at the absent accepted label, then passed through Active, Archived and All with literal child visibility, container composition, group counts and unchanged progress. Mac's initial runner timeout occurred before test execution and is separately recorded, rather than counted as a behavior red.

The [evidence manifest](evidence/navigation/native-counts-and-maps.json) records exact source hashes, commands, summaries, raw result paths and capture hashes. All final runs used the same nine affected source files without edits during execution.

| Destination | Executed journeys | Failures/skips | Result |
| --- | --- | --- | --- |
| iPhone 18 Pro simulator | 11 | 0/0 | Passed |
| iPad Air 11-inch M4 simulator | 11 | 0/0 | Passed |
| Native arm64 Mac | 0 | Runner initialization failed | App/test bundles compiled; automation mode timed out |

The eleven journeys on each simulator cover ordinary and comparison maps, useful details/diagnostics separation, cumulative filtering, appearance-to-source identity, independent itinerary appearances, disclosure/relaunch, and two real saved-data appearance completion/detail journeys. The saved journeys retain global OR local precedence and relaunch behavior; they do not create a saved location. Wiring saved location presentation is therefore distinct from a future native location edit/reopen proof.

Four final captures were visually inspected: [phone ordinary map](evidence/navigation/layouts/phone-ordinary-item-map.png), [phone with archived children](evidence/navigation/layouts/phone-itinerary-all-counts.png), [iPad ordinary map](evidence/navigation/layouts/tablet-ordinary-item-map.png), and [iPad filtered counts](evidence/navigation/layouts/tablet-itinerary-filtered-counts.png). Additional captures retain the opposite filter states. These maps use the fixture's synthetic owned coordinate, not the museum's geocoded address. Visible tiles do not establish general live-network availability or offline map behavior.

Strict formatting/lint on the nine affected Swift files, compiler checks through the selected native builds, affected Markdown lint and diff checks pass. Both Mac attempts failed before executing a behavior function; current Mac runtime and visual qualification remain open. This correction does not close Navigation prototype or waive its physical, accessibility, resizing, long-list, sync or Share requirements. The [whole-application polish ticket](https://github.com/dvcol/planner/issues/23) follows feature completion and records its own Context, DoR, DoD and `/tdd`/visual/device checks.

## Archive and cumulative saved filters

Before this slice, saved Lists always showed all their children and the Items catalog showed only active Items. Neither offered filter controls, and global Item details had no Archive/Unarchive action. Archived Items without a List could not be reached from the catalog.

Item actions in global Item detail now offers Archive Item or Unarchive Item. It executes the existing public Core archive command with the same durable-save and independent-recovery requirements as other native changes. Archiving preserves shared content, memberships, global completion and each membership's local completion. Contextual List details show Archived without adding a global action there.

Saved Lists and the Items catalog now have native menus with independent Completion and Archive selections. The displayed label is All or the cumulative restrictions, such as Todo · Archived. The menu provides Active, Archived and All archive states. Saved Lists retain their previous All/All default; the Items catalog retains All completion/Active archive. These choices belong to the current window and are not persisted or backed up in this slice. The active-Item membership picker uses its own read, so changing catalog filters cannot change its candidate set.

Each filter change requests a new public Core row window. A superseded query cannot replace newer filters, revision or selection. Previously loaded content remains visible with native loading feedback while it refreshes. Full List ProgressView counts still include archived and filtered-out children. Showing 0 of 1 item and No matching items distinguish a filtered empty result from a truly empty List. Regular iPad keeps valid contextual details after their row leaves the filter; unarchiving an Item in the Archived catalog keeps its valid global detail open while the catalog becomes empty.

Three separate native UI red/green cycles cover archive persistence, saved List filters and catalog recovery. The archive test first failed at the absent Item actions control. The List-filter test failed at its absent filter menu. The catalog test initially failed in a navigation helper that incorrectly waited for the missing new filter; after correcting that helper to use the existing New Item control, it reached the actual absent-filter assertion. That helper failure is recorded separately from the behavior red. Each corrected test passed its minimal implementation. The List and catalog journeys also passed on the iPad simulator.

Visual inspection then found that the system toolbar collapsed a Label to its icon even with titleAndIcon styling. The final menu uses a native Text label to keep the selected restrictions visible. The final source snapshot, selected regression results and inspected captures are recorded in the [evidence manifest](evidence/navigation/saved-archive-filters.json).

The six-journey regression passed on iPhone. On iPad, five passed and the catalog journey's broad Archived-text disappearance assertion failed because the now-visible filter label correctly remained Archived. Its hierarchy confirms that matching text belonged to the filter menu. The corrected test checks retained details and its existing Active-catalog read after relaunch proves saved Unarchive. That corrected catalog journey passes on both simulators.

A further public native UI qualification starts with Hotel/Museum/Cafe, completes Hotel locally, then filters Todo. Dragging Cafe before Museum retains full 1 of 3 progress and Showing 2 of 3 items. Returning to All and relaunching yields Hotel/Cafe/Museum, all three original memberships and Hotel's retained local Done state. This case passed the existing production implementation on its first executed run. Its initial test-only compile failure called a fileprivate helper from another file; moving that helper unchanged into the existing shared test adapter fixed compilation, with zero behavior functions executed in the failed build.

| Destination / run | Passed | Failures/skips | Scope |
| --- | --- | --- | --- |
| iPhone 18 Pro, regression | 6 | 0/0 | Five saved appearance/archive/filter journeys and unfiltered native reorder |
| iPad Air M4, regression | 5 | 1/0 | Same six journeys; the catalog text assertion was corrected below |
| iPhone 18 Pro, corrected qualification | 2 | 0/0 | Catalog Unarchive/relaunch and hidden-member filtered drag/relaunch |
| iPad Air M4, corrected qualification | 2 | 0/0 | Same two journeys |
| Native arm64 Mac | No runtime journeys | Not run | Updated app/UI-test bundles compile |

Seven distinct journeys are qualified per simulator across those recorded runs. Production source remained unchanged across regression and corrected qualification. Strict lint passes on all nine affected Swift files, compiler checks pass for the updated native bundles, and affected Markdown/diff checks pass. Six captures were visually inspected, including [phone filtered counts](evidence/navigation/layouts/phone-saved-filter-no-matches.png), [iPad retained filtered-out details](evidence/navigation/layouts/tablet-saved-filter-no-matches.png), [archived All rows](evidence/navigation/layouts/tablet-saved-archived-all.png), [phone filtered drag](evidence/navigation/layouts/phone-saved-filtered-drag.png), [iPad restored full order](evidence/navigation/layouts/tablet-saved-filtered-drag-reopened.png) and [iPad unarchived detail](evidence/navigation/layouts/tablet-saved-catalog-unarchived.png).

Advanced filters, remembered sort preferences, paging, other filtered reorder combinations, external refresh, native failure/recovery presentation and the remaining graph views are still open. Mac filtered-drag runtime remains unqualified. Core schema 7 and portable format 1 are unchanged; CloudKit remains disabled. Mac compilation does not qualify runtime, window restoration or visual behavior. Physical signing, Share, account transitions, sync, accessibility, resizing and long-list memory remain separate gates. Whole-app polish follows feature completion in [ticket 23](https://github.com/dvcol/planner/issues/23).

## Native membership removal

Before this slice, Core and authenticated HTTP could remove a membership, but the native app could only add, complete and reorder it. Native Item actions and row context menus now offer Remove from List. The action submits the exact List and membership identities through the existing Core command. It preserves the shared Item and other memberships; it offers no global completion, archive or source Delete fallback.

The native adapter keeps the same rejected, unverified and applied-with-incomplete-recovery distinctions as other saved changes. After Core reports the mutation applied, the adapter clears only a selection matching the removed appearance. A different current selection is retained. The removed detail becomes a native unavailable view, and an emptied List keeps No items without a completion percentage. The List notice explains that the Item remains available in Items; the detail pane prompts another selection. Choosing another List or appearance clears the notice. Native failure/recovery presentation and external deletion-driven refresh remain separate work.

The public native UI journey first failed at the missing Remove from List control. Its first green run passed with real saved data on iPhone. It completes separate memberships in Tokyo Food and Wishlist, removes the selected Tokyo Food membership, verifies cleared contextual details and empty progress, and relaunches. Wishlist retains its original membership identity/local Done, and the global Item retains its notes and Todo state. An ordinary re-add to Tokyo Food creates a different membership starting local Todo; Wishlist remains Done. This uses the previously qualified Core command and changes neither schema 7 nor portable format 1.

The same removal journey passes on iPad, alongside two affected completion/detail regressions. Those two regressions also pass on iPhone. Together with its first green removal run, three distinct journeys pass per simulator with zero failures/skips. Visual review found duplicate explanations in the iPad's empty columns. A text-only correction gives the detail pane a next-step prompt; the iPad removal/re-add journey passed again after that correction. Updated native Mac app/UI-test compilation passes, with no Mac runtime claim.

The [manifest](evidence/navigation/saved-membership-removal.json) preserves commands, actual summaries, source snapshots and four inspected captures: [phone removal](evidence/navigation/layouts/phone-saved-member-removed.png), [phone re-add](evidence/navigation/layouts/phone-saved-member-readded.png), [iPad removal](evidence/navigation/layouts/tablet-saved-member-removed.png) and [iPad re-add](evidence/navigation/layouts/tablet-saved-member-readded.png). Strict lint on the five affected Swift files, affected Markdown lint and diff checks pass. The journey exercises contextual Item actions; row menus are wired and compiled but their removal action still needs separate interaction qualification. Native Move, other Add paths, Undo, external refresh, failure/recovery, physical sync/Share and broader accessibility/window review remain open. This does not close the Navigation prototype or map.

## Remaining gates

The first read-only UI slice cannot establish completion writes, query generation/window completeness, ordinary import, recovery, capture, schedules, CloudKit or Share feasibility. Those journeys must use their approved public seams and truthful outcomes as implementation proceeds. Further comparison must cover Calendar content, iPad tab/sidebar adaptation, persistence/reopen, orientation/resizing, keyboard/focus, Dynamic Type, VoiceOver and final human layout decisions. Physical-device long-list latency and memory, signed Share and account/sync tests remain deferred rather than waived.

## Native row-menu removal

The next qualifier exercises Remove from List from an unselected row's native context menu. Long press on iPhone and iPad removes the membership, shows No items without an empty progress percentage, and leaves the source Item's notes and global Todo available in Items. This qualifies an alternative user entry point to the preceding selected-detail removal; it does not add a mutation or change Core.

One journey passes on each OS 27 simulator with zero failures/skips on the first executed run. This is interaction qualification, with no manufactured behavior red. Native arm64 Mac app/test bundles compile; its row-menu runtime is still unqualified. Strict affected Swift lint and source-hash checks pass. Xcode's context-menu animation waits remain in the raw logs.

Both app-owned captures were inspected. The [phone empty List](evidence/navigation/phone-saved-row-menu-removal.png) and [iPad empty List](evidence/navigation/tablet-saved-row-menu-removal.png) show the ordinary unselected state. The iPad detail remains Choose an Item. The [evidence record](evidence/navigation/saved-row-menu-removal.json) keeps exact commands, source hashes, result counts and capture hashes. Raw bundles and logs are `/private/tmp/PlannerRowRemoval{Phone,Tablet,Mac}` with their respective extensions.

Selected-context persistence remains covered by the preceding removal evidence. No native Move, external refresh, Undo, failure/recovery presentation, Mac runtime, signed/physical-device, CloudKit, Share, accessibility/keyboard or long-list performance result is established by this qualifier. The feature and final polish gates remain open.

## Native membership move

Before this slice, Core and authenticated HTTP could move a membership atomically, but contextual native Item actions could only view or remove it. The new Move to List action opens a native sheet with the Item, its source List and a destination selection. The source List is excluded. Move requires a valid selected destination and available mutation access; Cancel changes no data. The form retains one operation identity for its proposal and uses the existing domain command with end placement. It cannot change the shared Item or offer global completion from the List.

The public journey creates Nezu Museum with saved notes, marks its Tokyo Food appearance Done, then cancels a move to Wishlist. The source identity and completion remain. Confirming the next proposal empties Tokyo Food and clears only the removed appearance's selected detail. Wishlist receives a new membership, locally Todo; the global Item remains Todo with its notes. Relaunch keeps the empty source and the destination's new identity/state. The user selects the destination explicitly; the source detail never silently becomes a global or destination action.

The first executed red failed at the absent Move to List action. Initial green reached review/cancellation, then a test tried to inspect a hidden iPhone List row while detail remained visible. This was a test interaction error. Navigating back before checking the row corrected it, without mutation changes. The corrected move journey passes on both simulators. The affected selected-removal/re-add journey also passes on each, proving its retained other-List state and new local-Todo re-add after sharing selection clearing. These are two distinct journeys per simulator across recorded runs, with zero failures/skips in the passing runs.

Chooser copy was then clarified to include the global completion exception. Only its footer changed. The move journey passes again on both simulators at that source snapshot; all six final captures were inspected. Native arm64 Mac app/test bundles compile at both snapshots, with no runtime claim. Strict affected Swift lint and source/capture hash checks pass. No new Core, HTTP, schema or backup-format implementation is introduced.

| Native outcome | iPhone | iPad |
| --- | --- | --- |
| Destination review | [Chooser](evidence/navigation/phone-saved-move-chooser.png) | [Chooser](evidence/navigation/tablet-saved-move-chooser.png) |
| Selected source removed | [Empty source](evidence/navigation/phone-saved-move-source-empty.png) | [Empty source and cleared detail](evidence/navigation/tablet-saved-move-source-empty.png) |
| New Todo destination after relaunch | [Detail](evidence/navigation/phone-saved-move-destination-reopened.png) | [List and detail](evidence/navigation/tablet-saved-move-destination-reopened.png) |

The [evidence record](evidence/navigation/saved-membership-move.json) preserves commands, executed red, the test correction, passing runs, source snapshots and captures. Raw result bundles/logs remain under `/private/tmp/PlannerNativeMove{PhoneRed,PhoneGreen,PhoneCorrected,TabletCorrected,PhoneRemovalRegression,TabletRemovalRegression,MacCorrected,PhoneCopyReview,TabletCopyReview,MacCopyReview}` with their respective extensions.

Core's [membership mutation evidence](evidence/navigation/core-membership-mutations.json) separately proves existing-destination preservation, global Done precedence, replay and failure behavior at its recorded revision. Those are not all native UI outcomes here. The following row-menu slice qualifies Move and existing-destination interaction. Other Add paths remain open, alongside external refresh, Undo, native failure/recovery presentation, Mac runtime, signed/physical-device, CloudKit, Share, accessibility/keyboard, large-data and final human review. The final whole-app polish still follows feature completion.

## Native row-menu move

Before this slice, Move to List was available only after opening contextual detail. Native row menus now offer the same destination sheet for an unselected Item: long press on iPhone/iPad, right click in the Mac Table. They retain the exact source membership and use the already qualified move command. The shared Item is preserved.

The public journey creates Tokyo Food with Nezu Museum, and Wishlist with Nezu Museum first and Hotel second. Wishlist's Nezu appearance is locally Done while the global Item remains Todo. Moving from Tokyo Food to the existing Wishlist destination removes the source membership, preserves the destination identity/local completion/first position, and leaves exactly one Nezu appearance. Relaunch retains both the empty source and unchanged destination. Explicitly opening the global Item verifies its notes and Todo state.

The first executed red failed at the missing row-menu Move action. Adding the native menu entries made the journey pass on both simulators. The original fixture had Nezu last; it was strengthened to place Nezu first so an accidental move to the end would fail. Production stayed unchanged. The stronger journey passes once on each simulator, with zero failures/skips. The affected row-menu removal journey separately passes once on each simulator. Native Mac app/test bundles compile; no Mac runtime is claimed. Strict affected Swift lint and source/capture hashes pass.

| Native outcome | iPhone | iPad |
| --- | --- | --- |
| Existing destination review | [Chooser](evidence/navigation/phone-saved-row-menu-move-chooser.png) | [Chooser](evidence/navigation/tablet-saved-row-menu-move-chooser.png) |
| Preserved completion and first position after relaunch | [Wishlist](evidence/navigation/phone-saved-row-menu-move-destination-reopened.png) | [Wishlist](evidence/navigation/tablet-saved-row-menu-move-destination-reopened.png) |

All four final app-owned captures were inspected. The [evidence record](evidence/navigation/saved-row-menu-move.json) preserves exact commands, source snapshots, initial red/green, stronger fixture runs and removal regression. Raw bundles/logs remain under `/private/tmp/PlannerNativeRowMove{PhoneRed,PhoneGreen,TabletGreen,MacGreen,PhoneRemovalRegression,TabletRemovalRegression,PhonePositionReview,TabletPositionReview,MacPositionReview}`. Context-menu animation waits remain recorded.

Other Add paths, cross-List drag, external refresh, Undo, native failure/recovery presentation, Mac runtime, signed/physical-device, CloudKit, Share, accessibility/keyboard, large-data and final human review remain open. Whole-app polish follows feature completion.

## Add from global Item details

Before this slice, a saved Item could only be added by opening a List's existing-Item picker. Item actions now include Add to List. The native sheet names the Item and offers one destination List, with explicit Add/Cancel. Add requires a valid selection and mutation availability. Without Lists, ContentUnavailableView explains the next step and Add stays disabled. The proposal pins the Item identity and retains one operation identity; it uses the existing Core addMembership command at the end of Manual order. Success keeps the Item detail open and refreshes saved references. No content is copied.

The public journey creates a locally Done Tokyo Food appearance, completes its source Item globally, then selects Wishlist and Cancels. Wishlist remains empty and Tokyo Food retains its identity. Confirmed addition creates a different membership in Wishlist, displayed Done because the Item is globally Done, with its local circle disabled. Reopening the global Item reveals Wishlist's new local Todo while Tokyo Food stays locally Done. Adding to Wishlist again retains the same membership identity and one visible appearance. Relaunch retains both contexts, source notes and global Todo.

The first executed red fails at the absent Add to List action. The main journey then passes once on each simulator. Production remains fixed while a separate no-Lists interaction qualifier and the affected Archive/Unarchive catalog regression pass: two functions on each simulator, zero failures/skips. These are three distinct passing journeys per simulator across the recorded runs. The empty-state qualifier passes on its first run, so it has no claimed behavior red. Native Mac app/test bundles compile at both snapshots; Mac runtime remains unqualified. Strict affected Swift lint and source/capture hash checks pass.

| Native outcome | iPhone | iPad |
| --- | --- | --- |
| Add destination review | [Chooser](evidence/navigation/phone-saved-global-add-chooser.png) | [Chooser](evidence/navigation/tablet-saved-global-add-chooser.png) |
| Global Done display | [Wishlist](evidence/navigation/phone-saved-global-add-global-done.png) | [Wishlist](evidence/navigation/tablet-saved-global-add-global-done.png) |
| Local Todo after global reopening and relaunch | [Wishlist](evidence/navigation/phone-saved-global-add-reopened.png) | [Wishlist](evidence/navigation/tablet-saved-global-add-reopened.png) |
| No destination available | [Empty chooser](evidence/navigation/phone-saved-global-add-empty.png) | [Empty chooser](evidence/navigation/tablet-saved-global-add-empty.png) |

All eight app-owned captures were inspected. The [evidence record](evidence/navigation/saved-global-item-list-addition.json) preserves exact commands, executed red/green, first-run qualification, regression, source snapshots and capture hashes. Raw bundles/logs remain under `/private/tmp/PlannerNativeGlobalAdd{PhoneRed,PhoneGreen,TabletGreen,MacGreen,PhoneQualification,TabletQualification,MacQualification}`. Core, HTTP, schema 7 and portable format 1 are unchanged.

The following slice qualifies contextual/row-menu Add paths. Archived destination management, advanced filters/sorts/paging, external refresh, bulk review, rich rows and location editing remain open. Earlier remaining Mac runtime, failure/recovery, physical-device/CloudKit/Share, accessibility/keyboard, large-data and human-review limits still apply. Final whole-app polish follows feature completion.

## Contextual and row-menu Add

Before this slice, Add to List required opening the global Item detail or starting from a destination List. Contextual Item actions and native row menus now open the same destination picker directly. Contextual detail uses the appearance's shared Item reference; row actions use the row's source identity, never its membership identity. The existing command/picker keeps its validation, cancellation, operation identity and save/recovery behavior. Adding does not remove the current membership or switch selection to another context.

The public journey creates a locally Done Nezu Museum in Tokyo Food, then adds it to empty Wishlist from its contextual detail. Tokyo Food's selected detail, notes, source membership identity and local Done remain. Wishlist's new appearance starts Todo. The journey marks it locally Done, adds Hotel after it, then adds Nezu again from Tokyo Food's row menu. Wishlist retains its original identity, local Done, first position and one Nezu appearance. Relaunch retains both Lists' completion and identities. Explicit global Item detail remains Todo with its notes.

The first executed red fails at the missing contextual Add action. The minimal native wiring then passes one journey on each simulator, with zero failures/skips. Source hashes stayed fixed during green runs. Native Mac app/test bundles compile with no runtime claim. Strict affected Swift lint and source/capture checks pass. No picker, Core, HTTP, schema or backup-format code changes.

| Native outcome | iPhone | iPad |
| --- | --- | --- |
| Original detail retained after Add | [Detail](evidence/navigation/phone-saved-context-add-retained-detail.png) | [List and detail](evidence/navigation/tablet-saved-context-add-retained-detail.png) |
| Existing destination retained after relaunch | [Wishlist](evidence/navigation/phone-saved-context-add-destination-reopened.png) | [Wishlist](evidence/navigation/tablet-saved-context-add-destination-reopened.png) |

All four app-owned captures were inspected. The [evidence record](evidence/navigation/saved-contextual-list-addition.json) preserves exact commands, executed red/green, fixed source snapshots, result counts and capture hashes. Raw result bundles/logs remain under `/private/tmp/PlannerNativeContextAdd{PhoneRed,PhoneGreen,TabletGreen,MacGreen}`. Native row-menu animation waits remain recorded.

Shared Item content editing, rich rows, advanced filters/sorts/paging, bulk review, repeated Itinerary appearances, archived-container management, cross-List drag and external refresh remain open. Earlier failure/recovery, Undo, Mac runtime, signing/physical-device/CloudKit/Share, accessibility/keyboard, large-data and human-review limits still apply. Whole-app polish follows feature completion.

## Shared Item title and notes editing

Before this slice, saved Items could be created and completed but their title/notes could not be edited in the native app. Edit Item now opens a native grouped Form from global Item details. It reviews the shared title and notes, disables Save for unchanged or blank-title drafts, and keeps Cancel separate from saving. A draft pins the original public source read and its field hashes. Save sends only changed fields through the existing guarded Core command with one operation identity. The editor dismisses after an applied local save; a rejected save leaves its draft open with the native error alert. No contextual action silently becomes a global edit.

The main public journey cancels changed content, rejects a blank title, then saves both fields. Tokyo Food's locally Done appearance and Wishlist's local Todo keep their identities and completion while both display the new content. Relaunch retains that result. The second journey changes the title alone, then clears notes in a fresh editor. Global Done survives both saves and relaunch. Global Reopen then reveals the List's retained local Todo.

The executed red fails at the missing Edit Item action. Initial green runs on both simulators fail in the test helper before saving: app-owned accessibility values show that the helper assumed the insertion caret was at the end. Production remains fixed while the helper switches to native Select All. The main journey then passes on both simulators. The one-field/clear journey is a separate first-run qualification and passes on both simulators. Each final recorded run executes one function with zero failures/skips, giving two distinct passing functions per platform across separate runs. Final Mac app/test bundles compile; no Mac runtime function executes.

| Native outcome | iPhone | iPad |
| --- | --- | --- |
| Shared draft review | [Editor](evidence/navigation/phone-saved-item-edit-editor.png) | [Editor](evidence/navigation/tablet-saved-item-edit-editor.png) |
| Live locally Done reference | [Tokyo Food](evidence/navigation/phone-saved-item-edit-local-done.png) | [Tokyo Food](evidence/navigation/tablet-saved-item-edit-local-done.png) |
| Local Todo retained after relaunch | [Wishlist](evidence/navigation/phone-saved-item-edit-local-todo-reopened.png) | [Wishlist](evidence/navigation/tablet-saved-item-edit-local-todo-reopened.png) |
| Clear notes without changing title/global Done | [Item](evidence/navigation/phone-saved-item-edit-notes-cleared.png) | [Item](evidence/navigation/tablet-saved-item-edit-notes-cleared.png) |
| Global Done retained after relaunch | [List](evidence/navigation/phone-saved-item-edit-global-done-reopened.png) | [List](evidence/navigation/tablet-saved-item-edit-global-done-reopened.png) |

All ten original app-owned captures were inspected. The [evidence record](evidence/navigation/saved-item-editing.json) preserves commands, source epochs, initial test-helper failures, final results and capture hashes. Raw logs/results remain under `/private/tmp/PlannerNativeItemEdit{PhoneRed,PhoneGreen,TabletGreen,MacGreen,PhoneSelectionReview,TabletSelectionReview,MacSelectionReview,PhoneQualification,TabletQualification,MacQualification}`. Strict affected Swift lint, Markdown lint and source/capture checks pass.

This slice edits title/notes only and changes no Core, HTTP, schema or backup-format code. Native stale/concurrent-save and failure/recovery journeys remain unqualified. Rich rows, location/estimate/link/label editors, advanced filters/sorts/paging, bulk review, repeated Itinerary appearances, archived-container management, cross-List drag and external refresh remain open. Earlier Mac runtime, Undo, signing/physical-device/CloudKit/Share, accessibility/keyboard, large-data and human-review limits apply. Whole-app polish follows feature completion.

## Shared subtitle editing and row preview

Before this slice, the global catalog could display an owned subtitle, but List rows had only a title and the native editor could not change the subtitle. Edit Item now reviews an optional Subtitle field and sends Set/Clear only when it changes. The global catalog and contextual List rows share a compact native text stack. List navigation exposes title and subtitle to accessibility while retaining the separate contextual completion button, membership identity and selection. Row content comes from the existing lightweight RowRead without loading full source details for every row.

The public journey completes a List appearance locally, edits its shared subtitle in Item view, and observes that subtitle directly in the List row. It preserves notes, title, membership and local Done through relaunch. Clearing the subtitle removes its secondary line while retaining the same membership, notes, global Todo and complete-scope progress.

The executed native red fails at the missing subtitle field. Initial green attempts expose a deeper gap: Core supports subtitle creation/read but rejects edits. The draft remains open with a native alert. Both subtitle journeys fail at that rejected save; the affected iPhone title/notes regression passes. The [Core subtitle slice](core-local-qualification.md#guarded-item-subtitle-editing) then qualifies Set/Clear, persistence/recovery, stale-patch rejection and replay in 4032864. Native/test source remains fixed across that correction. The same subtitle function now passes on each simulator with zero failures/skips. Mac app/test bundles compile; no Mac runtime function executes.

| Native outcome | iPhone | iPad |
| --- | --- | --- |
| Shared subtitle draft | [Editor](evidence/navigation/phone-saved-subtitle-editor.png) | [Editor](evidence/navigation/tablet-saved-subtitle-editor.png) |
| Compact completed row | [List](evidence/navigation/phone-saved-subtitle-row.png) | [List and detail](evidence/navigation/tablet-saved-subtitle-row.png) |
| Cleared subtitle retains completion | [List](evidence/navigation/phone-saved-subtitle-cleared.png) | [List and detail](evidence/navigation/tablet-saved-subtitle-cleared.png) |

All six original app-owned captures were inspected. The [evidence record](evidence/navigation/saved-subtitle-preview.json) retains source epochs, commands, failures, corrections, final counts and capture hashes. The affected notes-over-HTTP command selected zero functions despite exiting successfully, so it does not qualify the regression. Its initial wrong-scheme attempt is also setup failure with zero executed functions. Raw results/logs remain under `/private/tmp/PlannerNativeSubtitle{PhoneRed,PhoneGreen,TabletGreen,MacGreen,PhoneCoreReview,TabletCoreReview,MacCoreReview,NotesHTTP,NotesHTTPReview}`. Strict affected Swift lint, Markdown lint and source/capture checks pass.

Only title/subtitle row content is qualified here. Saved location/date/estimate/link previews and their controls, advanced filters/sorts/paging, bulk review, repeated Itinerary appearances, archived-container management, cross-List drag and external refresh remain open. HTTP subtitle editing still needs its own admission/routing slice. Native stale-save/failure/recovery presentation and earlier Mac runtime, device/CloudKit/Share, Undo, accessibility/keyboard, large-data and human-review limits apply. Whole-app polish follows feature completion.

The subsequent [HTTP subtitle slice](mcp-http-qualification.md#guarded-item-subtitle-over-http) adds that route and passes four affected functions through the actual adapter in a temporary native package runner. It includes the notes regression previously selected as zero functions. The native Mac app/test bundle compiles; app-hosted XCTest startup remains unqualified.

## Native Item and List text search

Before this slice, the saved Items catalog and saved Lists had Completion/Archive menus but no text search control. Each now uses SwiftUI's native `searchable` interface, labelled "Search Items" or "Search this List". Queries pass text and the current Completion/Archive choices to the [qualified Core query](core-local-qualification.md#canonical-item-text-search). Search matches all words within one Item, including its currently saved shared content. The views retain their existing cancellation, filter, revision and selected-identity guards, adding the current text to the checks before displaying a load. Query text remains local presentation state. No Item, membership or progress state is edited by searching.

The implementation follows Apple's [search placement guidance](https://developer.apple.com/documentation/swiftui/adding-a-search-interface-to-your-app). Native [toolbar preservation](https://developer.apple.com/documentation/swiftui/view/searchpresentationtoolbarbehavior%28_%3A%29) keeps the cumulative filter menu accessible during search on iPhone. Items use the standard search-unavailable view for a nonempty query with no matches. Lists retain their native unavailable view beside complete-scope progress and "Showing x of y". All archive states makes archived children visible again; selecting Active can hide them without changing the denominator or local Done.

The first public journey creates Café Lunch and Hotel through the native app. Both have notes mentioning the garden. "cafe garden" matches Café Lunch across its title and notes with accent-insensitive comparison; "cafe hotel" matches neither because the words belong to different Items. Clearing search restores both rows, and opening Café Lunch confirms its original notes and global Todo.

The second public journey creates two live List memberships, completes Nezu Museum locally, and archives its shared Item. Its text matches one row while progress remains 1 of 2. Combining Active with that text hides every row while preserving "Showing 0 of 2 items" and full progress. A simultaneous valid selected detail must retain its List context and notes. All archive states restores the archived match; clearing only text restores both rows with the same membership and local completion.

Each executed red selects one actual native function and fails at its missing search field after setup succeeds. Each unchanged function then passes on the iPhone simulator. Final fixed-source qualification passes two affected functions on iPhone and three on iPad, including the existing cumulative archive-filter regression. Together with the separate iPhone List green, three distinct journeys qualify on each simulator with no failures or skips. The macOS app and UI-test bundles compile, with zero Mac runtime functions claimed. Strict affected Swift lint, Markdown lint and diff checks pass. The app-intents metadata extraction warning is also present in the earlier baseline build; no Swift type-check warning was introduced by this slice.

| Native outcome | iPhone | iPad |
| --- | --- | --- |
| Item text matches across fields | [Items](evidence/navigation/phone-saved-search-items-matching.png) | [Items and retained detail](evidence/navigation/tablet-saved-search-items-matching.png) |
| Clearing search retains content | [Detail](evidence/navigation/phone-saved-search-items-cleared.png) | [Catalog and detail](evidence/navigation/tablet-saved-search-items-cleared.png) |
| One List match with full progress | [List](evidence/navigation/phone-saved-search-list-matching.png) | [List and detail](evidence/navigation/tablet-saved-search-list-matching.png) |
| Active hides the archived match | [No matches](evidence/navigation/phone-saved-search-list-hidden.png) | [No matches and retained detail](evidence/navigation/tablet-saved-search-list-hidden.png) |
| All and cleared text restore rows | [Two rows](evidence/navigation/phone-saved-search-list-cleared.png) | [Two rows and detail](evidence/navigation/tablet-saved-search-list-cleared.png) |

All ten original app-owned captures were inspected. The iPad Item-search capture visibly retains Hotel detail after its row leaves the query; the automated retention assertion covers the List appearance. The [evidence record](evidence/navigation/saved-text-search.json) keeps exact commands, completed red/green outcomes, final source epochs and log/capture hashes. Raw logs and result bundles remain under `/private/tmp/PlannerNativeTextSearch{GlobalRed,GlobalGreen,ListRed,ListGreen,PhoneQualification,TabletQualification,MacBuild}`. XCTest startup and teardown are slow; their elapsed times do not measure app responsiveness.

Inbox presentation, shared-label search, structured filters, sorts, paging, external-writer refresh, filtered reorder, estimate controls and the 5,000-Item/200-List/300 ms device gate remain open. This does not qualify persistence of display preferences, Mac runtime/window restoration, keyboard/accessibility, rotation/resizing, physical iCloud/Share or final human review. Whole-app polish follows feature completion.
