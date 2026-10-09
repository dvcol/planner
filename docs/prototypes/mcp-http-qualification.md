# MCP HTTP qualification evidence

Work in progress for [MCP session prototype](https://github.com/dvcol/planner/issues/16), on the isolated prototype/mcp branch. Q33 approved the [HTTP/adapter contract](../adapter-contract.md) and [reader observations](../content-and-reader-review.md#credential-reader-declaration-accepted-contract-q32-a). This is execution at that unchanged HTTP boundary, separate from the pending navigation UI test approval.

## Context and observable boundary

The native [build setup](mcp-native-build.md) compiles on Mac and iOS simulators. PlannerCore has no domain implementation yet. Handler tests receive the official SDK's public HTTPRequest and return HTTPResponse. The listener test makes an actual loopback HTTP request through URLSession. Tests assert wire-visible status, headers and body, without inspecting handler state or mocking internal collaborators. Credential issuance, data mutation, real clients and reader execution remain unproved.

Each request is a POST to /mcp, Host 127.0.0.1:44444, Content-Type application/json, Accept application/json and text/event-stream, MCP-Protocol-Version 2025-11-25, and literal body {"jsonrpc":"2.0","id":1,"method":"ping"}. The test-only literal credential is 43 A characters and is never a live credential. Missing Authorization, or Authorization containing Bearer followed by 43 B characters, must return 401 without X-Planner-Access-Window. A credential used by tests is ordinary handler configuration, not an injectable production UUID/logger/factory callback.

## Executed red and green

| Slice | Executed result | Actual result summary |
| --- | --- | --- |
| Missing credential, red | One test executed, one failed. The working native test observed status 501 rather than 401. | [Red](evidence/mcp/authentication-missing-red.json) |
| Missing credential, green | One test executed, one passed after rejecting absent Authorization. | [Green](evidence/mcp/authentication-missing-green.json) |
| Incorrect credential, red | Two tests executed, one passed and the new test failed on 501 rather than 401. | [Red](evidence/mcp/authentication-incorrect-red.json) |
| Incorrect credential, green | Two tests executed, both passed after comparing against the configured credential. | [Green](evidence/mcp/authentication-incorrect-green.json) |
| Authorized ping, red | Three tests executed, two passed and the new ping test failed on unavailable status/result/window. | [Red](evidence/mcp/ping-red.json) |
| Authorized ping, green | Three tests executed, all passed after dispatch through the official SDK and preservation of its response. | [Green](evidence/mcp/ping-green.json) |
| Endpoint routing, red | Four tests executed, three passed. An authenticated ping to /admin returned 200 and an access-window header instead of 404 without that header. | [Red](evidence/mcp/routing-red.json) |
| Endpoint routing, green | Four tests executed, all passed after restricting dispatch to /mcp before authentication. | [Green](evidence/mcp/routing-green.json) |
| Loopback listener, red | Five tests executed, four passed. The new socket test reached the listener's unavailable error after compiling successfully. | [Red](evidence/mcp/listener-red.json) |
| Loopback listener, green | Five tests executed, all passed after adding native HTTP framing and forwarding the received request to the existing official-SDK handler. | [Green](evidence/mcp/listener-green.json) |
| Stop admission, red | Six tests executed, five passed. After Stop, the handler still admitted the old credential and returned 200 with the access-window header. | [Red](evidence/mcp/revocation-red.json) |
| Stop admission, green | Six tests executed, all passed after Stop invalidated the handler's credential before closing sockets. | [Green](evidence/mcp/revocation-green.json) |
| Unsupported initialization, red | Twelve tests executed, eleven passed. An initialize body requesting 2099-01-01 succeeded with a result/access-window header by selecting a supported fallback. | [Red](evidence/mcp/unsupported-initialization-red.json) |
| Unsupported initialization, green | Twelve tests executed, all passed after rejecting a decoded initialize request whose version is outside the SDK's supported set. The failure names the rejected and supported versions. | [Green](evidence/mcp/unsupported-initialization-green.json) |

The authentication filter discovers and executes AuthenticationTests in PlannerMCPTests. Later runs select the whole affected PlannerMCPTests target. Xcode's XCTest compatibility layer separately reports zero XCTest cases; Swift Testing and the xcresult summaries report the actual executed tests above. None is skipped or an expected failure. Test execution launches the signed native test host, not a protocol mock. The handler tests do not establish a live listener; ListenerTests starts and stops one disposable real socket. Neither establishes a reviewed UI.

For each row, run this affected-target command with its distinct result bundle and capture the actual exit code. Red exits 65 on its assertion failure; green exits zero. Missing source, compiler errors and zero discovered tests do not count as red.

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Planner.xcodeproj -scheme Planner -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:PlannerMCPTests/AuthenticationTests -onlyUsePackageVersionsFromResolvedFile -clonedSourcePackagesDirPath /private/tmp/PlannerMCPSourcePackages -derivedDataPath /private/tmp/PlannerMCPDerivedData -resultBundlePath /private/tmp/PlannerMCPWrongCredentialGreen.xcresult
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool get test-results summary --path /private/tmp/PlannerMCPWrongCredentialGreen.xcresult --format json
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift format lint --strict Planner/AgentControl/PlannerMCPRequestHandler.swift PlannerMCPTests/AuthenticationTests.swift
```

Results use the Mac/toolchain in the build evidence. Full xcresult bundles and logs remain machine-local under /private/tmp/PlannerMCPAuthenticationRed, PlannerMCPAuthenticationGreen, PlannerMCPWrongCredentialRed, PlannerMCPWrongCredentialGreen, PlannerMCPPingRed, PlannerMCPPingGreen, PlannerMCPRoutingRed, PlannerMCPRoutingGreen, PlannerMCPListenerRed and PlannerMCPListenerGreen, with xcresult/log extensions. Committed JSON summaries come from xcresulttool, omitting only local hardware identifiers under the Apple test access reporting rule. They preserve the executed counts and observed failing assertions. They are not regenerated expectations or fabricated passing results.

The ping fixture uses configured access window 00000000-0000-4000-8000-000000000701, the valid literal credential and JSON-RPC integer ID 7. Expected response is HTTP 200, JSON-RPC 2.0, integer ID 7, empty result object, no error, no MCP-Session-Id and X-Planner-Access-Window matching that admitted window. The test reads the actual SDK response body. The native adapter adds the header while retaining the SDK body/status/headers. It never manufactures a ping result.

This initial integration creates an official Server and StatelessHTTPServerTransport for each HTTP exchange, then stops them when that response resolves. It neither patches SDK sources nor introduces transport sessions or a client registry. That lifecycle is an unqualified integration candidate for the later initialization, context, cancellation and overlapping-request fixtures. A single ping does not prove that the inspected SDK defects or full client capability/version isolation are resolved.

## Real loopback observation

PlannerMCPLoopbackListener binds only 127.0.0.1. SwiftNIO 2.104.0 handles HTTP framing and sends each complete request to the existing handler; the official SDK owns MCP parsing, validation, dispatch and response bytes. A response includes its actual Content-Length and closes that HTTP connection. Separate connections are accepted independently. This step adds no Agent Control lifetime, idle expiry, session registry or client-count limit.

The test asks the OS for an available port with port zero so disposable parallel fixtures do not occupy the user's 44444 endpoint. The listener's default remains 44444. The real URLSession request uses literal ping ID 7 and asserts the actual 200/JSON-RPC result, matching access window, absent session ID and 127.0.0.1 host. Its five-second request timeout only bounds a failing test request; it is not an access expiry. The ping test alone does not prove listener closure, idle connection cancellation or revoked credentials.

The separate Stop-admission fixture starts and stops a real disposable listener, then submits the old credential through the approved HTTP handler boundary. It now returns 401 without an access-window header. Stop awaits credential revocation before its socket cleanup. This proves rejection after completed Stop, not every Stop/probe race or cleanup-failure case. An already-admitted command's commit/cancellation outcome still needs the real Core facade. A stopped handler cannot issue another credential; fresh Enable composition remains unimplemented.

The first revocation test attempt lacked its MCP import and failed compilation. That is not red evidence. The committed red summary comes from the corrected executable run at /private/tmp/PlannerMCPRevocationExecutableRed.xcresult; green is /private/tmp/PlannerMCPRevocationGreen.xcresult. Both executed six tests with no skipped or expected failures. Matching logs remain local.

## Existing behavior qualification

These additional fixtures observed existing native/SDK behavior and passed on their first executable run. No implementation was changed to make them pass, and no red result is claimed. Each uses the real loopback listener and URLSession rather than bypassing native header handling.

| Observation | Exact input and outcome | Actual evidence |
| --- | --- | --- |
| Listener closure | After Stop completes, a new HTTP request to its previous endpoint fails with URLError.cannotConnectToHost, code -1004. Seven tests pass. | [Summary](evidence/mcp/listener-closure.json) |
| Origin validation | Valid authenticated ping with Origin `https://untrusted.example` receives HTTP 403 and no access-window header. Eight tests pass. | [Summary](evidence/mcp/origin-validation.json) |
| Header validation | Four distinct parameterized ping cases change one header: Host untrusted.example gives 421; Accept text/plain gives 406; Content-Type text/plain gives 415; MCP-Protocol-Version 2099-01-01 gives 400. All omit the access-window header. | [Summary](evidence/mcp/header-validation.json), [executed case tree](evidence/mcp/header-validation-tests.json) |

The final header run reports nine test functions, including one function with four executed cases. It does not report twelve test functions. There are zero failed, skipped or expected failures. Bundles/logs are /private/tmp/PlannerMCPClosureQualification, PlannerMCPOriginQualification and PlannerMCPHeaderQualification with xcresult/log extensions. Native connection-refused diagnostics belong to the intentional closed-listener fixture. No source-content or store result is inferred from these transport-only checks.

## Request-scoped SDK qualification

Two more existing-behavior fixtures pass without an implementation change or a claimed red run. [Initialization evidence](evidence/mcp/initialization.json) records ten test functions passed. Fixture A initializes with integer ID 1 and version 2025-11-25, then initializes again with integer ID 2 and that same version. Fixture B initializes with integer ID 1 and version 2024-11-05. Each real HTTP response has its literal expected ID/version, empty advertised capabilities, current access-window header and no error/session ID. The requests omit the protocol-version header during initialization and supply their requested version in the standard body. This observes the request-scoped integration, not a patched SDK or initialized-client registry.

[Concurrent ping evidence](evidence/mcp/concurrent-ping.json) records eleven test functions passed. Two URLSession requests are submitted with async let, one carrying integer ID 1 and one string ID "1". Each receives its correctly typed ID, empty result and current window exactly through its own returned exchange. Neither returns an error or session header. Their five-second test request budgets do not add an Agent Control timeout. Bundles/logs are /private/tmp/PlannerMCPInitializationQualification and PlannerMCPConcurrentPingQualification with xcresult/log extensions.

Concurrent submission of two pings is a narrow routing observation. It does not prove the approved same-ID Hotel/Museum reads, overlap in the shared Core writer, retained per-caller tool/capability context, actual-client concurrency or the required 64-read load measurements. Empty advertised capabilities are accurate while no Planner tools exist; they are not the final tool catalog. Those original gates remain open.

The accepted Q29 contract additionally requires useful failure for unsupported versions without accidental downgrade. The pinned SDK defaults to its latest supported version for an unsupported initialization body; the new failing fixture observed that behavior over real HTTP. The native adapter now uses the SDK's public `Request<Initialize>` decoder, Initialize.name and Version.supported to reject that one case before dispatch. It returns the SDK's HTTP 400 error with no successful result/window header. Other envelope parsing, supported negotiation, method dispatch and result encoding remain SDK-owned. This is the approved stricter native constraint, not a fork or replacement handshake implementation. Red/green bundles are /private/tmp/PlannerMCPUnsupportedInitializationRed.xcresult and PlannerMCPUnsupportedInitializationDiagnosticGreen.xcresult, with matching logs.

## Incomplete request shutdown

The [actual incomplete-request result](evidence/mcp/incomplete-request-stop.json) records thirteen test functions passed, zero failures/skips. A real Network framework TCP connection sends a POST /mcp header declaring Content-Length 10, then supplies no body. The fixture invokes Stop while the connection is waiting for the remaining request. Stop returns, and the peer receives closure without response content. End of stream or a peer-reset error is accepted as socket closure; client cancellation does not satisfy that assertion. Client cancellation occurs only after observation or for test cleanup.

This qualification passed with the existing listener implementation; no red run or production change is claimed. The one-minute Swift Testing trait bounds the fixture only and does not create an Agent Control duration/idle limit. Native Network APIs handle connection/send/receive; test helpers wrap that actual I/O and never inspect NIO or handler internals. Bundle/log are /private/tmp/PlannerMCPIncompleteRequestQualification.xcresult and PlannerMCPIncompleteRequestQualification.log. This proves shutdown of an unfinished HTTP exchange, not before/after-commit domain cancellation or every app/reader lifecycle race.

## Remaining scope

The app has no Enable/Stop UI and does not instantiate the listener outside tests. Thirteen test functions cover authentication, endpoint routing, actual loopback ping, rejection after Stop, listener closure, incomplete-body shutdown, explicit Origin/Host/version/media cases and the narrow initialization/typed-ID observations above. Full command routing/caller context and native app lifecycle remain future slices. Core commands, genuine store/recovery outcomes and all four actual clients remain the original ticket's gates. Permanent Delete/admin authority and unchanged data after rejected domain requests require the eventual real facade; this result does not replace them.

The signed reader remains a native gate. A host-access read-only signing inventory found zero valid signing identities on 2026-10-09. The built app has only ad hoc signing and no provisioned App Group/application identity. The [existing Apple test access inputs](../setup/apple-test-access.md#human-inputs-and-actions) need the user's selected signing team and actual identifiers before those capability checks; no credential/certificate values belong in chat or source. Local HTTP qualification can continue independently. Do not weaken Data Protection Keychain/App Group requirements or the accepted reader checks to obtain a passing result.

## Clean-source reproduction

Exported committed snapshot eb7a392 with git archive into /private/tmp/PlannerMCPCleanCheckout, without personal Xcode state, ignored Local.xcconfig, previous build products or uncommitted source. Its Mac test command used a new /private/tmp/PlannerMCPCleanDerivedData directory, the committed resolved pins and the same affected PlannerMCPTests target. Existing downloaded package checkouts are a dependency cache, not app build products. [Actual clean-source result](evidence/mcp/clean-source-green.json) records three tests executed and passed, zero failed/skipped, on macOS 27.0.1. The full result bundle is /private/tmp/PlannerMCPCleanCheckout.xcresult and log is /private/tmp/PlannerMCPCleanCheckout.log.

The native test-host log includes nonfatal connection/re-registration diagnostics for the system com.apple.linkd.autoShortcut service. This report does not classify them as pre-existing or claim App Intents/Shortcuts integration passed. Those capabilities are not implemented; their signed runtime checks remain required. The HTTP test assertions and actual result bundle pass despite those diagnostics.

Committed snapshot 6593e79 was also archived into /private/tmp/PlannerMCPTransportCleanCheckout and tested using fresh /private/tmp/PlannerMCPTransportCleanDerivedData products. [Actual result](evidence/mcp/clean-transport-green.json) records eleven test functions passed, zero failures/skips, including all four header cases. This snapshot precedes the later unsupported-initialization slice and does not qualify that later guard. Its full bundle/log are /private/tmp/PlannerMCPTransportClean.xcresult and PlannerMCPTransportClean.log. A separate generic iOS Simulator build of 6593e79 passed using fresh /private/tmp/PlannerMCPMobileTransportDerivedData products, log /private/tmp/PlannerMCPMobileTransportBuild.log; no simulator UI or physical-device result is claimed.

The final implementation snapshot 6fe98ee was archived into /private/tmp/PlannerMCPFinalTransportCleanCheckout and tested using another fresh /private/tmp/PlannerMCPFinalTransportCleanDerivedData directory. [Actual final result](evidence/mcp/clean-final-transport-green.json) records twelve test functions passed, zero failures/skips, including the unsupported-initialization failure diagnostic and four header cases. The full bundle/log are /private/tmp/PlannerMCPFinalTransportClean.xcresult and PlannerMCPFinalTransportClean.log. No personal Xcode state, Local.xcconfig or previous app products were copied. The dependency cache remained the exact pinned package source.
