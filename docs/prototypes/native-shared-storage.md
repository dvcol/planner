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
