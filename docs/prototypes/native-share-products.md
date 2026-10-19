# Native Share products and local review

Status: source and initial local review/product checks are implemented. Compatibility and failure qualification continue. Signing and real shared-container setup remain deferred by the user.

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
