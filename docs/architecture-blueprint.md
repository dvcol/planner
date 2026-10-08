# Architecture blueprint

Approved blueprint for [Core architecture](https://github.com/dvcol/planner/issues/12), under accepted A1-A22 on 2026-10-08. The [decision record](core-architecture.md) records the human answers. This file fixes implementation ownership, native paths/schemes, records, public boundaries and focused commands for feasibility prototypes. It is not a runnable project or runtime evidence.

## Context, starting state and review goal

The source tree contains planning documents. There is no Xcode project, package, app or extension to build. The accepted topology is one multiplatform SwiftUI app, one PlannerCore package, separate mobile/Mac Share extensions, managed private CloudKit mirroring and independent account-scoped recovery. A21/A22 approve the packet's concrete public boundary and schema/ownership candidate. Use /tdd for the code-producing prototypes; approval carries forward for unchanged boundaries. [Shared command contracts](https://github.com/dvcol/planner/issues/13) owns final transport shapes and permissions.

## Project and ownership

| Artifact or responsibility | Approved owner |
| --- | --- |
| `Planner.xcodeproj`, shared `Planner` scheme | Multiplatform `Planner` app; native platform scenes/navigation/menus, resources and conditional extension embedding. |
| `Packages/PlannerCore/Package.swift`, `PlannerCore` library | Domain rules, commands, canonical queries, SwiftData storage, recovery and versioned portability. Use source folders for those responsibilities; no repository layer per entity. |
| `PlannerShareMobile`, `PlannerShareMac` targets and schemes | Native platform Share controllers, payload loading/review/lifecycle, calling the shared Core. |
| `PlannerCore` test scheme | Swift Testing unit suites and real-store integration target `PlannerCoreStoreTests`. |
| `Planner` test scheme | Selected `PlannerUITests` XCUITest journeys on phone, tablet and native Mac. |
| App/extension entitlement and configuration files | Explicit App Group/private CloudKit container, applicable extension configuration and conditional target membership. Apple test access supplies actual identifiers/team/signing; none is invented here. |
| Package dependencies | Swift Package Manager; commit resolved versions when dependencies exist. Foundation/SwiftData/SwiftUI cover this baseline; no third-party search library is required. |

One command owner per process uses an isolated context with autosave explicitly disabled. Native views hold draft values, not unrestricted mutable persistent models. Return Sendable values and Planner-owned IDs across actor boundaries. The same implementation can supply command and query roles; the public split is responsibility, not a requirement for extra packages or contexts. Observation publishes on the main actor and calls canonical Core queries rather than reimplementing completion/search in each adapter.

The following filenames complete the native build documentation within the approved layout. They are planned files; the code-producing prototypes must create and verify them with their source.

| Planned path | Purpose and membership |
| --- | --- |
| `Planner/PlannerApp.swift`, `Planner/Scenes/` | App entry and platform-native scenes; the multiplatform Planner target owns these files. |
| `Packages/PlannerCore/Sources/PlannerCore/` | Shared domain, commands, queries, persistence, portability and recovery folders, all in one library target. |
| `Packages/PlannerCore/Sources/PlannerCore/Persistence/PlannerSchemaV1.swift`, `PlannerSchemaMigrationPlan.swift` | Versioned models and main-app migration plan; app and extensions use the same compiled Core schema. |
| `Packages/PlannerCore/Tests/PlannerCoreTests/`, `PlannerCoreStoreTests/` | Swift Testing unit and real-store integration targets. `CompletionTests` is a selected unit suite; the store target is selected separately by the documented xcodebuild command. |
| `PlannerUITests/` | XCUITest target for selected phone, tablet and native Mac journeys, with platform-appropriate fixtures. |
| `Configuration/Base.xcconfig`, `Planner.xcconfig`, `PlannerShareMobile.xcconfig`, `PlannerShareMac.xcconfig` | Shared/native target settings, OS 27 minimums, platform membership and conditional embedding. Settings do not rely on personal Xcode state. |
| `Configuration/Local.example.xcconfig`, local ignored `Local.xcconfig` | Document actual deployment/signing inputs separately from committed source. Apple test access supplies team, bundle identifiers, App Group, CloudKit container and environment; no value is assumed provisioned. |
| `Planner/PlannerMobile.entitlements`, `Planner/PlannerMac.entitlements` | Platform-appropriate app capabilities selected conditionally by native configuration. Generate the ordinary app Info.plist through Xcode settings. |
| `PlannerShareMobile/Info.plist`, `PlannerShareMobile.entitlements`, `ShareViewController.swift` | Mobile Share product configuration, applicable shared capabilities and native controller. Activation/loader details inherit the capture contracts. |
| `PlannerShareMac/Info.plist`, `PlannerShareMac.entitlements`, `ShareViewController.swift` | Native Mac Share product configuration/capabilities/controller; never embed the mobile product into Mac. |
| `Planner.xcodeproj/xcshareddata/xcschemes/` | Committed Planner, PlannerCore and both Share schemes, with explicit build/test actions and appropriate embedded products. |
| `Planner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, `Packages/PlannerCore/Package.resolved` | Commit applicable resolution files when external dependencies are introduced; verify package and Xcode resolution agree. None exists or is required merely for this documentation. |

Navigation prototype commits the runnable local app/Core/test setup. Sync and share prototype completes extension embedding, signed capabilities, shared-store lifecycle and CloudKit device proof using Apple test access. MCP session prototype adds and verifies its authorized macOS adapter against the same facade. These ownership assignments do not promise any build command has already passed.

## Approved versioned-record design

Start a VersionedSchema at the first persisted schema. Cloud-backed attributes need supported defaults; relationships must be optional with appropriate inverses, without unique constraints, deny deletion or ordered relationships. Persist explicit logical IDs, source lifetimes and scalar ranks. A22 approves this implementation candidate; real-store/CloudKit proof remains required.

| Record | Fields and ownership to specify |
| --- | --- |
| Item | Planner UUID, source lifetime UUID, title, optional subtitle, notes, global Done, archive state, creation/Item Last updated, owned links/location/provenance and optional estimated whole minutes with retained display unit. |
| List | Planner UUID/lifetime, name/presentation metadata, archive and timestamps. Completion is derived, never a stored parent override. |
| Itinerary | Planner UUID/lifetime, title/notes/presentation metadata, archive/timestamps and owned links/location. Categories/Tags remain shared references; completion is derived. |
| Category / Tag | Separate stable UUID/lifetime, name/color/icon and timestamps. Names may duplicate; references do not copy label metadata. |
| List membership | Immutable association identity, owner/source identity and lifetime binding, local Done and scalar order rank. Ordinary remove/readd creates a new association; one effective membership per live Item/List pair. |
| Itinerary entry | Immutable entry identity, owning itinerary/source bindings, source kind and scalar rank. A direct Item entry stores its local Done. Intentional repeated additions have distinct entry identities. |
| Expanded List child state | Context key made from the List-entry lifetime and membership lifetime, plus local Done. Missing state means Todo. Two repeated List entries have distinct keys without copying source Items; reorder preserves keys. |
| Schedule | Stable UUID/lifetime, Item/Itinerary binding and either inclusive Gregorian civil dates or fixed start/optional-end Date instants with planning-zone identifier. No estimate-derived end. |
| Label association / owned Link | Explicit owner/target binding or owned bookmark fields, stable identity and required saved order. Capture provenance distinguishes user content, original bookmarks and permitted identifiers from transient previews. |
| Deletion identity metadata | Entity kind, logical ID/lifetime, operation identity and only necessary alias/restoration lineage. No deleted content. Accepted A16 includes this data in portable backups; A20 requires one concurrent restored version. |
| Internal operation receipt | Operation UUID, canonical payload digest, dataset/ownership binding, result identities and local outcome/checkpoint evidence. This is internal recovery state, excluded from portable data JSON. |

One stable public identity can acquire a new authorized lifetime after restoration. Native framework IDs are store-scoped and are not JSON identities. An association's immutable UUID can itself identify its lifetime unless original-association restoration requires preserving that public UUID. Avoid adding another ID where it has no role.

Use gapped signed integer ranks with immutable association/entry UUID ties. Concurrent independent insertions can share rank and still retain every member once. Rebalancing changes ranks, not membership arrays or source content. Duplicate standalone memberships and duplicate physical completion records need deterministic identity reconciliation; A17 supplies their local-completion outcome. Never deduplicate intentional repeated itinerary entries. Same-record native conflict winning does not itself reconcile two physical records that share a Planner ID.

Date values remain native: fixed timed instants use Date, planning zones use identifiers and all-day spans use civil year/month/day components. Estimates use optional positive Int64 whole minutes and checked fixed-unit arithmetic; retained unit controls display without Calendar month/year arithmetic. The packet supplies native representability validation; contracts supply exact transport encoding/budgets; native picker interaction remains Navigation prototype work.

The [approved architecture packet](architecture-review-packet.md) supplies concrete public fields/methods, native validation, reconciliation provenance, checkpoint sequence and evidence matrix under A21/A22.

## Approved public service outlines

The following roles belong to the packet's one approved Planner facade, not four required service instances. A21 approves the public field/method shapes; declaration compilation and runtime implementation belong to /tdd prototypes.

| Role | Approved public calls and observable values |
| --- | --- |
| Commands | Execute a mutation request carrying operation identity, dataset identity and typed command. Provide preview/approval for actions that already require confirmation. Query the status of the same operation; retry its recovery checkpoint without replaying its mutation. |
| Queries | Query Items in global/List scope; query itinerary entries and expanded appearances; fetch a selected source/appearance independently of its current filter; return effective completion and full-scope progress. Matching/sort uses native Foundation APIs. |
| Portability | Decode/validate a versioned data file, create immutable Skip/Overwrite preview, then apply the approved selection under the same command owner. Export portable data without presentation state or credentials. |
| Recovery | Establish independent checkpoint, inspect/export old account data and prepare explicit restoration. Report namespace-scoped observations; it does not force CloudKit synchronization or invent per-save upload receipts. |

Mutation cases include create/edit Item and container metadata, global Item Complete/Reopen, local appearance Complete/Reopen, confirmed full-context bulk completion, Archive/Unarchive, confirmed Delete, label editing/deletion, add/remove/move membership, ordered itinerary addition/reorder/removal, manual Schedule changes, reviewed capture create/reuse and approved import. A source Item ID and an appearance identity are different inputs. Native containers cannot call global completion as a fallback for a missing appearance.

An appearance identity denotes a standalone membership, direct itinerary entry or the pair of List-entry/membership identities. Result rows identify source and appearance separately. Query results carry an immutable generation UUID and complete ordered lightweight identity sequence; native batched fetching and lazy realization avoid retaining full detail content for every row. The UI cancels obsolete work and publishes only the current generation. A synchronous fetch may still finish after cancellation, so discarding stale output is required. The approved packet spells out public status/data fields using accepted A1-A22.

Known operation outcomes are unapplied failure, complete commit with recovery incomplete and independently recoverable success. Approval-required, stale-target/account, invalid input and unsupported schema errors do not mutate. Precommit cancellation changes nothing; postcommit cancellation resolves the operation and cannot mean rollback. Accepted A19 reports prepared-only lost-evidence outcomes as unverified. A18 blocks further Planner mutations in the affected dataset until known incomplete recovery succeeds, preserving reads/search/export. Neither case implies a CloudKit delivery pause. Surface authorization remains separate from domain behavior and must apply to import-triggered deletions as well as direct Delete.

## Recovery and account protocol to prove

The prototype candidate coordinates participating Planner writers/migration through one App Group control URL. A process-local ModelActor cannot serialize the app and extension. Resolve network account observations outside the coordinated section; inside it use fresh context/ownership checks, validate the operation/payload/targets, preserve prepared data, commit the complete action plus receipt and publish an independent logical archive with completed receipt evidence. R21 acknowledgement follows the archive checkpoint. A15 defines known postcommit copy failure; A19 covers loss of committed evidence.

The internal archive envelope adds account/container/environment binding, dataset/store epoch, generation and minimal receipts to the portable data portion. Prepared proposals are explicitly distinct from acknowledged state. Old-account envelopes never automatically enter another account's mirror. Minimal receipt retention must cover replay; no arbitrary timer proves an operation can no longer replay.

This is not a lock on Apple's account transitions or CloudKit writes. CKAccountChanged and account-status observations are asynchronous. Never read a live store after commit and label its snapshot with a previously observed account ID without validating immutable ownership. A coherent complete snapshot, epoch checks, mismatch quarantine and automatic-mirroring races are hard feasibility gates. If the prototype cannot establish them, do not acknowledge the checkpoint or claim this design passed.

## Focused native commands

Read-only inventory on 2026-10-08 found Xcode 27.0, build 27A266a, Swift 6.4 and iOS/iPadOS/macOS 27 SDKs. The machine default still uses Command Line Tools; every command below scopes DEVELOPER_DIR without changing global selection. No project command below has run because the named project/targets do not exist.

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Planner.xcodeproj -list -json
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Planner.xcodeproj -scheme Planner -showdestinations
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Planner.xcodeproj -scheme Planner -resolvePackageDependencies -onlyUsePackageVersionsFromResolvedFile
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project Planner.xcodeproj -scheme Planner -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project Planner.xcodeproj -scheme Planner -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project Planner.xcodeproj -scheme PlannerShareMobile -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project Planner.xcodeproj -scheme PlannerShareMac -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path Packages/PlannerCore --filter CompletionTests
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Planner.xcodeproj -scheme PlannerCore -destination 'platform=macOS,arch=arm64' -only-testing:PlannerCoreStoreTests -resultBundlePath /private/tmp/PlannerCoreStoreTests.xcresult
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Planner.xcodeproj -scheme Planner -destination 'platform=iOS Simulator,id=2A49C66C-C8A4-435F-B98A-9A90706780DE' -only-testing:PlannerUITests -resultBundlePath /private/tmp/PlannerPhoneUITests.xcresult
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Planner.xcodeproj -scheme Planner -destination 'platform=iOS Simulator,id=9FDD646F-2828-42FD-97C4-6EF3455D8E08' -only-testing:PlannerUITests -resultBundlePath /private/tmp/PlannerPadUITests.xcresult
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Planner.xcodeproj -scheme Planner -destination 'platform=macOS,arch=arm64' -only-testing:PlannerUITests -resultBundlePath /private/tmp/PlannerMacUITests.xcresult
```

The observed simulators are iPhone 18 Pro and iPad Pro 13-inch M5 on iOS 27. Revalidate destination IDs before execution and use fresh result-bundle paths. Discover executed test counts and inspect correct embedded extension products/entitlements. Unsigned builds do not establish signed Share/CloudKit behavior. Physical-device gates retain [Apple test access](https://github.com/dvcol/planner/issues/7); package tests cannot replace them. Swift compile/build checks and native formatting lint target affected sources/products.

The installed native formatter supports `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift format lint --strict` followed by explicit affected Swift file paths. Its help was checked; source lint has not run. Use `--recursive` only for an affected source directory, and retain invalid-syntax diagnostics. No placeholder source path is an executable check for this document.

## Required prototype evidence

| Boundary | Independent expectation and level |
| --- | --- |
| Completion/query unit tests | Hotel/Museum gives 1 of 3, global Hotel Done gives 2 of 3, Global Reopen restores retained local flags. Repeated List children remain independent; source/label edits remain live. |
| Portability unit/store tests | Exact accepted Skip/Overwrite, complete-owner dependency skips, confirmed restoration, omitted-source retention, repeat-import no-op and whole-invalid-file rejection. Reopen the store with the same logical IDs/order/states. |
| Command/store recovery integration | Precommit failure leaves no action. Postcommit copy failure retains the entire action and completes recovery without replay. Exercise every receipt/preparation/copy checkpoint and account-binding mismatch. A18 refuses the next affected-dataset mutation until recovery completes; A19 preserves lost-evidence proposals as unverified, requiring fresh explicit review. |
| Native and physical sync tests | Both reconnect orders preserve independent title/notes edits, delete defeats stale edits, every membership survives ordering convergence, duplicate contexts obey A17 and authorized restorations obey A20. Native account resets cannot leak old data into another account. |
| Query/store/UI performance | Complete 5,000-Item/200-List matching beyond the first window, exact sort/identity sequence, no omitted/duplicate rows, current results within 300 ms, discarded stale generations, valid filtered-out selection and measured platform scrolling/memory. |
| Adapter/UI equivalence | Allowed SwiftUI/Share/Intents/MCP operations share Core IDs/state/outcomes, while surface permissions can differ. Full-context bulk actions ignore filters and never become global completion. Native layout/accessibility and device presentation are reviewed in their prototype. |

A21/A22 already approve the Core public boundary, schema/ownership candidate and native value validation. Contracts supplies exact transport/loader/network budgets. Each code-producing prototype commits runnable configuration, works one independently specified failing behavior and its minimum passing implementation, and records focused build/lint/test counts/result artifacts. These runtime gates have not yet passed; unchanged approval is not requested again.
