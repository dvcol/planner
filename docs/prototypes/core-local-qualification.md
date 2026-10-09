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

## Default Item query

The next slice supplies the default Item identity query needed for the prototype's public count/readback checks. Museum is created first, then Hotel. Query returns Hotel then Museum with count 2, and a new facade returns those same source identities after reopening. Both returned identities remain readable as Todo/Active. Query fetches the identity/title/global/archive projection without loading full notes or computing content hashes. It uses the accepted case/diacritic-insensitive Foundation [String.Comparator initializer](https://developer.apple.com/documentation/swift/string/comparator/init(options:locale:order:)) with en_US_POSIX and stable UUID tie ordering.

The executable red runs one query test, failing because queries are unimplemented. Green runs all ten Core store tests successfully. The same ten pass through the package target. Generic iOS test-bundle compilation and thirteen affected app transport tests pass; source/document lint pass. The [actual summaries](evidence/mcp/core-default-query.json) retain the counts and failure text.

This is the default Item query and a partial native DTO. Full text/filter/sort/catalog/window variants, contextual queries, international fixtures and the 5,000-Item/200-List performance gate remain future evidence. List/Itinerary query scopes fail unavailable. The current Item-only schema has no memberships, so its Inbox is the full Item set; no membership data is guessed or copied. No actual selected-client or iOS runtime proof is claimed.

Result bundles are `/private/tmp/PlannerCoreDefaultQueryRed.xcresult` and `/private/tmp/PlannerCoreDefaultQueryGreen.xcresult`; matching logs record their execution.

## Item Archive and Unarchive

The accepted setArchive command now applies to Item sources through the existing coordinated writer/recovery sequence. Archive changes its own flag and Item Last updated when the flag changes, retaining identity/lifetime, content and global completion. It records the immutable operation payload with its original resolved lifetime, preserves a proposal before commit, saves the Item and receipt together and publishes independent recovery before complete acknowledgement. Other source kinds remain unavailable in this Item-only fixture. No migration or new persisted state is added.

The executable red runs one archive function and fails at the explicitly unimplemented command. Green runs all eleven Core store functions. Hotel/Tokyo/Original notes, its independently owned location and 91-minute estimate remain intact after Archive and reopening. Content hashes and creation time remain unchanged; global Todo remains Todo. The ordinary Active query becomes empty, the Archived query discovers the original Item and its independently decoded checkpoint 2 contains the same retained values with archived true.

A subsequent Unarchive/replay function passes existing implementation on first execution; no additional red or production change is claimed for it. Unarchive restores ordinary visibility at checkpoint 3. Reopening and replaying the earlier Archive operation returns its original result/checkpoint 2 without reapplying archived true. Changing that earlier operation's payload to archived false rejects as operationPayloadMismatch. Current content, timestamp, field hashes, visibility and checkpoint 3 remain intact.

[Actual archive evidence](evidence/mcp/core-archive.json) records red 1, green 11, Unarchive qualification 12 and affected MCP regression 19 functions. The same twelve Core store functions pass through the package across four suites, and the native Core test bundles compile for generic iOS Simulator. Source/document lint pass. Bundles/logs are /private/tmp/PlannerCoreArchiveRed, PlannerCoreArchiveGreen, PlannerCoreUnarchiveReplayQualification and PlannerMCPArchiveCoreRegression with xcresult/log extensions. The fixture starts globally Todo; globally Done, container/reference preservation, real failure/interruption, cross-process and physical CloudKit cases remain unqualified.

## Precommit recovery access failure

[Actual obstruction evidence](evidence/mcp/core-recovery-obstruction.json) records one passing native function and thirteen passing Core package functions across five suites. After saving Hotel with complete independent recovery, the fixture moves the configured recovery directory to a retained sibling and replaces its original location with a regular file. Creating Museum returns rejected/persistenceFailure with a useful message. It then restores the retained directory and opens a fresh facade. Public reads/query discover exactly the original Hotel/Original notes, Todo/Active, with unchanged creation/update dates and field hashes. The failed Museum operation has noReliableEvidence; Hotel's original result/checkpoint stays complete. Native recovery inspection retains that checkpoint, no prepared proposal and the independent original Hotel snapshot.

