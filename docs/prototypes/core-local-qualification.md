# Local Core fixture evidence

The accepted [Q36 fixture](core-local-fixture-review.md) now has one executed native store journey. This is partial evidence for [MCP session prototype](https://github.com/dvcol/planner/issues/16), which remains open. The implementation is a disposable local prototype, with CloudKit mirroring disabled.

## Create, reopen and inspect independent recovery

`ItemCreationTests.savedItemSurvivesReopenWithIndependentAcknowledgedRecovery` uses only Planner's accepted public bootstrap/execute/read/operationStatus/inspectRecovery methods. It creates a fresh on-disk SwiftData dataset, saves Hotel with Original notes, reads it, opens a new facade against the same locations, and reads the original operation's completed evidence. Native namespace discovery and checkpoint selection independently return the same identity/content and Todo/Active state. Construction alone creates no directory.

The executable red discovered and ran one test. It failed at explicit bootstrap returning the unimplemented-storage outcome. After implementation, the same native test passed, with no skips or expected failures. Swift Package Manager ran the same source and passed one test. The affected app's 13 MCP transport test functions passed. Native Core test bundles compiled for the generic iOS simulator destination; no iOS runtime test is claimed. Swift format lint and changed-document Markdown lint passed. The [actual native summaries](evidence/mcp/core-item-creation.json) preserve the counts and failure text.

The prototype uses private defaulted/optional SwiftData models under VersionedSchema 1 and its migration plan. A stable NSFileCoordinator control URL coordinates participating writers. Every action opens a fresh context with autosave disabled, validates the issued dataset session, preserves prepared evidence independently, then commits Item plus operation receipt together. A completed envelope is published separately before the result reports complete recovery. Database-only evidence cannot report completed recovery.

The independent archive contains data-only portable bytes with all declared root groups present, their exact-byte SHA-256 digest, ownership/checkpoint binding and minimal internal operation evidence. This initial projection supports Items only. Other graph groups must be empty during validation, and nonempty link/label creation returns unavailable rather than dropping data. Public declarations currently cover this slice; full source/read/result unions, portable graph types, additional commands and adapter serialization remain future work. Failure/interruption, competing writers and hostile-file cases still require their own tests.

## Replay and validation qualification

Three additional scenarios were added and executed one at a time through the same accepted facade. Each passed the existing implementation on its first run, requiring no production change. They are qualification checks, not additional red/green cycles.

- An identical create replay after reopening returns the original Item/result/checkpoint, with one recovered Item and no new checkpoint.
- Reusing the applied operation ID with Museum/Different notes rejects as operationPayloadMismatch. Hotel/Original notes and the original completed operation evidence remain unchanged; the snapshot still contains one Item.
- A new create with a whitespace-only title rejects as invalidInput at `/command/content/title`. Hotel's identity/content, checkpoint and empty prepared-proposal catalog remain unchanged.

The final qualification run discovers and executes four test functions, all passing with no skips or expected failures. The [actual summaries](evidence/mcp/core-creation-qualification.json) preserve the sequential two-, three- and four-test runs. Their result bundles are `/private/tmp/PlannerCoreItemReplayQualification.xcresult`, `/private/tmp/PlannerCoreChangedReplayQualification.xcresult` and `/private/tmp/PlannerCoreInvalidCreationQualification.xcresult`.

## Guarded notes edit

The next vertical slice adds the accepted typed Item changes and guarded edit case. Its executable red runs one test and rejects the edit as unimplemented. Its green runs that test plus the four existing creation checks, all passing. Hotel's notes change from Original notes to Friday booking while its identity, creation date, title hash, empty references and Todo/Active flags survive reopening. Operation status and a new independently decoded checkpoint retain the edited content.

Two subsequent qualification scenarios passed the green implementation on their first execution. A Monday booking edit using the old Original notes hash rejects as staleEdit, identifying the current Friday booking and current notes hash, while retaining the source timestamp/hashes/checkpoint. Replaying the acknowledged Friday edit after a later Saturday edit returns Friday's original result/checkpoint without replacing Saturday or advancing recovery. Echoing known hashes for unchanged fields does not alter that replay payload.

This slice supports notes Set/Clear only; other changed fields return unavailable. It performs the changed-field comparison in the same coordinated writer section as the complete action. Private receipt evidence now retains the original resolved binding for replay without changing the persisted VersionedSchema 1 attributes. The original creation-only receipt representation remains readable. This is not a historical-schema migration or account-reset replay proof.

The [actual notes-edit evidence](evidence/mcp/core-notes-edit.json) records the one-test red, five-test green, six- and seven-test qualification runs, five-test package run, thirteen-test affected app regression and generic iOS test-bundle compilation. Each native run has zero skips or expected failures. Source lint passed. No iOS runtime, fixed-context independent hash-vector, full compound-edit, competing-writer or physical CloudKit result is claimed.

Notes result bundles are `/private/tmp/PlannerCoreNotesEditRed.xcresult`, `/private/tmp/PlannerCoreNotesEditGreen.xcresult`, `/private/tmp/PlannerCoreStaleNotesQualification.xcresult` and `/private/tmp/PlannerCoreNotesReplayQualification.xcresult`. Matching logs record builds and execution. The affected app log retains metadata-extraction and com.apple.linkd.autoShortcut diagnostics; its thirteen transport tests pass, and this evidence does not qualify App Intents or dismiss those diagnostics as pre-existing.

## Independent text-field guards

The next slice extends that notes-only implementation to title Set and notes Set/Clear. An unrelated title edit changes Hotel to Tokyo Hotel while leaving Original notes and its prior hash intact. A subsequent notes-only edit accepts the earlier read, including its now-stale unchanged title hash, and preserves Tokyo Hotel after reopening. Payload fingerprints include only changed fields and their required hashes.

The executable red ran four edit tests, with the new title behavior failing as unavailable and the previous three passing. Its green runs all eight Core store tests, all passing. An earlier individual-test selector discovered zero tests and is explicitly excluded from behavior evidence.

A subsequent whole-patch qualification passed on its first execution. After Friday booking is saved, a patch proposing Tokyo Hotel and Monday booking from the earlier read has one stale field. It rejects the complete patch, reports only notes as conflicting, and retains Hotel/Friday booking, source timestamps/hashes and the acknowledged checkpoint with no prepared proposal.

The [actual text-field summaries](evidence/mcp/core-text-fields.json) record the four-test red, eight-test green, nine-test final qualification/package runs, thirteen-test affected app regression and generic iOS test-bundle compilation. Source and changed-document lint pass. Other changed content fields still return unavailable. No compound edit, fixed-context vector, competing-writer, account-reset or physical CloudKit evidence is claimed.

Result bundles are `/private/tmp/PlannerCoreUnrelatedFieldExecutableRed.xcresult`, `/private/tmp/PlannerCoreUnrelatedFieldGreen.xcresult` and `/private/tmp/PlannerCoreAtomicTextPatchQualification.xcresult`. The zero-test selection run is `/private/tmp/PlannerCoreUnrelatedFieldRed.xcresult`.

## Reproduction

Use unique result-bundle paths on rerun. Scope DEVELOPER_DIR to the accepted Xcode installation.

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Planner.xcodeproj -scheme PlannerCore -destination 'platform=macOS,arch=arm64' -only-testing:PlannerCoreStoreTests/ItemCreationTests -onlyUsePackageVersionsFromResolvedFile -clonedSourcePackagesDirPath /private/tmp/PlannerMCPSourcePackages -derivedDataPath /private/tmp/PlannerCoreFixtureDerivedData -resultBundlePath /private/tmp/PlannerCoreItemCreationGreen.xcresult
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path Packages/PlannerCore --filter ItemCreationTests --scratch-path /private/tmp/PlannerCoreFixturePackageBuild
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift format lint --strict --recursive Packages/PlannerCore/Sources/PlannerCore Packages/PlannerCore/Tests/PlannerCoreStoreTests
```

Native red: `/private/tmp/PlannerCoreItemCreationExecutableRed.xcresult`; green: `/private/tmp/PlannerCoreItemCreationGreen.xcresult`. Matching `.log` files record builds and execution. The first sandboxed invocation could not access Xcode's normal package caches. The first green attempt hit a compiler type-checking limit in byte assembly. Neither was counted as an executed behavior failure. The actual red/green ran on arm64 macOS 27.0.1 build 26A434 using Xcode 27.0 build 27A266a and Swift 6.4.

This evidence does not establish signed App Groups, Share execution, CloudKit ownership/cutoff, account resets, physical-device convergence, migrations across historical schemas, native UI, signed credential reading or real MCP client routes. Those original gates remain required.
