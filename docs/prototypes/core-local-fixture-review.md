# Local Core fixture setup

Accepted Q36 A on 2026-10-09 for the shared Core fixture used by [MCP session prototype](https://github.com/dvcol/planner/issues/16). The human approved the concrete packet with "looks good to me, continue." A21/A22/Q33 already accept the domain facade, source fields, writer/recovery sequence and local-store feasibility work. This packet specifies the storage-opening input, native recovery namespace discovery and exact first executable store journey. It adds no completion, conflict, backup, authority or account policy. Runtime evidence remains required.

## Context, starting state and expected end

PlannerCore currently has no domain implementation. Its committed shared scheme builds native Core unit/store test bundles from the same source folders as Swift Package Manager. The discovery run executes zero behavior tests. The HTTP prototype has passing transport evidence but no real Planner reads or changes, so it cannot yet prove the required Hotel/Museum commands.

The first store journey must prove a real action survives reopening and has independent complete recovery evidence before reporting saved success. An in-memory fake or fixture dictionary cannot establish that result. The existing [field-edit readiness requirement](../field-edit-contract.md#definition-of-ready) asks for agreement on the prototype's real storage configuration and affected commands before implementation.

The expected end of this review is agreement on the opening configuration and journey below. The subsequent implementation must record an executable failing behavior, its minimum passing implementation, real-store reread/reopen observations and affected-target checks. This document is no runtime proof.

## Proposed storage-opening boundary

Expose `Planner(configuration: PlannerStorageConfiguration)` without opening or migrating storage merely by constructing the facade. Call its existing approved asynchronous `bootstrap()` explicitly. Bootstrap returns `ready(session)`, `mainAppSetupRequired`, `mainAppMigrationRequired` or `unavailable(reason)` as already specified. Callers retain the Core-issued session; they cannot construct an ownership binding by editing configuration.

PlannerStorageConfiguration has these real configuration fields:

| Field | Proposed meaning |
| --- | --- |
| `storeURL: URL` | A file URL for a persistent SwiftData store. The fixture uses SQLite on disk, not in-memory storage. |
| `controlURL: URL` | Stable file URL coordinated by participating writers and migration. Separate facade instances/processes for this dataset use this same gate. |
| `recoveryDirectoryURL: URL` | Separate directory for namespace-scoped internal envelopes and prepared evidence. It is outside the mirrored store and is never a plaintext credential location. |
| `processRole` | `mainApplication` may initialize/migrate. `shareExtension` requires completed main-app setup/migration and does not perform either itself. |
| `storageMode` | This first fixture uses `localOnly`, with automatic CloudKit mirroring disabled. Signed App Group/private CloudKit deployment remains its owning prototype's separate configuration and proof. |

Use a fresh subdirectory of the native process's temporary directory for each independent test. Give it distinct store, control and recovery paths. A reopen/second-writer test reuses its original paths. These are genuine storage options, not injected clocks, UUID factories, database callbacks or private test hooks.

Core initializes and retains its dataset identity, store epoch and local ownership binding. The fixture does not fabricate an iCloud account record name or present local ownership as verified CloudKit ownership. Sessions and references remain subject to the approved writer-boundary validation. Temporary path selection is not a production data-location decision.

Use the approved VersionedSchema/migration candidate, optional/defaulted storage values and private SwiftData models. Each writer uses a fresh isolated context with autosave disabled under the shared control gate. A process-local actor alone is insufficient. Reads/results remain immutable Sendable values from Planner's facade.

## Native recovery namespace discovery

The accepted inspectRecovery requests select a namespace/snapshot/proposal by its Core-owned ID, but the contract does not yet declare how a native caller discovers those IDs. The status read carries checkpoint/blocked observations and no namespace ID. Reading private filenames in a view or test would bypass the facade.

Propose one native-only request variant, `inspectRecovery(request: .namespaces)`, returning `listedNamespaces([RecoveryView])` with the existing declared view fields. It discovers namespaces in this configuration's local recovery root, including retained old-account copies, without selecting an active account or changing data. IDs come from validated Core-owned metadata. The list is ordered by namespace UUID, not ownership-description text. An unreadable catalog returns a typed failure, not a successful empty list or invented IDs. Per-namespace availability retains the existing available/unavailable/ownershipUnverified meanings where identity is established.

The existing namespace/acknowledgedSnapshot/proposal requests and their ownership/integrity checks stay unchanged. This read is absent from MCP and App Intents, like other recovery administration. It also makes the first store journey verify the independently recovered content through a public interface rather than trust a successful database receipt alone.

## First real store journey

The observable seam is the approved Planner bootstrap/execute/read/status interface with the concrete opening input above. Tests never inspect ModelContext, SQLite tables or private record fields.

1. Construct Planner with the fresh on-disk configuration and mainApplication role. Explicit bootstrap returns ready with a Core-issued dataset session.
2. Submit operation `00000000-0000-4000-8000-000000000901`, command createItem, title `Hotel` and notes `Original notes`. Other declared optional content fields are nil; links/category/tag selections are empty.
3. The result contains exactly one generated Item identity. Creation is globally Todo and Active. It is applied with complete independent recovery and a known positive checkpoint generation; database commit alone cannot satisfy this assertion.
4. Read that returned identity through the same facade. Title/notes are exactly Hotel/Original notes, globalDone and archived are false, and no references or labels were invented. Read fields/hashes use the accepted content catalog.
5. Construct a fresh facade against the same paths and explicitly bootstrap again. Its session is new while the dataset and Item identity remain the same. Read the returned Item again with exactly the same content/global/archive state.
6. Query the original operation's status through the reopened facade. Its original result identity and completed independent checkpoint evidence remain available. Missing evidence cannot be reported as rollback or saved success.
7. Enumerate recovery namespaces through the proposed native request, find the namespace bound to this dataset, and select its acknowledged checkpoint through the existing inspectRecovery request. The Core-issued selection contains the same Item identity, Hotel/Original notes, Todo/Active state and no invented associations in its validated decoded backup. Prepared-only data cannot satisfy this step. The test does not inspect private files or decode its own expected snapshot with production internals.

This test's literal text/state expectations come from the accepted creation contract. Generated identities are obtained through its public result and then used as read inputs. Expected fingerprints for later guarded edits remain the independent vectors already committed; tests never generate their expected digest with the production encoder.

Only after that journey passes, add one scenario at a time: identical create replay retains one identity/count; changed-payload replay rejects; invalid creation changes nothing; notes hash/guard and unrelated-field edits; global completion/archive and reopened reads; actual precommit/postcommit recovery failure and A18 blocking; required two-client commands and full native lifetime/load checks. No fake success, partial action or weakened save acknowledgement is introduced to make the first test pass.

## Focused execution

The agreed baseline remains Xcode 27.0 build 27A266a, Swift 6.4 and native arm64 macOS 27.0.1. Scope DEVELOPER_DIR for every command. Run the selected new store suite with a unique result-bundle path and record discovered/executed counts. A missing declaration, compile error or zero discovered tests is setup failure, not red.

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Planner.xcodeproj -scheme PlannerCore -destination 'platform=macOS,arch=arm64' -only-testing:PlannerCoreStoreTests/ItemCreationTests -onlyUsePackageVersionsFromResolvedFile -clonedSourcePackagesDirPath /private/tmp/PlannerMCPSourcePackages -derivedDataPath /private/tmp/PlannerCoreFixtureDerivedData -resultBundlePath /private/tmp/PlannerCoreItemCreationRed.xcresult
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path Packages/PlannerCore --filter ItemCreationTests --scratch-path /private/tmp/PlannerCoreFixturePackageBuild
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift format lint --strict --recursive Packages/PlannerCore/Sources/PlannerCore Packages/PlannerCore/Tests/PlannerCoreStoreTests
```

The suite and its domain types do not exist yet; these commands are the proposed execution plan, not reported results. Before later native/client claims, compile and qualify the same facade in the app/test host and real client routes. Package/store tests cannot replace signed reader, App Group, extension, UI, account-transition or physical CloudKit evidence.

## Review choice

- A, recommended: accept this on-disk local configuration, native namespace discovery and exact create/read/reopen/status/recovery journey. Core fixture work can proceed independently of pending UI/signing inputs.
- B: revise the opening fields or observable journey before its tests. Specify the missing behavior or binding so the proposal can be corrected without guessing.
- C: wait for a provisioned App Group and run the first store journey there. This adds real sandbox/group configuration earlier but makes fixture work depend on signing setup. It still does not replace private CloudKit/device proof.

## Readiness and done

- [x] Existing domain/authority contracts are accepted; native Core scheme/targets build and their current zero-test discovery is recorded.
- [x] Real storage inputs, namespace discovery, ownership limits, first operation/read/status/recovery expectations and focused commands are concrete for review.
- [x] Human confirms the storage-opening input, native namespace discovery and first store journey before its new public-boundary tests under Q36 A.
- [ ] Executable red/green, actual reopen/recovery evidence, focused compilation/lint and discovered/executed counts are committed.
- [ ] Real MCP domain commands and the original owning prototype's remaining gates pass before resolution.
