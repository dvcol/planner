# Release privacy audit

31 October 2026. This is a source and built-bundle review, not an App Store
privacy submission or an approval of final release materials.

## Required-reason APIs

| Executable bundle | Use | Declaration |
| --- | --- | --- |
| Main app | Device-only sort and capture preferences | UserDefaults: CA92.1 |
| Share extensions | Capture destination preferences | UserDefaults: CA92.1 |
| All three | Local store inode/device metadata | FileTimestamp: C617.1 |
| Mac SwiftNIO resource bundle | SDK file API wrappers | FileTimestamp: 0A2A.1 |

The main app already declared UserDefaults. Both extensions compile
`SavedCaptureForm`, which reads and writes `UserDefaults.standard`, but had no
manifest. Each extension now has its own `PrivacyInfo.xcprivacy`. Their
filesystem-synchronized Xcode groups include the resource without a project
or target change.

Core's `nativeStoreFileIdentity()` reads file metadata to identify the local
store. It does not read creation/modification dates or use CloudKit record
dates as filesystem timestamps. C617.1 covers metadata within the app or shared
app-group container. No disk-space, keyboard or boot-time reason is added
without a corresponding use. See Apple's
[required-reason guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
and [API categories and reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).

## Bundled dependencies

The resolved package set is SwiftNIO 2.104.0, SwiftAtomics 1.3.1,
SwiftCollections 1.7.2, SwiftLog 1.16.1, SwiftSystem 1.8.1, MCP Swift SDK 0.12.1
and EventSource 1.5.1. These are source-built packages, not downloaded binary
SDK frameworks. V3 integration code remains outside MVP acceptance even where
linked into the Mac product.

The inspected universal Mac Release archive contains the app manifest and
SwiftNIO's `swift-nio_NIOPosix.bundle` manifest. SwiftNIO declares its own file
API wrapper reason and no tracking/collected types. Undefined symbols include
`stat`, `fstat`, `fstatat` and `lstat`; linked symbols alone do not establish the
purpose or execution of every API. The shared Core call and SDK declaration
are reviewed separately. No advertising or analytics SDK is in the resolved
package set.

The corrected signed Debug Mac app and embedded Share extension contain the
expected manifests. Both app and UI-runner signatures verify through the
normal trust service. Plist validation passes for all three source manifests.
The signed mobile app and embedded Share extension also contain both reasons,
and their signatures verify.

Fresh unsigned universal Mac and iOS Release archives both build successfully.
Each contains the corrected app and Share manifests plus SwiftNIO's resource
manifest, with no hosted test bundle. Both declare the intended app/group/
private-container identifiers, Production environment and version `0.0.1`.
The bundle review
retains parsed manifests, product hashes, exact archive commands and compressed
build logs. This proves packaging, not distribution signing, deployed cloud
schema or App Store upload acceptance.

## Data paths and declaration limits

The reviewed production paths use local SwiftData, private CloudKit,
MapKit/geocoding/directions, LinkPresentation, bounded Maps-link HTTP requests
and WebKit's default persistent website store. No public/shared CloudKit
fallback or developer-hosted planning/analytics endpoint is introduced.

The draft [privacy policy](privacy-policy-draft.md) describes those behaviors;
the [support draft](support-draft.md) proposes the existing public issue tracker
without copying private developer-account contact information.

Final App Store privacy answers remain subject to the release artifact and
owner review. Apple distinguishes on-device processing, requests, open-web
browsing and developer/partner collection. Private CloudKit alone is not the
entire audit. See [Apple's privacy-label guidance](https://developer.apple.com/app-store/app-privacy-details/).

## Remaining release checks

- [x] Read back mobile app/Share and both Release archive manifests.
- [ ] Generate/review Xcode's aggregate privacy report and any upload warnings.
- [ ] Approve the final policy, support contact and public hosting URLs.
- [ ] Complete App Store privacy answers from the actual release artifact.

No account setting, cloud schema, developer identifier, distribution resource,
App Store listing or public repository branch is changed by this audit.
