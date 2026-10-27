# Apple test access

## Current setup direction, 27 October 2026

The user enrolled in the Apple Developer Program. The signed-in Apple Developer
portal shows team `Y6HV37KJ2G`; identifier registration succeeds. This supersedes
the earlier decision to defer membership without changing the scope of the
historical ad hoc checks below. Provisioned builds and actual capability access
remain separate checks.

The supplied screenshot shows the enrolled developer team already added in
Xcode's **Apple Accounts** settings. A local build-settings read resolves the
supplied Team ID from ignored configuration. The user approved `dvcol.planner`,
`group.dvcol.planner` and `iCloud.dvcol.planner`, with derived Share extension
identifiers. The following identifiers are now registered:

| Kind | Registered identifier | Portal assignment |
| --- | --- | --- |
| Main app | `dvcol.planner` | App Group and iCloud container |
| Mobile Share | `dvcol.planner.ShareMobile` | App Group |
| Mac Share | `dvcol.planner.ShareMac` | App Group |
| App Group | `group.dvcol.planner` | Shared by the three app identifiers above |
| iCloud container | `iCloud.dvcol.planner` | Assigned to the main app with CloudKit support |

Registration changes no saved Planner data and deploys no CloudKit schema.
The app remains local-only. No store listing or publication was created.
Each App ID was reopened after saving to verify its persisted assignments.
[Registration evidence](evidence/apple-registration-2026-10-27/verification.json)
includes the inspected original lists for
[app identifiers](evidence/apple-registration-2026-10-27/app-identifiers.png),
the [App Group](evidence/apple-registration-2026-10-27/app-group.png) and the
[iCloud container](evidence/apple-registration-2026-10-27/icloud-container.png).

### Private storage and quota

