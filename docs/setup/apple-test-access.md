# Apple test access

Partial setup evidence for [Apple test access](https://github.com/dvcol/planner/issues/7), refreshed on 2026-10-08. This records toolchain and destination inventory. It does not prove a signed app launch, CloudKit access, extension execution, or planner correctness.

## Observed environment

| Check | Observed result | What it proves |
| --- | --- | --- |
| Host | Apple silicon, macOS 27.0.1, build 26A434 | The local Mac now meets the app's macOS 27 runtime minimum. An app launch remains unverified. |
| Default developer directory | `/Library/Developer/CommandLineTools` | Unqualified `xcodebuild` fails because the default points to Command Line Tools. |
| Full Xcode installation | `/Applications/Xcode.app`, Xcode 27.0, build 27A266a | A full OS 27 toolchain is installed and can be selected per command. |
| Swift compiler | Scoped Xcode and default `swift --version` both report Apple Swift 6.4 | Compiler discovery succeeds after the OS upgrade; use scoped Xcode selection for builds. |
| SDK discovery | iOS 27.0, iOS Simulator 27.0, macOS 27.0 | The required SDKs are present; SDK discovery is not an app build. |
| Xcode first-launch status | `xcodebuild -checkFirstLaunchStatus` exited 0 | The command reports no outstanding first-launch prerequisite. |
| Simulator runtime | iOS 27.0, build 24A434, available | An appropriate mobile runtime is installed. |
| Simulator destinations | Five available iPhone and six available iPad destinations for iOS 27 | Mobile prototype destinations exist; no simulator was booted or app launched. |
| Human-reported physical devices | The user has an iPhone and iPad running OS 27 available | Ownership/availability is confirmed by the user; exact model, OS build, pairing and Developer Mode remain to verify. |
| Physical-device discovery | Refreshed `devicectl list devices` succeeded with an empty device list | The available devices are not yet discoverable by this Xcode host. Pairing/connection and signed execution remain unverified. |
| Signing, team, iCloud account, container and App Group | Not selected or verified | These remain human inputs and later signed-runtime checks. |

The 2026-10-07 macOS 26.6.2 observation is superseded by this refresh. Current host-access simulator and device discovery succeeded. Initial sandbox failures on the previous run did not establish missing runtimes or devices. The developer-directory default was not changed.

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

- Choose the Apple Developer team for signing and CloudKit. Confirm whether membership and the required capabilities are already available; do not post passwords, keys, or certificates.
- Make the available iPhone and iPad discoverable to Xcode: connect and trust the selected devices, and enable Developer Mode where required. Confirm both may use the same private test iCloud account. Record model and OS version after successful discovery.
- The macOS 27 host prerequisite is now satisfied. Complete native Mac signing and launch checks once the disposable project and selected team are available.
- Agree the test iCloud account arrangement and test-only container/App Group identifiers before changing account or capability configuration.

After those inputs, complete the task's signed app, private-container, extension, EventKit, and Shortcuts checks. Agree any disposable public code-test interfaces before using `/tdd`. Keep the ticket open until its required checks actually pass. Prototype ownership and cross-device reliability remain with the corresponding prototype tickets.