This is genuine filesystem I/O at the approved storage configuration boundary. The test reads no private filenames or database tables, and adds no production failure callback. Existing implementation passes the first executable run; no red or production change is claimed. This obstruction prevents recovery access before proposal and commit. It does not prove a SwiftData-save failure, prepared-only interruption, postcommit applied/incomplete recovery, blocked mutation/retry or cross-process coordination. Those cases remain required separately.

Native bundle/log are /private/tmp/PlannerCoreRecoveryObstructionQualification.xcresult and PlannerCoreRecoveryObstructionQualification.log. The affected package regression log is /private/tmp/PlannerCoreRecoveryObstructionPackage.log. Both use the recorded Mac/toolchain and real disposable disk stores. The native command selects only PlannerCoreStoreTests/RecoveryFailureTests; the package command selects PlannerCoreStoreTests. Source/document lint pass.

## Generation-bound owned Item rows

The accepted [Q43–Q46 row contract](../navigation-row-contract-review.md) now has its first real-store read slice. Item queries capture a finite reference instant and valid display timezone once per generation. The caller can supply that presentation context; omitted values use the native current instant/zone. Window reads retain the query's context, count and ordered source identities. They fetch only the requested Item titles, subtitles, estimates, owned locations and completion/archive flags; full notes and field hashes are not part of each row.

The first executable package red failed because the row read was unavailable. Its green reopens the actual disk store and returns Nezu Museum's separately owned Meeting point A, coordinate and 120-minute estimate in the supplied Tokyo context. A second red exposed an old Active query returning an Item another facade had since archived. Binding queries and windows to the latest native SwiftData history token fixes that case: the old generation returns typed staleSnapshot; a fresh query returns only Museum. Query construction and projection check the history token before and after the read. This is two facades on the same local store, not cross-process or CloudKit proof.

Two further functions passed existing implementation on first execution. They verify independent Tokyo/Paris generations, empty and moving windows, Int64.max ranges without overflow, rejection of negative offsets/nonpositive limits, and rejection when a generation is reused through another issued dataset session. Invalid finite-time/timezone inputs return precise paths without invalidating a prior valid query. These are qualification checks, not additional red/green cycles.

[Actual row evidence](evidence/navigation/core-owned-rows.json) retains both package red/green pairs, all seventeen passing store functions, four passing native Xcode row functions and successful generic iOS Simulator test-bundle compilation. Strict Swift formatting and changed-document lint pass. The accepted public Planner facade remains the test boundary; tests use real temporary SwiftData and independent recovery locations.

This slice projects the existing Item-only store. It has no saved links, schedules, memberships or appearances, so previewLink remains null, scheduleSummary is none and localDone is null. It performs no provider I/O. The accepted full graph, schedule priority/additional counts, first non-Maps bookmark, contextual completion, native row interaction, window performance and MCP row serialization still require their own slices. Previous native screenshots describe their recorded source revision; they do not qualify this changed Core dependency.

Row logs are /private/tmp/PlannerCoreOwnedRowRed.log, PlannerCoreOwnedRowGreen.log, PlannerCoreStaleRowsRed.log, PlannerCoreStaleRowsGreen.log and PlannerCoreOwnedRowsPackageQualification.log. Native bundles/logs are /private/tmp/PlannerCoreOwnedRowsNativeQualification.xcresult and PlannerCoreOwnedRowsNativeQualification.log. The simulator build log is /private/tmp/PlannerCoreOwnedRowsSimulatorBuild.log; compilation is not an iOS runtime result.

## Global Item completion and Reopen

