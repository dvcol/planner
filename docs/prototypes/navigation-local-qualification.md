# Native navigation prototype qualification

Work for [Navigation prototype](https://github.com/dvcol/planner/issues/14) on
`prototype/navigation`. Q34 accepts the native UI journeys and fixtures. Q35
requires confirmation before deleting a Category/Tag with any association. The
user delayed signing and physical setup while authorizing simulator and local
Mac work.

The latest saved-data work is in
[Shared subtitle editing and row preview](#shared-subtitle-editing-and-row-preview),
[Shared Item title and notes editing](#shared-item-title-and-notes-editing),
[Contextual and row-menu Add](#contextual-and-row-menu-add),
[Add from global Item details](#add-from-global-item-details),
[Native row-menu move](#native-row-menu-move),
[Native membership move](#native-membership-move),
[Native row-menu removal](#native-row-menu-removal) and
[Native membership removal](#native-membership-removal).
[Archive and cumulative saved filters](#archive-and-cumulative-saved-filters)
records the preceding saved filters and hidden-member drag qualification. Other
sections retain their recorded revisions.

The human accepted Q38 A, Q39 B, Q40 A, Q41 A and Q42 A, then accepted Q43 A,
Q44 A, Q45 A and Q46 A. The
[accepted row decisions](../navigation-prototype-review.md#accepted-review-answers)
and [row contract review](../navigation-row-contract-review.md) record the exact
declarations and required tests. The accepted amendment itself added no runtime
qualification to the seven-journey presentation evidence below. Later sections
qualify saved Item/List appearance completion and standalone List reordering.
Native rich rows, cross-List drag-and-drop and provider lookup remain open.

## Owned Item row foundation

The
[real-store Core row slice](core-local-qualification.md#generation-bound-owned-item-rows)
now preserves owned locations/estimates and a fixed query presentation context
across moving windows. Two executable red/green pairs establish reopening and
stale-generation rejection after another facade archives an Item. Seventeen
package store functions and four native row functions pass; generic iOS test
bundles compile. The affected MCP regression exposed and then qualified a
separate
[accepted-socket shutdown fix](mcp-http-qualification.md#accepted-socket-lifecycle-correction).

This is the existing Item-only schema. The Item row wire path is now qualified
through
[real loopback HTTP](mcp-http-qualification.md#owned-item-row-windows-over-http),
including fixed context, owned metadata, malformed-input paths and structured
stale-generation failures. The full graph, link/schedule selection, native
rich-row rendering and completion writes remain future slices. The prior
seven-journey screenshots qualify their recorded UI source, not the changed Core
dependency. Navigation prototype remains open.

## Global Item completion foundation

[Global Item completion and Reopen](core-local-qualification.md#global-item-completion-and-reopen)
now save through Core with independent recovery. Completing an archived Item
preserves its content/archive state, updates its effective row state and
invalidates an old Todo window. No-op timestamp and identical/changed replay
checks preserve the current state after Reopen. Nineteen store functions and two
native completion functions pass; the affected 24-function MCP target passes and
simulator Core test bundles compile.

The
[global Item MCP route](mcp-http-qualification.md#global-item-completion-over-http)
is now qualified with replay and strict scope rejection through actual HTTP. At
this global-only revision, the native UI remained the recorded read-only
fixture. That slice added no contextual flag, bulk action, provider I/O or
simulated checkbox save. Those interactions still need full-graph persistence
and their own native tests before Navigation prototype can complete.

## Starting state and first goal

The inherited app was a placeholder. The first slice opens Lists → Tokyo Food,
shows its unfiltered 1 of 2 progress under the ordinary Todo/Active filter,
switches both filters to All and opens Nezu Museum's membership 401. Its detail
must retain that appearance and show Local Done / Global Todo. Opening its
source explicitly shows Item 101 in global context. Tokyo Weekend retains 0 of 3
progress.

The app links the existing PlannerCore package. This first layout experiment
reads the committed full-graph backup through a temporary, read-only fixture
projection. It resolves source references by identity and reads independent
appearance flags from that file. It does not import into the existing Item-only
Core store, mutate saved records, validate a general backup, or acknowledge a
durable save. Unrendered backup fields remain in the original resource.
Core/store tests and integration with full-graph persistence remain separate
required evidence. This prototype must not be promoted to production.

## Native configuration

`PlannerNavigation` builds the multiplatform app and a native XCUITest target,
without adding the Mac-only MCP test target to simulator testing. The existing
pinned packages remain authoritative. Debug builds use the active architecture
so the app and its local Swift package agree on the selected simulator
architecture. The fixture JSON is an explicit app resource referenced from its
existing location.

Phone navigation uses native tabs and stacks. Regular-width iPad and native Mac
initially use a three-column NavigationSplitView with a catalog, container
contents and selected Item. Filter controls are native menus. The prototype
identity inspector exposes source and appearance separately, with readable,
selectable values. On iPad portrait the system presents the sidebar as an
overlay. The journey opens it with the native Show Sidebar button; selecting a
container closes the overlay so it cannot intercept filter taps. Layout
comparison and human review remain open.

## Executed evidence

Setup, failing behavior, passing journeys and screenshots are recorded here as
they finish. Build failure and simulator installation failure are setup
outcomes, never behavior-test red evidence.

The initial simulator build exposed an architecture mismatch: the app attempted
x86_64 while its Swift package built arm64. The Debug active-architecture
setting corrected this. The next build-for-testing passed. Initial UI startup
then failed in the simulator install service with a missing placeholder promise.
A direct simulator boot, completion of boot status and app installation
succeeded; the subsequent UI test executed against the placeholder and failed
because Lists navigation was absent.

The first implementation attempt exposed native TabView accessibility behavior:
the identifier applied to a tab's root did not identify its button. The test now
uses the visible Lists label on every platform. A later attempt reached the
local detail and exposed combined LabeledContent accessibility. The identity
inspector now presents separate label/value elements. These findings are
retained in the local logs and result bundles.

### First slice results

| Destination / run                               | Outcome                                                                                                                               | Evidence                                                                                            |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Placeholder on phone, behavior red              | One executed journey failed at missing Lists navigation.                                                                              | Red summary                                                                                         |
| iPhone 18 Pro simulator, complete first journey | One journey passed, zero failures/skips.                                                                                              | Phone summary, appearance, source, itinerary                                                        |
| iPad Air 11-inch M4 simulator, portrait         | One journey passed, zero failures/skips after sidebar correction.                                                                     | Tablet summary, appearance, source, itinerary                                                       |
| Native arm64 Mac                                | App and UI runner build passed. UI runner initialization failed before the journey could execute: timed out enabling automation mode. | Startup failure summary. Xcode reports one failed planned test; this is no executed behavior proof. |

The phone screenshot run preceded the iPad-specific overlay correction and
addition of the test's normal sidebar-opening helper. The fixture and phone path
are unchanged. Subsequent layout work will run the affected journeys again. Raw
result bundles remain in
`/private/tmp/PlannerNavigationSelectionPhoneFinal.xcresult`,
`/private/tmp/PlannerNavigationSelectionTabletAllColumns.xcresult` and
`/private/tmp/PlannerNavigationSelectionMacAttempt.xcresult`. Committed
summaries remove device identities while retaining reported counts, OS and
hardware model.

The app can be launched with `./scripts/navigation-prototype.sh phone`, `tablet`
or `mac`. The script requires installed Xcode 27 and the named simulator
runtime, builds only the navigation scheme and scopes the developer directory to
Xcode. The original shell syntax and equivalent direct operations passed. The
later end-to-end phone launcher check and its UI availability limit are recorded
below. It does not configure paid signing, App Groups or CloudKit.

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

Substitute `platform=iOS Simulator,name=iPhone 18 Pro` for phone. Use
`platform=macOS,arch=arm64` and a separate derived-data directory for Mac
compilation. Mac UI execution remains unqualified. Xcode's unsuccessful
simulator diagnostic collection reported that its subprocess could not locate
simctl under the global Command Line Tools selection; the executed test logs and
result summaries still exist. No global toolchain setting was changed.

## Three layout comparisons

The layout selector now offers Library first, Itinerary first and Map alongside
list. On phone it is a native navigation toolbar menu; Itinerary first initially
selects the Itineraries tab. On iPad regular width it is a clearly marked menu
row in the native sidebar. Mac uses the native toolbar. The earlier global inset
chooser interfered with phone tab or iPad sidebar taps; regression checks
exposed this and the chooser was moved into platform controls.

Library first presents the catalog, contextual contents and detail columns.
Itinerary first uses a two-column itinerary catalog/ordered-child view on larger
screens. Map alongside list replaces selected appearance detail with native
MapKit and opens its unchanged appearance in a native inspection sheet. An Item
without owned coordinates has a No location view and remains available. The map
renders the fixture's owned coordinate, not a geocoded position for the museum's
name. It currently shows the selected appearance; a full filtered map of all
places remains unqualified. This is a presentation comparison over the same
read-only fixture, with no completion, archive or saved-content writes.

| Public journey                  | Phone | iPad portrait | Observable outcome                                                                                                                          |
| ------------------------------- | ----- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Library filter/selection/source | Pass  | Pass          | 1 of 2; membership 401 Local Done / Global Todo; explicit source 101; itinerary 0 of 3.                                                     |
| Itinerary-first selection       | Pass  | Pass          | Direct entry 451 Local Todo / Global Todo, independently of membership 401; itinerary 0 of 3.                                               |
| Map pin and generic Item        | Pass  | Pass          | Pin opens membership 401 with retained local/global flags; archived generic membership 402 remains visible under All and shows No location. |

The complete affected UI target executes three journeys on each simulator, with
zero failures/skips: phone summary, tablet summary. The new slices each started
with an executed failing test: itinerary-first red, map red. The chooser
accessibility probes were adapted to native controls and collapsed iPad
sidebars; the agreed observable identities, completion flags and progress did
not change.

| Comparison         | Actual phone | Actual iPad |
| ------------------ | ------------ | ----------- |
| Library detail     | Phone        | iPad        |
| Itinerary first    | Phone        | iPad        |
| Map alongside list | Phone        | iPad        |
| Generic Item       | Phone        | iPad        |

Raw current UI bundles are
`/private/tmp/PlannerNavigationThreeJourneysPhone.xcresult` and
`/private/tmp/PlannerNavigationThreeJourneysTablet.xcresult`. Use the same
focused scheme/destinations above without the single `-only-testing` argument to
run its three UI journeys. The current native Mac app and UI runner also compile
with local ad hoc signing; Mac UI automation remains unqualified because runner
initialization timed out. The updated app host's two existing public MCP
read/command suites pass four test methods, with reported counts and outcome.
That verifies the affected host still supports those local routes, not every MCP
feature or client.

MapKit uses Apple's
[native Map and Annotation API](https://developer.apple.com/documentation/mapkit/map).
Fixture location values use the existing shared PlannerCore owned-location type.
No additional package, provider enrichment, location permission or Calendar
export is introduced.

Q36 is accepted: live List entries appear as named expandable groups, initially
expanded, with direct Item entries kept separate. Group progress uses its child
appearances in this itinerary; source List completion remains independent.
Collapse changes visibility only. Q37 remembers expansion per device and
itinerary/List-entry identity across relaunches. The user requires
native/pre-made components and modern minimalist Liquid Glass, with a possible
subtle outline or tint to distinguish groups. The screenshots above show the
earlier flat presentation. The
[native component revision below](#native-component-revision-and-live-list-groups)
records the implemented groups and actual evidence; final layouts remain subject
to human review.

## Expanded appearance identity correction

The next agreed journey opens Nezu Museum through Tokyo Food inside Tokyo
Weekend. Its detail must show Local Todo / Global Todo even though the
standalone List membership is locally Done. The inspector must expose entry 452
and membership 401 together, because membership 401 can occur under multiple
itinerary List entries.

The executed red reached that detail and failed at its incomplete displayed
identity. The inspector showed only membership 401. The focused green passes
after displaying the complete appearance address. The actual phone screenshot
shows the unchanged source identity 101, independent Todo flags and full
address. The redundant single association ID was removed from the temporary
projection.

Raw bundles are `/private/tmp/PlannerNavigationExpandedIdentityRed.xcresult` and
`/private/tmp/PlannerNavigationExpandedIdentityGreen.xcresult`. Each executed
one test, with one failure before the correction and zero afterward. These
focused runs took about 266 seconds overall, including substantial native test
startup/teardown time; their action logs span about 12 seconds. They are
correctness checks, not the accepted 300 ms physical-device query measurement.

The updated native Mac app and four-journey UI runner compile. A standalone
local Mac app process was also launched from its derived products. Process
launch does not establish rendered Mac layout, interaction or
keyboard/accessibility behavior; the earlier automation startup failure still
leaves those gates open. Source hashes identify the corrected comparison code,
tests and unchanged fixture.

## Local build reproduction while signing is deferred

Committed source `90dd8cf` was exported with `git archive` and built with fresh
derived products. The narrow `PlannerNavigation` Mac build-for-testing passed
and produced the arm64 app and UI runner. The archived source hashes match the
comparison manifest. This is clean compilation evidence, not a successful Mac UI
run.

The same committed app also compiles for `generic/platform=iOS` with
`CODE_SIGNING_ALLOWED=NO` and fresh device products. The executable is arm64,
its SDK is iphoneos27.0, and codesign confirms the app is unsigned. It is ready
for later signing configuration, not installed or launched on a physical device.
Build evidence and limits record both outcomes. Raw logs remain
`/private/tmp/PlannerNavigationCleanMacBuild.log` and
`/private/tmp/PlannerNavigationUnsignedDeviceBuild.log`.

Reproduce the device compilation with the scoped developer directory,
resolved-package options above, destination `generic/platform=iOS`, a separate
derived-data directory and `CODE_SIGNING_ALLOWED=NO build`. No team/account
choice, provisioning, App Group or CloudKit setup was performed.

## Current four-journey qualification

All four public navigation journeys pass on iPhone and iPad portrait, with zero
failures or skips. The fourth opens the expanded itinerary List appearance and
checks its complete identity and independent completion. Phone results use the
current source. iPad results reproduce committed `90dd8cf` from an archive with
fresh products; the iPad expanded-appearance screenshot shows the full
entry/membership address.

Raw bundles are `/private/tmp/PlannerNavigationFourJourneysPhone.xcresult` and
`/private/tmp/PlannerNavigationFourJourneysCleanTablet.xcresult`. Both suites
take about 565 seconds, and Xcode reports about 698 seconds overall. Action logs
remain much shorter; substantial native startup/teardown delays are unresolved.
Xcode still reports incomplete simulator diagnostic collection under the
machine's default Command Line Tools selection. These runs establish the stated
read-only journeys, not query latency or a reviewed landscape layout.

The clean iPad summary retains four runtime warnings about declaring all
supported orientations. The built app lacked orientation keys; the native UI
runner already had the expected phone/iPad arrays. The original `67dfb50` app
configuration also lacks these keys. This is an identified app configuration
gap, not an assumed SDK fault. The correction now declares phone
portrait/landscape and every iPad orientation through Apple's
[supported-orientation property](https://developer.apple.com/documentation/bundleresources/information-property-list/uisupportedinterfaceorientations).
The actual generated plist contains the three phone and four iPad values. The
affected iPad selection journey passes again, with zero runtime warnings. The
updated unsigned device build also passes and emits those arrays. This fixes the
declaration; it does not establish landscape selection or resizing behavior.
Existing warnings remain in the historical evidence.

## End-to-end launcher check

`./scripts/navigation-prototype.sh phone` builds, installs and launches the app
in the simulator runtime and returns zero. Its initial attempt passed those
steps but failed while opening Simulator by name. The expected bundled Simulator
UI app is also absent in this selected Xcode bundle. The launcher now opens that
app when present and otherwise explicitly reports successful runtime launch with
unavailable GUI. It does not conceal a failed build, installation or runtime
launch.

Launcher evidence records the exact command, script hash and observed UI limit.
Raw attempts remain `/private/tmp/PlannerNavigationLauncherPhone.log`,
`/private/tmp/PlannerNavigationLauncherPhoneFixed.log` and
`/private/tmp/PlannerNavigationLauncherPhoneRuntime.log`. The shell syntax
passes. The tablet and Mac launcher variants were not rerun end to end; their
equivalent native build/test or process-launch outcomes above remain the
evidence for those paths.

## Native component revision and live List groups

The user's Mac review showed raised navigation buttons and a small detail form
centered in a large empty column. The app already used native SwiftUI
components, but their composition failed the intended Mac presentation. The
revision uses native sidebar selection and NavigationLinks, selectable Item
rows, bounded split-column widths, window toolbar filter menus and a grouped
Form anchored at the top of its detail column. Notes and prototype identity
inspection have separate system-grouped sections. The Mac scene supplies native
SidebarCommands and a default size for new windows; existing window restoration
can retain its earlier size.

The user asked for inspiration from Reminders, Notes and Calendar. Apple's
[Reminders sidebar guidance](https://support.apple.com/en-sg/guide/reminders/remnd854fc47/mac)
and
[Notes three-column presentation](https://support.apple.com/guide/notes/view-your-notes-apd8b73d28be/mac)
inform the composition. [Explore SwiftUI](https://exploreswiftui.com/) supplies
visual component examples. The implementation uses the installed native SDK,
with no added UI dependency or custom glass content cards. It preserves the
accepted Planner domain behavior.

Native DisclosureGroup presents each live List entry, with all child appearances
in its itinerary progress. AppStorage remembers its expansion locally by
itinerary and entry IDs; new preferences default to expanded. Planner content
remains read-only. A collapsed Tokyo Food still shows 0/2 and leaves direct Nezu
Museum visible; Tokyo Weekend remains 0/3. Expansion restores entry
452/membership 401 with its own Todo state, independent of standalone membership
401 Done. These preferences sit outside the backup/domain records; full native
backup integration is still a later gate.

The public UI journey first failed because the group was absent, then passed
after rendering, disclosure-header identification and relaunch memory were
implemented. An intermediate accessibility probe put the identifier on the whole
mobile DisclosureGroup, hiding the child's distinct identifier; assigning it
only to the header preserved both addresses. Native Mac disclosure triangles and
combined header text require platform-appropriate public UI queries.

Mac automation now executes. Earlier shared touch-tap actions did not activate
Mac controls; the test adapter now uses native mouse clicks and appropriate
element roles. A subsequent five-journey run passed three and failed two:
keyboard selection lost focus, and the group-progress probe assumed separate
static text. Keeping native List focus after selection and observing the
combined accessible header produced two focused passing journeys. The keyboard
journey selects archived appearance 402 with Down, then returns to 401 with Up,
retaining their independent local states. Sheet Close has a distinct public
identifier so the test cannot choose a window/menu Close action.

All five affected UI journeys now pass against the same final source hashes,
with zero failures or skips:

| Destination                             | Counts                             | Results |
| --------------------------------------- | ---------------------------------- | ------- |
| iPhone 18 Pro simulator, portrait       | 5/5                                | Phone   |
| iPad Air 11-inch M4 simulator, portrait | 5/5                                | iPad    |
| Native arm64 Mac                        | 5/5, including arrow-key selection | Mac     |

| Actual native presentation                                  | Evidence            |
| ----------------------------------------------------------- | ------------------- |
| Mac library, selected appearance and top-aligned detail     | Mac library         |
| Mac live List expanded and collapsed                        | Expanded, collapsed |
| Mac itinerary-first and selected-appearance map comparisons | Planning, map       |
| Live List after relaunch on phone and iPad                  | Phone, iPad         |

Raw final bundles are
`/private/tmp/PlannerNavigationNativePhoneComplete.xcresult`,
`/private/tmp/PlannerNavigationNativeTabletComplete.xcresult` and
`/private/tmp/PlannerNavigationNativeMacComplete.xcresult`. Use the existing
focused scheme/command above without `-only-testing`, and the corresponding
platform destination/derived-data directory. Mac uses native mouse actions and
its window-scoped screenshots. Strict Swift format lint and affected
app/UI-runner compilation pass. No unit tests were added for private fixture
projection or styling; these behaviors use Q34's accepted public native UI seam.
Full-graph Core/store tests remain separate obligations.

The source manifest records the exact final commands. Use a fresh result-bundle
path when repeating them. `./scripts/navigation-prototype.sh mac` also builds
and opens the revision, returns zero, and its compiled standalone process is
confirmed running. Mac launcher evidence records that outcome and script hash.
Raw launcher output is `/private/tmp/PlannerNavigationNativeMacLauncher.log`.

The earlier Mac automation startup failure remains historical evidence,
superseded for these five executed journeys. These checks establish selection,
disclosure memory, contextual identity and navigation, including the stated Mac
arrow-key journey. They do not establish every keyboard shortcut, VoiceOver,
Dynamic Type, resizing/rotation, the physical performance gate, durable Planner
writes, Share or CloudKit. Native composition and any additional group
border/tint still require the user's actual layout review.

## Native chrome, cumulative filters and inline maps

The next Mac screenshot review exposed a map occupying the entire detail column,
a separate Inspect Item sheet, plain-text progress, truncated independent filter
buttons, sidebar diagnostic text and an unexplained layout selector. This
revision keeps the selected appearance's details in the third pane and embeds a
compact native MapKit map in the Map alongside list comparison. It removes the
inspection sheet/action. An Item without coordinates still has its full detail
and a No location view. The other comparisons retain their ordinary detail form;
no address lookup or new provider policy is implemented.

Nonempty containers and live List groups now use a native determinate linear
ProgressView with their full completion count. Empty containers show No items
without an indeterminate spinner. A single native filter menu has independent
Completion and Archive selections, applied cumulatively. Its label is All when
both are unrestricted, or the selected restrictions, such as Todo · Active,
Active or Done. Filtering never changes full-container progress or appearance
state.

iPhone uses native TabView and NavigationStack. Regular iPad uses native top
tabs with NavigationSplitView content; portrait presents the catalog as a native
sidebar overlay. Mac uses native sidebar selection and three split columns in
every comparison. Prototype information and comparison choices live in the Mac
menu bar's named Prototype menu or the mobile information sheet. The visible
window no longer has sidebar diagnostic text or an unexplained right-hand layout
menu. The information sheet explicitly states that Planner data is read-only and
only local view preferences are saved. No custom navigation, glass cards or new
UI package was added.

The accepted Q34 public native UI seam observes literal fixture outcomes. The
inline-map journey first failed because Local Done was unavailable until
inspection, then passed with membership 401's details and map visible together.
The cumulative-filter journey first failed at the absent native progress
indicator, then passed: List A stays 1/2 while Todo/Active becomes Active, All
and Done, and appearance visibility changes accordingly. The separate
prototype-menu journey failed when the native Mac menu was absent, then passed.
The final suites include that menu/information path in their layout journeys.

Intermediate setup and accessibility probes did not all pass. The Mac
focused-binding and conditional toolbar compilation errors were corrected before
behavioral runs. Mac MenuButton exposes its visible title through AX title
rather than label. iPad's native floating tabs expose both a cell and child
Button with the same label, and its information toolbar must belong to the
sidebar within the tab's split content. Switching tabs also required reopening
the collapsed catalog in the portrait journey. Phone progress exposes a
localized percentage with a nonbreaking space; the test now reads it using
Foundation's native percent formatter. These changes observe actual native
controls and retain the independently specified expected fraction 0.5; they do
not derive expected results from private fixture projections.

All six affected public journeys pass against the same final source hashes and
exact commands, with no failures or skips. They cover cumulative
filtering/progress, appearance-to-source identity and Mac Down/Up selection,
independent direct itinerary completion, full expanded appearance identity,
disclosure memory after relaunch, and inline map/details with a generic Item
fallback.

| Destination                             | Passed | Failed/skipped | Results       |
| --------------------------------------- | ------ | -------------- | ------------- |
| Native arm64 Mac                        | 6/6    | 0/0            | Mac summary   |
| iPhone 18 Pro simulator, portrait       | 6/6    | 0/0            | Phone summary |
| iPad Air 11-inch M4 simulator, portrait | 6/6    | 0/0            | iPad summary  |

| Actual native presentation                                        | Evidence            |
| ----------------------------------------------------------------- | ------------------- |
| Mac third-pane detail with embedded map                           | Mac inline details  |
| Mac cumulative filter and full progress; live List group progress | Filters, groups     |
| iPad native top tabs, split details and cumulative filters        | Map/detail, filters |
| Phone native detail and cumulative progress                       | Map/detail, filters |

Mac evidence captures the owned application window, not the desktop. The iPad
map screenshot still has a loading/grid basemap and a native pin; it does not
prove live basemap availability or offline rendering. Every map uses the
fixture's synthetic owned coordinate, not geocoding of the museum's address.

Strict affected Swift formatting, app/UI-runner compilation through these test
runs, shell syntax, affected Markdown lint and diff checks pass. No private
fixture unit tests or Core mutation seam were added. Raw final result bundles
are `/private/tmp/PlannerNavigationChromeMacQualified.xcresult`,
`/private/tmp/PlannerNavigationChromePhoneQualified.xcresult` and
`/private/tmp/PlannerNavigationChromeTabletQualified.xcresult`. Their logs use
the same basenames with `.log`. Use the source manifest's focused commands with
fresh result-bundle paths to reproduce.

The Mac launcher now requests a fresh instance with `open -n` so a running older
process cannot conceal the rebuilt UI. `./scripts/navigation-prototype.sh mac`
builds and opens the current source, returns zero, and a new standalone process
was verified. It leaves existing instances alone. Launcher evidence records the
script hash and limits; raw output is
`/private/tmp/PlannerNavigationChromeLaunch.log`.

Planner content remains a read-only fixture projection. At this qualification,
Q38-Q42 still awaited answers for row ordering/drop/date/website/address
behavior; the later accepted choices are linked at the top of this report. Rich
metadata, completion writes, drag-and-drop and preview enrichment are not
established by these checks. Full-graph persistence,
physical/signing/sync/Share, broader keyboard/accessibility,
orientation/resizing, long-list performance and final human review remain
required. This revision records the requested presentation corrections without
closing Navigation prototype.

## Useful Item details and roomier referenced Lists

The next screenshot review requested more room around referenced List groups,
useful detail content and removal of the prominent Open source Item button. The
starting detail form exposed Global, Local and Effective flags plus
source/appearance UUIDs. The requested end keeps normal Item information in the
third pane or phone navigation stack and preserves explicit prototype inspection
for the accepted Q34 public UI seam.

The existing native DisclosureGroup now has more header spacing and vertical
padding, with additional indentation for child rows. Its native icon, title and
full-scope ProgressView distinguish the referenced List from an ordinary Item.
Collapse memory, Manual order, appearance identity and completion rules are
unchanged. This presentation does not add arbitrary List nesting.

Normal details show the Item title, Completed or To do, the containing
List/Itinerary name, notes and owned location text. The existing Map comparison
retains its compact map. Technical flags and UUIDs are available only through
Item actions → Prototype diagnostics. The source transition is Item actions →
View Item, retaining the source identity and explicitly opening its global view.
No form button or inspection sheet interrupts normal Item selection.

The new public UI journey first failed at the missing In Tokyo Weekend context,
then passed. It opens expanded appearance 452/401 and requires To do, Original
notes and Meeting point A while technical fields and Open source Item are
absent. Explicit diagnostics must still expose Local Todo, Global Todo and the
full appearance identity; closing diagnostics removes those fields again. The
existing journeys now inspect literal technical values through that same visible
diagnostics action. No private fixture unit tests or new production testing seam
were added.

All seven affected public journeys pass against the final source hashes and
exact commands. They cover the new clean-details journey, cumulative filtering
and progress, contextual-to-global Item navigation, Mac Down/Up selection with
native list focus, independent direct/expanded itinerary state, remembered
disclosure and inline map/details with a generic Item fallback.

| Destination                                     | Passed | Failed/skipped | Runtime warnings | Results       |
| ----------------------------------------------- | ------ | -------------- | ---------------- | ------------- |
| Native arm64 Mac, macOS 27.0.1                  | 7/7    | 0/0            | 0                | Mac summary   |
| iPhone 18 Pro simulator, iOS 27, portrait       | 7/7    | 0/0            | 0                | Phone summary |
| iPad Air 11-inch M4 simulator, iOS 27, portrait | 7/7    | 0/0            | 0                | iPad summary  |

| Actual native presentation                       | Evidence                                |
| ------------------------------------------------ | --------------------------------------- |
| Mac referenced List and useful third-pane detail | Expanded group/details, collapsed group |
| Explicit global Item view and compact map detail | Item view, map/detail                   |
| iPad native tabs and split details               | iPad details                            |
| Phone native navigation and details              | Phone details                           |

The Mac, iPad and phone captures were visually inspected. The Mac capture
contains only the owned app window. The referenced List has a taller
title/progress area and indented children, and the normal details contain no
prototype identifiers or state jargon. Native Form and navigation retain their
platform presentation. Final layout approval, landscape/resizing and broader
accessibility remain open.

Strict affected Swift lint, app/UI-runner compilation through the passing test
runs, affected Markdown lint and diff checks pass. Raw red/green bundles are
`/private/tmp/PlannerNavigationContentDetailsRed.xcresult` and
`/private/tmp/PlannerNavigationContentDetailsGreen.xcresult`. Raw final bundles
are `/private/tmp/PlannerNavigationContentMacQualified.xcresult`,
`/private/tmp/PlannerNavigationContentPhoneQualified.xcresult` and
`/private/tmp/PlannerNavigationContentTabletQualified.xcresult`; their logs use
the same basenames with `.log`. The source manifest records the narrow
scheme/destinations and resolved-package commands.

`./scripts/navigation-prototype.sh mac` rebuilt this source and returned zero. A
new standalone app process was confirmed after the launcher requested a fresh
instance. Launcher evidence records the script hash and qualification limits;
raw output is `/private/tmp/PlannerNavigationContentLaunch.log`.

Planner content remains a read-only fixture projection. At this runtime
qualification Q43-Q46 awaited human answers; the later accepted amendment linked
above records them without changing the app. This presentation introduces no
Core commands, provider requests, rich row metadata or drag writes. Maps still
use synthetic fixture coordinates. Physical/signing, CloudKit, Share, full-graph
persistence, long-list performance and final human review remain required.
Navigation prototype stays open.

## Saved native Lists and durable creation

The default app scene now opens the real local PlannerCore store and discovers
saved Lists through the public catalog and row-window reads. A native
three-column NavigationSplitView presents the sidebar, List contents and future
Item detail. New List uses a grouped Form with an unsaved draft, Cancel and
explicit Save. Save runs one Core command with a stable operation identity,
refreshes the catalog and selects the saved List. An empty List shows No items
without a completion percentage.

The process owns one shared facade/session; each window owns its selection and
draft. Reads preserve the selected identity while showing loading, unavailable
or Retry states. Save failures cannot produce a success acknowledgement. Applied
actions with incomplete recovery remain distinguishable from rejected or
unverified outcomes; the recovery controls and native failure presentation still
need qualification.

The accepted public native journey first failed at the absent New List control.
It now checks cancellation, explicit saving, the visible empty state and
reopening the same local dataset after terminating the app. A stronger iPad
assertion exposed an open sidebar covering the content. The native iOS column
visibility now changes to two columns after selection; Mac retains its sidebar.
The execution manifest records final source hashes, exact commands, actual
behavior failures, intermediate build/startup corrections and the qualified
regression revisions.

The final saved journey passes once on iPhone 18 Pro and once on iPad Air
11-inch M4, both using iOS 27 simulators, with no failures/skips. Their phone
and iPad captures were visually inspected. The earlier eight-function suites
passed on both simulators before the later loading/visibility correction; those
bundles include the seven unchanged comparison journeys. The final manifest
distinguishes these revisions instead of counting repeated executions as new
coverage.

The final native Mac app/UI-runner test build succeeds. Actual Mac UI startup
timed out while enabling automation mode, so zero behavior functions executed
there. The 55-function MCP regression passed with the saved default scene before
the layout-only correction; Core and transport source hashes still match the
catalog qualification. Strict lint of all six affected Swift files passes. Raw
logs retain SDK/debugger/accessibility/cleanup diagnostics.

The earlier read-only comparison remains available through the Mac Prototype
menu and `--navigation-prototype`; all existing fixture journeys launch it
explicitly. The comparison launcher forwards that argument. Normal launch uses
Application Support for local data. `--local-prototype-dataset <UUID>` selects
an isolated app-owned temporary dataset for review; the same UUID reopens that
dataset. A malformed identifier cannot open another dataset. Shell syntax
passes; the changed comparison launcher was not rerun end to end.

At this List-only revision, native Item creation/details and tabs were still
pending. These saved Lists are a localOnly prototype with CloudKit disabled.
Contextual completion circles, valid selection during live refresh, the other
source kinds, filters, progress for nonempty Lists, provider previews and drag
actions remain open. This slice reads complete row windows, so it does not
qualify moving-window memory or long-list performance. Physical
signing/sync/Share, Mac UI execution, accessibility, orientation/resizing and
final human review remain required.

## Saved native Items and global completion

Before this slice, saved native navigation could create Lists but had no Item
library or saved Item detail. It now reads active Items through the public
global query and compact row window. Both Todo and Done Items remain in this
initial library. iPhone/iPad use native TabView for Lists and Items; Item
navigation uses a native split view that collapses on phone. Mac retains three
columns for primary navigation, Item library and selected details.

New Item is a grouped native Form with title, notes, Cancel and explicit Save.
The draft owns a stable operation identity; one createItem command creates one
source. Cancel never submits a command. Saved detail displays title/notes and a
native Completed toggle. This toggle calls global Item completion from the Item
view, without changing local membership flags. Technical identities, field
hashes and Open source Item are absent. Container-local completion controls
remain separate work.

Core outcomes remain authoritative. Rejection preserves the draft or current
completion display. Unverified outcomes block further changes and require
recovery review. Applied outcomes with incomplete independent recovery are
presented as saved with recovery still needed, rather than as rolled back.
Native failure/interruption/recovery presentation still needs its own runtime
qualification. Loading/retry retains the selected source identity and discards
cancelled or superseded detail reads.

The native journey first failed because Items navigation was absent. Its next
run created the Item and displayed notes but failed after tapping the completion
row's center. Exported native accessibility attachments show a wide parent
Switch and its smaller visible switch; the final test targets that child
control. The first corrected iPhone run passed creation, cancellation, global
completion surviving relaunch and global reopening in detail. The later
two-journey run caught an iPhone List regression: an empty sidebar returned a
nonexisting Lists selection, opening a phantom detail and hiding New List. Empty
iOS selection now stays nil.

Final qualification passes both saved journeys on iPhone 18 Pro and iPad Air
11-inch M4 simulators: two functions per device, zero failures/skips. It
includes the previous List cancellation/save/relaunch behavior under native
tabs. All four final Item screenshots were visually inspected: phone completed,
phone reopened, iPad completed and iPad reopened. The iPad library and detail
remain visible together; the phone uses collapsed navigation and native floating
tabs.

The execution manifest preserves each actual failure/pass, final source hashes,
exact commands and native attachments. The final Mac app/UI bundle compiles; no
Mac behavior function executed for this slice, and the earlier test-daemon
limitation remains open. Strict affected Swift and Markdown lint and diff checks
pass. Raw logs retain SDK/debugger/accessibility diagnostics, including messages
also present in the preceding saved List runs. Historical Core/MCP
qualifications retain their recorded revisions; this UI slice changes neither
Core nor transport and claims no new HTTP execution.

At this Item-only revision, membership UI was still pending. The foundation
supports title/notes creation and global Item completion. Existing content
edits, other Item fields, contextual completion/selection, filters, provider
previews and drag remain open. It reads full row windows, so it does not qualify
paging or large-library memory. Cross-window live refresh, native failures,
accessibility and orientation/resizing also remain unqualified. Core schema 7
and portable format 1 are unchanged; CloudKit is disabled.

## Native existing-Item addition to Lists

Before this slice, native Lists could display saved memberships but could not
add them. Add existing Item now opens a native selection List with explicit
Cancel/Add. The draft retains the selected source identity, target List and one
operation identity. Add submits one Core addMembership command at the end of
saved Manual order, then refreshes that List's public row window. It creates a
reference to the existing Item; it never submits createItem or copies shared
fields. Adding the same source again retains the single membership. The picker
currently offers active Items, including globally Done ones. An empty picker
explains how to create an Item first and keeps Add disabled.

The initial test build failed because its count assertion used an element
instead of an element query; zero behavior functions executed. After that
correction, the native test failed at the absent Add existing Item control. The
first green run proved addition, duplicate addition, membership retention after
relaunch and one source in the Item library. Final qualification additionally
selects then Cancels and relaunches before adding, proving no membership was
saved by that cancelled draft.

All three saved native journeys pass on both iPhone 18 Pro and iPad Air M4
simulators: three functions per device, zero failures/skips. This retains the
earlier Item/List creation and global completion journeys. The phone and iPad
membership captures were visually inspected. The manifest records exact
commands, actual counts and final source/screenshot hashes. Native Mac
app/UI-bundle compilation, strict affected Swift/Markdown lint and diff checks
pass; Mac UI runtime remains unqualified. Raw logs retain
SDK/debugger/accessibility diagnostics and the red run's tooling diagnostic.

At this membership-only revision, the addition reuses the previously qualified
Core membership command on schema 7/portable format 1. Core and transport are
unchanged; no new HTTP admission/runtime proof is claimed. Native appearance
selection/details, contextual completion controls, nonempty progress, live
refresh, removal/move/reorder, bulk actions, other catalogs/filters and provider
previews remain open. The displayed membership circle is still an indicator.
Full-window reads, recovery failures/interruption, accessibility,
orientation/resizing, physical signing/Share/CloudKit and final human review
remain unqualified.

## Native List appearance details and completion

Before this slice, saved List rows were static indicators and the third pane
stayed empty. Rows now select their exact List membership through native
NavigationLink/List selection. Regular iPad and Mac use the detail column;
compact iPhone navigation opens the same contextual Form. Details show the
shared title, effective completion, containing List and notes. Technical flags,
hashes and UUIDs are absent. Item actions → View Item explicitly changes to the
source's global Item view; no dedicated source button or Inspect sheet is
present. Choosing another List clears the former appearance selection.

The row's native circle button submits one Core appearance completion command.
It changes only that membership's local state. Global Done disables the
contextual circle with Completed globally, without clearing its retained local
flag or offering global reopening in the List. Global reopening in Item detail
reveals each List's retained local state. A nonempty List uses a native
determinate ProgressView with Core's full-container counts; an empty List keeps
No items without a percentage. Successful app-owned changes refresh retained
List rows/progress, global Item detail and exact appearance detail. Cancelled or
superseded reads cannot replace a newer selection or revision; refresh keeps
previously loaded valid content visible.

The first native selection test failed at missing notes, then passed after exact
appearance navigation. The next test failed at the absent contextual circle. Its
two-List journey checks independent local completion, global Todo remaining
unchanged, global Done disabling the local circle, global reopening restoring
different retained local states, progress and local Done/Undone surviving
relaunch. Mac diagnostics exposed an un-restored window, native Button rows and
numeric checkbox values. The test adapter uses normal File → New Window when
needed and observes the actual controls; default Mac window launch/restoration
remains unqualified. An explicit scene-launch experiment did not resolve startup
and was removed. The iPad run then caught an overlay covering rows when
reselecting the same List. Every iOS sidebar List selection now reveals content,
even when its identity is unchanged, and the journey checks actual row
hittability.

Five saved journeys pass on each of Mac, iPhone 18 Pro and iPad Air M4 after the
sidebar correction, with zero failures/skips. They cover Item/List creation,
cancellation, adding references and both appearance journeys. Visual inspection
then caught the contextual completion icon blending into an iPad selected row.
The final one-line native plain button style has its own two affected appearance
journeys per platform, recorded separately from that earlier five-journey pass.
The execution manifest retains actual failed/passed counts, exact commands,
source revisions and screenshot provenance.

The final contextual and globally completed captures are linked for Mac, Mac
global Done, phone, phone global Done, iPad and iPad global Done. Native test
builds compile the affected app and UI tests on each platform. Strict affected
Swift/Markdown lint and diff checks pass. SDK/debugger/accessibility diagnostics
remain in raw logs.

This reuses qualified public Core commands and reads on schema 7/portable format
1, with CloudKit disabled. It adds no HTTP route, provider requests or new
persistence model. The app-owned refresh revision is not an external
Core/CloudKit observer. Cross-window runtime, external writes, contextual
removal/deletion, filtering/paging, drag/bulk actions, recovery
failures/interruption, broader accessibility, rotation/resizing, physical
signing/Share/sync and final human layout review remain unqualified.

## Saved native List reordering

Before this slice, saved List appearances could be selected and completed
locally but had no native saved-order controls. This slice submits the existing
Core reorderMembership command for one exact membership. Move to Beginning/End
is available in each row's native context menu. Mobile Lists use EditButton and
List.onMove. macOS uses a native Table with row Transferable drag payloads and
insertion destinations; its selection binding opens the contextual third-pane
details. This uses Apple's
[native Table row drag-and-drop](https://developer.apple.com/documentation/swiftui/adopting-drag-and-drop-using-swiftui).
Drag payloads contain List/membership identities only. A different List's
payload is not accepted by this reorder-only destination.

The app preserves the membership identity, local completion and shared Item
content. It refreshes rows, progress and selected details after the durable
command outcome. The selected Item remains attached to that same appearance.
Busy controls and destinations refuse another change; errors use the existing
save/recovery presentation. The current scope is one unfiltered standalone List
in saved Manual order. Filtered Manual reordering, cross-List Move/Add,
multi-selection, external writes and other sort modes still require separate
work.

The native journey creates Hotel/Museum and their Tokyo List through normal UI,
completes Hotel locally, moves it using the context menu, and checks exact
appearance identity, notes and completion after relaunch. It then drags Hotel
before, after and before Museum, checks literal row geometry each time, and
relaunches again to check the final order and retained state. It reads no
private persistence state. Existing Core reorder proof at 3fb72a5 covers
rejected anchors/payloads, replay, recovery obstruction, rank rebalance and
unchanged Item data; this UI slice changes no Core schema or command contract.

The initial red run failed at the missing Move to End action. Mobile
qualification then caught a missing Edit control and an incorrect assumed
reorder-handle label. The adapter now locates the actual native handle within
the exact appearance's cell. Earlier Mac experiments incorrectly used XCTest's
touch press-and-drag. A disposable plain SwiftUI probe failed with that gesture
and passed with the native mouse click-and-drag API. That corrected gesture
still failed in the Planner List/table experiments. A smaller native Table probe
isolated a second cause: plain Text rows accepted mouse drags, while otherwise
equivalent title Button rows did not. The final Mac table lets the native row
select and drag; only the independent completion circle remains a Button. Probe
source/tests are removed from the app.

Four affected Mac journeys passed after the Text-row correction, with zero
failures/skips. The subsequent native inset style and formatting correction have
a separately recorded final reorder journey on each of Mac, iPhone 18 Pro and
iPad Air M4, all passing with zero failures/skips at the same frozen source
hashes. Test builds compile the affected app/UI bundle on every platform. Strict
affected Swift/Markdown lint, Info.plist validation and diff checks pass.

Execution manifest records the failed and passed runs, separate source
snapshots, exact commands and local result bundles. Earlier passes are not
attributed to later source hashes. The phone capture shows retained contextual
detail after drag; row order is established by native geometry assertions. The
tablet and Mac captures show the List order and selected details together.
Captures are exported from the named test attachments, checked by byte
count/hash and inspected visually.

- Mac saved List after drag
- Phone contextual detail after drag
- iPad saved List after drag

Mobile raw logs include context-menu animation/quiescence delays. These runs
establish functional behavior, not interaction latency, long-list performance or
every accessibility/keyboard path. macOS automatic window restoration,
orientation/resizing, native failure/interruption, full-graph persistence,
provider previews, physical signing/Share/CloudKit and final human review remain
open. The Navigation prototype gate stays open.

## Clear counts and ordinary location maps

The user accepted Q47 A after noticing that full progress exceeded the visible
rows, and requested archived-item visibility. The starting comparison showed 0
of 3 done for one direct Item plus a live List with two children, although
Active hid one archived child. Its map was also restricted to the Map alongside
list comparison.

Progress now names its item units, including singular item for one child. The
Itinerary separately shows 1 direct item · 1 list. When cumulative filters hide
children, the container shows Showing 2 of 3 items and the referenced List shows
Showing 1 of 2 items. Full completion totals still include archived/filtered
children and independent repeated appearances. Disclosure collapse changes
presentation only. Active, Archived and All already existed in the native
archive picker; the new journey explicitly exercises all three and verifies
unchanged full progress. Saved flat Lists use the same clearer item units, while
saved cumulative query-filter controls remain unfinished.

A shared native ItemLocationSection now displays owned name/address data and a
MapKit marker whenever saved coordinates exist, in ordinary global and
contextual details. Both saved detail adapters use this section. The map's
identity follows its coordinates so selecting another place resets the initial
region. The comparison retains its missing-location fallback. No coordinates are
invented from an address, and no new provider lookup or metadata cache is
implemented.

The accepted public native UI seam establishes two separate red/green pairs. The
ordinary-map test failed at the absent map in normal Wishlist appearance
details, then passed in both contextual and global Item detail without selecting
the special layout. The count test failed at the absent accepted label, then
passed through Active, Archived and All with literal child visibility, container
composition, group counts and unchanged progress. Mac's initial runner timeout
occurred before test execution and is separately recorded, rather than counted
as a behavior red.

The evidence manifest records exact source hashes, commands, summaries, raw
result paths and capture hashes. All final runs used the same nine affected
source files without edits during execution.

| Destination                   | Executed journeys | Failures/skips               | Result                                               |
| ----------------------------- | ----------------- | ---------------------------- | ---------------------------------------------------- |
| iPhone 18 Pro simulator       | 11                | 0/0                          | Passed                                               |
| iPad Air 11-inch M4 simulator | 11                | 0/0                          | Passed                                               |
| Native arm64 Mac              | 0                 | Runner initialization failed | App/test bundles compiled; automation mode timed out |

The eleven journeys on each simulator cover ordinary and comparison maps, useful
details/diagnostics separation, cumulative filtering, appearance-to-source
identity, independent itinerary appearances, disclosure/relaunch, and two real
saved-data appearance completion/detail journeys. The saved journeys retain
global OR local precedence and relaunch behavior; they do not create a saved
location. Wiring saved location presentation is therefore distinct from a future
native location edit/reopen proof.

Four final captures were visually inspected: phone ordinary map, phone with
archived children, iPad ordinary map, and iPad filtered counts. Additional
captures retain the opposite filter states. These maps use the fixture's
synthetic owned coordinate, not the museum's geocoded address. Visible tiles do
not establish general live-network availability or offline map behavior.

Strict formatting/lint on the nine affected Swift files, compiler checks through
the selected native builds, affected Markdown lint and diff checks pass. Both
Mac attempts failed before executing a behavior function; current Mac runtime
and visual qualification remain open. This correction does not close Navigation
prototype or waive its physical, accessibility, resizing, long-list, sync or
Share requirements. The
[whole-application polish ticket](https://github.com/dvcol/planner/issues/23)
follows feature completion and records its own Context, DoR, DoD and
`/tdd`/visual/device checks.

## Archive and cumulative saved filters

Before this slice, saved Lists always showed all their children and the Items
catalog showed only active Items. Neither offered filter controls, and global
Item details had no Archive/Unarchive action. Archived Items without a List
could not be reached from the catalog.

Item actions in global Item detail now offers Archive Item or Unarchive Item. It
executes the existing public Core archive command with the same durable-save and
independent-recovery requirements as other native changes. Archiving preserves
shared content, memberships, global completion and each membership's local
completion. Contextual List details show Archived without adding a global action
there.

Saved Lists and the Items catalog now have native menus with independent
Completion and Archive selections. The displayed label is All or the cumulative
restrictions, such as Todo · Archived. The menu provides Active, Archived and
All archive states. Saved Lists retain their previous All/All default; the Items
catalog retains All completion/Active archive. These choices belong to the
current window and are not persisted or backed up in this slice. The active-Item
membership picker uses its own read, so changing catalog filters cannot change
its candidate set.

Each filter change requests a new public Core row window. A superseded query
cannot replace newer filters, revision or selection. Previously loaded content
remains visible with native loading feedback while it refreshes. Full List
ProgressView counts still include archived and filtered-out children. Showing 0
of 1 item and No matching items distinguish a filtered empty result from a truly
empty List. Regular iPad keeps valid contextual details after their row leaves
the filter; unarchiving an Item in the Archived catalog keeps its valid global
detail open while the catalog becomes empty.

Three separate native UI red/green cycles cover archive persistence, saved List
filters and catalog recovery. The archive test first failed at the absent Item
actions control. The List-filter test failed at its absent filter menu. The
catalog test initially failed in a navigation helper that incorrectly waited for
the missing new filter; after correcting that helper to use the existing New
Item control, it reached the actual absent-filter assertion. That helper failure
is recorded separately from the behavior red. Each corrected test passed its
minimal implementation. The List and catalog journeys also passed on the iPad
simulator.

Visual inspection then found that the system toolbar collapsed a Label to its
icon even with titleAndIcon styling. The final menu uses a native Text label to
keep the selected restrictions visible. The final source snapshot, selected
regression results and inspected captures are recorded in the evidence manifest.

The six-journey regression passed on iPhone. On iPad, five passed and the
catalog journey's broad Archived-text disappearance assertion failed because the
now-visible filter label correctly remained Archived. Its hierarchy confirms
that matching text belonged to the filter menu. The corrected test checks
retained details and its existing Active-catalog read after relaunch proves
saved Unarchive. That corrected catalog journey passes on both simulators.

A further public native UI qualification starts with Hotel/Museum/Cafe,
completes Hotel locally, then filters Todo. Dragging Cafe before Museum retains
full 1 of 3 progress and Showing 2 of 3 items. Returning to All and relaunching
yields Hotel/Cafe/Museum, all three original memberships and Hotel's retained
local Done state. This case passed the existing production implementation on its
first executed run. Its initial test-only compile failure called a fileprivate
helper from another file; moving that helper unchanged into the existing shared
test adapter fixed compilation, with zero behavior functions executed in the
failed build.

| Destination / run                      | Passed              | Failures/skips | Scope                                                                       |
| -------------------------------------- | ------------------- | -------------- | --------------------------------------------------------------------------- |
| iPhone 18 Pro, regression              | 6                   | 0/0            | Five saved appearance/archive/filter journeys and unfiltered native reorder |
| iPad Air M4, regression                | 5                   | 1/0            | Same six journeys; the catalog text assertion was corrected below           |
| iPhone 18 Pro, corrected qualification | 2                   | 0/0            | Catalog Unarchive/relaunch and hidden-member filtered drag/relaunch         |
| iPad Air M4, corrected qualification   | 2                   | 0/0            | Same two journeys                                                           |
| Native arm64 Mac                       | No runtime journeys | Not run        | Updated app/UI-test bundles compile                                         |

Seven distinct journeys are qualified per simulator across those recorded runs.
Production source remained unchanged across regression and corrected
qualification. Strict lint passes on all nine affected Swift files, compiler
checks pass for the updated native bundles, and affected Markdown/diff checks
pass. Six captures were visually inspected, including phone filtered counts,
iPad retained filtered-out details, archived All rows, phone filtered drag, iPad
restored full order and iPad unarchived detail.

Advanced filters, remembered sort preferences, paging, other filtered reorder
combinations, external refresh, native failure/recovery presentation and the
remaining graph views are still open. Mac filtered-drag runtime remains
unqualified. Core schema 7 and portable format 1 are unchanged; CloudKit remains
disabled. Mac compilation does not qualify runtime, window restoration or visual
behavior. Physical signing, Share, account transitions, sync, accessibility,
resizing and long-list memory remain separate gates. Whole-app polish follows
feature completion in [ticket 23](https://github.com/dvcol/planner/issues/23).

## Native membership removal

Before this slice, Core and authenticated HTTP could remove a membership, but
the native app could only add, complete and reorder it. Native Item actions and
row context menus now offer Remove from List. The action submits the exact List
and membership identities through the existing Core command. It preserves the
shared Item and other memberships; it offers no global completion, archive or
source Delete fallback.

The native adapter keeps the same rejected, unverified and
applied-with-incomplete-recovery distinctions as other saved changes. After Core
reports the mutation applied, the adapter clears only a selection matching the
removed appearance. A different current selection is retained. The removed
detail becomes a native unavailable view, and an emptied List keeps No items
without a completion percentage. The List notice explains that the Item remains
available in Items; the detail pane prompts another selection. Choosing another
List or appearance clears the notice. Native failure/recovery presentation and
external deletion-driven refresh remain separate work.

The public native UI journey first failed at the missing Remove from List
control. Its first green run passed with real saved data on iPhone. It completes
separate memberships in Tokyo Food and Wishlist, removes the selected Tokyo Food
membership, verifies cleared contextual details and empty progress, and
relaunches. Wishlist retains its original membership identity/local Done, and
the global Item retains its notes and Todo state. An ordinary re-add to Tokyo
Food creates a different membership starting local Todo; Wishlist remains Done.
This uses the previously qualified Core command and changes neither schema 7 nor
portable format 1.

The same removal journey passes on iPad, alongside two affected
completion/detail regressions. Those two regressions also pass on iPhone.
Together with its first green removal run, three distinct journeys pass per
simulator with zero failures/skips. Visual review found duplicate explanations
in the iPad's empty columns. A text-only correction gives the detail pane a
next-step prompt; the iPad removal/re-add journey passed again after that
correction. Updated native Mac app/UI-test compilation passes, with no Mac
runtime claim.

The manifest preserves commands, actual summaries, source snapshots and four
inspected captures: phone removal, phone re-add, iPad removal and iPad re-add.
Strict lint on the five affected Swift files, affected Markdown lint and diff
checks pass. The journey exercises contextual Item actions; row menus are wired
and compiled but their removal action still needs separate interaction
qualification. Native Move, other Add paths, Undo, external refresh,
failure/recovery, physical sync/Share and broader accessibility/window review
remain open. This does not close the Navigation prototype or map.

## Remaining gates

The first read-only UI slice cannot establish completion writes, query
generation/window completeness, ordinary import, recovery, capture, schedules,
CloudKit or Share feasibility. Those journeys must use their approved public
seams and truthful outcomes as implementation proceeds. Further comparison must
cover Calendar content, iPad tab/sidebar adaptation, persistence/reopen,
orientation/resizing, keyboard/focus, Dynamic Type, VoiceOver and final human
layout decisions. Physical-device long-list latency and memory, signed Share and
account/sync tests remain deferred rather than waived.

## Native row-menu removal

The next qualifier exercises Remove from List from an unselected row's native
context menu. Long press on iPhone and iPad removes the membership, shows No
items without an empty progress percentage, and leaves the source Item's notes
and global Todo available in Items. This qualifies an alternative user entry
point to the preceding selected-detail removal; it does not add a mutation or
change Core.

One journey passes on each OS 27 simulator with zero failures/skips on the first
executed run. This is interaction qualification, with no manufactured behavior
red. Native arm64 Mac app/test bundles compile; its row-menu runtime is still
unqualified. Strict affected Swift lint and source-hash checks pass. Xcode's
context-menu animation waits remain in the raw logs.

Both app-owned captures were inspected. The phone empty List and iPad empty List
show the ordinary unselected state. The iPad detail remains Choose an Item. The
evidence record keeps exact commands, source hashes, result counts and capture
hashes. Raw bundles and logs are
`/private/tmp/PlannerRowRemoval{Phone,Tablet,Mac}` with their respective
extensions.

Selected-context persistence remains covered by the preceding removal evidence.
No native Move, external refresh, Undo, failure/recovery presentation, Mac
runtime, signed/physical-device, CloudKit, Share, accessibility/keyboard or
long-list performance result is established by this qualifier. The feature and
final polish gates remain open.

## Native membership move

Before this slice, Core and authenticated HTTP could move a membership
atomically, but contextual native Item actions could only view or remove it. The
new Move to List action opens a native sheet with the Item, its source List and
a destination selection. The source List is excluded. Move requires a valid
selected destination and available mutation access; Cancel changes no data. The
form retains one operation identity for its proposal and uses the existing
domain command with end placement. It cannot change the shared Item or offer
global completion from the List.

The public journey creates Nezu Museum with saved notes, marks its Tokyo Food
appearance Done, then cancels a move to Wishlist. The source identity and
completion remain. Confirming the next proposal empties Tokyo Food and clears
only the removed appearance's selected detail. Wishlist receives a new
membership, locally Todo; the global Item remains Todo with its notes. Relaunch
keeps the empty source and the destination's new identity/state. The user
selects the destination explicitly; the source detail never silently becomes a
global or destination action.

The first executed red failed at the absent Move to List action. Initial green
reached review/cancellation, then a test tried to inspect a hidden iPhone List
row while detail remained visible. This was a test interaction error. Navigating
back before checking the row corrected it, without mutation changes. The
corrected move journey passes on both simulators. The affected
selected-removal/re-add journey also passes on each, proving its retained
other-List state and new local-Todo re-add after sharing selection clearing.
These are two distinct journeys per simulator across recorded runs, with zero
failures/skips in the passing runs.

Chooser copy was then clarified to include the global completion exception. Only
its footer changed. The move journey passes again on both simulators at that
source snapshot; all six final captures were inspected. Native arm64 Mac
app/test bundles compile at both snapshots, with no runtime claim. Strict
affected Swift lint and source/capture hash checks pass. No new Core, HTTP,
schema or backup-format implementation is introduced.

| Native outcome                      | iPhone       | iPad                            |
| ----------------------------------- | ------------ | ------------------------------- |
| Destination review                  | Chooser      | Chooser                         |
| Selected source removed             | Empty source | Empty source and cleared detail |
| New Todo destination after relaunch | Detail       | List and detail                 |

The evidence record preserves commands, executed red, the test correction,
passing runs, source snapshots and captures. Raw result bundles/logs remain
under
`/private/tmp/PlannerNativeMove{PhoneRed,PhoneGreen,PhoneCorrected,TabletCorrected,PhoneRemovalRegression,TabletRemovalRegression,MacCorrected,PhoneCopyReview,TabletCopyReview,MacCopyReview}`
with their respective extensions.

Core's membership mutation evidence separately proves existing-destination
preservation, global Done precedence, replay and failure behavior at its
recorded revision. Those are not all native UI outcomes here. The following
row-menu slice qualifies Move and existing-destination interaction. Other Add
paths remain open, alongside external refresh, Undo, native failure/recovery
presentation, Mac runtime, signed/physical-device, CloudKit, Share,
accessibility/keyboard, large-data and final human review. The final whole-app
polish still follows feature completion.

## Native row-menu move

Before this slice, Move to List was available only after opening contextual
detail. Native row menus now offer the same destination sheet for an unselected
Item: long press on iPhone/iPad, right click in the Mac Table. They retain the
exact source membership and use the already qualified move command. The shared
Item is preserved.

The public journey creates Tokyo Food with Nezu Museum, and Wishlist with Nezu
Museum first and Hotel second. Wishlist's Nezu appearance is locally Done while
the global Item remains Todo. Moving from Tokyo Food to the existing Wishlist
destination removes the source membership, preserves the destination
identity/local completion/first position, and leaves exactly one Nezu
appearance. Relaunch retains both the empty source and unchanged destination.
Explicitly opening the global Item verifies its notes and Todo state.

The first executed red failed at the missing row-menu Move action. Adding the
native menu entries made the journey pass on both simulators. The original
fixture had Nezu last; it was strengthened to place Nezu first so an accidental
move to the end would fail. Production stayed unchanged. The stronger journey
passes once on each simulator, with zero failures/skips. The affected row-menu
removal journey separately passes once on each simulator. Native Mac app/test
bundles compile; no Mac runtime is claimed. Strict affected Swift lint and
source/capture hashes pass.

| Native outcome                                         | iPhone   | iPad     |
| ------------------------------------------------------ | -------- | -------- |
| Existing destination review                            | Chooser  | Chooser  |
| Preserved completion and first position after relaunch | Wishlist | Wishlist |

All four final app-owned captures were inspected. The evidence record preserves
exact commands, source snapshots, initial red/green, stronger fixture runs and
removal regression. Raw bundles/logs remain under
`/private/tmp/PlannerNativeRowMove{PhoneRed,PhoneGreen,TabletGreen,MacGreen,PhoneRemovalRegression,TabletRemovalRegression,PhonePositionReview,TabletPositionReview,MacPositionReview}`.
Context-menu animation waits remain recorded.

Other Add paths, cross-List drag, external refresh, Undo, native
failure/recovery presentation, Mac runtime, signed/physical-device, CloudKit,
Share, accessibility/keyboard, large-data and final human review remain open.
Whole-app polish follows feature completion.

## Add from global Item details

Before this slice, a saved Item could only be added by opening a List's
existing-Item picker. Item actions now include Add to List. The native sheet
names the Item and offers one destination List, with explicit Add/Cancel. Add
requires a valid selection and mutation availability. Without Lists,
ContentUnavailableView explains the next step and Add stays disabled. The
proposal pins the Item identity and retains one operation identity; it uses the
existing Core addMembership command at the end of Manual order. Success keeps
the Item detail open and refreshes saved references. No content is copied.

The public journey creates a locally Done Tokyo Food appearance, completes its
source Item globally, then selects Wishlist and Cancels. Wishlist remains empty
and Tokyo Food retains its identity. Confirmed addition creates a different
membership in Wishlist, displayed Done because the Item is globally Done, with
its local circle disabled. Reopening the global Item reveals Wishlist's new
local Todo while Tokyo Food stays locally Done. Adding to Wishlist again retains
the same membership identity and one visible appearance. Relaunch retains both
contexts, source notes and global Todo.

The first executed red fails at the absent Add to List action. The main journey
then passes once on each simulator. Production remains fixed while a separate
no-Lists interaction qualifier and the affected Archive/Unarchive catalog
regression pass: two functions on each simulator, zero failures/skips. These are
three distinct passing journeys per simulator across the recorded runs. The
empty-state qualifier passes on its first run, so it has no claimed behavior
red. Native Mac app/test bundles compile at both snapshots; Mac runtime remains
unqualified. Strict affected Swift lint and source/capture hash checks pass.

| Native outcome                                 | iPhone        | iPad          |
| ---------------------------------------------- | ------------- | ------------- |
| Add destination review                         | Chooser       | Chooser       |
| Global Done display                            | Wishlist      | Wishlist      |
| Local Todo after global reopening and relaunch | Wishlist      | Wishlist      |
| No destination available                       | Empty chooser | Empty chooser |

All eight app-owned captures were inspected. The evidence record preserves exact
commands, executed red/green, first-run qualification, regression, source
snapshots and capture hashes. Raw bundles/logs remain under
`/private/tmp/PlannerNativeGlobalAdd{PhoneRed,PhoneGreen,TabletGreen,MacGreen,PhoneQualification,TabletQualification,MacQualification}`.
Core, HTTP, schema 7 and portable format 1 are unchanged.

The following slice qualifies contextual/row-menu Add paths. Archived
destination management, advanced filters/sorts/paging, external refresh, bulk
review, rich rows and location editing remain open. Earlier remaining Mac
runtime, failure/recovery, physical-device/CloudKit/Share,
accessibility/keyboard, large-data and human-review limits still apply. Final
whole-app polish follows feature completion.

## Contextual and row-menu Add

Before this slice, Add to List required opening the global Item detail or
starting from a destination List. Contextual Item actions and native row menus
now open the same destination picker directly. Contextual detail uses the
appearance's shared Item reference; row actions use the row's source identity,
never its membership identity. The existing command/picker keeps its validation,
cancellation, operation identity and save/recovery behavior. Adding does not
remove the current membership or switch selection to another context.

The public journey creates a locally Done Nezu Museum in Tokyo Food, then adds
it to empty Wishlist from its contextual detail. Tokyo Food's selected detail,
notes, source membership identity and local Done remain. Wishlist's new
appearance starts Todo. The journey marks it locally Done, adds Hotel after it,
then adds Nezu again from Tokyo Food's row menu. Wishlist retains its original
identity, local Done, first position and one Nezu appearance. Relaunch retains
both Lists' completion and identities. Explicit global Item detail remains Todo
with its notes.

The first executed red fails at the missing contextual Add action. The minimal
native wiring then passes one journey on each simulator, with zero
failures/skips. Source hashes stayed fixed during green runs. Native Mac
app/test bundles compile with no runtime claim. Strict affected Swift lint and
source/capture checks pass. No picker, Core, HTTP, schema or backup-format code
changes.

| Native outcome                               | iPhone   | iPad            |
| -------------------------------------------- | -------- | --------------- |
| Original detail retained after Add           | Detail   | List and detail |
| Existing destination retained after relaunch | Wishlist | Wishlist        |

All four app-owned captures were inspected. The evidence record preserves exact
commands, executed red/green, fixed source snapshots, result counts and capture
hashes. Raw result bundles/logs remain under
`/private/tmp/PlannerNativeContextAdd{PhoneRed,PhoneGreen,TabletGreen,MacGreen}`.
Native row-menu animation waits remain recorded.

Shared Item content editing, rich rows, advanced filters/sorts/paging, bulk
review, repeated Itinerary appearances, archived-container management,
cross-List drag and external refresh remain open. Earlier failure/recovery,
Undo, Mac runtime, signing/physical-device/CloudKit/Share,
accessibility/keyboard, large-data and human-review limits still apply.
Whole-app polish follows feature completion.

## Shared Item title and notes editing

Before this slice, saved Items could be created and completed but their
title/notes could not be edited in the native app. Edit Item now opens a native
grouped Form from global Item details. It reviews the shared title and notes,
disables Save for unchanged or blank-title drafts, and keeps Cancel separate
from saving. A draft pins the original public source read and its field hashes.
Save sends only changed fields through the existing guarded Core command with
one operation identity. The editor dismisses after an applied local save; a
rejected save leaves its draft open with the native error alert. No contextual
action silently becomes a global edit.

The main public journey cancels changed content, rejects a blank title, then
saves both fields. Tokyo Food's locally Done appearance and Wishlist's local
Todo keep their identities and completion while both display the new content.
Relaunch retains that result. The second journey changes the title alone, then
clears notes in a fresh editor. Global Done survives both saves and relaunch.
Global Reopen then reveals the List's retained local Todo.

The executed red fails at the missing Edit Item action. Initial green runs on
both simulators fail in the test helper before saving: app-owned accessibility
values show that the helper assumed the insertion caret was at the end.
Production remains fixed while the helper switches to native Select All. The
main journey then passes on both simulators. The one-field/clear journey is a
separate first-run qualification and passes on both simulators. Each final
recorded run executes one function with zero failures/skips, giving two distinct
passing functions per platform across separate runs. Final Mac app/test bundles
compile; no Mac runtime function executes.

| Native outcome                                 | iPhone     | iPad       |
| ---------------------------------------------- | ---------- | ---------- |
| Shared draft review                            | Editor     | Editor     |
| Live locally Done reference                    | Tokyo Food | Tokyo Food |
| Local Todo retained after relaunch             | Wishlist   | Wishlist   |
| Clear notes without changing title/global Done | Item       | Item       |
| Global Done retained after relaunch            | List       | List       |

All ten original app-owned captures were inspected. The evidence record
preserves commands, source epochs, initial test-helper failures, final results
and capture hashes. Raw logs/results remain under
`/private/tmp/PlannerNativeItemEdit{PhoneRed,PhoneGreen,TabletGreen,MacGreen,PhoneSelectionReview,TabletSelectionReview,MacSelectionReview,PhoneQualification,TabletQualification,MacQualification}`.
Strict affected Swift lint, Markdown lint and source/capture checks pass.

This slice edits title/notes only and changes no Core, HTTP, schema or
backup-format code. Native stale/concurrent-save and failure/recovery journeys
remain unqualified. Rich rows, location/estimate/link/label editors, advanced
filters/sorts/paging, bulk review, repeated Itinerary appearances,
archived-container management, cross-List drag and external refresh remain open.
Earlier Mac runtime, Undo, signing/physical-device/CloudKit/Share,
accessibility/keyboard, large-data and human-review limits apply. Whole-app
polish follows feature completion.

## Shared subtitle editing and row preview

Before this slice, the global catalog could display an owned subtitle, but List
rows had only a title and the native editor could not change the subtitle. Edit
Item now reviews an optional Subtitle field and sends Set/Clear only when it
changes. The global catalog and contextual List rows share a compact native text
stack. List navigation exposes title and subtitle to accessibility while
retaining the separate contextual completion button, membership identity and
selection. Row content comes from the existing lightweight RowRead without
loading full source details for every row.

The public journey completes a List appearance locally, edits its shared
subtitle in Item view, and observes that subtitle directly in the List row. It
preserves notes, title, membership and local Done through relaunch. Clearing the
subtitle removes its secondary line while retaining the same membership, notes,
global Todo and complete-scope progress.

The executed native red fails at the missing subtitle field. Initial green
attempts expose a deeper gap: Core supports subtitle creation/read but rejects
edits. The draft remains open with a native alert. Both subtitle journeys fail
at that rejected save; the affected iPhone title/notes regression passes. The
[Core subtitle slice](core-local-qualification.md#guarded-item-subtitle-editing)
then qualifies Set/Clear, persistence/recovery, stale-patch rejection and replay
in 4032864. Native/test source remains fixed across that correction. The same
subtitle function now passes on each simulator with zero failures/skips. Mac
app/test bundles compile; no Mac runtime function executes.

| Native outcome                      | iPhone | iPad            |
| ----------------------------------- | ------ | --------------- |
| Shared subtitle draft               | Editor | Editor          |
| Compact completed row               | List   | List and detail |
| Cleared subtitle retains completion | List   | List and detail |

All six original app-owned captures were inspected. The evidence record retains
source epochs, commands, failures, corrections, final counts and capture hashes.
The affected notes-over-HTTP command selected zero functions despite exiting
successfully, so it does not qualify the regression. Its initial wrong-scheme
attempt is also setup failure with zero executed functions. Raw results/logs
remain under
`/private/tmp/PlannerNativeSubtitle{PhoneRed,PhoneGreen,TabletGreen,MacGreen,PhoneCoreReview,TabletCoreReview,MacCoreReview,NotesHTTP,NotesHTTPReview}`.
Strict affected Swift lint, Markdown lint and source/capture checks pass.

Only title/subtitle row content is qualified here. Saved
location/date/estimate/link previews and their controls, advanced
filters/sorts/paging, bulk review, repeated Itinerary appearances,
archived-container management, cross-List drag and external refresh remain open.
HTTP subtitle editing still needs its own admission/routing slice. Native
stale-save/failure/recovery presentation and earlier Mac runtime,
device/CloudKit/Share, Undo, accessibility/keyboard, large-data and human-review
limits apply. Whole-app polish follows feature completion.

The subsequent
[HTTP subtitle slice](mcp-http-qualification.md#guarded-item-subtitle-over-http)
adds that route and passes four affected functions through the actual adapter in
a temporary native package runner. It includes the notes regression previously
selected as zero functions. The native Mac app/test bundle compiles; app-hosted
XCTest startup remains unqualified.

## Native Item and List text search

Before this slice, the saved Items catalog and saved Lists had
Completion/Archive menus but no text search control. Each now uses SwiftUI's
native `searchable` interface, labelled "Search Items" or "Search this List".
Queries pass text and the current Completion/Archive choices to the
[qualified Core query](core-local-qualification.md#canonical-item-text-search).
Search matches all words within one Item, including its currently saved shared
content. The views retain their existing cancellation, filter, revision and
selected-identity guards, adding the current text to the checks before
displaying a load. Query text remains local presentation state. No Item,
membership or progress state is edited by searching.

The implementation follows Apple's
[search placement guidance](https://developer.apple.com/documentation/swiftui/adding-a-search-interface-to-your-app).
Native
[toolbar preservation](https://developer.apple.com/documentation/swiftui/view/searchpresentationtoolbarbehavior%28_%3A%29)
keeps the cumulative filter menu accessible during search on iPhone. Items use
the standard search-unavailable view for a nonempty query with no matches. Lists
retain their native unavailable view beside complete-scope progress and "Showing
x of y". All archive states makes archived children visible again; selecting
Active can hide them without changing the denominator or local Done.

The first public journey creates Café Lunch and Hotel through the native app.
Both have notes mentioning the garden. "cafe garden" matches Café Lunch across
its title and notes with accent-insensitive comparison; "cafe hotel" matches
neither because the words belong to different Items. Clearing search restores
both rows, and opening Café Lunch confirms its original notes and global Todo.

The second public journey creates two live List memberships, completes Nezu
Museum locally, and archives its shared Item. Its text matches one row while
progress remains 1 of 2. Combining Active with that text hides every row while
preserving "Showing 0 of 2 items" and full progress. A simultaneous valid
selected detail must retain its List context and notes. All archive states
restores the archived match; clearing only text restores both rows with the same
membership and local completion.

Each executed red selects one actual native function and fails at its missing
search field after setup succeeds. Each unchanged function then passes on the
iPhone simulator. Final fixed-source qualification passes two affected functions
on iPhone and three on iPad, including the existing cumulative archive-filter
regression. Together with the separate iPhone List green, three distinct
journeys qualify on each simulator with no failures or skips. The macOS app and
UI-test bundles compile, with zero Mac runtime functions claimed. Strict
affected Swift lint, Markdown lint and diff checks pass. The app-intents
metadata extraction warning is also present in the earlier baseline build; no
Swift type-check warning was introduced by this slice.

| Native outcome                    | iPhone     | iPad                           |
| --------------------------------- | ---------- | ------------------------------ |
| Item text matches across fields   | Items      | Items and retained detail      |
| Clearing search retains content   | Detail     | Catalog and detail             |
| One List match with full progress | List       | List and detail                |
| Active hides the archived match   | No matches | No matches and retained detail |
| All and cleared text restore rows | Two rows   | Two rows and detail            |

All ten original app-owned captures were inspected. The iPad Item-search capture
visibly retains Hotel detail after its row leaves the query; the automated
retention assertion covers the List appearance. The evidence record keeps exact
commands, completed red/green outcomes, final source epochs and log/capture
hashes. Raw logs and result bundles remain under
`/private/tmp/PlannerNativeTextSearch{GlobalRed,GlobalGreen,ListRed,ListGreen,PhoneQualification,TabletQualification,MacBuild}`.
XCTest startup and teardown are slow; their elapsed times do not measure app
responsiveness.

Inbox presentation, shared-label search, structured filters, sorts, paging,
external-writer refresh, filtered reorder, estimate controls and the
5,000-Item/200-List/300 ms device gate remain open. This does not qualify
persistence of display preferences, Mac runtime/window restoration,
keyboard/accessibility, rotation/resizing, physical iCloud/Share or final human
review. Whole-app polish follows feature completion.

## Native sorts and device preferences

Before this slice, saved Items always used Title ascending and saved Lists
always used Manual order. Both views now offer a native SwiftUI
[Menu](https://developer.apple.com/documentation/swiftui/menu) with inline
Pickers for Title, Created, Last updated and Duration, plus
Ascending/Descending. Standalone Lists also offer Manual, which always sends
ascending saved order. Requests use the qualified Core query rather than sorting
detailed rows in the view. Source/appearance selection stays attached to its
identity. Loads capture the selected sort and ownership namespace alongside
search, filters and revision, discarding obsolete results.

Native
[UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults)
stores each choice under a hash of the dataset UUID and opaque ownership
binding, followed by the Items view or stable List UUID. The existing
A21-approved session ownership field is now readable by the adapter; Core still
creates and validates sessions. Session UUIDs are excluded from the preference
key because reopening issues a new session. Preferences remain outside shared
records and portable backups. The app includes the app-only UserDefaults
declaration, CA92.1, following Apple's
[required-reason API guidance](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest).

Reordering is available only in Manual. iOS disables row moves and the Edit
button for computed sorts, and exits edit mode when the sort changes. Mac Table
rows only provide a membership drag value in Manual; context actions, drops and
reorder commands use the same guard. Add, Remove and local completion retain
their existing scopes.

The new public Core ownership test starts with two actual local datasets and
reopens the first. It verifies stable dataset/ownership identity, a changed
session UUID and distinct ownership for the other dataset. Its executed red
fails compilation because the approved field was internal, with zero runtime
functions. Exposing that same field permits the unchanged function to pass. The
narrow Core regression passes five functions in three suites, including
canonical duration and chronological sorts.

The Item UI journey creates Zulu, Alpha and Middle through native forms. It
exercises every available mode and both directions, verifies unknown-duration
title ties, relaunches, opens a separate empty dataset with default sorting and
returns to the original remembered choice. The List journey uses those sources
in two differently ordered Lists. It verifies independent remembered choices,
local Done in Tokyo versus Todo in Weekend, complete progress, stable membership
identities and restored Manual order after relaunch. It also enters drag-edit
mode before choosing Title and verifies the disabled Edit control afterward.
Source Item completion remains Todo.

Each native red executes one function and fails at the missing menu after setup
succeeds. Initial implementation runs expose two test assumptions: UIKit's
toolbar Menu omits an accessibility value, and iOS progress accessibility rounds
one of three to 33%. The Menu now exposes its choice in the native label; the
test reads that label. The List test checks the exact one-of-three text and
expected native percentage, and uses the established Toggle selector. Corrected
Item and List runs each pass one function. The initial four-function regressions
pass on both simulators, but capture inspection reveals that the toolbar remains
in Done after choosing a computed sort. A strengthened assertion reproduces this
in an executed red. Binding the native List and toolbar Edit button explicitly
to the same state makes the unchanged strengthened journey pass. Production
source remains fixed from that edit-mode green through the final qualification.

The final fixed-source regression passes four functions on each simulator with
zero failures or skips: Item sorting, List sorting, cumulative List search and
filtered Manual drag. The final Mac app and UI-test bundles compile, with zero
runtime functions. Strict affected Swift lint, Markdown lint and diff checks
pass.

| Native outcome                                     | iPhone | iPad                      |
| -------------------------------------------------- | ------ | ------------------------- |
| Chronological Item sort                            | Items  | Items and retained detail |
| Returning dataset retains its choice               | Items  | Items                     |
| Manual order and local Done survive computed sorts | List   | List                      |
| Relaunch retains List choice and order             | List   | List                      |

All eight final original captures were inspected. Manual List captures show Edit
without drag handles, Zulu locally Done, one-of-three progress and the saved
Zulu/Alpha/Middle order. The narrow iPad Items title still truncates; resizing
and whole-app polish qualification remain open. The evidence record preserves
executed counts, exact commands, failures, source epochs and capture hashes. Raw
logs/results remain under
`/private/tmp/PlannerNativeSort{OwnershipRed,OwnershipGreen,CoreQualification,CatalogRed,CatalogGreen,CatalogCorrectedGreen,ListRed,ListGreen,ListCorrectedGreen,EditModeRed,EditModeGreen,MacBuild,PhoneQualification,TabletQualification,MacFinalBuild,PhoneEditModeQualification,TabletEditModeQualification,MacEditModeBuild}`.

The native Duration journey currently uses Items without estimates; numeric
estimate ordering is qualified at Core/HTTP seams. Native estimate entry awaits
Q48/Q49. List rename, restored same-UUID views in different datasets/accounts,
account transitions, multiwindow preference refresh, import/export preference
preservation and physical cross-device behavior still need their own runtime
evidence. Native Inbox/Itinerary sorts, paging, remaining filters, external
refresh and failure/recovery presentation remain open. Compilation does not
establish Mac runtime, window restoration or visual quality. Whole-app polish
follows feature completion in ticket 23.

## Saved Inbox navigation

Before this slice, Core supported unlisted Items but the saved native app had
only Lists and Items destinations. Inbox now uses a native Tab on iPhone/iPad
and a sidebar entry on Mac. It reuses the lightweight catalog and sends the
existing canonical Inbox scope. Loads bind scope as well as text, filters, sort,
revision and ownership; an obsolete scope cannot replace the current result.
Item details and actions retain their global source identity.

Inbox starts with Todo and Active filters. Its search and cumulative
Completion/Archive choices remain independent from Items during the current
launch. Its remembered sort uses the existing dataset/ownership namespace with a
separate Inbox view key. Relaunch resets transient search/filter state and
retains the sort. No shared records, schema, portable format or Core interfaces
change.

The public journey creates Zulu, Alpha and Middle through native forms and adds
Zulu to Tokyo with local Done. Inbox initially shows Alpha and Middle, excluding
Zulu. Global completion and archiving of Alpha change its visibility
independently; All completion and All archive restore its same source row. The
final journey searches `alpha garden` across that archived Item's title and
notes, hides Middle and excludes listed Zulu, then clears only search. Items and
Inbox retain different sort choices. Removing Zulu's last membership makes it
appear in Inbox with its shared notes and global Todo. Relaunch retains that
removal and Inbox's Title descending choice, while Items remembers Created
descending.

The executed red selects one function and fails at the missing Inbox destination
after setup succeeds. Initial green reaches Inbox but fails at a test assumption
that the compact phone shows its catalog instead of retaining Middle detail. The
test now uses the native Back control. That corrected run reaches the archive
step but fails after a tap leaves the native menu open with Active still
selected, visible in the app-owned test recording. The test waits for menu
option existence/hittability and targets Alpha by stable identity after its
archive icon changes the combined accessibility label. Production source stays
fixed across these test corrections. The corrected journey passes one function;
final qualification strengthens archived-hidden assertions and adds the Inbox
text-search observations.

Native search adds a separate UI observation. Clearing the field leaves iPhone
search active until its native Close action. iPad presents Hide keyboard, which
retains editing; the first following tab activation can end that interaction
without selecting the requested tab. An empty-dataset reproduction fails in
28.680 seconds, excluding memberships, completion and archive data as
prerequisites. Targeting the hittable inner tab button also fails. A second
activation succeeds as a diagnostic, and does not become the test's navigation
shortcut. Explicit search presentation and fixed child tab scopes do not change
the reproduction and are removed.

On iPad, tapping the native List background after Hide keyboard ends editing.
The small journey then activates Items once and verifies selected state and
toolbar hittability. Heading queries failed before evaluating focus and provide
no focus proof. The full Inbox journey uses the same List-background sequence.
iPhone uses its native Close action. The first five-function phone run exposes a
test reading Close's label after that control disappears; the correction
captures the control kind before activation. Native search ending remains part
of human keyboard/UI review.

The five-function iPad run passes all five. The phone run passes the three
existing sort/search regressions and fails the two new journeys at the
disappearing-control query. After capturing the control kind before activation,
the two affected functions pass on each simulator. These runs qualify five
behaviors per device across the recorded source epochs, rather than claiming one
final all-passing five-function phone run. Production source matches the
original Green exactly; both unsuccessful app variants are removed. The
unchanged Core membership/search suites pass ten functions in three suites,
including twenty parameterized literal-search cases. The final Mac app and
UI-test bundles compile and execute zero runtime functions. Its two
metadata-extraction log warnings also occur in the earlier build; the Xcode
build summary reports zero compiler errors.

Saved Inbox evidence records twenty-seven run commands, actual outcomes, source
epochs, corrections and eight final original captures with matching hashes. All
eight are inspected: Todo/Active Inbox excludes listed Zulu, All shows
archived/completed Alpha, relaunch returns Zulu after last-membership removal,
and the selected Items tab is visible after search ends. iPhone archive capture,
iPad archive capture and iPad tab-switch capture retain those observations.
Narrow iPad toolbar titles can hide or truncate beside the filter controls;
resizing and whole-app polish remain required. Affected Swift format lint,
compilation and Markdown lint pass.

Native Itinerary presentation, rich rows/editors, remaining filters, paging,
external-writer refresh, bulk review, container archive and cross-List drag
remain open. Earlier account/restoration, Mac runtime, physical iCloud/Share,
failure/recovery, Undo, accessibility/keyboard, resizing, large-data and
human-review gates remain required. Whole-app polish follows features 14–17.

## Saved List archive and visibility

Before this slice, Core could archive a List and query Active, Archived or All
Lists, but native saved navigation exposed only active Lists and had no
container archive action. The goal is to make Archive and Unarchive available
without changing referenced Items, membership identities, order or local
completion. R1 and R14 establish container-only Archive with no Trash; the
existing Core archive/catalog tests and the agreed native UI seam provide the
DoR.

The final native sidebar uses a List context menu for Archive and Unarchive. Its
system Menu/Picker selects Active, Archived or All; the visible label stays
compact while its accessibility label names Lists. Archived rows carry an
archive icon and accessibility value. The selected List's ordinary header shows
Archived List with its full ProgressView. Catalog filtering uses Core, retains
valid selection and rejects obsolete loads. Membership destination forms
continue using their existing active-List discovery.

The public journey creates Zulu and Alpha, references both in Tokyo in that
order, and references Zulu separately in Wishlist. Tokyo's Zulu becomes locally
Done. Archive removes Tokyo from Active, Archived reveals its same identity, and
All includes both containers. Opening archived Tokyo retains the same two
membership identities, Zulu then Alpha, local completion and 1/2 progress.
Wishlist's Zulu and the source Item remain Todo; the source stays active with
its notes. Relaunch preserves archive and membership state. Unarchive returns
Tokyo to Active without resetting completion or order.

The initial red reaches the missing content-toolbar List actions control. The
first iPhone green fails because the test looks for the global Toggle as a
Button; its query is corrected to the existing accessibility boundary. The first
iPad green shows the long sidebar label displacing New List into native
overflow. A compact label makes that action reachable, but the next iPad run
finds the added content-toolbar List menu displacing Add Item. The final UI
removes that redundant menu and uses the native sidebar context action. These
failures and the intermediate passing iPhone run remain in the evidence.

The final archive journey passes one function per simulator. A separate
regression run passes two existing functions per simulator: native List draft
cancellation/creation and cumulative search with full archived progress and
retained valid detail. Three native behaviors qualify per device across those
runs. The iPad regression run takes 567.907 seconds, with repeated 60-second
animation-completion waits during search editing. That is an observed runtime
limitation, not a completed responsiveness gate or a claim about the base
revision. Three existing Core functions pass in two suites. Final Mac app and
UI-test bundles compile with zero runtime functions; the raw log retains two
metadata-extraction warnings and its build summary reports zero compiler errors.

Saved List archive evidence records twelve commands/outcomes, four source
epochs, the unchanged Core base and six inspected original captures with
matching hashes. iPhone archived progress, iPad All Lists and iPad after
Unarchive show the expected state. The iPad sidebar title truncates at this
width, and the archive header uses subdued secondary text. Resizing, contrast
and human review remain part of the native polish gate. Affected strict Swift
format lint, compilation, Markdown lint and whitespace checks pass.

This satisfies the local saved List archive slice of DoD. Saved Itinerary
archive, reviewed bulk completion, external-writer refresh, physical
CloudKit/account checks, failure/recovery UI, Mac runtime and the earlier
accessibility/keyboard/large-data/human-review gates remain open. Whole-app
polish still follows features 14–17. Schema 7, portable version 1 and localOnly
storage remain unchanged.

## Saved Item bookmarks

Starting state: Core already owns ordered bookmarks and guards their
replacement, but the saved native editor exposes only title, subtitle and notes.
Details and rows cannot show the links. The goal is native, staged bookmark
management through the existing Item edit command, with live content in every
List and independent completion retained. Q50 A separately approves the
production native cache/provider boundary for automatic previews; that boundary
is still next.

The grouped Edit Item form now adds labelled URL fields and native Move Up, Move
Down and Remove Link menus. Cancel discards all staged changes. Save sends one
guarded patch; unchanged links stay unchanged, and removing the last link sends
an empty replacement. Existing owned identities, exact URL spelling, saved order
and optional labels survive editing. Native Link controls appear in both source
and appearance details. Rows display the selected website caption or a Maps hint
for Maps-only content. These reads perform no provider fetch or implicit content
update.

The first native red reaches the missing Add Link control. Its implementation
run saves both exact URLs and verifies row/local state, then fails because the
test helper searches for a Button instead of the observed native Link role. The
corrected journey passes. The next red verifies invalid-URL rejection before
reaching the missing link-actions menu. After those actions are added, phone and
tablet runs expose a query still matching the old Guide label after rename.
Exported query descriptions establish that cause; assertions then follow the
saved identity. The revised journey verifies both ordering directions and
cancelled removal before reproducing the missing Maps-only row hint. Its native
caption makes the two complete journeys pass on both simulators.

The live-reference journey uses Tokyo and Wishlist, retaining Done versus Todo
and the same owned bookmarks after relaunch. The management journey rejects a
combined title/invalid-link edit, preserves global Done and notes,
edits/reorders links without replacing their identities, cancels removal,
removes individual links and finally verifies empty links after reopening. The
existing six Core link functions pass in two suites, including validation,
guarded replacement, exact identities/order and reopen/recovery behavior. Core
source is unchanged from `635d43d`.

The fixed functional source passes two bookmark functions per simulator.
Separate affected Inbox/subtitle regressions pass two more functions per
simulator. Their operation logs take 426.588 seconds on phone and 434.020
seconds on tablet, each with two native 60-second animation waits around the
Inbox menu actions. Those observations are recorded; responsiveness remains
open. Screenshot inspection also reveals a phone editor title overlapping Cancel
with the keyboard visible. The only subsequent production change uses the native
iOS inline title modifier. The live-reference journey passes again on each
simulator, and the inspected editor captures show a clear title. Mac app and
UI-test bundles compile again, with zero Mac runtime functions. Strict affected
Swift formatting, Markdown lint and whitespace checks pass.

| Native outcome                                  | iPhone      | iPad                    |
| ----------------------------------------------- | ----------- | ----------------------- |
| Staged bookmark fields and native actions       | Editor      | Editor                  |
| Edited bookmarks retain identity and order      | Details     | Details and row caption |
| Maps-only content retains a useful row          | Items       | Items and owned link    |
| Reopening retains shared content and local Done | List detail | List and detail         |

All eight original captures were inspected and their copied hashes verified.
Saved bookmark evidence records eighteen commands/outcomes, eight source epochs,
executed function counts, the failed selectors, the Maps-only red, the
presentation correction and capture provenance. The original red exec response
was lost during context truncation; its completed failed log and failed xcresult
remain the terminal evidence. Mac build summaries report zero compiler warnings;
their raw logs contain AppIntents metadata-extraction warnings, which the
evidence retains. Raw logs/results use
`/private/tmp/PlannerNativeBookmarks<phase>` paths recorded in that file.

This satisfies the local saved bookmark management slice. Automatic link images,
address-only lookup and cache invalidation remain unimplemented; Q50 approves
their new public test boundary. Saved coordinates retain the existing native
Map, while a Maps bookmark alone does not supply coordinates. Native
location/estimate/label editing, remaining filters/paging, Itinerary
presentation/archive, external refresh, bulk review and cross-List drag remain
open alongside the existing physical sync/account/Share, recovery, Mac
runtime/restoration, accessibility/keyboard, responsiveness and human-review
gates. The iPad catalog title still truncates at this width and details repeat
the navigation title; whole-app polish remains in ticket 23 after feature
completion. Schema 7/portable 1 and localOnly storage are unchanged.

## Preview source lifetime binding

Q50 A requires temporary native preview results to remain attached to the
correct dataset, source lifetime and saved input. Core already checks lifetime
UUIDs internally. Before this slice, row, Item source and appearance reads did
not return that UUID, so native views could not share a preview key safely
across those reads.

The reads now return the existing `sourceLifetimeId`. This adds no stored or
portable schema and no fetched provider data. Lightweight rows still omit full
notes, field hashes and the complete bookmark collection. The manually
constructed MCP projections retain their existing wire fields.

The public Core test creates a saved Item with an owned bookmark and address,
adds it to a List, compares the lifetime returned through source/appearance/row
reads, locally completes it, edits its notes and reopens the real local store.
It verifies the same lifetime, owned values, dataset namespace and retained
local completion. The reopened query uses Completion All so a completed
appearance remains in the tested window.

The initial compilation failure included an incorrect test ownership property;
the corrected red contains only the missing lifetime properties. The first
implemented run exposed the test's Todo-filter exclusion, which was corrected.
Final qualification executes 13 tests in five affected Core suites and passes.
Mac and iPhone simulator build-for-testing both pass, with zero runtime UI tests
in these builds. Each raw build log contains the existing AppIntents
metadata-extraction warning. Swift format strict lint and diff checks pass.
Machine-readable evidence records source hashes and the outcomes.

Native provider requests, stale-response/cache tests and actual
link-image/address-map UI integration remain the next Q50 work. This slice does
not prove deletion/recreation, account switching or CloudKit behavior.

## Native Category name management

Before this slice, Core and the HTTP adapter at `b8a3468` save Category
metadata, but native Planner has no Category entry point. The goal is a native
name-management journey through the existing public commands. The accepted
Core/native UI test seams and guarded label contract supply DoR; schema 8 and
independent recovery are already qualified separately.

Planner now opens a native Category list and staged create/edit forms using
NavigationStack, List, NavigationLink, Form, TextField, system toolbar actions
and ProgressView. Cancel discards a draft, Save uses the existing creation or
name-only guarded edit, and a successful acknowledged save returns to the list.
Names persist after relaunch. The edit retains the source read's original guard
and preserves color/icon fields. Recovery-incomplete or rejected saves keep
their explanation available instead of closing as an acknowledged success.

The app-owned iPhone journey establishes a missing-entry-point red and then
passes create, Cancel, rename, Cancel and relaunch. Its first version lacked
MainActor/failure-stop conventions; these are corrected before the recorded
one-failure red. An iPad compatibility journey then exposes a crowded sidebar
toolbar that hides New List. Moving Categories to every mobile bottom toolbar
passes iPad but creates an off-screen iPhone action. The final adaptive
placement keeps the header action in compact layouts and uses the native bottom
toolbar in regular-width layouts. Existing List tests remain unchanged
throughout these corrections.

Final fixed-source qualification passes two UI functions on each simulator,
covering Category names and existing List draft/relaunch behavior. Actual result
summaries confirm two passed, zero failed and zero skipped per device. The Mac
app and native test bundle compile with zero runtime functions. Strict lint for
the four affected Swift files, Markdown lint, source-hash verification and
whitespace checks pass. Execution evidence retains commands, failures, source
epochs and the original captures. Phone and iPad captures show the native
catalog. The accompanying toolbar captures establish the surviving List
presentation; form controls are observed through XCTest, without a separate form
pixel capture.

This qualifies native Category names. Category associations/deletion, color/icon
editors, Tags, large label catalogs/paging, iPad compact-window changes,
external refresh, stale/recovery UI, keyboard/VoiceOver/Dynamic Type and Mac
runtime still need their own checks. Earlier Core/HTTP qualifications are not
rerun by this UI-only slice. Schema 8/portable 1 remain localOnly with CloudKit
disabled. Signed sync/account/Share, manual JSON administration and whole-app
polish remain open.

## Native reviewed List bulk completion

Context: individual List rows can change completion, but the saved app has no
full-context completion confirmation. The List actions menu now offers Mark all
Done and Mark all Undone. Core prepares an immutable review before a standard
SwiftUI Form shows the exact complete count and List name, including archived
children and rows hidden by current filters. Cancel executes nothing. Confirm
applies the same review and command through the existing durable writer. Global
Item flags and other contexts stay unchanged; Undone explains why globally
completed Items can still appear done.

DoR is the approved Q8 precedence, full-context reviewed Core/MCP boundary,
archived progress and native component preference. NavigationStack, Form, Menu,
toolbar actions and ProgressView supply the interface. No technical IDs, hashes
or raw local/global/effective status fields appear. A stale-target response
prepares a new review and updates the form; the user must confirm again. That
refresh branch compiles but controlled native stale-target/failure interaction
is not yet qualified. Existing rejection, recovery-blocking and revision
handling share the same result handler as ordinary changes.

The first launch incorrectly selects the Planner scheme, which excludes UI
tests. The corrected PlannerNavigation run fails at the unavailable List action
before implementation. Initial implementation and diagnostic runs still fail
because the test assumes an inline toolbar button. The actual hierarchy and
screenshot show SwiftUI's native overflow; the journey now opens More and its
List actions submenu. The iPad initially fails earlier at Add existing Item,
also moved into native overflow in its narrower content column. The setup helper
now follows that native path. Count, cancellation, archive, completion, identity
and relaunch assertions remain intact; corrections add diagnostics and reach
existing native controls.

The final iPhone run passes three functions: the new bulk journey and existing
archived-search and per-List sort journeys. The same bulk journey passes once on
iPad. Both results have zero failures/skips. It proves cancellation leaves 0/2,
bulk Done produces 2/2 despite one hidden archived child, the global Hotel flag
remains Todo, explicit global Done survives bulk Undone as 1/2, global Reopen
reveals retained local Todo as 0/2, and source archive/row identities survive
relaunch. Native Mac app/UI test-bundle compilation executes zero runtime
functions. Strict four-file Swift lint, affected Markdown lint and whitespace
checks pass on 240 frozen source/resolution hashes. Only the existing App
Intents metadata-skip warning appears in final logs.

Actual iPhone and iPad summaries and screenshots retain the results: phone
review, phone completed, phone relaunch, tablet review, tablet completed and
tablet relaunch. Failed runs also report an Apple simulator
diagnostic-collection error after the behavior/setup failure; final successful
runs have no such error. No failed attempt counts as qualification.

This completes the tested List confirmation journey, with partial overall bulk
DoD. Itinerary/List-entry native presentation, Intent system confirmation,
controlled native stale-target/failure interaction and genuine save/recovery
faults remain open. Core, HTTP admission, schema 13 and portable format 1 are
unchanged from ddf203f. Storage remains localOnly. Pending decisions, schedules,
controls/paging, deletion/admin, physical sync/account/Share and whole-app
polish retain their owning gates.

The subsequent
[Core recovery-fault qualification](core-local-qualification.md#bulk-completion-after-recovery-publication-fails)
proves the postcommit recovery path for all three bulk scopes on macOS and
iPhone. It changes no UI source and does not qualify the native failure
presentation. Genuine SQLite save-failure rollback remains open.

## Native Itinerary catalog and staged editing

Context: Core and HTTP can create, read and guard Itinerary content, but the
saved native app has no Itineraries entry point. This slice adds the active
catalog, creation and separate title/notes editing through those existing public
commands. The qualified Core source/catalog/edit boundary and agreed native UI
seam supply DoR. Schema 13, portable format 1 and Core/HTTP sources remain
unchanged; storage remains localOnly.

Mobile uses a native Tab and NavigationSplitView. Mac adds sidebar selection
with catalog and detail columns. List, NavigationLink, Form, TextField, toolbar
buttons, system sheets, ContentUnavailableView and ProgressView provide the
interface. Creation stays staged until Save; empty titles disable Save and
Cancel submits nothing. Detail displays the saved title, notes and derived
empty/progress presentation. Edits submit only changed title/notes fields with
the original read's guards, preserving other content. The edit draft pins that
read independently from detail refresh. Rejected or recovery-incomplete saves
retain their explanation and do not dismiss as acknowledged success. Controlled
native concurrent refresh and failure interaction still need their own
qualification.

The unchanged native tracer first fails at the absent Itineraries entry point.
The first implemented compile exposes optional progress counts; rendering is
corrected to the declared empty/known/unresolved states. The first green passes
creation cancellation, empty/unchanged Save disabling, title-edit cancellation,
separate title/notes preservation, stable source identity and relaunch. Review
then keeps existing List/Item sheet alerts available from the Itineraries
section. Four iPhone journeys and three iPad journeys pass, including existing
Category/List journeys and the iPhone Item journey. Mac app/UI test-bundle
compilation executes zero runtime functions.

A final review pins the original edit snapshot instead of letting its sheet
input follow refreshed detail state. Only the new Itinerary view file changes
after that compatibility epoch. The same frozen Itinerary tracer reruns and
passes once per simulator, with final Mac compilation and strict four-file Swift
lint. Every successful native summary has zero failures/skips. The
functional-red test remains byte-identical. Execution evidence retains every
attempt, source epoch, commands, four summaries and 242 final source/resolution
hashes. The functional red's later Apple diagnostic-collection error is recorded
separately and never counted as a pass. Final logs report only the existing App
Intents metadata-skip warning.

All four retained captures are visually inspected: phone details, phone catalog
after relaunch, iPad details and iPad catalog after relaunch. Phone navigation
collapses into catalog/detail; iPad retains both columns. Technical state
fields, IDs and a layout selector are absent from the visible interface. Forms
are exercised through real native controls; no separate form pixel capture is
claimed.

This qualifies the basic native catalog/edit journey. Ordered child
presentation, entry controls, Itinerary archive/filter/search/paging, richer
content editors, schedules, bulk confirmation, deletion/admin, controlled native
failures/external changes, Mac runtime, accessibility and physical
sync/account/Share remain open, followed by whole-app polish. Q56 A is now
accepted: explicit ascending Manual queries will extend to itineraries,
preserving alphabetical omitted-sort API behavior. That shared query capability
is the next slice; this revision does not implement it. Earlier pending
decisions remain unanswered.

## Native ordered Itinerary entries

Context: Q56 A qualifies explicit Manual ordering in Core and HTTP. The saved
native Itinerary previously displayed title, notes and progress, with no child
entry controls. This slice reads that shared query and adds saved Item/List
entries, contextual checks and native appearance details. DoR is the qualified
public entry/query/completion boundary and accepted native UI test seam. DoD for
this slice is cancellation without mutation, route/child order, independent
repeated-Item completion and exact identities/state after relaunch. Schema 13,
portable format 1 and localOnly storage are unchanged.

A native List presents route order. Referenced Lists use a roomier
DisclosureGroup with their own ProgressView; the full Itinerary ProgressView and
direct-Item/List counts explain the structure. Add stages an existing active
Item or List and saves through the existing Core command. Repeated sources
remain live references with independent appearance checks. Global Done retains
precedence, and the Itinerary view offers only local completion actions.
Selection opens ordinary Form details in the third split column, collapsing
naturally on phone. Existing owned-link and location sections are reused; this
fixture does not qualify provider previews again.

The real native tracer first fails at the absent Add entry control. Initial
phone compatibility passes four functions. Tablet compatibility finds a missing
test path through the native List overflow menu and a real edit-presentation
regression in the unchanged catalog journey. Isolating that catalog test
reproduces the failure. Single-sheet and root-owned presentation experiments
fail and are removed. Explicitly focusing the content column when selecting an
Itinerary fixes the regression; the unchanged catalog function passes on iPad
after the experiments are removed. The affected phone pair passes at the same
production epoch.

The new entry tracer then needs the native Show Sidebar action to locate its
retained Itinerary after relaunch on iPad. Only that test navigation changes;
production bytes stay fixed. The final entry function passes once on each
simulator, preserving Hotel → List → Hotel order, List child order, appearance
identities, local Done independence and the full one-of-three progress. These
final summaries are not combined with earlier source epochs into a larger pass
count. Mac app/UI-test bundles compile with zero runtime functions. Strict
five-file Swift formatting and whitespace checks pass; final compilation reports
the prior App Intents metadata-skip warning. Core, preview and HTTP
sources/tests are byte-identical to `ec30ef5` and are not rerun.

Execution evidence retains all attempts, the failed experiments, navigation
corrections, source-epoch differences, 248 final hashes and final mobile
summaries. All four final captures are visually inspected: phone contents, phone
appearance details, iPad contents and iPad appearance details. Historical
catalog captures retain their original bytes.

Basic native ordered contents/addition/checks/details are qualified. Entry
reorder/removal/bulk, native archive/filter/sort/search/paging, richer owned
content and schedules remain open. All archived children are presently
displayed; cumulative controls and moving-window loading are separate work.
Controlled native concurrent/stale/failure interactions, Intent confirmation,
genuine SQLite rollback, Mac runtime/resize/accessibility, physical
sync/account/Share and whole-app polish retain their gates. Earlier pending
decisions remain unanswered.

## Native reviewed Itinerary bulk completion

Context: Core and HTTP qualify reviewed List, Itinerary and itinerary List-entry
completion. Native List confirmation already exists; Itinerary views lack both
bulk scopes. DoR is the accepted Q8 precedence, complete appearance targets,
public review/execute boundary and native UI test seam. DoD for this slice is
explicit scope/count confirmation, cancellation without mutation, archived
inclusion, local-only effects, repeated-entry independence and durable relaunch.
Schema 13, portable format 1 and localOnly storage are unchanged.

A native toolbar Menu offers whole-Itinerary Mark all Done/Undone. A List
header's native context menu offers the same actions for that exact entry. Both
ask Core to prepare the complete target review, then use the existing Form and
system sheet for Confirm/Cancel. The form names the container and completion
scope and explains archive/filter inclusion and global Done precedence. It
offers no global action. The existing stale-review path requires a refreshed
confirmation. A recovery-incomplete explanation now keeps the form visible
rather than dismissing as acknowledged success; controlled native stale/failure
interaction remains an open qualification gate.

The first two whole-scope attempts fail during setup because the test queries a
Toggle as a Button. The query and native Back/Sidebar/archive-filter paths are
corrected without production changes. The functional red then reaches the
missing Itinerary action. Its green verifies three appearances, an archived List
child, Cancel, Done/Undone, retained global Hotel Done, untouched standalone
List completion and relaunch. A second tracer first fails at the absent
List-header action. Its green verifies that the first of two repeated List
entries changes while the second entry, direct Item and standalone List remain
Todo, preserving exact appearance identities after relaunch. Its functional-red
file remains byte-identical to the final test source; adding it preserves the
whole-scope assertions and existing helpers.

Frozen compatibility passes four functions on each simulator: both new journeys
and the byte-identical existing List bulk and Itinerary edit regressions. Both
summaries have zero failures/skips. Mac app/UI-test bundles compile with zero
runtime functions. Strict four-file Swift formatting and whitespace checks pass.
Core, previews and HTTP sources/tests are byte-identical to `b0d8464` and are
not rerun. Final compilation reports the prior App Intents metadata-skip
warning. The slow native menu interaction and measured simulator durations are
recorded; no responsiveness threshold is claimed.

Execution evidence retains attempts, commands, tracer changes, final summaries
and 249 frozen hashes. Eight captures are visually inspected. Whole-scope phone
review and iPad review name three children. Their phone relaunch and iPad
relaunch retain global Done and the archived child's local Todo. Entry-scoped
phone review and iPad review name one child. Their phone relaunch and iPad
relaunch show independent repeated entries.

This qualifies basic native confirmation and both Itinerary bulk scopes. Native
Itinerary filters remain open, so hidden-child interaction is supplied by the
existing standalone List regression, not claimed for Itineraries. Entry
reorder/removal, archive/filter/sort/search/paging, richer content, schedules,
deletion/admin, controlled native stale/recovery/save failures, Intent
confirmation, genuine SQLite rollback, Mac runtime/resize/accessibility,
physical sync/account/Share and whole-app polish retain their gates.
[Q53/Q54/Q55 A](../navigation-row-contract-review.md#accepted-native-labels-and-filter-round)
are now explicitly accepted presentation decisions; their implementation is next
work.

## Live shared labels in row windows

Baseline 447e63e. Q55's shared read slice adds the existing PlannerLabelRead
array to compact Core rows and the existing LabelValue shape to HTTP rows.
Previously only full source reads exposed live names. Global Item rows and
standalone/repeated Itinerary appearances now resolve the Item's referenced
labels; Itinerary catalog rows resolve their own labels. Category, Tag and List
catalog rows return an empty array. Same-name labels retain distinct identities
and optional color/icon metadata. No persisted models, schema 13, portable
version 1, localOnly storage or native UI behavior changes.

Public Core tracer cycles cover metadata, empty labels, contextual references,
independent owner labels, another writer, generation invalidation, unchanged
Item hashes/timestamp and reopening. The initial interface compile red is
followed by a functional empty-label red. The contextual tracer's first attempt
also uses an invalid archive criterion for label catalogs; correcting that
fixture reaches only the missing Itinerary metadata assertions. The HTTP tracer
first has no matching temporary-package source, then an incorrect
source-envelope helper. Neither attempt qualifies row behavior. Its corrected
functional red reaches the absent labels field, and the serializer passes it.
Two existing exact-key tests are updated for the additive labels field and still
require empty arrays for unlabeled fixtures.

Frozen qualification passes 15 Core functions in eight affected suites, 29 real
HTTP functions in five suites and six native Core functions in two suites on the
iPhone simulator, with zero failures. The phone has zero skips. Mac
build-for-testing compiles the app and MCP tests and runs zero runtime
functions. Nine affected Swift files pass strict swift-format lint. The 256
source/resolution/configuration hashes stay unchanged through qualification.
Machine-readable evidence and the phone summary preserve outcomes and source
hashes.

Q53–Q55 native presentation and controls remain open: compact overflow with
complete accessible names, all labels in details, association editors, Manage
Labels including associated-label deletion confirmation/Settings access, and
adaptive cumulative Filters. Existing bounded paging, physical
synchronization/account/Share, SQLite rollback/native controlled failures, Mac
runtime, responsiveness/accessibility and whole-app polish gates remain open.
This qualification adds no UI screenshots or physical-device proof.

## Shared native label management

Baseline 399bc21. Q53's first native slice replaces Category-only management
with one Manage Labels destination. Native List sections separate Categories and
Tags, a system New Label menu chooses their kind, and staged Forms create/rename
either kind through guarded Core commands. No new main tab, schema or backup
changes are introduced. The existing library toolbar opens the destination.
Settings access and associated-label deletion/impact confirmation remain open.

The new native Tag tracer first fails at the absent destination title. After
implementation, the existing Category journey passes; the Tag journey creates
and opens editing, then fails because its Select All helper restricts its query
to Buttons. Correcting it to the proven Category query preserves its behavioral
assertions. Tag create/rename cancellation, Save, retained identity and relaunch
then pass. The Category journey keeps its prior assertions and changes only its
creation helper for the new menu. The final production epoch also discards
canceled/outdated label loads.

Frozen qualification passes two real UI functions on each of the iPhone and iPad
simulators, with zero failures/skips. Mac build-for-testing compiles the app and
native UI tests and runs zero runtime functions. Five affected present Swift
files pass strict format lint; the 257 source/configuration hashes stay
unchanged through qualification. Core, previews and HTTP source/tests are
byte-identical to 399bc21 and are not rerun. All four retained app-owned
relaunch captures were visually inspected. Evidence, phone summary and tablet
summary retain the checks.

Phone Category, phone Tag, tablet Category and tablet Tag show native sections
and system toolbar controls without diagnostic identities or state fields. These
captures qualify this destination, not whole-app polish or Mac runtime.

Native label association editors, compact row overflow/full
accessibility/details, adaptive cumulative Filters and bounded paging remain
open. Associated-label deletion, Settings entry, controlled native save/recovery
failures, SQLite rollback, Mac runtime, physical synchronization/account/Share,
accessibility/keyboard, responsiveness and whole-app polish keep their owning
gates. Schema 13, portable version 1 and localOnly storage are unchanged.

## Live labels in contextual details

Baseline f543cb4. Q55's next shared-read slice adds the existing
PlannerLabelRead metadata to PlannerAppearanceRead and its HTTP value.
Previously appearance details exposed label identities inside Item content but
omitted resolved names/colors/icons. Standalone List, direct Itinerary and
expanded List appearances now return their source Item's live metadata without a
second full-source read. The existing snapshots already resolve those labels;
this change adds no persistence model or client-side join.

The contextual public-read tracer first fails to compile without the property,
then fails functionally with empty metadata before and after reopening. Reusing
each resolved source snapshot passes the tracer. The real HTTP tracer reaches
the missing detail labels and passes the shared serializer. Rename from another
writer preserves source Item hashes/timestamp and appearance completion while
fresh details retain the renamed metadata after reopen.

Frozen qualification passes five Core functions in three affected suites, five
HTTP functions in three suites and five native Core functions in three suites on
the iPhone simulator, with zero failures/skips. Mac build-for-testing compiles
the app and MCP tests and runs zero runtime functions. Five affected Swift files
pass strict format lint. All 257 source/configuration hashes stay unchanged
through qualification. Evidence and the phone summary retain these checks. No UI
screenshots or physical-device proof are added in this read-only slice.

Native association editors, compact overflow/full accessibility/details,
associated-label deletion/Settings access, adaptive Filters and bounded paging
remain open, alongside existing native failure/SQLite rollback, Mac runtime,
physical sync/account/Share, accessibility/responsiveness and polish gates.
Q48/Q49/Q51 are re-presented through the question tool without inferring an
answer; Q52 remains pending. Schema 13, portable version 1 and localOnly storage
are unchanged.

## Native Item label selection and previews

Baseline dbf511c. Before this slice, Manage Labels could create/rename shared
Categories and Tags, but Item editing could not select them and native
rows/details omitted their names. DoR is the accepted Q53/Q55 A presentation,
existing guarded Item label commands, live row/appearance metadata and approved
native UI seam. DoD for this slice is staged selection with Cancel/Save, compact
overflow with complete accessible names, full labels in details, live rename
propagation and durable relaunch. It does not include label deletion, Settings
or adaptive Filters.

The grouped Item editor now opens native Category/Tag selection Lists with
system Toggles. Selections remain draft identity sets until the parent Save,
which sends only changed sets through the existing guarded Item command. Cancel
discards them. The shared row component displays all Category names and two
Tags, followed by +N for additional Tags; its accessible value includes every
name. Native Category/Tag sections show all names in Item, standalone List and
Itinerary appearance details. Foundation's localized comparison orders display
names with stable identity ties; names are never copied into Item content.

The native tracer first fails at the absent Category selector. Its initial
compile attempt used a nonexistent test helper and is not functional evidence.
The implemented selection journey passes Cancel, Save, literal overflow/full
accessible names, and reopening. Extending it with shared renames initially
queries a row identity after leaving that row; capturing the identity before
navigation fixes the helper without weakening assertions. The extended journey
then passes on both simulators: Culture becomes Art, Rain becomes Wet weather,
the same Item's compact/full names refresh, and global Todo remains unchanged.

Qualification records two frozen source epochs. The initial epoch passes all
three selected functions on iPhone. On iPad it passes the live-reference edit
and label journeys, then fails the bookmark helper's visibility assertion before
scrolling. The first helper correction reaches a second identical assumption at
Guide actions. Revealing controls before existence checks and after a reorder
preserves every behavioral assertion; the final bookmark journey passes on both
simulators with zero failures/skips. The app and new label-test source remain
byte-identical across these epochs; only the existing bookmark test file
changes. Three unique functions therefore pass per simulator across the recorded
runs, rather than an invented all-green initial iPad bundle.

Final Mac app/UI-test compilation passes with zero runtime functions. Ten
affected present Swift files pass strict format lint. All 259
source/configuration hashes remain unchanged through each run, with the single
changed test file recorded between epochs. Core, previews and HTTP source/tests
are byte-identical to dbf511c and are not rerun. Machine-readable evidence
retains attempts, commands, summaries, source hashes and qualification limits.

The eight retained app-owned captures were visually inspected. The phone row and
tablet row show compact secondary text and +1. Phone details and tablet details
show every label after relaunch. Shared rename updates the phone row, tablet
row, phone details and tablet details. This is local simulator evidence;
whole-app polish and Mac runtime are not qualified by these captures.

The shared detail component is wired into contextual forms; a native journey
with nonempty labels in each contextual detail remains open. Itinerary-owned
label editing, associated-label deletion/Settings access, adaptive cumulative
Filters, duration/location decisions, bounded paging, controlled native
failures/SQLite rollback, Mac runtime, physical synchronization/account/Share,
accessibility/keyboard, responsiveness and whole-app polish retain their owning
gates. Schema 13, portable format 1 and localOnly storage are unchanged.

## Adaptive native state and label filters

Baseline 55d8423. Before this slice, Item/Inbox and standalone List toolbars
offered one-step completion/archive menus. DoR is accepted Q54 A, the existing
public Core identity-group queries and the approved native UI seam. DoD for this
slice is one adaptive native Form, cumulative state/Category/Tag criteria,
Any/All matching within a label group, Clear, accurate active summaries, and
full completion progress independent of filtered rows. Duration and other query
criteria retain separate gates.

The toolbar now opens a native grouped Form with system completion/archive
Pickers and the existing Category/Tag selection Lists. Phone compact
presentation adapts to a sheet; larger presentations use a popover. Each label
group offers Any selected or All selected and can be cleared separately. Clear
Filters resets every criterion to unrestricted All. The toolbar summarizes
active criteria and distinguishes All 2 Tags from any two selected Tags.
Item/Inbox and standalone List reads pass the selected identities and match
modes directly to Core; no client-side label join or new persistence fields are
introduced. Full List progress still comes from the complete container read.

The first real UI red reaches the absent Category selector. Its green proves
cumulative Category/Tag narrowing and unchanged local completion/full progress.
Extending the tracer with Any/All exposes the identical two-Tag summary, then
the corrected summary passes. The final tracer additionally checks Item-catalog
filtering, complete labels in a completed List appearance, independent group
clearing and restoring all rows. Existing state-filter journeys keep their
assertions and move through the new Form. Their first migrated attempt reaches
Done but resolves the covered form button instead of the native menu choice.
Excluding that toolbar identity corrects the test selector without changing
production behavior.

Qualification uses three frozen source epochs. The initial five-function run
passes on iPhone. On iPad, Inbox, state filters and itinerary bulk pass, while
label and filtered-drag fixtures stop at Add Item after it moves into the native
toolbar overflow. Both helpers adopt the already proven overflow route; every
behavioral assertion remains. The compatibility epoch changes only these two
native test files, leaving all app, Core, HTTP and preview sources
byte-identical.

The corrected drag function passes on both simulators. The iPad label journey
then reaches an offscreen Match row in its 420-point native popover Form. Its
saved UI hierarchy places that row below the visible boundary; this is not a
missing criterion or a different match result. Scrolling the containing native
Form before querying the picker preserves the test's Any/All assertions. That
final epoch changes only the label journey source.

Five unique real UI functions pass per simulator across these recorded epochs.
The final label journey and corrected drag journey each pass on both devices
with zero failures/skips. All app sources stay byte-identical between epochs.
Mac app/UI-test bundles compile in each epoch and run zero runtime functions.
Nine affected Swift files pass strict format lint. The 259 source/configuration
hashes remain unchanged during each qualification; exact helper differences,
commands, durations, failures and summaries are preserved in machine-readable
evidence. Core, previews and HTTP source/tests are byte-identical to 55d8423 and
are not rerun. Schema 13, portable format 1 and localOnly storage remain
unchanged.

All six retained app-owned captures were visually inspected. The phone Form and
iPad popover show native grouped controls and All selected Tags. The phone List
and iPad List show full progress with one matching row and compact live labels.
Phone details and iPad details show every label in a locally completed
appearance. The iPad detail remains alongside the List. Compact native toolbars
display the filter glyph; its full summary remains accessible, and selected
criteria are visible in the Form. Visible compact-toolbar summaries remain a
polish check.

This qualifies basic native state/label filtering and nonempty standalone List
labels. Duration/list/presence criteria, native Itinerary filters and nonempty
Itinerary label journeys, Itinerary-owned label editing, associated-label
deletion/Settings, bounded paging, controlled native stale/save/recovery
failures, genuine SQLite rollback, Mac runtime/resize/accessibility, physical
synchronization/account/Share, responsiveness and whole-app polish retain their
owning gates. Earlier pending decisions remain unanswered.

## Native address and link filters

Baseline 49a1144. Before this slice, Core supported owned-address and owned-link
criteria, but the native adaptive Form did not expose them. DoR is accepted Q54
A, the qualified public presence query and the approved native UI seam. DoD for
this slice is cumulative native content filtering, independent criterion
clearing, Clear Filters, unchanged source content and appearance
identity/completion, and full List progress after filtering and relaunch.

The grouped Form adds native Has an address and Has links Toggles. With a Toggle
off, that criterion stays unrestricted. An enabled address criterion requires
nonblank owned address text; a map coordinate or location name alone does not
satisfy it. Links means owned bookmarks, including Apple Maps links. Both
criteria narrow together with the existing state and label groups. Shared
Item/Inbox and standalone List reads pass these values directly to Core. They
add no client-side filtering, persisted fields or provider dependency. The real
UI journey exercises the Item catalog and standalone List; an Inbox-specific
content-filter journey is not claimed.

The tracer first fails at the absent address control. Its first iPhone green
passes with four fixtures covering neither criterion, address only, link only
and both. It then checks a locally completed List appearance while only that row
remains visible, clears the criteria, relaunches and verifies retained identity,
full progress, local Done, global Todo, saved address and bookmark. New fixtures
have no owned coordinates, and the journey does not await or assert Apple
preview-service results.

The initial frozen two-function qualification passes on iPhone. On iPad, the new
content journey passes, while the existing label journey stops at its offscreen
Tags selector after selecting a Category. Its actual native hierarchy retains
the Category controls and places later content below the 420-point popover
boundary. Scrolling the containing native Form before opening an offscreen
selection row fixes the helper. Every behavioral assertion remains unchanged;
only that test file changes between source epochs. The later Apple
diagnostic-collection error is recorded separately from the assertion failure.

The corrected label journey passes once on each simulator with zero
failures/skips, retaining Category/Tag Any/All matching, independent group
clearing and full progress with the longer Form. Two unique real UI functions
pass per simulator across the recorded epochs. All app sources remain
byte-identical between them. Mac app/UI-test bundles compile in each epoch and
run zero runtime functions. Five changed Swift files pass strict format lint and
whitespace checks. All 259 source/configuration hashes stay unchanged during
each qualification. Execution evidence retains the functional red, initial
green, failed compatibility attempt, commands, durations, summaries and exact
source-epoch differences. Core, HTTP and preview sources/tests are
byte-identical to the baseline and are not rerun. Schema 13, portable format 1
and localOnly storage remain unchanged.

All six app-owned captures were visually inspected. The phone Form and iPad
popover show both native switches. The phone List and iPad List distinguish full
one-of-four progress from Showing 1 of 4 items. Phone details and iPad details
show the retained address and global Todo after relaunch. The native test
separately verifies the saved bookmark. Compact toolbar summaries remain
accessible; visible compact text retains its polish check.

Duration/List criteria, native Itinerary filtering and nonempty Itinerary
labels, Itinerary-owned label editing, associated-label deletion/Settings,
bounded paging, controlled native stale/save/recovery failures, genuine SQLite
rollback, Mac runtime/resize/accessibility, physical
synchronization/account/Share, responsiveness and whole-app polish keep their
owning gates. Earlier pending decisions remain unanswered.

## Native List membership filters

Context and goal. At baseline c4330c7, Core already supports Any/All List
membership criteria, but native Filters cannot select Lists. This slice adds
that selection to the shared Item/Inbox reader and standalone List reader. It
uses the Q54 adaptive Form and existing public Core query. No schema, command,
provider cache or portable-backup field changes are needed.

Readiness. Q54 A supplies the presentation decision. Existing identity groups
define Any/All matching, including archived List identities. The approved native
UI seam uses a real temporary local dataset. Source identities, contextual
completion and full container progress must survive filtering.

Result. A native In Lists destination reads active and archived Lists, with an
Archived badge and accessibility hint. Native Toggles select stable identities.
Match chooses Any selected or All selected. Clear Lists removes only that group;
Clear Filters resets all criteria. Membership criteria narrow together with
labels, state and saved-content presence. Loading, empty and retry presentations
use native components. Controlled loader failures and archived or duplicate-name
picker journeys remain unqualified here.

The new native journey creates Shared, North only, South only and Unlisted.
North and South reference the same Shared Item. Any selected retains their
union; All selected returns Shared once with its original source identity. Links
remains active after Clear Lists. Clear Filters restores all four Items. In
North, filtering to South membership preserves Shared's appearance identity and
local Done, shows one of two Items, and keeps full progress at one of two. Clear
and relaunch preserve that state. South's separate appearance remains Todo with
zero-of-two progress.

Required /tdd and attempts. The first run fails at the missing native Lists
selector. The initial implementation reaches the final assertion, which
incorrectly expects the accessibility value Not completed; the actual native
value is To do. Only that expectation changes. The first frozen qualification
passes all three functions on iPhone. iPad exposes two helper failures: Lists
starts below the popover viewport, and a full swipe places Tag Match beneath the
native navigation bar. Actual accessibility hierarchies establish those
coordinates. A shared helper now uses small native drags and requires the entire
control to be visible below that bar. The existing Form receives a stable
accessibility identifier. Behavioral matching, identity, completion and progress
assertions remain intact.

Final qualification. Three functions pass on each simulator with zero failures
or skips: membership filters, address/link filters, and cumulative label
filters. Six changed Swift files pass strict format lint. Both Mac
build-for-testing epochs succeed and execute zero runtime functions. Each
qualification holds 259 Swift/project/configuration source hashes fixed. Four
files differ between epochs: the Form identifier and three UI-test files. Core,
preview and HTTP sources/tests remain byte-identical to c4330c7 and are not
rerun. Markdown lint and whitespace checks accompany this commit.

The machine-readable evidence retains red/failed attempts, exact commands and
durations, both source epochs, failed-run diagnostic collection errors and all
capture hashes. Final summaries are iPhone and iPad. The six inspected captures
show the phone Form, phone filtered progress, phone independent completion, iPad
Form, iPad filtered progress and iPad independent completion.

The journey directly exercises the Item catalog and standalone Lists. A separate
Inbox membership interaction, archived/duplicate-name picker UI, controlled
loader failures and provider results are not claimed. Compact toolbars still
show a native glyph with the full accessible summary; visible summary polish
stays open. Duration criteria, native Itinerary filters/labels, associated-label
deletion/Settings, paging/schedules/admin, native failures and SQLite rollback,
Mac runtime, signed synchronization/account/Share and whole-app polish retain
their gates. Schema 13, portable format 1 and localOnly storage stay unchanged.

## Native Itinerary label selection

Context and goal. At baseline feaf7b6, native Itinerary creation/editing handles
title and notes, while Core already owns Category/Tag identity sets and resolves
their live names. This slice adds staged label selection and full Itinerary
label details through those existing commands and reads.

Readiness. Q53/Q55 and the shared-label model establish the native destination
and live identity rules. The approved test seam is the real native UI with a
temporary local dataset. Existing Core commands/read tests remain unchanged. The
end must preserve Cancel, guarded Save, source identity, empty progress and live
shared renames.

Result. The existing native label picker now serves the Itinerary create/edit
Form. Selections start from the source's identity sets, remain local drafts
until Save, and make a label-only edit saveable. The store sends only changed
label sets, including an empty set for clearing, with the pinned source field
hashes. Full details reuse the existing Category/Tag sections. Shared names stay
read metadata; this adds no copied label content, migration or backup field.

Required /tdd. The tracer first fails at the absent Category selector after
38.988 seconds. It then qualifies canceled creation, saved creation with a
Category, disabled unchanged Save, canceled Tag selection, a guarded label-only
Save, live Category/Tag renames, stable source identity and relaunch. Removing
the Tag leaves the Category and No items intact. Existing Item-label and
Itinerary bulk-completion journeys supply focused compatibility checks.

Qualification. Three unique functions pass per simulator with zero failures or
skips in one frozen 259-file source epoch. iPhone runs the new tracer once and
the two compatibility functions separately; iPad runs all three together. Mac
build-for-testing succeeds with zero runtime functions. Three changed Swift
files pass strict format lint. Core, preview and HTTP sources/tests are
byte-identical to feaf7b6 and are not rerun. Markdown lint and whitespace checks
accompany the commit. The red run's later simctl diagnostic-collection failure
remains separate from its functional missing-control failure.

The machine-readable evidence retains exact commands, durations, source hashes
and inspected capture hashes. Summaries are iPhone tracer, iPhone compatibility
and iPad. Six inspected captures show the phone Form, phone saved labels, phone
renamed labels, iPad Form, iPad saved labels and iPad renamed labels.

This tracer qualifies Itinerary-owned labels on an empty route. Nonempty Item
labels in repeated direct/expanded Itinerary rows, native duplicate-name
selection and controlled stale/save/loader failures retain separate gates.
Native Itinerary filters and richer content/schedules, duration criteria,
associated-label deletion/Settings, paging, genuine SQLite rollback, Mac
runtime/resize/accessibility, signed synchronization/account/Share and whole-app
polish remain open. Schema 13, portable format 1 and localOnly storage stay
unchanged.

## Native Settings access for shared labels

Context and goal. At baseline 4da2831, Manage Labels is reachable through the
native library toolbar, while its accepted Q53 Settings entry is absent. This
slice adds that entry and reuses the same management view and saved data. The
approved test seam remains the real native UI with a temporary local dataset.

The Mac app declares SwiftUI's Settings scene, which supplies the standard
app-menu and keyboard entry. Mobile opens a native Settings sheet from Lists.
This follows Apple's
[Settings scene documentation](https://developer.apple.com/documentation/swiftui/settings)
and
[Settings guidance](https://developer.apple.com/design/human-interface-guidelines/settings).
A grouped Form opens the existing Manage Labels destination. Store readiness,
loading, failure and Try Again presentations use native components. Mobile Done
returns to Planner, and its parent alert leaves errors to the active label form
while Settings is open. Settings adds no main tab or persisted preference.

Required /tdd and result. The tracer first fails at the missing mobile Settings
control after 17.094 seconds. The implementation then qualifies opening
Settings, canceled Tag creation, successful creation, return from Manage Labels
to Settings, and a rename through the original toolbar route. Reopening Settings
resolves the same saved Tag identity and new name. Relaunch retains that
identity/name and excludes the canceled draft. The existing standalone Manage
Labels journey retains its staged creation, canceled rename, save and relaunch
assertions.

Qualification. Two unique functions pass per simulator with zero failures or
skips in one frozen 260-file source epoch. iPhone runs the new tracer and
compatibility function separately; iPad runs both together. Mac
build-for-testing succeeds with zero runtime functions. Four changed Swift files
pass strict format lint. Core, preview and HTTP sources/tests remain
byte-identical to 4da2831 and are not rerun. Markdown lint and whitespace checks
accompany the commit. The red run's later simctl diagnostic-collection failure
remains separate from the functional missing-control failure.

The machine-readable evidence retains exact commands, durations, source hashes
and inspected capture hashes. Summaries are iPhone tracer, iPhone compatibility
and iPad. Six inspected captures show phone Settings, phone shared labels, phone
restored labels, iPad Settings, iPad shared labels and iPad restored labels.

The direct Settings journey exercises Tag management. Category management reuses
its existing destination but is not a separate Settings-specific journey here.
Mac menu/shortcut/runtime, multiwindow failure presentation, controlled
opening/save failures, duplicate-name native selection and resize/accessibility
retain separate qualification gates. Associated-label deletion, native Itinerary
filters/richer content/schedules, duration criteria, contextual Item labels,
paging, genuine SQLite rollback, signed synchronization/account/Share and
whole-app polish remain open. Schema 13, portable format 1 and localOnly storage
stay unchanged.

## Native labels in repeated Itinerary appearances

Context and goal. At baseline 293fd0c, production already displays compact live
labels and complete label sections in Itinerary appearances. This slice
qualifies that behavior for one Item referenced twice directly and once through
a List. Readiness is the accepted Q55 presentation, independent per-appearance
completion contract and approved real native UI seam. The intended end preserves
all three appearance identities, live names, local completion and global Todo
after relaunch.

The journey creates a Category and three Tags through Manage Labels, assigns
them to Museum and builds the repeated route through native forms. Every row
exposes the complete names and displays the literal compact overflow. Completing
the first direct appearance leaves the other two Todo and full progress at 1
of 3. Its details show every label. Shared Category/Tag renames then resolve
after relaunch in all rows and the expanded List appearance's complete detail.
Order and appearance identities remain exact; the source Item remains globally
Todo.

Required /tdd and qualification. This is qualification of existing production
behavior, so no missing-feature red is claimed. The initial iPhone attempt fails
because its helper does not return from the selected List to the library before
opening Manage Labels. The next iPhone attempt reaches the final assertion but
queries the global native Toggle as a Button. The first iPad attempt tries to
tap Manage Labels in a hidden sidebar. Only test navigation and element queries
change between these attempts; all production bytes remain fixed. Later simctl
diagnostic-collection errors remain separate from those failures.

The corrected journey passes once on each simulator with zero failures or skips
in one frozen 260-file source epoch. iPhone takes 201.761 seconds and iPad
220.609 seconds. Mac build-for-testing succeeds with zero runtime functions. The
changed Swift test passes strict format lint; Markdown lint and whitespace
checks accompany the commit. App sources and Core, preview and HTTP
sources/tests remain byte-identical to the baseline. Package and HTTP checks are
not rerun.

The machine-readable evidence retains exact attempts, commands, source hashes
and inspected captures. Summaries are iPhone and iPad. Six inspected captures
show phone rows, phone direct details, phone renamed expanded details, iPad
rows, iPad direct details and iPad renamed expanded details.

This closes the nonempty repeated direct/expanded native label journey gate.
Itinerary filtering, entry reorder/removal, richer content/schedules, duration,
associated-label deletion, paging, controlled native failures and SQLite
rollback, Mac runtime/resize/accessibility, signed synchronization/account/Share
and whole-app polish remain open. Schema 13, portable format 1 and localOnly
storage stay unchanged.

## Native Itinerary entry ordering menus

Context and goal. At baseline e58fb4c, native Itineraries display saved route
order and allow entry creation, but cannot change that order. Readiness is the
accepted repeated-reference and per-appearance completion model, Core's existing
guarded entry-reordering command, explicit Manual reads and approved native UI
seam. This slice adds endpoint ordering actions without changing source content,
child completion or List membership order.

Direct Item entries and List headers now offer native Move to Beginning/End
context-menu actions. The current endpoint's action is disabled, and
saving/readiness or pending bulk review preparation disables ordering. List
headers retain their existing reviewed local bulk actions. Every action sends
the selected entry identity through Core; it changes that route occurrence's
position and preserves its expanded children. No schema, provider, backup or
agent API changes are introduced.

Required /tdd. The native tracer first fails at the absent Move to End action
after 71.835 seconds. It then builds two direct Museum entries plus one Food
List appearance, completes the first direct entry, moves that entry to the end
and moves the List to the beginning. Exact appearance identities/order,
independent Done/Todo values, full 1-of-3 progress and the List entry's 0-of-1
progress survive relaunch. The global source remains Todo. The affected
repeated-List bulk journey also retains cancellation, save, relaunch and
scope-isolation assertions.

Qualification. Two unique functions pass per simulator with zero failures or
skips in one frozen 260-file source epoch. iPhone runs the new tracer in 118.024
seconds and the compatibility function in 136.562 seconds. The isolated iPad run
takes 129.485 and 146.969 seconds. Mac build-for-testing succeeds with zero
runtime functions. Three changed Swift files pass strict format lint. Core,
preview and HTTP sources/tests remain byte-identical to the baseline and are not
rerun. Markdown lint and whitespace checks accompany the commit.

The initial iPad run is interrupted after nine repeated XCTest animation-idle
warnings during fixture setup, before the ordering check. It exits 75; its
summary records zero passes and one failure with Testing was canceled. The
isolated retry uses identical source. This does not establish the wait's root
cause or qualify responsiveness. The red run's later simctl
diagnostic-collection failure remains separate from its missing-action
assertion.

The machine-readable evidence retains exact attempts, commands, source hashes
and inspected captures. Summaries are iPhone tracer, iPhone compatibility,
isolated iPad and interrupted iPad. Six inspected captures show the phone menu,
phone group order, phone restored order, iPad menu, iPad group order and iPad
restored order.

This qualifies endpoint ordering menus. Arbitrary-position drag gestures, entry
removal, native Itinerary filters/richer content/schedules, duration,
associated-label deletion, paging, controlled failures and SQLite rollback, Mac
runtime/resize/accessibility/responsiveness, signed
synchronization/account/Share and whole-app polish retain their gates. Schema
13, portable format 1 and localOnly storage stay unchanged.

## Native Itinerary entry drag handles

Context and goal. At baseline d0bb121, direct Item entries and List headers have
endpoint ordering menus, but arbitrary-position dragging is unavailable.
Readiness is the accepted saved route order, repeated-reference and
per-appearance completion model, Core's existing guarded ordering command and
approved native UI seam. This slice adds native drag controls while preserving
identities, content and completion.

Each route entry now forms one SwiftUI List row. A referenced List retains its
native DisclosureGroup, header progress and expanded children inside that row.
Native onMove sends the moved entry's identity and neighboring entry's identity
through the existing Core command. On iPhone/iPad, the system EditButton exposes
drag handles; moving is enabled only while Edit mode is active. Done remains
available if live changes leave fewer than two entries. Readiness, saving and
bulk-review preparation gate moving. Existing context-menu and reviewed
completion actions remain.

Required /tdd. The tracer first fails when dragging leaves route order
unchanged. The final journey creates Museum, Food stops and a Museum/List/Museum
route, completes the first direct occurrence, moves the last occurrence into the
middle, moves the expanded List to the beginning and moves the completed
occurrence to the end. Exact appearance identities/order, independent
completion, full 1-of-3 progress and group 0-of-1 progress survive relaunch; the
global source stays Todo. Compatibility journeys exercise endpoint menus,
repeated-List bulk review/cancel/save/relaunch and expanded-child detail
selection/relaunch.

Qualification. Four unique UI functions pass per simulator with zero failures,
skips or animation-idle warnings. In the journey order above, iPhone durations
are 134.858, 115.341, 134.424, 91.065 seconds and iPad durations are 167.039,
134.279, 145.688, 104.386 seconds. Mac build-for-testing succeeds with zero
runtime functions.. Two changed Swift files pass strict format lint. Core,
preview, HTTP and native Store sources remain byte-identical to the baseline and
are not rerun. The final 260-file source epoch stays unchanged throughout
sequential simulator qualification. Markdown lint and whitespace checks
accompany the commit.

The evidence retains all seven failed attempts, a superseded drag pass and the
stopped compatibility run. The OS 27 reorderable/reorderContainer approach did
not qualify in this app's existing context-menu layout; this is not proof of an
SDK defect. The native List approach initially left moving enabled outside Edit
mode. Its menu journey passed in 356.105 seconds with four 60-second
animation-idle warnings. The exact owned Xcode process was stopped before
completing the bulk function, which is recorded as canceled. Restricting mobile
moving to active Edit mode removes those warnings in the final checked journeys.
This does not qualify general responsiveness, concurrent/stale dragging or
physical-device behavior. Later simctl diagnostic-collection failures remain
separate from functional test failures.

The machine-readable evidence records attempts, exact commands, summaries,
source hashes and six inspected captures. Final summaries are iPhone and iPad.
Captures show the phone middle insertion, phone List-group move, phone restored
order, iPad middle insertion, iPad List-group move and iPad restored order.

This qualifies local mobile entry drag handles and the affected functional
journeys. Entry removal, native Itinerary filters/richer content/schedules,
duration, associated-label deletion, paging, controlled native failures and
SQLite rollback, Mac runtime/resize/accessibility/responsiveness, signed
synchronization/account/Share and whole-app polish retain their gates. Schema
13, portable format 1 and localOnly storage stay unchanged.

## Native Itinerary entry removal

Context and goal. At baseline a6b4902, saved route entries can be added, moved
and completed, but cannot be removed through the native UI. Readiness is the
accepted live-reference model, ordinary re-add starting local Todo, Q8
completion precedence and Core's existing entry-removal command. This slice
removes one selected route entry while preserving its shared source and every
surviving occurrence.

Direct Item rows and referenced List headers expose Remove from Itinerary in
their native context menus. The action uses the shared command and
durable-save/recovery outcome. Removing the entry that owns the current detail
clears that selection and explains where its source remains available. A
different selected entry remains selected. The menu uses the existing readiness,
saving and bulk-review preparation gates.

Required /tdd. The initial iPhone tracer fails because Remove from Itinerary is
absent. Before the final green epoch, it gains an additional selected-detail
assertion. The journey marks the standalone Food stops membership locally Done,
then creates Museum, Food stops, Museum, Food stops in an itinerary. All four
itinerary appearances initially stay Todo. It completes appearances zero, one
and three, removes the first List entry, then removes the first direct entry.
Surviving IDs/order/local flags yield 2-of-3, then 1-of-2 full progress.
Ordinary re-add creates two new Todo appearances without copying source-List
completion. Relaunch retains all four exact IDs and 1-of-4 progress; the global
Item remains Todo and the original standalone membership remains Done with its
original identity. iPad also clears the selected removed appearance's details
with native feedback. The existing ordered-entry detail journey is the
compatibility check.

Qualification. Two unique UI functions pass on each simulator with zero
failures, skips or animation-idle warnings. Removal and compatibility durations
are 164.154 and 91.091 seconds on iPhone, 185.538 and 107.713 seconds on iPad.
All runtime checks use one frozen 260-file source epoch, with sequential
simulator runs. Review then adds a message-only recovery-incomplete warning to
the selected-removal alert. That final reporting branch passes strict formatting
and Mac build-for-testing, but has no controlled native failure UI
qualification. It changes no command, state or normal-success message. Mac
executes zero runtime functions. Three changed Swift files pass strict format
lint. Core, preview and HTTP sources remain byte-identical to the baseline and
are not rerun. Markdown lint and whitespace checks accompany the commit.

The first iPad removal attempt reaches removal, selected-detail clearing,
re-addition and relaunch, then fails while looking for the standalone List
catalog before invoking the existing sidebar/navigation helper. Its failure and
captured navigation state are retained. The accompanying compatibility function
records animation-idle waits; the cause remains unestablished. These timings do
not qualify responsiveness.

The machine-readable evidence records the real red, initial iPhone passes,
failed/canceled iPad attempt, corrected runtime source hashes, reporting-only
follow-up, exact commands, summaries and inspected captures. Final runtime
summaries are iPhone and iPad. Captures show phone retained occurrences, phone
re-added entries, phone relaunch, iPad retained occurrences, iPad re-added
entries, iPad relaunch and the failed hidden-sidebar assertion.

This qualifies local entry removal and the stated functional journeys. External
removal/deletion selection invalidation, native Undo, Itinerary filters/richer
content/schedules, duration, associated-label deletion, paging, controlled
native failures and SQLite rollback, Mac
runtime/resize/accessibility/responsiveness, signed
synchronization/account/Share and whole-app polish retain their gates. Schema
13, portable format 1 and localOnly storage stay unchanged.

## Native start-only Item scheduling

Context and goal. At baseline dd93a73, Core and HTTP support direct schedules,
but the saved native Item detail has no scheduling action. Readiness is the
accepted fixed-instant/planning-zone model, valid optional end, separation from
activity estimates, existing durable Core command and approved native UI seam.
This slice adds a cancelable native start-only draft and reads saved direct
schedules in Item details. The intended end preserves schedule identity,
displayed date/zone, Item notes and global Todo after relaunch.

Schedule Item opens a native grouped Form with DatePicker, the captured initial
device timezone and system Cancel/Save actions. The picker uses that planning
timezone. Save creates an independent direct Schedule with no end through the
existing durable command and recovery path. Estimates never supply an end. The
detail reads complete Schedule records, shows native loading/retry controls when
needed, and formats dates with Foundation in the saved planning timezone. It
adds no section for an unscheduled Item. No Calendar permission, EventKit
export, new dependency, schema or agent API is introduced. Apple's
[DatePicker](https://developer.apple.com/documentation/swiftui/datepicker) and
[timeZone environment](https://developer.apple.com/documentation/swiftui/environmentvalues/timezone)
are the native input boundary.

Required /tdd. The initial attempt fails during setup because its global
completion Toggle query targets buttons on iOS. The inspected failure capture
shows the saved Item and unchanged notes. Correcting that query produces a valid
red at the absent Schedule Item action after 23.017 seconds, before production
scheduling changes. The new journey then cancels a draft, observes zero
schedules, saves one start-only assignment and checks one saved identity/date
description after relaunch. Item notes and global Todo remain unchanged. The
affected existing global completion journey also runs. Later simctl
diagnostic-collection errors remain separate from the setup and missing-action
assertions.

Qualification. Two unique functions pass on each simulator with zero failures,
skips or animation-idle warnings. Tracer and compatibility durations are 46.720
and 41.775 seconds on iPhone, 48.352 and 42.466 seconds on iPad. Mac
build-for-testing succeeds with zero runtime functions. Four changed Swift files
pass strict format lint. Core, preview and HTTP sources/tests remain
byte-identical to dd93a73 and are not rerun. The frozen 261-file source epoch
stays unchanged throughout sequential simulator qualification. Markdown lint and
whitespace checks accompany the commit.

The machine-readable evidence records exact commands, source hashes, attempts
and inspected captures. Summaries are iPhone, iPad, setup failure and valid red.
Captures show phone saved schedule, phone relaunch, iPad saved schedule, iPad
relaunch and the initial Toggle-query failure.

This first native schedule journey saves the default picker value. It does not
qualify changing date/time values, explicit timezone selection, supplied ends,
all-day creation, editing/removal, Itinerary schedules or calendar navigation.
Reading pre-existing end/all-day forms compiles but those render branches have
no native runtime qualification here. Controlled native read/save failures,
rollback, external changes and physical sync/account/Share remain open, as do
Mac runtime and whole-app polish. Schema 13, portable format 1 and localOnly
storage stay unchanged.

## Native optional Item schedule end

Context and goal. At baseline f30c7c3, native Item scheduling supports
start-only appointments. Readiness is accepted Q6, the existing timed Schedule
form and durable command, and the approved native UI seam. This slice exposes an
optional end without changing completion, notes, estimates or Schedule identity
after relaunch.

A native Include end time Toggle reveals an End DatePicker. Both endpoints use
the captured planning timezone. New drafts default to start-only; the inactive
end picker initially holds one hour after the initial start. Only explicitly
enabling the Toggle supplies an end, and no activity estimate participates.
Clearing the Toggle saves no end. Equal/earlier end instants disable Save and
show End must be later than Start. Core retains its own validation at the
durable command boundary.

Required /tdd. The tracer first fails at the absent Include end time control
after 22.580 seconds. It then enables, clears and re-enables the end picker,
cancels without creating a Timed schedule, opens a fresh start-only draft,
enables its end and saves. One Timed schedule's exact identity and formatted
date interval survive relaunch; global completion remains Todo. The prior
start-only cancellation/save/relaunch journey is the affected compatibility
check. The red run's later simctl diagnostic-collection error remains separate
from the missing-control failure.

Qualification. Two unique functions pass per simulator with zero failures, skips
or animation-idle warnings. Optional-end and start-only durations are 53.757 and
46.675 seconds on iPhone, 52.908 and 50.523 seconds on iPad. Mac
build-for-testing succeeds with zero runtime functions. Three changed Swift
files pass strict format lint. The frozen 261-file source epoch stays unchanged
through sequential simulator qualification. Core, previews and HTTP remain
byte-identical to f30c7c3 and are not rerun. Markdown lint and whitespace checks
accompany the commit.

The machine-readable evidence retains exact commands, source hashes, results and
inspected captures. Summaries are iPhone, iPad and valid red. Captures show
phone saved interval, phone relaunch, iPad saved interval and iPad relaunch.

This journey uses the initial valid endpoint values. Changing picker values, the
native invalid-end explanation, DST missing/repeated-time resolution and
earlier/later occurrence controls remain unqualified. All-day creation, explicit
planning-zone selection, editing/removal, Itinerary schedules/calendar,
controlled native read/save failures, rollback, external changes, Mac runtime
and physical sync/account/Share retain their gates. Whole-app polish follows
feature completion. Schema 13, portable format 1 and localOnly storage stay
unchanged.

## Native confirmed Item schedule removal

Context and goal. At baseline 3347efb, native Item scheduling can create
start-only and timed assignments, but cannot remove them. Readiness is the
accepted confirmed removal with no Trash, preserved source/other records,
existing Core removeSchedule command and approved native UI seam. The intended
end removes only the chosen appointment, preserves another exact schedule
identity after relaunch, and retains the Item after its last schedule is
removed.

Each direct Schedule summary now has a native Remove Schedule context-menu
action. A system confirmation dialog states that one schedule will be removed
and the Item/other schedules stay available. Cancel changes nothing. Confirm
sends the chosen Schedule identity and an operation identity through the
existing durable command/recovery path. The Item details refresh through their
normal live read. Readiness and saving disable removal; the existing Planner
alert presents command/recovery failures. This adds no Trash, schema, provider
or agent API.

Required /tdd. The native tracer first fails at the missing Remove Schedule
action after 36.346 seconds, with two appointments already saved. Before green,
removal assertions adopt XCTest's waitForNonExistence to observe asynchronous
save/read completion. The journey cancels removal, checks both records remain,
confirms removal of the Timed entry and checks the start-only identity remains.
Relaunch preserves it. Removing the last appointment and relaunching preserves
the Item's notes and global Todo with zero schedules. The optional-end
cancellation/save/relaunch journey is the affected compatibility check. The red
run's later simctl diagnostic-collection error remains separate from the
missing-action assertion.

The first green attempt reaches the native confirmation and records its impact
message, but the cancellation test fails because it assumes a visible Cancel
button. The inspected iPhone capture shows a native popover with only Remove
Schedule. Optional-end compatibility passes in 54.053 seconds. The corrected
test dismisses the popover by tapping outside on the Item title and waits for
confirmation to disappear before checking both records remain. Production bytes
stay fixed between attempts. Apple's
[confirmationDialog documentation](<https://developer.apple.com/documentation/swiftui/view/confirmationdialog(_:ispresented:titlevisibility:presenting:actions:message:)>)
defines the adaptive native presentation; this observed layout is not an SDK
defect claim.

The second attempt verifies outside-tap cancellation and both retained records,
then fails because the confirmation query assumes one matching accessibility
element. Its sparse hierarchy shows one Popover/Sheet containing nested Button
elements with the same identifier. The final test selects the first native
Button for that identifier; no production container or dialog changes. The
second optional-end compatibility run passes in 53.889 seconds. Both failed
attempts remain recorded and do not qualify removal.

A third iPhone run passes its assertions, but capture review exposes a product
error. After successful removal, a read of the old reference sets a global
missing-Schedule alert before the owning view can discard the stale result. Its
74.252-second removal and 53.768-second compatibility passes are superseded and
do not qualify the final product. The exact owned iPad Xcode process is
interrupted with SIGINT; exit 75 records one removal assertion pass and one
canceled compatibility failure. No product qualification is claimed for that
epoch. A strengthened native assertion then fails at the erroneous Planner alert
after 44.468 seconds, before the read repair.

The repaired schedule reader returns Core's typed read result without changing
global alert state. The owning section retains current failures for local retry
after cancellation/revision checks. Durable command errors still use the normal
Planner alert. An initial repair fails compilation on both targets because it
constructs PlannerFailure through an internal initializer; no runtime functions
execute. The final repair uses the existing public read result, with no Core API
change. Final removal assertions require no Planner alert after removing one and
the last appointment; capture review verifies those outcomes. This closes the
reproduced stale-read alert bug, without claiming broad controlled-failure or
external-change qualification.

Qualification. Two unique functions pass per simulator with zero failures, skips
or animation-idle warnings. Removal and optional-end compatibility durations are
78.432 and 53.750 seconds on iPhone, 82.066 and 54.103 seconds on iPad. Mac
build-for-testing succeeds with zero runtime functions. Four changed Swift files
pass strict format lint. The frozen 261-file source epoch stays unchanged
through sequential simulator qualification. Core, previews and HTTP stay
byte-identical to 3347efb and are not rerun. Markdown lint and whitespace checks
accompany the commit.

The machine-readable evidence retains exact commands, source hashes, attempts
and inspected captures. Final summaries are iPhone and iPad. It also retains
initial red, missing-Cancel query failure, nested-Button query failure,
superseded assertions-only pass, interrupted iPad and stale-alert regression
red. Captures show phone confirmation, phone retained appointment, phone
unscheduled Item, iPad confirmation, iPad retained appointment, iPad unscheduled
Item, first query failure and the pre-fix false alert.

This qualifies only locally initiated direct Schedule removal after successful
save. Native Undo, external deletion during confirmation, command/save/recovery
failure presentation and SQLite rollback retain their gates. Date
editing/invalid ends/DST, all-day creation, planning-zone selection, Schedule
editing, Itinerary schedules/calendar, Mac runtime, signed physical
sync/account/Share and whole-app polish stay open. Schema 13, portable format 1
and localOnly storage stay unchanged.

## Native Item row schedule previews

Context and goal. At baseline 652ba0f, native Item details can create and remove
direct appointments, but the Item rows omit their dates. Readiness is the
accepted compact Reminders-style row preview, Core's existing selected
Schedule/additional-count contract, generation-bound display timezone and
approved native UI seam. The intended end shows a compact date caption, explains
additional appointments through accessibility and preserves the row's identity
and metadata after relaunch.

A native calendar Label now shows the selected direct appointment below the Item
title, with +N for other saved schedules. Accessibility states Scheduled and
spells out the additional-schedule count. The native Item, List and Itinerary
adapters retain the row window's presentation context; the shared renderer
formats timed appointments in its captured display timezone. Core continues to
select the appointment. All-day formatting uses Gregorian civil dates without
saving a timezone or midnight instant. This adds no persistence, agent API,
dependency or provider cache.

Required /tdd. The new native journey first fails after 38.631 seconds because
Scheduled metadata is absent after a successful save and return to the Item
catalog. Production changes follow that completed red. The journey checks no
date on an unscheduled Item, one start-only preview, a selected timed preview
with one additional appointment, unchanged row identity and identical metadata
after relaunch. The confirmed schedule-removal journey checks the affected
save/read compatibility. The red run's later simctl diagnostic-collection error
remains separate from the missing-preview assertion.

Qualification. Two unique functions pass per simulator with zero failures, skips
or animation-idle warnings. Preview and removal durations are 54.557 and 78.468
seconds on iPhone, 56.140 and 80.409 seconds on iPad. Mac build-for-testing
succeeds with zero runtime functions. Six changed Swift files pass strict format
lint. The frozen 261-file source epoch stays unchanged through sequential
simulator qualification. Core, previews and HTTP remain byte-identical to
652ba0f and are not rerun. Six exported captures were individually inspected,
showing readable date captions and additional counts. Markdown lint and
whitespace checks accompany the commit.

The machine-readable evidence retains exact commands, source hashes, results and
inspected captures. Summaries are iPhone, iPad and valid red. Captures show
phone start-only caption, phone additional appointment, phone relaunch, iPad
start-only caption, iPad additional appointment and iPad relaunch.

Only direct Item catalog previews receive runtime qualification here. The shared
List/Itinerary renderers and all-day formatting compile but retain native
runtime gates. Existing Core winner tests stay unchanged; the UI journey does
not cover every ongoing/future/past boundary or UUID tie. Travel, display-zone
overrides and locale transitions also remain open. Edited dates/invalid
ends/DST, all-day creation, planning-zone selection, Schedule editing, Itinerary
schedules/calendar, controlled failures/rollback, Mac runtime, physical
sync/account/Share and whole-app polish retain their gates. Schema 13, portable
format 1 and localOnly storage stay unchanged.

## Native all-day Item scheduling

Context and goal. At baseline 3149725, native scheduling creates
start-only/timed appointments and rows show their selected date, but the draft
cannot create an all-day Schedule. Readiness is accepted inclusive civil dates,
separation from timed appointments and activity estimates, Core's existing
all-day durable/recovery command and the approved native UI seam. The intended
end adds a cancelable date-only draft and preserves one same-day inclusive
Schedule's identity, civil-date description and row metadata after relaunch.

A native All day Toggle changes Start/End to date-only DatePickers and hides the
planning-zone row. Include end date supplies an inclusive end; its footer
explains that both dates are included. Without an end, the form covers the
selected day. Turning All day on resets only the draft's end picker to the start
date. The draft uses a captured timezone and Gregorian calendar to extract civil
date components, then saves only those dates through Core. No timezone or
midnight instant enters the all-day record. An earlier end date disables Save;
an equal date is valid. Timed validation still requires a supplied end strictly
after its start. Native alerts, saving controls and durable recovery remain
shared with existing scheduling.

Required /tdd. The initial test attempt fails compilation because its
schedule-row query was omitted; zero runtime functions execute. Correcting the
query produces a valid behavioral red after 23.273 seconds at the absent All day
control, before production changes. The final journey opens an all-day draft,
enables its end date and cancels without saving, then opens a fresh
timed-default draft, switches to all-day and saves with Start/End on the same
initial date. One All day row has a nonempty date-only description. Its exact
identity/description and the Item-row metadata remain after relaunch. The
existing timed optional-end cancellation/save/relaunch journey is the affected
compatibility check. The behavioral red's later simctl diagnostic-collection
error remains separate from the missing-control assertion.

Qualification. Two unique functions pass per simulator with zero failures, skips
or animation-idle warnings. All-day and timed compatibility durations are 59.733
and 53.591 seconds on iPhone, 60.894 and 53.654 seconds on iPad. Mac
build-for-testing succeeds with zero runtime functions. Three changed Swift
files pass strict format lint. The frozen 261-file source epoch stays unchanged
through sequential simulator qualification. Core, previews and HTTP remain
byte-identical to 3149725 and are not rerun. Six exported captures were
individually inspected, including the date-only draft, saved detail and iPad All
day row caption. Markdown lint and whitespace checks accompany the commit.

The machine-readable evidence retains exact commands, source hashes, failures
and inspected captures. Summaries are iPhone, iPad, test compilation and valid
behavioral red. Captures show phone date-only draft, phone saved date, phone
relaunch, iPad date-only draft, iPad saved date and iPad relaunch.

The native all-day journey uses the initial date with an explicit inclusive
same-day end. Edited multi-day ranges and native invalid-end feedback retain
their gates. Existing Core tests already cover literal multi-day civil dates,
invalid dates, independent recovery and travel; they stay byte-identical and are
not rerun here. Native travel/locale transitions, display-zone overrides,
contextual date previews, timed date edits/invalid ends/DST, explicit
planning-zone selection, Schedule editing, Itinerary schedules/calendar,
controlled failures/rollback, Mac runtime, physical sync/account/Share and
whole-app polish stay open. Schema 13, portable format 1 and localOnly storage
remain unchanged.

## Native edited all-day ranges

Context and goal. At baseline 54677e7, native all-day creation and same-day
persistence are qualified, while date edits and invalid-end feedback remain
open. Readiness is accepted inclusive civil-date ranges and earlier-end
rejection, existing production validation and the approved native UI seam. This
slice changes tests and evidence only. The intended end qualifies actual
calendar-picker edits, blocked save for an earlier end and one retained
multi-day Schedule after relaunch.

Required /tdd. The native journey selects Start day 9, End day 8, then End day
11 in the initially displayed month. It requires the earlier-end message,
disabled Save and zero saved Schedules before correction. The valid range
requires inclusive-date guidance, enabled Save and one All day record showing
both selected days. Relaunch preserves its exact identity and description. These
runs select Friday 9 through Sunday 11 October 2026. The test uses the native
calendar controls rather than writing Planner data through another interface.

The first iPhone attempt opens the calendar but fails after 33.909 seconds
because its Button query assumes the numeral is the full accessibility label.
The inspected hierarchy shows full spoken-date Button labels containing numeric
StaticText; selecting that Button by its child corrects the test. The next
iPhone journey passes in 61.404 seconds. On iPad, the journey observes
earlier-end validation but fails after 47.870 seconds when the Item-title tap
leaves the calendar popover open, hiding the compact date button on its next
read. The inspected iPad hierarchy retains the selected day 8 and the validation
message. A second helper taps the native dismissal region near the screen edge
and waits for disappearance. Its iPhone run passes in 71.462 seconds, but iPad
fails after 40.660 seconds because the outside tap also dismisses the scheduling
form. An inspected recording frame shows the source Item retained with no saved
schedule. The final helper taps empty toolbar space inside the scheduling
presentation, waits for the calendar dismissal region to disappear and checks
that the form's Cancel control stays present. No production change follows these
query failures; no missing-product behavior red is claimed. Later simctl
collection errors remain separate from the actual query assertions.

Qualification. One unique function passes per simulator with zero failures,
skips or animation-idle warnings: 69.677 seconds on iPhone and 71.156 seconds on
iPad. Mac build-for-testing succeeds with zero runtime functions. The changed
Swift test file passes strict format lint. All 261 source/configuration hashes
remain unchanged throughout the sequential final simulator runs. Production,
Core, preview and HTTP sources/tests stay byte-identical to 54677e7; unchanged
tests are not rerun. Eight final captures and the earlier dismissed-form frame
were individually inspected. The iPad catalog and detail show Oct 9–11, 2026.
Markdown lint and whitespace checks accompany the commit.

The machine-readable evidence retains exact commands, final and earlier source
epochs, query failures and inspected captures. Summaries are final iPhone, final
iPad, first phone query failure, earlier phone pass, iPad dismissal-query
failure, outside-tap phone pass and outside-tap iPad failure. Inspected
accessibility records are phone calendar labels and iPad open calendar. The
inspected outside-tap recording frame shows the dismissed form. Final captures
show phone invalid end, phone valid range, phone saved range, phone relaunch,
iPad invalid end, iPad valid range, iPad saved range and iPad relaunch.

This qualifies all-day date edits within one displayed month and the native
earlier-end message/disabled save. Month/year navigation, cross-month ranges,
travel, locale transitions and display-zone overrides retain their gates. Timed
date/time edits and timed invalid-end feedback, DST choices, planning-zone
selection, Schedule editing, Itinerary schedules/calendar, controlled
failures/rollback, Mac runtime, physical sync/account/Share and whole-app polish
stay open. Schema 13, portable format 1 and localOnly storage remain unchanged.

## Native Item Schedule editing

Context and goal. At baseline 2d51e2d, native Item details create and remove
schedules, but cannot edit an existing assignment. Readiness is the accepted
optional-end model, Core's guarded whole-form replacement command and the
approved native UI seam. The intended end lets a user cancel a changed draft or
clear a saved timed end without replacing the Schedule identity, duplicating the
assignment or changing Item content/completion.

Edit Schedule opens the shared native Form from the saved schedule's context
menu. Timed drafts start from the stored instants, optional end and planning
timezone. Save passes the captured form hash to Core's existing edit command,
retaining ordinary save/recovery handling. Cancel submits nothing. All-day draft
initialization uses Gregorian civil dates at noon GMT for the picker, with no
timezone added to the saved all-day form. If Foundation cannot represent a saved
civil date, Save stays disabled and the form explains the problem. This adds no
schema, agent API, dependency or provider cache.

Required /tdd. The new native journey first saves a timed appointment, observes
one assignment and then fails after 31.166 seconds at the missing Edit Schedule
action. Production changes follow that completed red. The journey checks that
the existing end initializes enabled, cancellation preserves the exact original
description and identity, clearing the end saves one Start only record under
that identity, and relaunch preserves its edited description, Item notes and
global Todo. The affected all-day creation/cancellation/relaunch journey checks
compatibility. The red's later simctl diagnostic-collection error remains
separate from the missing-action assertion.

The first implementation fails the edit journey after 33.960 seconds while
all-day compatibility passes in 61.524 seconds. The inspected recording frame
shows an edit sheet limited to the bottom of the screen, with the end control
unavailable. The sheet had been attached inside the Schedule Form section. The
corrected implementation lets the parent Item detail own the shared create/edit
presentation. The test stays unchanged, and both runtime journeys are rerun
against the corrected source epoch. The earlier Mac compile and simulator
attempt qualify only their earlier bytes. Later diagnostic collection errors
remain separate from this presentation failure.

Qualification. Two unique functions pass per simulator with zero failures, skips
or animation-idle warnings. Edit and all-day compatibility durations are 57.536
and 60.045 seconds on iPhone, 59.393 and 62.028 seconds on iPad. Mac
build-for-testing succeeds with zero runtime functions. Four changed Swift files
pass strict format lint. All 261 source/configuration hashes remain unchanged
through sequential final simulator qualification. Core, preview and HTTP
sources/tests stay byte-identical to 2d51e2d and are not rerun. Eight final
captures and the earlier clipped-sheet frame were individually inspected.
Markdown lint and whitespace checks accompany the commit.

The machine-readable evidence records the completed red, earlier presentation
failure, exact commands, both source epochs and inspected captures. Summaries
are iPhone, iPad, missing-action red and earlier presentation failure. Captures
show phone edit draft, phone saved edit, phone relaunch, phone all-day
compatibility, iPad edit draft, iPad saved edit, iPad relaunch, iPad all-day
compatibility and the earlier clipped edit sheet.

This slice qualifies clearing a saved timed end through native editing. Changing
timed picker values, adding an end to a saved start-only entry, native all-day
edit initialization, form-kind conversions, stale edits and external removal
during a draft retain their native runtime gates. Core's existing guarded-edit,
validation and recovery tests remain unchanged. Cross-month ranges,
travel/locale/display-zone transitions, DST choices, explicit planning-zone
selection, Itinerary schedules/calendar, controlled failures/rollback, Mac
runtime, physical sync/account/Share and whole-app polish stay open. Schema 13,
portable format 1 and localOnly storage remain unchanged.

## Native all-day Schedule editing

Context and goal. At baseline 1f6e9c3, the shared native edit Form initializes
all-day drafts from Gregorian civil dates, but that branch has no native runtime
qualification. Readiness is the accepted inclusive-date model, qualified
parent-owned edit presentation and approved native UI seam. This slice changes
tests and evidence only. The intended end verifies the saved civil range in an
edit draft, cancellation without changes, and a changed end under the same
Schedule identity after relaunch.

Required /tdd qualification. The native journey creates one all-day range using
calendar days 9–11 of the initially displayed month. Opening Edit Schedule must
retain All day and Include end date, and show the same Start/End button labels
used to create it. Changing End to day 12 and canceling preserves the original
saved description and identity. Reopening must show the original draft values
again; changing End to 12 and saving produces one All day assignment with the
same identity and a changed description containing days 9 and 12. Relaunch must
retain that exact edited description. This qualifies existing production
behavior; it claims no missing-feature red and uses no alternate data interface.

Qualification. One unique function passes per simulator with zero failures,
skips or animation-idle warnings: 96.241 seconds on iPhone and 104.558 seconds
on iPad. The selected ranges are October 9–11 and October 9–12, 2026. Mac
build-for-testing succeeds with zero runtime functions. The changed Swift test
file passes strict format lint. All 261 source/configuration hashes remain
unchanged through sequential simulator qualification. Production, Core, preview
and HTTP sources/tests stay byte-identical to 1f6e9c3; unchanged tests are not
rerun. Eight captures were individually inspected, including the original draft
values, edited end and retained inclusive dates. Markdown lint and whitespace
checks accompany the commit.

The machine-readable evidence records exact commands, frozen source hashes and
inspected captures. Summaries are iPhone and iPad. Captures show phone loaded
draft, phone changed end, phone saved range, phone relaunch, iPad loaded draft,
iPad changed end, iPad saved range and iPad relaunch.

The journey selects days in one displayed month, without month/year navigation.
It qualifies an existing range with an explicit end; absent-end all-day
initialization, form-kind conversions, native stale edits/external removal and
unrepresentable civil-date failure presentation retain gates. Cross-month
ranges, travel, locale transitions, display-zone overrides, timed picker
edits/invalid ends/DST, planning-zone selection, Itinerary schedules/calendar,
controlled failures/rollback, Mac runtime, physical sync/account/Share and
whole-app polish stay open. Schema 13, portable format 1 and localOnly storage
remain unchanged.

## Native Itinerary scheduling

Context: saved Itineraries had no Schedule action; their actions menu was
disabled when empty. The first native tracer reproduces that disabled menu. The
initial shared-form implementation then reached Core's Item-only rejection,
preserved in the inspected failure capture.
[The qualified Core prerequisite](core-local-qualification.md#itinerary-owned-schedules-and-schema-14-migration)
implements durable Itinerary ownership before this UI slice.

DoR is the accepted Itinerary scheduling model, public Core/native UI/HTTP test
seams and qualified native Item Schedule forms. Itineraries now use the shared
native Schedule section and form, with their own source reference and Schedule
row identities. The menu permits scheduling an empty Itinerary while keeping
empty bulk actions disabled. Item callers keep their existing behavior. The
parent owns presentation and suppresses background alerts while its form
presents a save failure.

The native journey creates an empty Itinerary with notes, cancels one start-only
draft without saving, then saves one appointment with its own retained identity
and description. Relaunch preserves that row, notes and No items progress. The
Item-edit compatibility journey verifies cancel/end clearing under the same
Schedule identity. The menu-specific bulk journey verifies confirmed
full-context completion, archived children and relaunch without changing
Item-global or standalone List completion.

DoD passes all three journeys on each simulator with zero
failures/skips/animation-idle warnings. Phone durations are 52.272 seconds for
Itinerary scheduling, 58.955 for Item editing and 208.940 for bulk scope. iPad
durations are 66.047, 62.222 and 222.938 respectively. Mac app/UI-test
compilation passes with zero runtime functions. Five affected Swift files pass
strict lint; changed Markdown and whitespace checks pass. The evidence record
retains separate failed attempts, actual summaries, 265 frozen sources and four
individually inspected final captures, plus the earlier Core-rejection capture.
Core/HTTP/preview code is byte-identical to `bfce18d`; its prior qualification
is reused, not rerun. Schema 14/portable 1/localOnly remain unchanged in this UI
slice.

The new journey uses the default native timed picker value without an end.
Itinerary-native editing/removal/all-day journeys, explicit timed picker
edits/invalid ends/DST/planning-zone selection, inherited schedule
summaries/filters, calendar, cumulative Itinerary filters/duration,
associated-label deletion, paging/admin, controlled failures/rollback/external
invalidation, Mac UI runtime, signed physical sync/account/Share and whole-app
polish retain their gates. Captures preserve phone toolbar title crowding for
later polish. Calendar export remains outside the map.

## Native Itinerary Schedule conversion and removal

Context and goal. At baseline `6417545`, saved Itineraries already use the
shared native Schedule controls. Creation/cancellation/relaunch is qualified,
but Itinerary editing, all-day conversion and removal lack native runtime
evidence. DoR is the accepted Schedule ownership, optional-end/all-day model,
qualified Core commands and the approved native UI seam. This slice changes
tests and evidence only. The intended end verifies canceled drafts/removal,
conversion under the same Schedule identity and confirmed removal without losing
the Itinerary or its other assignment.

Required /tdd qualification. The journey creates an empty Itinerary with notes
and two appointments: Start only and Timed. It cancels a timed-to-all-day draft
and requires the original Timed description/identity. Saving the conversion
retains that identity, changes the description and leaves exactly two Schedules.
Reopening the saved all-day form retains All day and Include end date. Relaunch
must preserve both assignments. Removal explains that one Schedule is affected;
outside dismissal preserves both records. Confirmed removal leaves one Start
only appointment, the same notes and No items progress. A second relaunch
retains that exact surviving Schedule and keeps the removed one absent. Every
operation uses actual native controls and a real temporary dataset.

Two test-targeting failures remain recorded. The first reaches the removal scope
after conversion/relaunch, then tries a Cancel button absent from the native
confirmation popover. The second proves outside dismissal but finds two
accessibility elements for the confirmation button. The corrected test uses the
outside title and first matching confirmation, following the existing Item
journey. Production code remains unchanged, and neither failed attempt is
presented as a missing-feature red. Their later simctl diagnostic-collection
errors remain separate.

DoD passes one lifecycle journey per simulator: iPhone in 115.369 seconds and
iPad in 121.317, with zero failures/skips/animation-idle warnings. Mac
app/UI-test compilation passes with zero runtime functions. Strict lint on the
affected Swift file, Markdown lint and whitespace checks pass. The evidence
record retains actual summaries, both failed attempts, 265 frozen
source/configuration files, eight individually inspected final captures and
three inspected earlier captures. App/Core/HTTP/preview production remains
byte-identical to `6417545`; prior qualification is reused, not rerun. Schema
14, portable format 1 and localOnly remain unchanged.

This qualifies the default timed picker values and their all-day conversion,
plus native single-assignment removal. Explicit time/day picker edits,
month/year navigation, planning-zone selection, travel, DST and native invalid
timed ends retain their gates. Inherited scheduling summaries/filters, calendar,
cumulative Itinerary filters/duration, associated-label deletion, paging/admin,
controlled failures/rollback/external invalidation, Mac UI runtime, physical
sync/account/Share and whole-app polish remain open. Captures retain title
truncation for later polish. Calendar export remains outside the map.

## Native contextual Schedule row summaries

Context and goal. At baseline `77e14cd`, Item rows show direct appointments
only. An itinerary's scheduled span and planning inherited through live
references have no row preview. DoR is the accepted contextual summary contract,
qualified Schedule ownership and the approved public Core/native UI/HTTP seams.
The intended end shows the current itinerary's actual date in its child rows,
while the Item catalog can indicate inherited planning without fabricating an
Item appointment.

Required /tdd qualification. The native journey creates Hotel with notes, adds
it to Weekend route and verifies both rows initially have no Schedule metadata.
It saves a default same-day all-day itinerary assignment through the actual
native Form. The route row shows Plan and All day, preserves its appearance
identity and keeps progress at 0 of 1 item done. The global Item row shows In
scheduled plan without an all-day date. Relaunch preserves both exact summaries
and identities. Existing direct all-day creation/relaunch runs alongside it. The
shared Core tracer separately qualifies live-List reachability,
current-Itinerary ownership, ongoing/next/past selection, independent
estimates/completion/archive and removal of the final reachable path.

DoD passes two UI functions per simulator with zero failures, skips or
animation-idle warnings. The new row journey takes 73.788 seconds on iPhone and
81.184 on iPad; direct all-day compatibility takes 61.315 and 62.234
respectively. Twelve focused iPhone Core functions and nine actual Mac HTTP
functions also pass. Mac app/UI-test compilation succeeds with zero runtime
functions. Strict lint on seven Swift files and four Markdown files, plus
whitespace checks, passes. The evidence record retains actual summaries, 266
frozen source/configuration files and eight individually inspected final
captures. The Item catalog's pre/post relaunch phone captures have identical
pixels, with separate actual capture timestamps. Source schema 14, portable
format 1 and localOnly storage remain unchanged.

The first native attempt passes direct compatibility, then fails because its new
assertion expects plural progress for one Item. The test wording is corrected to
match the existing singular label. The last frame of that attempt's recording
was inspected, but precedes the failure and is not claimed as a synchronized
failure screenshot. The later simctl diagnostic-collection error is separate.
Core's initial compile/test assertion errors and corrected red/green attempts
remain in the shared record.

The native journey qualifies one default same-day all-day itinerary span and
global inherited planning. Itinerary +N, live-List row visuals, timed spans,
travel/display-zone changes and typed unresolved summaries retain separate
gates. Scheduled/unscheduled filtering, calendar, cumulative Itinerary
filters/duration, associated-label deletion, paging/admin, controlled native
failures, Mac UI runtime, signed physical sync/account/Share and whole-app
polish remain open. Captures preserve title crowding for later polish. Calendar
export remains outside the map.

## Native scheduling filters

Context and goal. At baseline `12337a5`, Core and HTTP support
Scheduled/Unscheduled/All, but native Filters cannot select that criterion. DoR
is the accepted cumulative Filters Form, any-retained-assignment rule and
qualified shared query layer. The intended end uses native Picker selection in
Items, Inbox and standalone Lists, with cumulative summaries and full progress
independent of visible rows.

Required /tdd qualification. The actual native tracer first reaches Filters and
fails because Scheduling is absent. The unchanged tracer then selects
Scheduled/Unscheduled/All in Items, independently selects Scheduled/Unscheduled
in Inbox, and creates a List with two children. Hotel inherits planning from an
Itinerary and is locally completed in the List; Plain is unplanned. Scheduled
plus Todo produces no matching rows while retaining one of two completion and
Showing 0 of 2 items. Clear restores all rows and the local flag. Unscheduled
shows Plain while full progress stays one of two. Relaunch preserves the exact
Hotel membership/completion and permits Scheduled selection again. The existing
contextual Schedule-row journey checks compatibility.

DoD passes two UI functions on each simulator with zero failures, skips or
animation-idle warnings. The new filter journey takes 206.078 seconds on iPhone
and 224.993 on iPad; row-preview compatibility takes 72.651 and 83.854
respectively. Mac app/UI-test compilation succeeds with zero runtime functions.
Strict lint passes on five Swift files and two Markdown files, with whitespace
checks. The evidence record retains actual summaries, 268 frozen sources and
eight individually inspected captures. Core/HTTP sources remain byte-identical
to `12337a5`, so their qualification is reused. Schema 14/portable 1/localOnly
remain unchanged.

The initial command selects the app scheme, which excludes UI tests, and runs
zero functions. The corrected native red reaches the missing Scheduling picker
and fails in 63.758 seconds. Both native test files remain unchanged from that
red through successful qualification. These attempts remain separate in the
record.

The new journey uses one default timed Itinerary assignment; other retained date
forms and live-List paths have separate Core/HTTP qualification. The iPad
Scheduled-catalog capture retains valid Plain details while its row leaves the
query, matching A3. Compact toolbars collapse filter summaries to icons; visible
active-filter text and title crowding remain polish tasks. Itinerary cumulative
native filters/duration, calendar, typed unresolved graphs, associated-label
deletion, paging/admin/performance, controlled native failures, Mac UI runtime,
signed physical sync/account/Share and whole-app polish retain their gates.
Calendar export stays outside the map.

## Native itinerary owned links

Context and goal. At baseline `7f19883`, Core retains itinerary-owned bookmarks,
but native itinerary forms/details omit them. DoR is the accepted owned-link
identity/order contract, qualified Core creation/guarded editing and the
existing native Item link editor. The intended end lets users stage itinerary
links, labels and order, save or cancel, and read the retained links in ordinary
itinerary details after relaunch.

The shared native Links section uses Form, TextField, Menu and Button for both
Items and Itineraries. An itinerary draft carries the saved link identities,
exact URLs, optional labels and order. Save sends the changed links through the
existing guarded durable command; Cancel executes nothing. Details reuse the
native Link/preview component. The immutable itinerary source read now exposes
its existing source lifetime for the preview-cache binding. No HTTP
serialization, storage schema or portable format changes.

Required /tdd. The native tracer first fails at the missing Add Link control in
23.321 seconds. The first implementation attempt saves two links, then fails in
76.099 seconds because the test queries a native Link as a Button. The corrected
test uses its actual Link role. Its prefix through that query remains identical
to red; the complete test file also gains a separate invalid-URL journey. Both
failed runs have later simctl diagnostic-collection errors, kept separate from
their assertions. The exported/inspected first-attempt capture shows the staged
form before the failure; it is not a failure frame.

The successful journey adds two Maps links, cancels a third addition,
edits/reorders a retained link, cancels then saves another link's removal, and
verifies exact identities, URLs, order, notes and No items after relaunch. The
validation journey rejects an invalid creation while retaining its draft,
corrects and saves it, then rejects an invalid link together with a notes edit.
Cancel/relaunch preserve the original saved owner. The existing Item bookmark
journey checks the shared editor's compatibility. Public Core tests check
itinerary creation/edit/catalog/recovery, including the source lifetime matching
its catalog row; actual authenticated HTTP checks source/edit/catalog
compatibility.

DoD passes three native UI functions on each simulator with zero failures, skips
or animation-idle warnings. Item compatibility takes 165.493 seconds on iPhone
and 174.697 on iPad; itinerary validation takes 72.742 and 82.323;
editing/order/relaunch takes 101.896 and 110.057. Four focused Core functions in
four suites pass in 0.267 seconds; three actual HTTP functions in three suites
pass in 0.712. Mac app/UI-test compilation succeeds with zero native runtime
functions. Strict lint passes on seven Swift and two Markdown files, with
whitespace checks. The evidence record retains actual summaries and twelve
individually inspected final captures. Its 271 source hashes remain frozen for
final native, HTTP and Mac-build qualification; the focused Core run precedes
the native test amendment with Core sources/tests unchanged. Schema 14/portable
1/localOnly remain unchanged.

The new itinerary fixtures use owned Maps links; automatic website
images/provider errors and itinerary-owned location/map controls retain separate
gates. Narrow iPhone toolbar/title crowding remains whole-app polish work.
Itinerary cumulative filters/duration, calendar, associated-label deletion,
paging/admin, controlled native failures, Mac UI runtime, signed physical
sync/account/Share and whole-app polish remain open. Calendar export stays
outside the map.

## Native planning-timezone selection

Context and goal. At baseline `4c642bf`, the native Schedule Form shows its
planning zone as read-only text. Core already supports validated zone changes
that preserve fixed instants. DoR is the accepted preserve-instant choice,
native timezone APIs, existing guarded complete-form editing and the approved
native UI seam. The intended end lets users search/select a zone in timed
drafts, cancel without saving, and retain the changed zone and appointment
through relaunch. All-day dates remain independent of timezone selection.

The shared Item/Itinerary Form now opens a native searchable List with system
timezone names, location labels and a selected checkmark. Selection updates only
the draft's zone; its Date instants stay unchanged while DatePicker redisplays
them. Save uses the existing guarded complete-form edit. Cancel executes
nothing. All-day forms omit the control. A native footer explains that changing
the zone keeps the same moment. No Core, HTTP, schema or portable-format
changes.

Required /tdd. The actual native tracer fails at the missing zone control in
24.054 seconds, before implementation. The first implementation passes in 69.814
seconds; two Item-edit compatibility journeys also pass, and Mac compilation
succeeds. Its inspected phone draft omits the second footer message, so the
final production change groups both messages in a VStack. The final test adds
one screenshot call in its search helper; functional assertions remain
byte-identical to red, while the complete file differs. The red run's later
simctl diagnostic-collection error is separate from its functional failure.

The timezone journey saves a start-only appointment in Europe/Paris, cancels an
America/New_York draft, then saves Asia/Tokyo under the same Schedule identity.
Native search matches city names containing spaces. Parsed native summaries must
represent the same minute-resolution instant before and after the saved zone
change. Notes, record count and identity survive both cancellation and relaunch.
Existing timed-end clearing and edited all-day range journeys check shared Form
compatibility.

DoD passes three unique functions per simulator with zero failures, skips or
animation-idle warnings. Timezone selection takes 69.937 seconds on iPhone and
72.059 on iPad; timed-end editing takes 57.792 and 59.143; all-day editing takes
96.450 and 101.685. Mac app/UI-test compilation succeeds with zero native
runtime functions. Three Swift files pass strict format lint; two Markdown files
and whitespace checks pass. All 272 source/configuration hashes remain frozen
through final simulator and Mac qualification. Twelve final captures were
individually inspected, including native search results, both footer messages,
saved details and relaunch. Core/preview/HTTP sources and tests are
byte-identical to `4c642bf`; their prior qualification is reused. Existing
ScheduleZoneTests also match the earlier catalog record and cover exact raw
instants, optional ends, guards and recovery.

The evidence record retains exact commands, the red and preliminary passes, both
source epochs, reused qualification and inspected captures. Final summaries are
iPhone and iPad. Captures show phone search, phone draft, phone relaunch, iPad
search, iPad draft and iPad relaunch.

The new journey uses an Item's start-only assignment. Itinerary owner-specific
zone runtime, native timed DatePicker edits, DST choices, travel and
display-zone changes retain their gates. Itinerary cumulative
filters/duration/location, calendar, associated-label deletion,
paging/admin/performance, controlled native failures, Mac UI runtime, signed
physical sync/account/Share and whole-app polish remain open. Schema 14,
portable format 1 and localOnly storage remain unchanged. Calendar export stays
outside the map.

## Native Itinerary planning-timezone qualification

Context and goal. At baseline `b83d000`, Item timezone creation/editing/relaunch
is qualified, but the shared Form's Itinerary owner path lacks runtime evidence.
DoR is accepted fixed instants, instant-preserving zone edits, the existing
native Itinerary scheduling journey and approved native UI seam. The intended
end qualifies zone selection, Cancel and Save/relaunch while preserving the
itinerary owner. This slice adds one UI journey and evidence only; it changes no
production behavior and claims no missing-feature red.

Required /tdd qualification. The actual controls create an empty Tokyo afternoon
itinerary with notes, save one start-only Schedule in Europe/Paris, cancel an
America/New_York edit, then save Asia/Tokyo under the same Schedule identity.
The new saved summary must represent the original minute-resolution instant.
Cancel preserves the original description. The itinerary catalog identity,
notes, No items progress, one Schedule identity/count and saved zone survive
relaunch. Exact raw instant, optional-end and guard/recovery behavior reuse
unchanged Core tests. No private database reads or alternate seeding interface
is used.

DoD passes one unique journey on each simulator with zero failures, skips or
animation-idle warnings: iPhone in 82.201 seconds and iPad in 90.463. Mac
app/UI-test compilation succeeds with zero native runtime functions. The changed
Swift test passes strict format lint, with Markdown and whitespace checks. All
272 source/configuration hashes remain frozen through sequential simulator and
Mac qualification. Six final captures were individually inspected.
Production/Core/preview/HTTP sources and tests remain byte-identical to
`b83d000`; their qualification is reused, not rerun.

The evidence record retains commands, frozen hashes, reused qualification and
captures. Summaries are iPhone and iPad. Captures show phone draft, phone saved
appointment, phone relaunch, iPad draft, iPad saved appointment and iPad
relaunch.

This qualifies an empty Itinerary's single start-only appointment. Timed forms
with an end, native time editing, DST/travel/display-zone transitions and
controlled stale/failure interactions retain separate gates. The phone captures
retain title/toolbar crowding for whole-app polish. Calendar modes/navigation
and itinerary estimates await Q59-Q61, native filtered groups await Q57, and the
loading fixture awaits Q58. Associated-label deletion, manual administration,
performance, Mac UI runtime and signed physical sync/account/Share remain open.
Schema 14, portable format 1 and localOnly storage remain unchanged.
