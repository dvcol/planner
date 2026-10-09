# Native MCP prototype build evidence

Temporary source on `prototype/mcp` for [MCP session prototype](https://github.com/dvcol/planner/issues/16). The accepted [architecture](../architecture-blueprint.md), [adapter contract](../adapter-contract.md) and Q33 public-boundary approval govern this work. This branch is a feasibility artifact, not the production app or a resolved prototype ticket.

## Starting state and goal

The starting checkout had no native project or package. Navigation's new UI journeys still await Q34; its label confirmation decision awaits Q35. MCP's HTTP and shared-command contracts are already accepted, so native build setup and the unchanged HTTP boundary can proceed independently.

This first step supplies a native multiplatform app target, local PlannerCore package, shared Planner build/test scheme, Mac transport test target and explicit prototype sandbox configuration. It does not implement domain storage, Agent Control, Share, a credential reader or CloudKit.

## Observed setup

Checked 2026-10-09 on macOS 27.0.1 build 26A434, arm64. Xcode 27.0 build 27A266a supplies Swift 6.4 and OS 27 SDKs. Every native command scopes DEVELOPER_DIR; the global developer directory remains unchanged.

- Xcode discovers Planner and PlannerMCPTests targets, committed Planner scheme and the automatically generated PlannerCore package scheme.
- Planner has native Mac and iOS simulator destinations, including iPhone 18 Pro and iPad Air 11-inch M4 on iOS 27. No simulator was booted or app installed by these build checks.
- Official Swift MCP SDK is pinned to 0.12.1, revision a0ae212ebf6eab5f754c3129608bc5557637e605. SwiftNIO is pinned to 2.104.0. The [resolved dependency file](../../Planner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved) records all seven remote pins. PlannerCore itself has no external package dependency and therefore needs no separate resolution file yet.
- The official SDK's [repeated initialization fix](https://github.com/modelcontextprotocol/swift-sdk/pull/257) and [request-isolation fix](https://github.com/modelcontextprotocol/swift-sdk/pull/264) remain unmerged. This refresh does not qualify a workaround or establish safe concurrent clients.
- Installed client versions are Codex CLI 0.160.1, Claude Code CLI 2.1.291 and Claude Desktop 1.46388.2. Installation is not a successful connection. Codex desktop and all four actual client routes remain separate evidence gates.

## Executed focused commands

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -resolvePackageDependencies -project Planner.xcodeproj -scheme Planner -clonedSourcePackagesDirPath /private/tmp/PlannerMCPSourcePackages
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -list -json -project Planner.xcodeproj -onlyUsePackageVersionsFromResolvedFile -clonedSourcePackagesDirPath /private/tmp/PlannerMCPSourcePackages
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -showdestinations -project Planner.xcodeproj -scheme Planner -onlyUsePackageVersionsFromResolvedFile -clonedSourcePackagesDirPath /private/tmp/PlannerMCPSourcePackages
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project Planner.xcodeproj -scheme Planner -configuration Debug -destination 'platform=macOS,arch=arm64' -onlyUsePackageVersionsFromResolvedFile -clonedSourcePackagesDirPath /private/tmp/PlannerMCPSourcePackages -derivedDataPath /private/tmp/PlannerMCPDerivedData
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project Planner.xcodeproj -scheme Planner -configuration Debug -destination 'generic/platform=iOS Simulator' -onlyUsePackageVersionsFromResolvedFile -clonedSourcePackagesDirPath /private/tmp/PlannerMCPSourcePackages -derivedDataPath /private/tmp/PlannerMCPDerivedData CODE_SIGNING_ALLOWED=NO
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test list --package-path Packages/PlannerCore --scratch-path /private/tmp/PlannerCorePrototypeBuild
codesign --verify --deep --strict --verbose=2 /private/tmp/PlannerMCPDerivedData/Build/Products/Debug/Planner.app
```

Dependency resolution, discovery and both app builds passed. Signature verification passed. The Mac app uses ad hoc signing and contains app-sandbox, network-client, network-server and Debug get-task-allow entitlements. It has no provisioned team, application identifier, App Group or CloudKit entitlement. Its org.example bundle identifier is explicitly a disposable prototype placeholder, not a provisioned product identifier.

Core test targets compile and discovery returns zero tests. They are empty configuration targets, not passing behavior suites. The initial build-only step has no unit behavior to assert. A missing project, compile failure or undiscovered test cannot be reported as a TDD red result.

Logs are machine-local at /private/tmp/PlannerMCPResolve.log, PlannerMCPProjectList.json, PlannerMCPDestinations.log, PlannerMCPMacBuild.log, PlannerMCPMobileBuild.log and PlannerCoreDiscovery.log. Builds emit the expected App Intents metadata-skipped warning because no App Intents implementation exists yet. No source compile failure is dismissed as pre-existing.

## Remaining gates

The committed package and app are deliberately incomplete. Navigation/UI suites, platform Share targets/embedding and domain implementation remain required by their owning prototypes. The explicit Core scheme configuration is recorded below. The [HTTP evidence](mcp-http-qualification.md) now records a real disposable loopback exchange. Native Agent Control operation, real client calls, signed Data Protection Keychain/App Group reader access, lifecycle/concurrency/load evidence and human connection review remain MCP gates. Ad hoc signature verification does not establish those capabilities. Physical-device navigation performance and private CloudKit/Share proof remain required elsewhere in the map.

Subsequent slices test the approved HTTP boundary through the SDK's public HTTPRequest/HTTPResponse values and actual loopback requests. Use one executed failing behavior and its minimum implementation at a time. In-process tests do not substitute for listener or client evidence. Navigation's unconfirmed UI tests remain unwritten.

## Explicit Core test scheme

The committed PlannerCore scheme now refers to explicit native PlannerCoreTests and PlannerCoreStoreTests targets. Their synchronized source folders are the same test folders used by the package manifest; both link the PlannerCore package product. The test configuration supports Mac and iOS destinations. No second Core implementation or hosted app is introduced.

The first scheme attempt referred directly to package test names and Xcode reported no available test bundles, exit 70. That was setup failure, not a TDD red. Native target references corrected discovery. The focused command below then built the Core library and both test bundles, launched the standalone store test runner, and exited zero. The [actual summary](evidence/mcp/core-scheme-discovery.json) records zero discovered/executed behavior tests because the source folders still contain only import declarations. No domain behavior is claimed passing.

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Planner.xcodeproj -scheme PlannerCore -destination 'platform=macOS,arch=arm64' -only-testing:PlannerCoreStoreTests -onlyUsePackageVersionsFromResolvedFile -clonedSourcePackagesDirPath /private/tmp/PlannerMCPSourcePackages -derivedDataPath /private/tmp/PlannerCoreSchemeDerivedData -resultBundlePath /private/tmp/PlannerCoreNativeSchemeDiscovery.xcresult
```

Project-list readback includes PlannerCoreTests/PlannerCoreStoreTests and the shared PlannerCore scheme. Logs and readback are /private/tmp/PlannerCoreSchemeDiscovery.log, PlannerCoreNativeSchemeDiscovery.log and PlannerCoreNativeSchemeProjectList.json. This completes buildable scheme configuration; its first real store behavior test and cross-platform runtime checks remain required.