The accepted setCompletion command now has a globalItem scope through the public facade. It changes only the selected Item's globalDone and its own Last updated when the flag changes. Content, content hashes, archive state and creation identity/time remain intact. It uses the existing coordinated prepare/save/publish/receipt sequence and resolved Item lifetime binding. Archive and global completion share that sequence while retaining different immutable command fingerprints; Archive's existing canonical payload is unchanged. No persisted schema change is required.

The [executed completion red](evidence/navigation/core-item-completion.json) fails at the unimplemented command. Green passes all eighteen Core store functions. The new journey completes an archived Hotel, invalidates its old Todo window, reopens the disk store and reads global/effective Done with localDone null. The Done query discovers Hotel and Todo does not. Source content/hashes/archive, recorded operation status and independently decoded checkpoint 3 retain the accepted values.

One further function passed existing implementation on first execution. An explicit same-state operation receives its own acknowledged checkpoint without changing the Item's timestamp/hashes. Global Reopen saves Todo at checkpoint 4. Replaying the earlier Done operation after reopening returns its original result/checkpoint 2, preserving current Todo, timestamp/content and checkpoint 4. Reusing that operation ID with done false or with Archive rejects operationPayloadMismatch. A missing Item rejects before recorded applied evidence; all failed actions preserve Hotel and an empty prepared-proposal catalog.

The package qualification passes nineteen functions across seven suites. Both completion functions pass in the native Core target; all 24 affected MCP functions pass. Generic iOS Simulator Core test bundles compile; this is not an iOS runtime result. Strict source/document lint and diff checks pass. Package logs are /private/tmp/PlannerCoreItemCompletionRed.log, PlannerCoreItemCompletionGreen.log and PlannerCoreItemCompletionQualification.log. Native bundles/logs use PlannerCoreItemCompletionNativeQualification and PlannerMCPItemCompletionRegression with xcresult/log extensions. The simulator build log is PlannerCoreItemCompletionSimulatorBuild.log.

This is global Item scope only. Appearance-local and bulk completion, the Q44 disabled contextual control, saved Lists/Itineraries, native checkbox writes and the MCP completion command still require their own slices. These tests do not prove cross-process/CloudKit state merging, account transitions, save/publication interruption or historical migrations. The completed command never copies global completion into local flags; the current schema has no such records, so that full-graph behavior remains to be proved.

## Reproduction

Use unique result-bundle paths on rerun. Scope DEVELOPER_DIR to the accepted Xcode installation.

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Planner.xcodeproj -scheme PlannerCore -destination 'platform=macOS,arch=arm64' -only-testing:PlannerCoreStoreTests/ItemCreationTests -onlyUsePackageVersionsFromResolvedFile -clonedSourcePackagesDirPath /private/tmp/PlannerMCPSourcePackages -derivedDataPath /private/tmp/PlannerCoreFixtureDerivedData -resultBundlePath /private/tmp/PlannerCoreItemCreationGreen.xcresult
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path Packages/PlannerCore --filter ItemCreationTests --scratch-path /private/tmp/PlannerCoreFixturePackageBuild
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift format lint --strict --recursive Packages/PlannerCore/Sources/PlannerCore Packages/PlannerCore/Tests/PlannerCoreStoreTests
```

Native red: `/private/tmp/PlannerCoreItemCreationExecutableRed.xcresult`; green: `/private/tmp/PlannerCoreItemCreationGreen.xcresult`. Matching `.log` files record builds and execution. The first sandboxed invocation could not access Xcode's normal package caches. The first green attempt hit a compiler type-checking limit in byte assembly. Neither was counted as an executed behavior failure. The actual red/green ran on arm64 macOS 27.0.1 build 26A434 using Xcode 27.0 build 27A266a and Swift 6.4.

This evidence does not establish signed App Groups, Share execution, CloudKit ownership/cutoff, account resets, physical-device convergence, migrations across historical schemas, native UI, signed credential reading or real MCP client routes. Those original gates remain required.
