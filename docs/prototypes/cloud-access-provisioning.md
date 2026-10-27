# Private CloudKit development provisioning

Local setup checkpoint, 27 October 2026. This follows the
[unsigned access-check preparation](cloud-access-preparation.md).

The subsequent [registered-Mac build and native run](cloud-access-native.md)
clear this checkpoint's provisioning blocker. The failed result below retains
its original scope and evidence.

The user explicitly approved development signing-resource management under team
`Y6HV37KJ2G`, preserving existing certificates, and the main app's silent CloudKit
notification capability. Push Notifications is now enabled for `dvcol.planner`.
The App ID was reopened after saving; its enabled setting and disabled Save
button confirm persistence. Broadcast remains disabled. No Push certificate,
store submission or production schema deployment was created.

The disposable native probe now requests the documented
[macOS APNs development entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.aps-environment)
alongside its approved private CloudKit and App Group entitlements. Its Xcode
target declares those three capabilities. Production app configuration and
Planner's local-only storage remain unchanged. Mobile remote-notification
background delivery remains to configure with the actual sync integration.

## Executed result

The scoped Mac build uses `-allowProvisioningUpdates`, automatic Apple Development
signing and one build job. It exits 65 after 6.436 seconds, before signing: Xcode
reports that the execution Mac is not registered in the developer account and no
matching Mac App Development profile is available. The build does not use
`-allowProvisioningDeviceRegistration`; permission to register this Mac is now
requested separately because the preceding setup approval named profiles, App ID
configurations and certificates.

The probe was not launched. This failure establishes a provisioning prerequisite,
not a private-key, iCloud account, container-access or schema failure. Earlier
unsigned products are not evidence of selected-team signing. Existing Planner
data and certificates remain untouched.

[Evidence](evidence/cloud-access-provisioning/result.json) retains the actual
command, exit, diagnostic source/configuration and build log in a seven-member
verified archive, plus hashes of all 90 Core and three probe inputs. Only the
execution Mac's serial is redacted from the archived log; the raw log hash is
recorded. The original
[persisted-capability screenshot](evidence/cloud-access-provisioning/push-enabled.png)
was inspected. No compiled or runtime success is claimed for this signed attempt.

After approved registration, retry provisioning, inspect the actual signature,
profile and entitlements, then launch only the disposable access check. Actual
private-store access, asynchronous delivery, ownership cutoffs, installed Share
and two-device synchronization remain open. Production CloudKit integration is
still required; this setup checkpoint does not implement it.