The user explicitly requests using each user's iCloud storage rather than an
app-owned public storage quota. Keep the planned private CloudKit database.
Apple states that [private-database data](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase?changes=__3)
counts against the user's iCloud storage, while
[public-database data](https://developer.apple.com/documentation/cloudkit/ckcontainer/publicclouddatabase?changes=_1)
counts against the app's quota. The registered container is still required for
the private database; its identifier does not select public storage. This is a
quota distinction, not an assertion that every CloudKit limit or sync failure
has been qualified.

The user subsequently approved silent CloudKit notifications. Push Notifications
is now saved and verified on the main App ID, with Broadcast disabled. This
supersedes the earlier automatic-review rejection, which applied before that
explicit approval. The [provisioning checkpoint](../prototypes/cloud-access-provisioning.md)
records the inspected portal evidence and actual signed-build result. Mobile
remote-notification background delivery remains to configure with integration.

### Development identity

The original [disposable private-access check](../prototypes/cloud-access-preparation.md)
compiled with signing disabled; that unsigned version was not launched.
The user now authorizes
Xcode's development signing-resource management, resolving the earlier rejection
of `-allowProvisioningUpdates`. The [signed attempt](../prototypes/cloud-access-provisioning.md)
reaches provisioning and exits before signing because the execution Mac is not
registered and no matching Mac development profile exists. After the user also
authorizes registering this Mac, the [next build and native run](../prototypes/cloud-access-native.md)
pass selected-team signature/profile checks, actual App Group access, iCloud
account availability and synchronous initialization of an empty private store
with all 16 production entities. Existing certificates are preserved. Subsequent
[asynchronous setup](../prototypes/cloud-setup-native.md) and
[synthetic content round trips](../prototypes/cloud-round-trip-native.md) pass
actual private-service reads, native events, exact fresh-store content reads and
confirmed cloud-fixture cleanup. Account transitions, production integration,
installed Share and physical sync remain open; production is still local-only.

The user explicitly defers account-transition testing on 27 October. No iCloud
setting or account is changed. Keep that ownership/reset requirement open and
continue independent local work; the deferral does not approve production sync
activation without its safety evidence.

A separate [development-signed Mac UI build](../prototypes/native-development-signed-mac-ui.md)
now passes for the unconfigured local-only app, embedded Share and test runner.
Strict signatures verify, but the bounded UI setup still starts no journey body.
The user-requested retry exits with an automation-mode initialization timeout,
without an explicit approval request or permission denial in its runtime log.
The later system-log diagnosis confirms that macOS requested “Enable UI
Automation” authentication, which completed after XCTest's timeout. Follow the
report's selected manual-approval policy. With the user ready to approve, the
unchanged title/layout test passes with zero failures in 67.622 seconds.
Authentication remains required before and after the run. Future tests retain
manual prompt coordination; other Mac journeys and installed Share remain open.

After the user created Apple Development, the certificate existed but a
disposable signing probe failed with a missing issuer-chain warning and
`errSecInternalComponent`. The required WWDR G3 intermediate was absent.
The official Apple G3 certificate was downloaded from
[Apple PKI](https://www.apple.com/certificateauthority/), its Apple-root chain
verified, and the public intermediate added to the user's default Keychain.
No trust override was added. Its SHA-256 is
`dcf21878c77f4198e4b4614f03d696d89c66c66008d4244e1b99161aac91601f`.
Apple documents G3's role in [software signing](https://developer.apple.com/help/account/certificates/wwdr-intermediate-certificates/).
The subsequent inventory reports one valid identity. A fresh disposable signing
attempt times out after 25 seconds; actual private-key use and provisioned app
builds are not yet qualified. The user is asked whether a Keychain prompt appeared.
No executable was launched or installed, and the temporary probe was removed.

The requested eventual distribution is an unlisted App Store app for personal
use. Apple's [unlisted distribution rules](https://developer.apple.com/support/unlisted-app-distribution/)
exclude such apps from search and other listings, but anyone with the direct
link can install them. Final App Review and approval of an unlisted request are
required; approval is not assumed. No store submission or publication is
authorized by identifier setup alone.

Start with the Team ID in Account → Membership details, as described in Apple's
[Team ID guidance](https://developer.apple.com/help/glossary/team-id/). The app,
App Group and iCloud container identifiers are chosen and registered for that
team afterward. Keep machine-specific signing inputs in ignored
`Configuration/Local.xcconfig`; do not commit account secrets or signing material.

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

On 18 October 2026 the user returned to the unlocked Mac and declined a paid Developer Program subscription for this personal app. A fresh unsandboxed read-only identity check still reports zero valid code-signing identities. Current ad hoc Mac compilation succeeds, and the Q101 native retry now starts and operates Capture. Its workflow failures and subsequent qualification belong to the [catalog Add review](../prototypes/native-catalog-add-menu.md); automation availability supplies no provisioned signing or Keychain evidence.

Signing and paid membership are separate requirements. Apple's [current Personal Team guidance](https://developer.apple.com/help/account/basics/about-your-developer-account) permits free personal-device testing with seven-day provisioning. Its [CloudKit setup](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app) requires active Program membership. Continue no-fee local development and verify the actual free signing/capability route for Q100. No account enrollment or capability changes have occurred. The original CloudKit sync gate remains unmet; a subscription-free replacement needs its own reviewed sync design rather than an assumed equivalent.

- Before physical provisioning, choose the Apple Account/Personal Team or enrolled team used for the particular build. Before CloudKit setup, confirm access to an active Program team and its required capabilities. This selection can wait during domain/local work; do not post passwords, keys, or certificates.
- Make the available iPhone and iPad discoverable to Xcode: connect and trust the selected devices, and enable Developer Mode where required. Confirm both may use the same private test iCloud account. Record model and OS version after successful discovery.
- The macOS 27 host prerequisite is now satisfied. Complete native Mac signing and launch checks once the disposable project and selected team are available.
- Agree the test iCloud account arrangement and test-only container/App Group identifiers before changing account or capability configuration.

After those inputs, complete the task's signed app, private-container, extension and Shortcuts checks. Agree any disposable public code-test interfaces before using `/tdd`. Keep the ticket open until its required checks actually pass. Prototype ownership and cross-device reliability remain with the corresponding prototype tickets.

Apple Calendar/EventKit export and its permission/access checks are deferred outside the current map under [accepted Scheduling Q7](../itineraries-and-scheduling.md#accepted-export-scope-scheduling-q7). Signed app/extension and physical CloudKit checks remain required; the selected team, pairing and private-account/container setup are still unverified.
