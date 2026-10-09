# Local Core fixture evidence

The accepted [Q36 fixture](core-local-fixture-review.md) now has one executed native store journey. This is partial evidence for [MCP session prototype](https://github.com/dvcol/planner/issues/16), which remains open. The implementation is a disposable local prototype, with CloudKit mirroring disabled.

## Create, reopen and inspect independent recovery

`ItemCreationTests.savedItemSurvivesReopenWithIndependentAcknowledgedRecovery` uses only Planner's accepted public bootstrap/execute/read/operationStatus/inspectRecovery methods. It creates a fresh on-disk SwiftData dataset, saves Hotel with Original notes, reads it, opens a new facade against the same locations, and reads the original operation's completed evidence. Native namespace discovery and checkpoint selection independently return the same identity/content and Todo/Active state. Construction alone creates no directory.

The executable red discovered and ran one test. It failed at explicit bootstrap returning the unimplemented-storage outcome. After implementation, the same native test passed, with no skips or expected failures. Swift Package Manager ran the same source and passed one test. The affected app's 13 MCP transport test functions passed. Native Core test bundles compiled for the generic iOS simulator destination; no iOS runtime test is claimed. Swift format lint and changed-document Markdown lint passed. The [actual native summaries](evidence/mcp/core-item-creation.json) preserve the counts and failure text.

The prototype uses private defaulted/optional SwiftData models under VersionedSchema 1 and its migration plan. A stable NSFileCoordinator control URL coordinates participating writers. Every action opens a fresh context with autosave disabled, validates the issued dataset session, preserves prepared evidence independently, then commits Item plus operation receipt together. A completed envelope is published separately before the result reports complete recovery. Database-only evidence cannot report completed recovery.

The independent archive contains data-only portable bytes with all declared root groups present, their exact-byte SHA-256 digest, ownership/checkpoint binding and minimal internal operation evidence. This initial projection supports Items only. Other graph groups must be empty during validation, and nonempty link/label creation returns unavailable rather than dropping data. Public declarations currently cover this slice; full source/read/result unions, portable graph types, commands and adapter serialization remain future work. The native storage and recovery boundaries are implemented, but failure/interruption, competing writers, replay and hostile-file cases still require their own tests.

## Reproduction

Use unique result-bundle paths on rerun. Scope DEVELOPER_DIR to the accepted Xcode installation.

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Planner.xcodeproj -scheme PlannerCore -destination 'platform=macOS,arch=arm64' -only-testing:PlannerCoreStoreTests/ItemCreationTests -onlyUsePackageVersionsFromResolvedFile -clonedSourcePackagesDirPath /private/tmp/PlannerMCPSourcePackages -derivedDataPath /private/tmp/PlannerCoreFixtureDerivedData -resultBundlePath /private/tmp/PlannerCoreItemCreationGreen.xcresult
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path Packages/PlannerCore --filter ItemCreationTests --scratch-path /private/tmp/PlannerCoreFixturePackageBuild
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift format lint --strict --recursive Packages/PlannerCore/Sources/PlannerCore Packages/PlannerCore/Tests/PlannerCoreStoreTests
```

Native red: `/private/tmp/PlannerCoreItemCreationExecutableRed.xcresult`; green: `/private/tmp/PlannerCoreItemCreationGreen.xcresult`. Matching `.log` files record builds and execution. The first sandboxed invocation could not access Xcode's normal package caches. The first green attempt hit a compiler type-checking limit in byte assembly. Neither was counted as an executed behavior failure. The actual red/green ran on arm64 macOS 27.0.1 build 26A434 using Xcode 27.0 build 27A266a and Swift 6.4.

This evidence does not establish signed App Groups, Share execution, CloudKit ownership/cutoff, account resets, physical-device convergence, migrations across historical schemas, native UI, signed credential reading or real MCP client routes. Those original gates remain required.
