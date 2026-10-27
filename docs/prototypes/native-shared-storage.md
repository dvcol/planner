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
