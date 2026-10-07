# Apple test access

Partial setup evidence for [Apple test access](https://github.com/dvcol/planner/issues/7), inspected on 2026-10-07. This records toolchain and destination inventory. It does not prove a signed app launch, CloudKit access, extension execution, or planner correctness.

## Observed environment

| Check | Observed result | What it proves |
| --- | --- | --- |
| Host | Apple silicon, macOS 26.6.2, build 25G83 | The local Mac's current OS is below the app's agreed macOS 27 minimum. |
| Default developer directory | `/Library/Developer/CommandLineTools` | Unqualified `xcodebuild` fails because the default points to Command Line Tools. |
| Full Xcode installation | `/Applications/Xcode.app`, Xcode 27.0, build 27A266a | A full OS 27 toolchain is installed and can be selected per command. |
| Scoped Swift compiler | Apple Swift 6.4 | The Xcode compiler differs from the default Command Line Tools compiler, which reports Swift 6.3.2. |
| SDK discovery | iOS 27.0, iOS Simulator 27.0, macOS 27.0 | The required SDKs are present; SDK discovery is not an app build. |
| Xcode first-launch status | `xcodebuild -checkFirstLaunchStatus` exited 0 | The command reports no outstanding first-launch prerequisite. |
| Simulator runtime | iOS 27.0, build 24A434, available | An appropriate mobile runtime is installed. |
| Simulator destinations | Available iPhone and iPad destinations | Mobile prototype destinations exist; no simulator was booted or app launched. |
| Physical-device discovery | `devicectl list devices` succeeded with an empty device list | No devices were discoverable in this check. This does not establish whether the user owns suitable devices. |
| Signing, team, iCloud account, container and App Group | Not selected or verified | These remain human inputs and later signed-runtime checks. |

Simulator and device discovery initially failed or timed out in the filesystem sandbox. The same read-only commands succeeded with host-service access. Do not interpret the sandbox failures as missing runtimes or devices. The developer-directory default was not changed.

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
- Identify two physical OS 27 devices that may use the same private test iCloud account. Connect and trust the selected devices, and enable Developer Mode where required. Record model and OS version after successful discovery.
- Provide a macOS 27 runtime environment for the native Mac checks, using a compatible Mac you select. This Mac can provide SDK/build tooling, but its current OS cannot establish the app's macOS 27 runtime behavior. No OS upgrade is authorized by this inventory.
- Agree the test iCloud account arrangement and test-only container/App Group identifiers before changing account or capability configuration.

After those inputs, complete the task's signed app, private-container, extension, EventKit, and Shortcuts checks. Agree any disposable public code-test interfaces before using `/tdd`. Keep the ticket open until its required checks actually pass. Prototype ownership and cross-device reliability remain with the corresponding prototype tickets.
