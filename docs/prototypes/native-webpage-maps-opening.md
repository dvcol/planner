# Confirmed webpage-to-Maps opening

## Accepted behavior and existing boundary

Q145 A requires explicit confirmation before a reported Maps app link opens. Existing native journeys qualify its exact target and cancellation, including automatic redirects, but actual system launch remains open. Reuse the existing production native UI and real HTTP fixture; no new public interface, target, dependency, provider or direct test boundary is proposed.

The saved policy guide contains `maps://?ll=35,139`. Open that guide, select Maps, require Planner's exact confirmation while Planner remains foreground and Maps does not, then activate Planner's native Open action. Require the installed `com.apple.Maps` process to become foreground. Preserve actual state observations and original Simulator screenshots. Activate Planner again, require the same readable guide and dismissed confirmation, then Return and verify its exact original bookmark identity/URL.

The journey operates only Planner controls and reads the Maps application's state. It does not operate Maps, configure system preferences, request location permissions, start navigation, place a call or send a message. Both controlled OS-27 Simulators report Maps version 1.0, build 2972.30.6.12.58. Foreground evidence establishes launch; the test does not claim that Maps rendered the requested coordinate or finished onboarding/network loading.

First run the bounded phone trial against unchanged shipping production. Diagnose any genuine failure rather than adding a speculative workaround. Then qualify dark iPad, strict formatting and matching Mac compilation. Verify that shipping code, the real HTTP helper and all existing journey bodies remain unchanged from the preceding checkpoint; their cancellation/generated-redirect evidence keeps its own scope without an unnecessary repeat. Mac runtime, Mail/Phone activation, other owner/lifetime contexts, physical/system gates and the feature-complete whole-app polish remain open. Q147/Q148 import contracts and signing remain separate pending gates.

## Final local Maps-launch checkpoint

The [reconciliation](evidence/native-webpage-maps-opening/final-reconciliation.json) records two passing native executions of the complete new journey on phone and dark iPad, with no failures or skips. Planner remains foreground and Maps does not until the exact `maps://?ll=35,139` confirmation is accepted. Maps then reports foreground. Returning by activating Planner preserves the readable original guide, dismisses its confirmation and retains the saved bookmark identity/URL.

All 1,081 inputs match both runtime invocations and Mac compilation. Each runtime's four products validate before reuse; matching Mac compilation validates nine products and supplies no Mac UI credit. All six original captures and both raw foreground observations reconcile. The external captures show black launch content, so coordinate rendering, completed onboarding and usable Maps UI are not proven. No Maps control is activated. Dark iPad appearance is preserved.

The [source comparison](evidence/native-webpage-maps-opening/unchanged-production-and-journeys.json) proves that only the new native journey differs from the preceding checkpoint across all 1,081 inputs. Removing that method reproduces the entire previous journey file exactly. Shipping app/Core/Share code, the real HTTP helper, existing journey bodies, public interfaces, targets, dependencies and backups remain unchanged. Existing cancellation/generated-redirect evidence keeps its original scope; no unnecessary repeated execution is counted here.

This qualifies the represented explicit Maps launch and return. Mail/Phone activation, other content/owner handoffs, actual Mac UI, physical/system qualification, broad accessibility and feature-complete whole-app polish remain open. The retained narrow-iPad Items title is still truncated. Pending Q147/Q148 import reviews and deferred signing retain their separate gates.

## Generated export cleanup

After reconciliation, 2 duplicate temporary attachment-export directories are removed, totaling 1,016,789 nominal bytes. The [cleanup record](evidence/native-webpage-maps-opening/generated-export-cleanup.json) preserves exact paths and counts. Original xcresult bundles, selected captures/observations, manifests, source roots, reusable products and user datasets remain; nominal bytes do not promise equal APFS free-space recovery.
