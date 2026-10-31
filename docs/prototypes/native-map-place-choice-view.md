# Native Map place-choice view feasibility

Q144 A approves the [test-owned native window boundary](../native-map-place-choice-view-test-contract-review.md). Use the production Map view, real Planner storage and the existing provider boundary. Reach the existing Locations and Maps-link menu before testing the missing address-choice control. No Computer Use, global accessibility interaction, new target, production hook or signing setup is used.

The first attempt fails Swift 6 compilation because its Timer closure transfers non-Sendable accessibility values. Moving the inspection into an explicitly MainActor-isolated closure corrects that compiler issue. Neither compilation nor that failed attempt qualifies runtime access.

The next actual invocation starts the hosted test, but cannot find Locations in the window-root traversal. It fails in 3.782 seconds and closes its owned window. This is failed feasibility, not behavioral red for the missing candidate control. A bounded diagnostic now also inspects the owned content view after layout and retains its actual accessibility tree. No system Call/Message, other application or user window is touched.

The address-choice behavior and twelve existing loader regressions remain separate follow-up. Keep the real storage fixtures until the host has exited and the existing verifier can establish closed handles; do not unlink a live SQLite store.

## Scoped accessibility environment candidate

The diagnostic confirms that the NSWindow has its titlebar children and the NSHostingView group, but the hosting group has zero children. Apple’s public, writable [accessibilityEnabled environment value](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityenabled) can be scoped to the test-owned hosted view. Try that value once within the approved boundary. Apple does not document that it initializes descendants. The [application accessibility setting](https://developer.apple.com/documentation/accessibility/accessibilitysettings/isapplicationaccessibilityenabled) is a read-only diagnostic, not a supported enabling switch. If the scoped environment still leaves an empty tree, retain the failed trial and review the boundary without private activation or manually supplied children.

The single scoped-environment trial starts and fails in 4.272 seconds at the same missing Locations query. Its hosting group exposes three children, but only the Map child conforms to the protocol used by this traversal; Locations is still unreachable through that code. All 1,074 workspace/frozen inputs and three executable products match. The prototype test is removed from the shipping test source after its complete source and failed result are retained in the packet. No global activation or permission change is attempted. Q144’s proposed boundary has not established native control access. A supported existing-fixture alternative is being checked before another boundary choice; Q130 continues independently.

## Existing fixture path

The repository already has a suitable established native UI boundary. PlannerFixtures includes the complete production Planner source group and opens SavedPlannerMainWindow with FixturePreviewProvider. Its address-candidates scenario supplies the same real owned address to a controlled North/South result, and AddressCandidateJourneyTests already tests the detail picker. Extend that native journey to the collection Map, then repeated itinerary appearances using real domain commands in the fixture. No source-sharing change, new provider parameter, target or dependency is required. The direct hosted-window trial remains failed; this is a return to the existing native UI/provider boundary.
