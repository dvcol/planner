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

The [evidence](evidence/native-shared-storage/final-validation.json) retains exact
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

The [result](evidence/native-shared-storage/app-hosted-2026-10-27/result.json)
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

The [evidence](evidence/native-shared-storage/registered-app/result.json) retains
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
[curated evidence](evidence/native-shared-storage/physical-build-ready/result.json)
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
[evidence](evidence/native-shared-storage/physical-core-2026-10-27/result.json)
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
[diagnostic records](evidence/native-shared-storage/ordinary-mac-2026-10-27/result.json)
retain the clean build, installation hashes and separate registration outcomes.
