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

The test asks the OS for an available port with port zero so disposable parallel fixtures do not occupy the user's 44444 endpoint. The listener's default remains 44444. The real URLSession request uses literal ping ID 7 and asserts the actual 200/JSON-RPC result, matching access window, absent session ID and 127.0.0.1 host. Its five-second request timeout only bounds a failing test request; it is not an access expiry. The test stops the listener before returning, but does not yet prove listener closure, idle connection cancellation or revoked credentials.

The separate Stop-admission fixture starts and stops a real disposable listener, then submits the old credential through the approved HTTP handler boundary. It now returns 401 without an access-window header. Stop awaits credential revocation before its socket cleanup. This proves rejection after completed Stop, not every Stop/probe race or cleanup-failure case. An already-admitted command's commit/cancellation outcome still needs the real Core facade. A stopped handler cannot issue another credential; fresh Enable composition remains unimplemented.

The first revocation test attempt lacked its MCP import and failed compilation. That is not red evidence. The committed red summary comes from the corrected executable run at /private/tmp/PlannerMCPRevocationExecutableRed.xcresult; green is /private/tmp/PlannerMCPRevocationGreen.xcresult. Both executed six tests with no skipped or expected failures. Matching logs remain local.

## Remaining scope

The app has no Enable/Stop UI and does not instantiate the listener outside tests. Six tests prove the two authentication rejections, genuine authenticated SDK ping, exact /mcp routing, one real loopback exchange and rejected admission after Stop. Origin/Host/version/media validation, listener closure, concurrent routing/negotiation and full lifecycle remain future slices. Core commands, genuine store/recovery outcomes and all four actual clients remain the original ticket's gates. Permanent Delete/admin authority and unchanged data after rejected domain requests require the eventual real facade; this result does not replace them.

The signed reader remains a native gate. A host-access read-only signing inventory found zero valid signing identities on 2026-10-09. The built app has only ad hoc signing and no provisioned App Group/application identity. The [existing Apple test access inputs](../setup/apple-test-access.md#human-inputs-and-actions) need the user's selected signing team and actual identifiers before those capability checks; no credential/certificate values belong in chat or source. Local HTTP qualification can continue independently. Do not weaken Data Protection Keychain/App Group requirements or the accepted reader checks to obtain a passing result.

## Clean-source reproduction

Exported committed snapshot eb7a392 with git archive into /private/tmp/PlannerMCPCleanCheckout, without personal Xcode state, ignored Local.xcconfig, previous build products or uncommitted source. Its Mac test command used a new /private/tmp/PlannerMCPCleanDerivedData directory, the committed resolved pins and the same affected PlannerMCPTests target. Existing downloaded package checkouts are a dependency cache, not app build products. [Actual clean-source result](evidence/mcp/clean-source-green.json) records three tests executed and passed, zero failed/skipped, on macOS 27.0.1. The full result bundle is /private/tmp/PlannerMCPCleanCheckout.xcresult and log is /private/tmp/PlannerMCPCleanCheckout.log.

The native test-host log includes nonfatal connection/re-registration diagnostics for the system com.apple.linkd.autoShortcut service. This report does not classify them as pre-existing or claim App Intents/Shortcuts integration passed. Those capabilities are not implemented; their signed runtime checks remain required. The HTTP test assertions and actual result bundle pass despite those diagnostics.
