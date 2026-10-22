# Native Map place-choice view test review

Status: Q144 A accepted on 22 October 2026. The additional production-view test boundary and bounded runtime feasibility trial are approved. The bounded trials have now failed to reach Locations; they receive no candidate-control credit. Q143's loader and existing native UI seams remain accepted.

## Context and evidence

The production loader already qualifies zero, one and multiple address candidates through real Planner storage and the existing external-provider protocols. Its `chooseAddressCandidate` command validates the complete row/input binding and preserves independent repeated appearances. Native Locations still lacks the multiple-candidate control.

A live `MKGeocodingRequest` discovery probe returned one candidate each for Springfield, Main Street and Paris. Those results do not establish a repeatable multiple-choice native test. Adding a test-only launch flag or replacing providers inside the shipping app is outside the accepted design.

The existing `PlannerMCPTests` target runs in Planner.app and can import the production view through its existing testable app import. There are no current in-process hosting/accessibility tests. Apple's public `NSHostingView`, `NSWindow` and `NSAccessibilityProtocol` APIs permit hosting a SwiftUI view, inspecting its accessibility children and invoking its controls. The installed SDK declarations and a scratch Swift 6 typecheck confirm these APIs exist. No view or accessibility action was executed by that probe. Native Menu/Picker accessibility behavior remains unproven.

## Proposed additional boundary

Approve one app-hosted test of the production `SavedMapCollectionView` through its actual native controls. Reuse the existing test class, disposable real Planner storage, production collection initializer/reload interface and controlled address-provider protocol. Add no package, target, library, launch flag, production test hook or new dependency parameter.

The test owns one `NSWindow` containing an `NSHostingView` of the production Map view. Inspect only that window and its attached native sheet/menu. Invoke actual controls through their in-process accessibility interfaces. Do not use cross-application Computer Use, global accessibility automation or a replacement window callback. Do not inspect, close or reconfigure unrelated user windows.

First perform a bounded feasibility trial of Locations and its existing native menu. Public API typechecking alone is not runtime proof. If actual controls cannot be reached through this boundary, retain the failed trial and revisit the proposal. Never replace a missing native action with a direct loader command and call it view coverage. No new system permission or signing setup is part of the proposal.

## Literal behavior and required /tdd

Use real repeated itinerary appearances of one Item with a saved address. The controlled external provider returns two literal candidates: East at 35,139 and West at 36,140. Both appearances initially require a choice. Capture a versioned Planner export through the public interface before native actions.

The new test must first reach the missing place-choice control through the actual native Locations sheet. A compiler, hosting, accessibility-query or menu-tracking failure is not behavioral red. After implementing the minimum native control:

1. Choose West for the first appearance through that native control. Its public collection resolution becomes 36,140; the second appearance still requires a choice.
2. Choose East for the second appearance. Its resolution becomes 35,139; the first remains 36,140.
3. Reopen the first appearance's choices and choose East. Both now resolve to 35,139 without rewriting their shared Item or contextual completion.
4. Read the actual Planner export again. Its exact content equals the earlier export. Verify resulting collection state, not just the Boolean returned by an accessibility action.

Retain existing loader tests for stale address/lifetime rejection, repeated work sharing, deadlines and cancellation. The view test does not replace them. Close only the test-owned window and release its hosted view after the test. Reuse the existing owned-store markers and post-host fixture verifier rather than unlinking an open SQLite store.

## Definition of done and limits

Record actual executed results, exact source/product inputs and the native control path. Run the affected existing loader regressions, strict Swift/docs lint and platform compilation. A successful app-hosted Mac view test qualifies only this native view/control boundary. It does not qualify external Mac UI automation, mobile presentation, VoiceOver, window resizing, physical performance or installed/signed workflows.

If the user keeps only the existing seams, native ambiguity controls and their positive UI qualification remain open until an appropriate live case or another approved boundary is available. Independent Map, browser and other local work continues.

## API references

- [NSHostingView](https://developer.apple.com/documentation/swiftui/nshostingview).
- [NSAccessibilityProtocol](https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol).
- [accessibilityPerformPress](https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol/accessibilityperformpress()). An action's return value alone does not establish its final effect.

## Executed feasibility result and existing-boundary alternative

The [owned-window trials](prototypes/native-map-place-choice-view.md) start actual app-hosted tests but cannot reach Locations through their public protocol traversal. A scoped public accessibility environment exposes additional hosting children but still does not establish control access. Complete source/results are retained and the prototype test is removed. No global activation, private API or permission change is attempted. This additional direct boundary remains unqualified.

The existing PlannerFixtures target already compiles the production Planner sources and opens SavedPlannerMainWindow with the accepted external preview-provider protocols. Its existing address-candidates dataset and provider supply North entrance at 35.662,139.717 and South entrance at 35.655,139.717. AddressCandidateJourneyTests already exercises this deterministic provider through real native controls. Continue the missing Map chooser through that previously established native UI boundary, without a new target, dependency, shipping launch flag, production hook or interface. Use these existing literal candidates rather than introduce duplicate East/West provider data. Native UI checks will cover exact appearances, visible pin changes, unchanged owned fields and relaunch; the already accepted loader/Core tests retain exact before/after export checks. This does not turn the failed direct-window trial into passing evidence.
