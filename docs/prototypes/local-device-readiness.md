# Local device build and remaining access

Status: physical-device SDK compilation passes. Signing/account setup remains deferred; no installation or cloud-runtime result is claimed.

## Verified local result

The existing native Planner scheme builds for `generic/platform=iOS`, arm64, with `CODE_SIGNING_ALLOWED=NO` and one build job. It uses the checked-in Xcode project and pinned Swift packages. The app contains only its mobile Share extension. Source/product hashes, exact command and compiler log are retained in [the device build packet](evidence/navigation/native-share-products/device-unsigned-planner-host/).

This proves device-SDK compilation, not execution on iPhone/iPad, entitlement grants or synchronization. The optional local configuration file is absent, and the build does not configure a development team or install a profile.

## Read-only readiness

The 19 October 2026 inventory finds zero valid code-signing identities. CoreDevice distinguishes one paired physical iPad Pro 13-inch M4 on iOS 27.0.1, with Developer Mode enabled and a disconnected local-network tunnel, from two simulated devices. The committed summary excludes personal device names, identifiers, serial numbers and certificate fingerprints. The original device inventory remains local.

No account, signing, device-pairing or capability mutation is performed by this check. Physical execution needs valid signing/provisioning and an available device connection. This inventory does not establish whether the user already has an enrolled team, and it does not require buying a membership merely to compile the application.

## Remaining prototype gates

The production app still uses localOnly storage. Real shared-container/account-bound storage, CloudKit convergence/account transitions and installed Share remain implementation and signed/physical qualification work. Q100 B also retains actual signed storage/native Agent Control and selected-client gates. A build without those capabilities cannot stand in for their evidence.

Apple's system Intent testing service independently rejects the installed Customer runtime with error 803 before Planner runs. Direct production-interface Intent checks pass under Q112, but actual system discovery/background/lock behavior remains open. Signing is not established as a fix for that runtime-service error.

[Q113's compact toolbar choice](../native-list-toolbar-review.md) is pending. It concerns later UI presentation; its diagnostic trial is not an accepted feature or completed fix. Final whole-app polish remains after feature completion.
