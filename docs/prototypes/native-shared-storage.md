# Native app and Share storage

Local checkpoint, 26 October 2026.

The main app previously opened Application Support `Planner/Local`, while Share
expected an App Group `Planner` directory. Configuring the extension alone would
therefore leave the two entry points on different datasets.

`PlannerNativeStorage` now builds both configurations. The main app and embedded
Share read the same `PLANNER_APP_GROUP_IDENTIFIER` through their Info plists.
An unconfigured main app retains its existing local path; disposable prototype
datasets remain isolated. Selecting an empty shared location while local data
exists fails with an explanation and leaves the local data unchanged. This is
a safety guard, not an implemented migration. An already initialized shared
dataset stays separate from any old local copy.

The [registered-app checkpoint](#registered-app-checkpoint-27-october-2026)
below supersedes the earlier configuration and transition prerequisites for
this installation. The older results retain their original scope.

The [physical Safari Share checkpoint](native-share-products.md#physical-safari-share-29-october-2026)
adds installed mobile extension launch, cancellation, saving and foreground
readback on the authorized iPad. Role-level fixtures and ordinary app saves
remain distinct from that actual system handoff. CloudKit remains off.

## Executed checks

- A standalone native Swift check compiles the production helper with 90 actual
  PlannerCore object files and exercises four real-storage scenarios: main/Share
  initialization and reciprocal reads, reopening unconfigured local data,
  refusing silent abandonment of local data, and selecting an initialized shared
  dataset without modifying the local copy. All four pass. The disposable data
  is removed after the process exits. This is same-process role qualification,
  not installed extension or entitlement evidence.
- Existing rich Item creation and Google Maps capture journeys each pass on
  light iPhone and dark iPad simulators: four executions across two functions.
  They preserve original List membership, saved content and link identities
  through relaunch. Four final original captures were inspected.
- Matching Mac app, Share and UI-test compilation passes. A separate Mac
  app-hosted build compiles the four new XCTest functions. They have not run:
  `PlannerMCPTests` is Mac-only, and a Simulator attempt rejects before starting
  any test. The existing Mac runtime gate remains separate.
- All compiler/UI phases use the same 1162 native inputs. Actual built app and
  embedded Share Info plists on both platforms contain the same empty default
  App Group setting. No real group access or provisioning is claimed.

The evidence retains exact
commands, source/product hashes, outcomes and original captures. Failed preflight
and compile-only results retain those scopes.

## Remaining work

Register and authorize the intended App Group, wire the actual entitlements and
qualify installed app/Share access. Existing local data needs an explicit safe
transition before enabling a new shared store. No data is copied automatically.

CloudKit is still unimplemented: Core exposes only `localOnly`, explicitly opens
SwiftData with CloudKit disabled, and reports account/cloud state as unknown.
Implement the accepted native integration, then qualify account changes and
two-device behavior. This correction changes no Core schema, portable format or
recovery algorithm and supplies no cloud-sync evidence.

## App-hosted execution, 27 October 2026

The four existing `NativeSharedStorageTests` now execute through the approved
Mac app-hosted target. All four pass with zero failures in 0.267 seconds; the
command exits 0 in 5.012 seconds. They cover reciprocal main/Share reads, local
reopen, refusal to silently abandon local data, and separation of an initialized
shared dataset from the existing local copy. The signed build takes 77.994
seconds, with 1164 source inputs matched and seven actual product hashes.

The host uses the existing navigation-prototype and disposable-dataset launch
arguments. Each test uses real disposable storage through the production helper;
no installed extension or provisioned App Group access is implied. Production,
test source, signing resources and iCloud settings are unchanged for this run.

All fixture-owning host processes have exited, and the test log contains no
SQLite lifetime diagnostics. The strict cleanup verifier refuses removal because
macOS denies command-line access to the app-container ownership markers. Four
marked fixtures remain; no files are removed and no permission workaround is
attempted. Cleanup remains incomplete, separately from the four passing tests.

The result
and retained records preserve that distinction. The earlier standalone and
compile-only checkpoints keep their original outcomes. Safe data transition,
entitlement wiring, installed Share and physical/cloud acceptance remain open.

## Registered-app checkpoint, 27 October 2026

The user confirms that the prototype contains only disposable test data and
authorizes a fresh app. The registered app now uses `dvcol.planner`; both Share
targets derive their identifiers from it. Main and Share entitlements request
`group.dvcol.planner` on Mac and mobile. Development signing replaces the Mac's
ad hoc default. The development team remains machine-local, and other teams
can override the registered identifiers. Existing prototype data is untouched;
the local-data guard remains in place. No migration feature is added.

The five app-hosted storage tests pass with zero failures in 0.194 seconds.
The added test resolves the provisioned App Group, writes and reads a temporary
file there, removes it, and verifies matching main/Share store, control and
recovery paths. The other four tests retain their actual disposable-store
checks. This proves native main-app group access, not a save from an installed
extension process.

The final Mac build exits 0 in 7.894 seconds. Main and embedded Share pass strict
deep signature verification, use the existing development certificate, and have
matching profiles covering this Mac and the exact App Group. Neither signed
product requests CloudKit yet. The mobile compiler exits 0 in 5.693 seconds;
its actual app and extension Info plists contain the registered identifiers and
same App Group. Mobile products are unsigned Simulator products.

The existing untouched-link capture regression passes once on iPhone and once
on iPad, preserving the exact original URL and saved Item navigation. These two
executions do not exercise installed Share. All final phases match the same
1,167 native inputs; 66 Mac and 26 mobile product files are hashed.

An initial mobile metadata check found that the generated test Info plist
omitted the custom application identifier. An explicit test Info plist fixes
that defect; the final built test bundle contains `dvcol.planner`. The Intent
journey now reads that configured value instead of the old prototype constant.
No system Intent execution is claimed.

The verified development app is installed at
`~/Applications/Planner Development.app`. Launch Services recognizes that path,
but PlugInKit still returns no matching `dvcol.planner.ShareMac`, including after
explicit local registration. A bounded diagnostic logs a proxy-construction
error with the target redacted by macOS; it does not establish the root cause.
The user is asked whether Planner appears in the Sharing extensions list.
No extension election, privacy setting or security policy is changed.

The evidence retains
commands, input/product hashes, signature/profile checks, executed test results
and registration observations. Profile contents, certificates, device IDs and
unrelated system logs are excluded. Installed Share execution, mobile signing,
physical devices and production CloudKit remain open. Account-transition testing
stays explicitly deferred.

## Physical build preparation, 27 October 2026

A paired physical iOS device runs 27.0.1. The ordinary device build exits 0 in
261.247 seconds. Main and embedded Share pass strict signature verification,
reuse the existing development certificate, and have App Group profiles already
covering that device. No additional device registration is requested.

The final build-for-testing exits 0 in 16.658 seconds with 1,168 matched native
inputs. Main, Share and the native test runner all pass strict signature and
profile/device checks. Forty actual product files are hashed. The runner uses
a team wildcard development profile and needs no App Group access;
the Item operations execute through the real main app's native UI.

The hardware-only `SavedRegisteredStorageJourneyTests` is compiled, and its
method symbol is verified. It requires a disposable installation with an empty
matching catalog. It launches without prototype arguments, saves one uniquely
named Item, checks its public row identity and notes after normal relaunch, then
confirms deletion of that Item and checks another relaunch. The existing Map
provider/uncertainty journey is the second prepared check. No new target,
production test hook or provider seam is introduced.

These are preparation checks, not physical test passes. No installation or
launch is requested by these commands. Execution awaits the user's reply that
the device can remain unlocked and idle. The
curated evidence
excludes profiles, certificates and device identifiers. Production remains
local-only; account-transition testing stays deferred. Installed Share and
actual physical shared-store access remain unqualified until they execute.

## Physical core journeys, 27 October 2026

With the user ready, Xcode installs the signed app, embedded Share extension and
test runner on the paired iPad running 27.0.1. Both initial test methods start
but fail because Planner crashes during launch. Two app-only crash reports
show main-thread stack-guard failures while Swift recursively constructs the
root view's generic metadata. This is a runtime defect, not a signing refusal.

A computed-property split alone still fails both tests with the same stack
pattern. The final correction separates lifecycle from presentation modifiers
and uses two explicit `AnyView` boundaries at the root. It changes no saved-data,
provider, signing or public-interface contract and adds no test hook or target.

Both physical journeys then pass, with zero failures or skips: the Map case in
51.383 seconds and normal shared storage in 48.616 seconds. Xcode exits 0 in
107.978 seconds. The normal-app test uses no prototype launch arguments. Its
unique Item retains the same public row identity and notes through relaunch;
confirmed deletion and another relaunch verify its cleanup. The Map case uses
its separate disposable dataset, preserves the exact original coordinate-search
bookmark, and verifies provider attribution and the unverified-place warning.
It does not qualify arbitrary provider lookups or ambiguous address choices.

The final device build takes 23.397 seconds. Main, Share and runner retain valid
signatures and profiles covering the device, with the existing certificate and
approved App Group. All 37 device product hashes remain unchanged during the
passing run. The affected Mac and Simulator builds also pass, in 31.750 and
54.968 seconds, against the same 1,168 native inputs. Mac main/Share strict
signature checks pass; no new Mac UI execution is implied.

The existing compact iPhone Simulator Map journey also passes: one test, zero
failures or skips in 75.082 seconds, with Xcode exiting 0 in 104.689 seconds.
Its two distinct original captures are inspected. This adds compact navigation
regression coverage, not a second physical device or a full accessibility pass.

All three distinct original device captures are inspected; the two Locations
attachments are byte-identical and retained once. Planner is reopened with
normal launch arguments after the checks. The
evidence
retains the failed attempts separately from the passing run, without device
identifiers, raw crash-report personal fields, profiles or certificates.

Installed Share execution, broader physical/UI acceptance and production
CloudKit remain open. Production stays local-only, and the explicit deferral
of account-transition testing remains in force.

## Ordinary Mac installation, 27 October 2026

The installed test build contains both `PlannerMCPTests.xctest` and Share.
An ordinary application-only build, after removing only its inactive generated
app product, succeeds in 12.236 seconds with the same 1,168 native inputs as
the physical-core checkpoint. It contains only `PlannerShareMac.appex` in
PlugIns. Main and Share pass strict deep signature checks. Both processed Info
plists are unchanged from the test build.

After the user saves drafts and quits Planner, the ordinary build replaces the
installed development app. All 25 product files match their build hashes;
the previous app bundle is retained temporarily. App data, security settings,
extension elections and the old prototype are untouched by the installer.
The app opens normally from its installed path.

Launch Services registration returns 0 and its plist lint reports no errors.
Explicit registration of the embedded extension also returns 0, but a fresh
exact PlugInKit query still reports no matching `dvcol.planner.ShareMac` record.
Removing the embedded test bundle is therefore insufficient to fix discovery.
The actual Sharing-settings visibility observation is requested after this
installation; no extension save or provider handoff is claimed.

The installed Xcode Mac Share template agrees with the extension-point and
principal-class structure. Its additional icon resource does not establish a
registration requirement. Apple's
[extension-key reference](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/AppExtensionKeys.html)
also documents the current extension-point key. No speculative metadata or
signing change is made. The
diagnostic records
retain the clean build, installation hashes and separate registration outcomes.

## Mac Share discovery checks, 28 October 2026

Read-only AppKit lookup resolves the intended installed development app.
Its 25 installed files still match the ordinary-build manifest, and main/Share
strict signatures verify outside the command sandbox. Both have the approved
App Group. The query runs in the console user's Aqua session. These checks do
not identify a signing, wrong-app-copy or session mismatch.

The command-sandbox PlugInKit query fails with Connection invalid; it cannot
establish extension absence. Outside that sandbox, the exact query succeeds
but has no matches. A control query lists seven built-in Share plugins, with
no Planner record. One instrumented registration of the existing extension
returns zero, followed by the same successful empty query. The system trace
contains no Planner-specific message. Other plugins' redacted rejection messages
cannot establish Planner's failure cause.

Deprecated AppKit service enumeration also omits Planner for synthetic URL and
text inputs. No picker is displayed and no service performs sharing; this does
not qualify the modern native Share menu. The
discovery record
retains the scoped probe and checks without unrelated full system logs.

No production metadata, certificate, security setting or extension election is
changed. The existing human Sharing-settings visibility/enabled-state observation
remains pending. Installed handoff and a real extension save remain unqualified;
the main-app and explicit-configuration capture tests do not replace them.

## Duplicate Share registration cleanup, 28 October 2026

The user's Settings capture shows four Planner entries, all with Sharing off.
This establishes visible discovery despite the empty PlugInKit command query;
that query alone cannot establish absence from the actual Settings interface.

Scoped Launch Services inspection finds old test, probe and missing-app records.
The authorized cleanup unregisters 26 obsolete Planner app paths and three test
Share paths, then registers the canonical app at
`~/Applications/Planner Development.app`. Its Planner Share-host records contain
only that app and its embedded `dvcol.planner.ShareMac` extension. All 30 initial
cleanup commands return zero. No global registry reset or extension-election
change is made.

Four inactive generated/backup app bundles are also removed from temporary
storage, after exact process checks. One is an incomplete old bundle. Two bundle
sizes were not recorded before removal; the other two account for 148,640,589
nominal bytes. The canonical app still passes strict deep signature verification,
and app data remains untouched.

Settings initially still shows four entries after a pane refresh. After fully
quitting Settings and reopening it, the user confirms one Planner Development
entry remains and Sharing is enabled. Installed Share execution/save is not yet
qualified; the next native check uses that installed app and a separate ShareLink
source fixture with no embedded extension. It does not recreate a Planner Share
host copy. Map layout and multi-place work continues
separately, with production CloudKit disabled and account-transition testing
still deferred. The cleanup record
records registry verification and the user-confirmed Settings result separately.

## Installed native Share picker, 28 October 2026

The native source fixture shares a synthetic HTTPS URL through `ShareLink`.
It has no embedded extension or App Group. It uses the existing development
certificate and test entitlements; no new identifier, profile or certificate is
created. The final fixture-only build succeeds in 10.863 seconds against 1,172
matched native inputs. The canonical installed app and all 25 of its files stay
unchanged, with strict deep signatures verified before and after each run.

Manual UI automation reaches actual test execution. The initial unobstructed
native picker offers Reading List, AirDrop, Mail, Notes and Copy, but no Planner.
Its first driver incorrectly matches an unrelated Apple-menu Recent Items entry;
no extension review or Save occurs. The corrected driver scopes the actual
`ShareSheet.Popover` and requires a hittable Planner service button. A subsequent
retry finds Planner running without a window; the driver now opens a normal
File → New Window when necessary rather than restarting a running app.

The final corrected retry opens the native picker and fails to find Planner in
23.511 seconds. Its capture also contains a macOS authentication dialog over
the picker, so it does not establish an unobstructed final result. The user is
asked to resolve the expected manual authentication dialog and independently
check Safari's Share menu. The authentication-required policy remains unchanged.

The installed activation predicate accepts actual native URL and plain-text
providers. Scoped registration lint exits zero without metadata errors, and
Launch Services retains the canonical app/extension pair. The exact PlugInKit
query still returns no matches. These checks narrow the investigation but do
not establish a root cause or qualify installed Share launch/save.

The picker evidence
keeps the clear initial picker capture, exact final fixture sources and bounded
run outcomes. Raw recent-item hierarchies, the authentication-dialog capture,
full system logs and signing-resource contents are excluded. No production
metadata, security setting or installed app is changed by these trials.

### Discovery follow-up after manual approval

The user confirms Planner is also absent from Safari's Share menu and that the
expected automation dialog has been approved and closed. This rules out a
failure confined to the source fixture. A scoped unregister/register cycle for
the canonical app and its embedded extension returns zero for all three steps,
but the exact PlugInKit query remains empty. Installed product files stay unchanged.

The user's discovery daemon predates this installation by more than six days.
It belongs to the user service domain, rather than the GUI domain. macOS refuses
its requested restart with error 150, "Operation not permitted while System
Integrity Protection is engaged." The service is not restarted and protection
is unchanged. This is an operating-system refusal, not an automation approval
failure, and stale discovery remains a hypothesis rather than an established cause.

Read-only controls find 487 registered plugins, including 14 non-Apple entries.
The installed OneNote Share extension is also absent from its exact query.
No relevant restriction payload appears in the configuration profiles readable
by this process. These controls do not prove a system-wide failure or exclude
every device-management policy. No profile, election, certificate or app metadata
is changed to make these observations pass.

The unchanged test is retried after the user's approval confirmation, but Xcode
reports "Timed out while enabling automation mode" before any test case starts.
The bounded run receives no Share acceptance credit. Further identical UI retries
are stopped until discovery changes. The next requested diagnostic is a normal
Mac restart, followed by a fresh discovery query before another installed Share
run. A restart is not yet proven to fix the issue. Signing remains verified and
no security protection is weakened.

The user subsequently confirms a normal restart and that Xcode is open. The
execution service nevertheless reports the same discovery-process identity,
an October 14 kernel boot date and thirteen days of uptime. `last reboot` and
the launch-process age agree with that execution-side date. Planner's query
still has no matches; the canonical signature verifies and its file count
remains 25. The project binding reports the local host.

These observations do not establish which session the user restarted or whether
the execution connection is stale. The next diagnostic asks for `hostname` and
`uptime` from the user's Terminal for comparison. No additional restart or UI
run is requested before resolving that discrepancy.

A later direct check observes the restart: uptime is six minutes, the discovery
process has been replaced, and temporary build products have been cleared.
The earlier Terminal comparison is no longer required. Planner nevertheless
remains absent from its successful PlugInKit query. macOS 27.0.1 satisfies the
app and extension's minimum 27.0, and the canonical signature still verifies.
The fresh boot therefore does not restore discovery. Keep that negative result
separate from the earlier stale-process hypothesis and continue with a minimal
native registration control rather than repeating unchanged Share UI runs.

Launching the canonical installed parent after the fresh boot also leaves its
exact query empty. Apple Share services remain discoverable in the same user
session. A minimal, independently signed native control with the standard Share
declaration and icon is likewise absent; its parent was not launched, so this
control does not establish a system-wide failure. Its temporary registration
and application are removed afterward.

The canonical app has no quarantine attribute and still passes signature
verification, but `spctl --assess --type execute` rejects its development build
with exit 3. Apple's [extension distribution guidance](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionCreation.html)
separately requires user approval of a containing app signed without Developer
ID. This is a plausible admission cause, not a confirmed diagnosis. The next
human check is a Finder Control-click → Open of the canonical app followed by
the actual Safari Share menu. No global Gatekeeper setting, certificate,
capability or production metadata is changed. UI automation approval and this
app-opening approval remain separate.

### Managed Share restriction established

The user opens the exact canonical app through Finder and confirms that Planner
is still absent; their Safari screenshot independently shows the omission.
The post-opening PlugInKit query still succeeds with no matches. This opening
step does not resolve discovery and Gatekeeper is not established as its cause.

A bounded live `pkd` debug trace during registration provides the first concrete
rejection reason. ManagedClient reports 29 denials for
`com.apple.share-services`, including 25 with redacted plugin identities, and
discovery records `plugin rejected by MCX`. The policy message says the Share
extension point is implicitly denied by a payload. The payload identity and
Planner-specific plugin identity are redacted, so this establishes the active
Share management restriction without identifying its administering profile.

Neither the readable configuration-profile report nor the two targeted managed
preference files expose that rule; Foundation's effective preference reads are
also absent. Those negative reads do not override the actual runtime denial.
Apple documents this policy under the
[Extensions management payload](https://developer.apple.com/documentation/devicemanagement/nsextensionmanagement).
The device administrator must review `com.apple.NSExtension` and permit
`dvcol.planner.ShareMac` and the required `com.apple.share-services` point under
the applicable policy. Alternatively, installed Share can be qualified on a Mac
whose policy permits it. No profile, restriction or security protection is
removed or modified. Further identical Share runtime retries are held until
admission changes; handoff/save remains unqualified.

The fixture-only source host and opt-in UI journey now compile independently.
An initial development-signing build fails because the fixture's unregistered
test identifier has no development profile. A local ad-hoc build with no App
Group entitlement succeeds in 58.326 seconds; no test identifier/profile is
registered. The real installed app and extension retain their verified signing
and App Group. The journey skips unless explicitly enabled for disposable
installed data and deletes only its uniquely created Item after a successful
handoff/readback. That success/cleanup path has not executed while discovery is
blocked. Compilation supplies no installed-extension execution credit.

The subsequent MVP focus moves installed Mac Share integration and qualification
to post-MVP. In-app New Item and From Link or Text remain the Mac capture path.
The prepared source host and opt-in test are retained in the
deferred source/evidence packet
rather than added to the active fixture target. The fixture app returns exactly
to its preceding committed source. Existing production Share implementation,
signing, saved data and the diagnosis remain intact. Further discovery work and
administrator policy exceptions are not MVP tasks.

## Current itinerary device build, 28 October 2026

The current signed physical build passes in 52.305 seconds with all 1,169 native
inputs matching the workspace. Main app, embedded Share and UI runner pass strict
signature checks; their profiles cover the paired iPad and use the existing
development certificate. Main and Share retain the approved App Group. All 37
physical product files are hashed and verified.

The physical iPad is reachable, but its native lock-state read reports that a
passcode is required. The user is asked to unlock it and confirm availability.
The existing itinerary creation/relaunch and selected-plan deletion journeys
are prepared; their runner requires that readiness confirmation before starting.
No installation or physical execution occurs during this preparation.

The preparation record
retains the commands and verification without device identifiers or profile and
certificate contents. It supplies no physical itinerary, installed Share or sync
credit. Production CloudKit remains disabled and the account-transition
experiment stays user-deferred. Mac UI readiness remains a separate pending gate.

## Physical itinerary journeys, 28 October 2026

After renewed human readiness and a fresh unlocked-state check, both prepared
journeys pass on the physical iPad running 27.0.1, with zero failures or skips.
Creating a second itinerary opens its own empty contents and retains its public
identity and single heading after relaunch. The deletion journey verifies
Cancel on an empty plan, confirmed empty-plan deletion and deletion while an
Item appearance is selected. After relaunch both deleted plans remain absent;
the original shared Museum Item retains its identity, notes and global Todo
state.

Creation takes 89.557 seconds and deletion takes 135.657 seconds. The complete
command exits 0 in 236.503 seconds. All 1,169 native input hashes and 37 signed
product-file hashes remain unchanged. Main app, embedded Share and runner pass
the prepared signature checks. No production or test code changes are needed.
The app is then launched normally without prototype arguments.

All four original captures are inspected and three retained in the
execution evidence.
The native hierarchy reports a 1600-by-1200 main window; the screenshot files
carry a 3200-by-2400 pixel matrix and EXIF orientation 8. The represented heading,
review controls and cleared selection are checked, without claiming full-device
layout or orientation acceptance. The read-back-verified archive retains
redacted commands, source/product hashes, results, logs and heading hierarchy;
device identifiers, names and profile/certificate contents are excluded.

These journeys use disposable local-prototype datasets through the registered
signed app. They add physical itinerary UI evidence, not normal shared-store,
installed Share, broader deletion-matrix, accessibility or synchronization
qualification. Production CloudKit stays disabled, account-transition testing
remains user-deferred, and the prepared Mac run still needs manual automation
readiness at this checkpoint. The subsequent
[reader runtime checkpoint](native-reader-pane-width.md#mac-runtime-qualification-28-october-2026)
records actual Mac reader passes and a separate itinerary-selection failure.

## Physical Map preparation and readiness, 29 October 2026

The current signed iOS app, embedded Share and UI runner build succeeds in
202.382 seconds against the same 1,170 inputs as the passing Mac/phone camera
checkpoint. Main and runner signatures pass. The existing approved team, app
identifier, App Group and device coverage are verified without provisioning
changes. A fresh check reports no passcode required.

The physical iPad run starts one case on OS 27.0.1, then fails after the first
New Item Save in 34.041 seconds; the whole command exits 65 in 47.130 seconds.
The editor remains present. Its recording includes a floating overlay near the
Save area and an orientation transition. The evidence does not establish the
Save's persistence outcome or an app Save defect. The itinerary Map and route
checks are not reached, so no physical Map acceptance is granted.

Further device UI waits for the user's confirmation that the same iPad is idle,
unobstructed, unlocked and awake. The signed build is ready. No account-transition
experiment or CloudKit activation is armed. A host-side devicectl lookup warning
also appears during teardown; no additional device cleanup is claimed.

The readiness record
retains build, signature, execution and source-hash facts. Physical screen content,
full hierarchies, device identifiers and provisioning contents are excluded.

### Physical readiness retry, 29 October 2026

After renewed readiness confirmation and a fresh unlocked-state check, the
refreshed signed build passes in 34.820 seconds. Existing signatures, approved
identifiers, App Group and device profile coverage pass without new provisioning
resources. The next physical run again stops after its first New Item Save:
one failure in 36.876 seconds, exit 65 in 55.298 seconds. Its recording still
contains a floating video panel and rotation near Save. The persistence outcome
and physical Map remain unproven.

The scoped follow-up record
retains sanitized results and excludes physical screen content. A new readiness
request asks for playback to stop and the iPad to rest still, unobstructed,
unlocked and awake. No further physical UI runs before that confirmation. The
next retry must rebuild current sources, which subsequently gained the final
minimized-Search and test-scroll corrections. This is separate from signing and
the user-deferred iCloud transition test.
