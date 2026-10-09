# Apple test access

Partial setup evidence for [Apple test access](https://github.com/dvcol/planner/issues/7), refreshed on 2026-10-09 for Navigation prototype readiness. The read-only refresh matches the 2026-10-08 inventory below. Subsequent local native/Core/MCP execution is recorded separately below. Selected-team signing, physical-device launch, CloudKit access and extension execution remain unverified.

## Observed environment

| Check | Observed result | What it proves |
| --- | --- | --- |
| Host | Apple silicon, macOS 27.0.1, build 26A434 | The local Mac meets the runtime minimum. Local test-host execution is recorded below; provisioned app launch remains unverified. |
| Default developer directory | `/Library/Developer/CommandLineTools` | Unqualified `xcodebuild` fails because the default points to Command Line Tools. |
| Full Xcode installation | `/Applications/Xcode.app`, Xcode 27.0, build 27A266a | A full OS 27 toolchain is installed and can be selected per command. |
| Swift compiler | Scoped Xcode and default `swift --version` both report Apple Swift 6.4 | Compiler discovery succeeds after the OS upgrade; use scoped Xcode selection for builds. |
| SDK discovery | iOS 27.0, iOS Simulator 27.0, macOS 27.0 | The required SDKs are present; SDK discovery is not an app build. |
| Xcode first-launch status | `xcodebuild -checkFirstLaunchStatus` exited 0 | The command reports no outstanding first-launch prerequisite. |
| Simulator runtime | iOS 27.0, build 24A434, available | An appropriate mobile runtime is installed. |
| Simulator destinations | Five available iPhone and six available iPad destinations for iOS 27 | Mobile prototype destinations exist; no simulator was booted or app launched. |
| Human-reported physical devices | The user has an iPhone and iPad running OS 27 available | Ownership/availability is confirmed by the user; exact model, OS build, pairing and Developer Mode remain to verify. |
| Physical-device discovery | Refreshed `devicectl list devices` succeeded with an empty device list | The available devices are not yet discoverable by this Xcode host. Pairing/connection and signed execution remain unverified. |
| Signing, team, iCloud account, container and App Group | A 2026-10-09 read-only signing inventory finds zero valid identities; selected team and provisioned identifiers remain unverified | The local app uses ad hoc signing. Selected-team, Keychain-reader, App Group and CloudKit checks remain required. |

The 2026-10-07 macOS 26.6.2 observation is superseded by this refresh. Current host-access simulator and device discovery succeeded. Initial sandbox failures on the previous run did not establish missing runtimes or devices. The developer-directory default was not changed.

## When an account is needed

Account requirements were checked against current Apple documentation on 2026-10-08. An Apple Developer Program membership is not a prerequisite for continuing domain decisions, local Swift package work, local-only persistence tests, simulator UI work, or ordinary local Mac execution. The installed Xcode can run that work before team selection. Capabilities that require provisioning add their own setup requirements. See Apple's [simulator and physical-device workflow](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices) and [local package workflow](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages).

| Work | Account or capability gate | What remains unverified here |
| --- | --- | --- |
| Specification, local PlannerCore tests, simulator layouts and ordinary local Mac prototype | No paid membership required. | Native project, agreed Core/HTTP/UI seams and local evidence are supplied below. Navigation comparisons and final human review remain open. |
| Basic personal iPhone/iPad app testing | A free Apple Account signed into Xcode can use a Personal Team. | Selected team, device pairing, Developer Mode, provisioning and actual launches. |
| Private CloudKit setup and two-device synchronization | Access to an active Apple Developer Program team with appropriate setup authority. | Container selection, account arrangement, entitlements and actual development/production access. |
| App Group configuration for app/Share targets | Apple currently lists App groups as available to free Apple Developers on iOS and macOS; verify the actual selected team's arrangement. | Group registration/configuration, signing and cross-process access for the chosen targets. |

Personal Team provisioning requires periodic rebuilding/reinstallation. Apple currently lists ten App IDs, three devices and up to three installed apps per device, with seven-day expiration limits. This makes basic personal-device testing possible before paid enrollment, subject to the capabilities in that build. [Apple account overview](https://developer.apple.com/help/account/basics/about-your-developer-account).

Apple's [CloudKit setup instructions](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app) require active Program membership and administrative setup access. The official capability tables mark App groups available in the free Apple Developer column while iCloud: CloudKit is unavailable there. See the [iOS capability table](https://developer.apple.com/help/account/reference/supported-capabilities-ios) and [macOS capability table](https://developer.apple.com/help/account/reference/supported-capabilities-macos). Table check markers were inspected because their text extraction omits availability icons. These are documented capability facts, not successful provisioning or runtime checks.

Team selection can wait while the remaining domain and interface decisions proceed. It must be settled before the gated signing/CloudKit checks. This does not remove CloudKit from the accepted V0 foundation or daily-use quality gates, and does not allow local/simulator evidence to stand in for physical sync evidence.

[Navigation prototype](https://github.com/dvcol/planner/issues/14) and [MCP session prototype](https://github.com/dvcol/planner/issues/16) use disposable local fixtures and verify their own applicable build/launch and access requirements. They can proceed after their domain/build prerequisites without completing this task's CloudKit checks. [Sync and share prototype](https://github.com/dvcol/planner/issues/15) still depends on completing Apple test access. Its physical two-device and extension evidence remains required.

## Local prototype evidence and remaining gates

The prototype/mcp branch now contains the committed native Xcode project, shared schemes and local PlannerCore package. The [native build report](../prototypes/mcp-native-build.md), [Core qualification](../prototypes/core-local-qualification.md) and [MCP qualification](../prototypes/mcp-http-qualification.md) record the actual source snapshots, commands and limits. Clean committed 94c75fc reproduces twenty hosted MCP functions, thirteen Core package store functions and a generic iOS Simulator app build with fresh products. The later SDK-constructor correction separately passes twenty hosted functions. The isolated read workload completes all 384 requests. These results establish the stated local prototype behaviors and compilation, not physical-device, provisioned identity or CloudKit access.

Xcode launches the ad hoc signed Mac test host for the hosted tests. That does not satisfy the selected-team launch, signed Keychain reader or signing-update requirements. A refreshed read-only `security find-identity -v -p codesigning` count on 2026-10-09 still reports zero valid identities. The prototype uses an org.example bundle identifier and has no provisioned App Group. No account, team, container or device configuration has been changed by these local checks.

The user accepted Q34 native public UI journeys and Q35 confirmation before deleting a Category/Tag with any association. On 2026-10-09 the user deferred signing and physical setup while away from the computer, and authorized simulator and local development work. The [navigation qualification](../prototypes/navigation-local-qualification.md) records actual simulator journeys and local Mac outcomes. These results do not close the remaining selected-team, physical, CloudKit or extension gates.

When the user returns to signing setup, the remaining inputs are the intended team and Team ID, app bundle ID and App Group ID, the test account/container arrangement, and discoverable physical devices authorized for provisioning. Continue local work while those inputs are deferred.

## Reproduce the inventory

Select Xcode for each command without changing the machine-wide default:

```sh
sw_vers
xcode-select -p
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift --version
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -showsdks
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -checkFirstLaunchStatus
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list runtimes
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl list devices --timeout 15
```

Device listings may contain personal device names and identifiers. Record only the platform, model, OS version, and access status needed for the ticket; keep raw local inventories out of the repository.

## Human inputs and actions

- Before physical provisioning, choose the Apple Account/Personal Team or enrolled team used for the particular build. Before CloudKit setup, confirm access to an active Program team and its required capabilities. This selection can wait during domain/local work; do not post passwords, keys, or certificates.
- Make the available iPhone and iPad discoverable to Xcode: connect and trust the selected devices, and enable Developer Mode where required. Confirm both may use the same private test iCloud account. Record model and OS version after successful discovery.
- The macOS 27 host prerequisite is now satisfied. Complete native Mac signing and launch checks once the disposable project and selected team are available.
- Agree the test iCloud account arrangement and test-only container/App Group identifiers before changing account or capability configuration.

After those inputs, complete the task's signed app, private-container, extension and Shortcuts checks. Agree any disposable public code-test interfaces before using `/tdd`. Keep the ticket open until its required checks actually pass. Prototype ownership and cross-device reliability remain with the corresponding prototype tickets.

Apple Calendar/EventKit export and its permission/access checks are deferred outside the current map under [accepted Scheduling Q7](../itineraries-and-scheduling.md#accepted-export-scope-scheduling-q7). Signed app/extension and physical CloudKit checks remain required; the selected team, pairing and private-account/container setup are still unverified.
