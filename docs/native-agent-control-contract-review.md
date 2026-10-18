# Native Agent Control lifecycle contract review

Status: proposed for Q100. No implementation or tests at the new lifecycle/credential-store interface are authorized by this proposal alone. Existing public Core, HTTP, native UI and reader-process contracts remain accepted.

## Context and goal

The production app owns a real `Planner` facade and dataset session in `SavedPlannerStore`. Hosted tests construct `PlannerMCPRequestHandler` and `PlannerMCPLoopbackListener`, but production startup does not construct them. There is no native Enable/Stop controller, menu-bar status or `--mcp-headers` entry branch. Transport tests and CLI installation cannot establish a usable Agent Control feature.

Before: authenticated real-Core HTTP works in disposable tests; ordinary Planner cannot manually enable it. After the complete feature: the running Mac app explicitly enables access to its own current Core session, publishes truthful native status and connection instructions, retains access through the accepted lifecycle, and stops/revokes it explicitly. The same signed executable supplies the accepted reader. This proposal declares the first lifecycle implementation and its test boundary; it does not waive reader, activity-history, client or signed/device gates.

The behavior remains governed by [Shared command contracts](shared-command-contracts.md), [reader declaration](content-and-reader-review.md#credential-reader-declaration-accepted-contract-q32-a) and [adapter contract](adapter-contract.md). Q98 itinerary windows and Q99 selected-row appearance are independent.

## Definition of ready

- The existing app-owned Core session, stateless official-SDK handler and real loopback start/stop interfaces are available. MCP clients cannot choose a dataset or account.
- Q100 confirms the concrete lifecycle and credential I/O interfaces below before their tests are written.
- Local app-hosted tests use disposable real Core stores, temporary control-record directories and controlled credential I/O results. This supplies no signing or production Keychain credit.
- Actual signed App Group/Keychain and physical work remain deferred by the user. No enrollment, provisioning, permission changes or plaintext fallback are authorized by this proposal.

## Proposed production interfaces

Add one Mac-only app-internal `PlannerAgentAccessController`. It owns enablement and exposes the same state to the Settings form and menu-bar control. It reuses the existing handler/listener and the exact `Planner` and `PlannerDatasetSession` already owned by the app.

Its production initializer receives that facade/session, the configured App Group control-directory URL, the launch identity and a `PlannerAgentCredentialStore`. An absent control-directory URL represents missing app capability configuration. Those are deployment/I/O dependencies used by the app, not test-only optional callbacks. The native factory obtains them from the running store and configured app capabilities; the UI supplies only the requested port. The main-instance UUID is generated once per app launch and shared with the controller and control record.

Observable lifecycle API:

```swift
init(
  planner: PlannerCore.Planner,
  datasetSession: PlannerDatasetSession,
  controlDirectory: URL?,
  mainInstanceIdentifier: UUID,
  credentialStore: any PlannerAgentCredentialStore
)
var state: PlannerAgentAccessState { get }
var notice: String? { get }
func enable(port: UInt16 = 44444) async
func stop() async
```

`PlannerAgentAccessState` is `off`, `enabling`, `on(endpoint: URL)`, `stopping` or `unavailable`. A separate credential-free notice explains failure or incomplete cleanup. Neither state nor notices expose credentials. Enable with port zero is invalid; an occupied requested port fails explicitly without choosing another port. Native UI validates the integer range before conversion.

Enable is accepted from Off/Unavailable. Repeating Enable while On does not rotate credentials or create another listener. During an in-flight transition, another Enable is ignored. Stop remains available during enabling: revoke any admitted window and clean up partial setup before publishing Off. A superseded async completion must never publish On after Stop. A later explicit Enable gets a fresh access window and credential.

The production credential boundary is shared by the native owner and the eventual reader:

```swift
protocol PlannerAgentCredentialStore: Sendable {
  func createCredential(for accessWindowIdentifier: UUID) async throws -> String
  func readCredential(for accessWindowIdentifier: UUID) async throws -> String
  func removeCredential(for accessWindowIdentifier: UUID) async throws
}
```

The native implementation combines the already specified random-byte generation and data-protection Keychain operations. It uses the configured bundle identifier plus `.AgentControl`, the access-window UUID account and the exact accepted accessibility/noninteractive policy. It returns controlled failures without credentials. A controlled test implementation replaces this actual external I/O boundary; it is not injected into arbitrary internal collaborators or exposed as a runtime test mode.

No package, target, Core API, MCP wire schema, backup format, client registry, expiry timer or request cap is added. The same executable reader's public command/output contract remains unchanged. Its process bootstrap and signed storage qualification follow this lifecycle slice.

## Enable, Stop and ownership behavior

1. Begin Off on every launch. Stale control metadata cannot start a listener or authorize a new session.
2. Enable requires a current app-owned Core context and configured control storage. Create a fresh credential/window, bind the exact requested loopback endpoint, then atomically publish the accepted control record. Report On only after all three steps succeed.
3. Missing capabilities, credential/RNG failure, bind failure or control-record failure leave no admitted listener. Best-effort cleanup cannot convert a failed setup into On. Do not use a volatile/plaintext production fallback to make local builds appear configured.
4. Stop revokes admission before listener shutdown and metadata/credential cleanup. Cleanup failure can leave a warning, but not working old authorization. A request already committed keeps its normal Core result and recovery evidence.
5. Re-enable uses a new credential/window. The old credential is rejected without mutation, including if old metadata or a Keychain item remains.
6. A dataset/session replacement stops the existing access owner. It cannot silently move an already enabled client onto a different dataset. Native wiring creates the replacement owner Off using the new authorized context.
7. No elapsed time, idle period, lock, sleep or last-window closure revokes access. Quit ends the listener. Real lock/sleep/window/quit observations remain native qualification, not inferred from unit tests.

The control file retains exactly the fields already approved in the reader declaration. It is temporary control metadata outside synced/portable Planner data, not a token container. The native factory fails clearly when the App Group location is unavailable.

## Required TDD at the proposed boundaries

Use the existing app-hosted target and public real-Core reads/commands. Write one lifecycle behavior, execute its failure, implement its correction, and repeat. Observe controller state, real HTTP results and the public control-record interchange; do not inspect private tasks, database internals or method-call counts.

- Before Enable, state is Off and there is no listener. A first successful Enable with controlled credential I/O reaches On, authenticated HTTP reads the literal saved Hotel identity/content, and public Core state stays unchanged by enablement.
- With an occupied port, missing configuration or failed credential creation, Enable reports unavailable and leaves no listener. A later explicit retry can succeed after the external condition is corrected. Never report On early.
- Make the real control directory unwritable at its filesystem boundary. Publication failure revokes/closes the bound listener and reports unavailable. No Planner command, receipt or recovery checkpoint is created.
- Stop a successful enablement. Real requests can no longer connect, direct stale admission is unauthorized, the control record is no longer usable, and the saved graph is unchanged. Simulated external cleanup failure still leaves old authorization unusable.
- Re-enable, prove that the old credential is unauthorized and the new credential reads the same source. Do not infer rotation from an internal constructor call.
- Overlap Enable and Stop, including slow credential I/O at that production boundary. Final state is Off and no delayed completion can republish On. A subsequent explicit Enable remains possible. No test-only delay, clock, constructor flag or callback is added to production.
- Replace the app's authorized dataset context. The old owner stops; the new owner starts Off. Existing clients cannot select or mutate the replacement dataset using the old credential.
- Preserve the existing HTTP authentication, protocol, cancellation, replay, Core ownership and reader ping observations. Native status/menu-bar controls must use this same owner, not a second controller.

Controlled credential I/O tests establish orchestration and real listener/Core behavior only. They cannot prove data-protection Keychain, signed caller identity, first-unlock/locked/restart behavior, App Group access or an actual client's connection. Existing reader-process declarations supply the later signed test seam. The three-hour idle and real lock/sleep/window/quit scenarios remain required; short tests are not substitutes.

## Native integration and definition of done

Use native Form/Section, Button/Toggle and MenuBarExtra controls on Mac, with truthful busy/unavailable states and On/Off/Stop. Preserve the existing pane navigation and source commands. Show the endpoint/helper invocation rather than credentials. Recovery-blocked Core commands retain their accepted results; enabling access does not bypass recovery or create another facade/session.

For the lifecycle slice, require passing focused app-hosted state/HTTP/Core tests, affected formatting/lint and compiler checks, plus source review of cancellation/cleanup ownership. Run native UI journeys where XCTest can start, recording any pre-discovery failure without UI credit. Keep the exact current source/products and literal results with each run.

The full MCP feature remains incomplete until the reader implementation, useful credential-free activity history, actual signed storage/reader observations, accepted long-idle and system lifecycle scenarios, four real client routes, concurrent native/client use and human connection review pass. Local I/O fixtures and Mac compilation do not close those gates. This proposal adds no signing setup task while signing is deferred.

## Q100 options

A approves this lifecycle owner and shared production credential I/O boundary, with app-hosted controlled-I/O/real-HTTP tests and separate signed/native qualification. It supports the user's requested local development staging without weakening the final feature.

B defers this lifecycle implementation until signing and native Mac automation are available, using real signed storage/native journeys without the controlled credential boundary. It avoids that additional production interface, but prevents this work from advancing locally now.

C revises the proposed API or test boundary before implementation. Existing accepted policy and security requirements remain fixed.
