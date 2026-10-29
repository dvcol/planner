# Native Share products and local review

Status: native Share products and local review are implemented. Development
signing and shared storage are configured. The installed mobile checkpoint below
supersedes the original unsigned setup notes. Installed Mac Share is post-MVP.

## Context and goal

At `fff58048`, Core can load native providers and perform reviewed capture, but there is no Share extension product or native controller. A1 accepts separate mobile and Mac targets. A5 requires the main application to initialize and migrate data before Share can save. Q33 carries forward capture authority, durable operation outcomes and the existing provider/Core/native test boundaries.

The local goal is buildable native extensions using the same production capture review, plus real-provider fixture qualification. Installed Share requests and shared storage are separate acceptance gates.

## Implementation

`PlannerShareMobile` hosts the shared SwiftUI review in UIHostingController. `PlannerShareMac` uses NSHostingController. They receive actual NSExtensionItem attachments, use the production native provider loader and complete the host request only after an applied change with complete recovery. Cancellation cancels the host request. Provider prose remains held for explicit review; the original URL is retained. Missing group configuration/access fails explicitly. There is no extension-private fallback store.

The targets have separate schemes and extension-only API checking. Actual unsigned builds validate platform-filtered dependencies and copy entries. The fresh mobile app contains only `PlugIns/PlannerShareMobile.appex`; the fresh Mac app contains only `Contents/PlugIns/PlannerShareMac.appex`. An initial mobile build caught incorrect embedding under singular platform-filter declarations. Explicit platform-filter arrays correct that failure; both fresh-bundle builds pass. Standalone extension builds also pass with extension-only API checking. Prototype identifiers derive from the existing application identifier; no identifier is claimed provisioned.

## Shared storage remains explicit

The checked-in local application still opens its existing Application Support dataset. This change must not silently relocate or replace that data. The new extension resolves `PlannerAppGroupIdentifier` from its own Info.plist and requires actual sandbox access. No group is configured or granted by this checkpoint. Opening the current local prototype does not initialize a future App Group directory.

The actual group identifier, entitlements for both processes, reviewed transition of existing data and real shared/account-bound storage integration still need implementation and qualification. Setting the Info key alone does not make Share operational. The fixture passes an explicit disposable shared path to both real Core roles; it does not emulate an entitlement grant or an installed extension host.

## Local evidence

The native fixture registers real public URL and UTF-8 text representations, enters the production Share view with the shareExtension role, and uses the real coordinated Core store. Its first red fails at the missing review UI in 15.447 seconds. Subsequent diagnostics correct an incorrect test expectation about provider prose, remove an unnecessary fixture toolbar action, and account for the existing reuse-candidate review on reopening.

Two journeys pass on each simulator. Reviewed capture, Cancel without an Item, explicit title entry, original-link retention, Save, reopening/reuse and stable identity pass in 41.570 seconds on iPhone and 48.076 on iPad. The real main-app-setup gate passes in 11.841 and 12.241 seconds. All have zero failures. These are controlled native fixtures, not installed extension or physical-device results.

Six original captures were inspected. The shared review uses native Form, navigation and toolbar actions; saved phone details retain the bookmark, and tablet details retain the selected row. Setup-required screens clearly direct the user to Planner. The website card in saved fixture details uses the existing controlled preview provider and is not live website-service proof.

Build and runtime packets are retained under [navigation compatibility evidence](evidence/navigation/native-itinerary-window-compatibility/). Extension compile/embedding packets are retained separately under [native Share product evidence](evidence/navigation/native-share-products/). Foundation evaluates the actual activation predicates successfully for URL, UTF-8 text and native MapKit registrations, rejecting unsupported-image-only and empty registrations. This is a metadata check, not installed-host invocation. Two existing direct-capture compatibility journeys pass on both simulators. Text/estimate cancellation and Inbox persistence pass in 86.826 seconds on dark iPhone and 92.147 on light iPad; untouched-link Save passes in 23.320 and 23.948 seconds. These qualify the existing form paths at the recorded source epoch, not a whole-app appearance audit. Later recovery failure corrections and qualification are tracked in [native Share recovery outcomes](native-share-recovery.md). Native Mac runtime and installed-host qualification remain separate gates.

## Remaining qualification

Installed extension launch from real senders, cancellation/host closure, extension memory/deadline behavior on physical devices, actual group access and simultaneous processes remain open. CloudKit/account transitions and independent recovery keep their existing gates. Unsigned builds and fixture paths do not establish any of those outcomes. Final whole-app polish remains after feature completion.

## Installed mobile Share, 29 October 2026

The real Safari Share sheet now launches Planner's embedded mobile extension in
disposable Simulators. This uncovered a production defect: Safari supplied an
opaque URL representation, and the input loader treated it only as UTF-8 text.
The review had no usable link and kept Add disabled after an explicit title edit.

The loader now asks the same provider for a typed native URL when URL data cannot
be decoded as text. Existing text representations retain their exact values.
The fallback uses the existing cancellable continuation, overall deadline and
1 MiB decoded budget. No storage model, public command or backup format changes.

The focused native capture-loading suite passes all 27 test functions in
31.497 seconds; compilation and execution take 335.573 seconds. Three new
controlled-provider checks cover exact encoded URLs, oversized URL objects and
cancelled requests delivering late values. The existing real-Foundation,
MapKit, byte-budget, retry and callback-order cases also pass. The controlled
provider checks do not replace the separate real Safari host journey.

The first Safari trial passes on iPhone in 90.349 seconds. The expanded phone
and iPad dark-mode journeys then pass in 95.190 and 94.005 seconds. They verify
Cancel without an Item, explicit title entry, Save, exact bookmark identity after
relaunch, and deletion of only the synthetic Item. Each disposable Simulator is
shut down and removed successfully. The original phone review in light mode and
iPad details in dark mode are inspected; the loading link card supplies no
positive image-preview qualification.

The final foreground-return journeys pass on phone and dark iPad in 87.567 and
82.672 seconds. Planner remains running in the background, and its existing
Items view refreshes without another navigation action. Item/bookmark identity
then survives relaunch, and cleanup leaves no test Item. These runs and their
matching Simulator/device builds share 1,172 source inputs. The Mac build
predates this iOS-only test refinement; its production sources are identical.
The signed device build and existing profiles are ready, but physical execution
waits for confirmed device availability.

The matching Mac app and Share build pass strict signature checks. Temporary
build registrations are removed: their path mentions fall from 6 to 0, while
the installed app retains 3 mentions and unchanged metadata/executable hashes.
`pluginkit` exits 0 and `lsregister` exits 1; the post-cleanup registry observation
establishes removal, rather than an assumed successful exit. Build products are
preserved. Installed Mac Share remains outside MVP.

Production CloudKit remains off. The user confirms the iCloud-transition
deferral on 29 October; no cloud diagnostic or account-setting change is armed.

The [curated evidence](evidence/navigation/native-share-products/mobile-installed-2026-10-29/result.json)
includes original captures, source hashes and compressed execution records.
Earlier failures retain their scope: initial unsigned App Group access,
test-driver selectors and URL launching, an installation-service failure before
any case, the actual blocked Add diagnostic, and a later discovery-only failure.
No failing startup is counted as an application test pass.

One local capture follow-up remains: failed provider inputs offer Remove, while
the accepted Retry capability exists only in Core. Add its native control through
the existing capture update command, preserving current owned edits and links.
