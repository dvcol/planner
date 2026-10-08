# MCP HTTP qualification evidence

Work in progress for [MCP session prototype](https://github.com/dvcol/planner/issues/16), on the isolated prototype/mcp branch. Q33 approved the [HTTP/adapter contract](../adapter-contract.md) and [reader observations](../content-and-reader-review.md#credential-reader-declaration-accepted-contract-q32-a). This is execution at that unchanged HTTP boundary, separate from the pending navigation UI test approval.

## Context and observable boundary

The native [build setup](mcp-native-build.md) compiles on Mac and iOS simulators. PlannerCore has no domain implementation yet. This slice receives the official SDK's public HTTPRequest and returns HTTPResponse through the native app's request handler. Tests assert wire-visible status and headers, without inspecting handler state or mocking internal collaborators. Native listener, credential issuance, data mutation, real clients and reader execution remain unproved.

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

The authentication filter discovers and executes AuthenticationTests in PlannerMCPTests. The ping runs select the whole affected PlannerMCPTests target and execute AuthenticationTests plus PingTests. Xcode's XCTest compatibility layer separately reports zero XCTest cases; Swift Testing and the xcresult summaries report the actual one/two/three tests above. None is skipped or an expected failure. Test execution launches the signed native test host, not a protocol mock. It does not establish a reviewed UI or a live listener.

For each row, run this affected-target command with its distinct result bundle and capture the actual exit code. Red exits 65 on its assertion failure; green exits zero. Missing source, compiler errors and zero discovered tests do not count as red.

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Planner.xcodeproj -scheme Planner -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:PlannerMCPTests/AuthenticationTests -onlyUsePackageVersionsFromResolvedFile -clonedSourcePackagesDirPath /private/tmp/PlannerMCPSourcePackages -derivedDataPath /private/tmp/PlannerMCPDerivedData -resultBundlePath /private/tmp/PlannerMCPWrongCredentialGreen.xcresult
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool get test-results summary --path /private/tmp/PlannerMCPWrongCredentialGreen.xcresult --format json
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift format lint --strict Planner/AgentControl/PlannerMCPRequestHandler.swift PlannerMCPTests/AuthenticationTests.swift
```

Results use the Mac/toolchain in the build evidence. Full xcresult bundles and logs remain machine-local under /private/tmp/PlannerMCPAuthenticationRed, PlannerMCPAuthenticationGreen, PlannerMCPWrongCredentialRed, PlannerMCPWrongCredentialGreen, PlannerMCPPingRed and PlannerMCPPingGreen, with xcresult/log extensions. Committed JSON summaries come from xcresulttool, omitting only local hardware identifiers under the Apple test access reporting rule. They preserve the executed counts and observed failing assertions. They are not regenerated expectations or fabricated passing results.

The ping fixture uses configured access window 00000000-0000-4000-8000-000000000701, the valid literal credential and JSON-RPC integer ID 7. Expected response is HTTP 200, JSON-RPC 2.0, integer ID 7, empty result object, no error, no MCP-Session-Id and X-Planner-Access-Window matching that admitted window. The test reads the actual SDK response body. The native adapter adds the header while retaining the SDK body/status/headers. It never manufactures a ping result.

This initial integration creates an official Server and StatelessHTTPServerTransport for each HTTP exchange, then stops them when that response resolves. It neither patches SDK sources nor introduces transport sessions or a client registry. That lifecycle is an unqualified integration candidate for the later initialization, context, cancellation and overlapping-request fixtures. A single ping does not prove that the inspected SDK defects or full client capability/version isolation are resolved.

## Remaining scope

The app has no listener or Enable/Stop implementation. Three tests prove only the two rejection observations and genuine authenticated SDK ping through the native handler. Origin/Host/version/media/path validation, revoked access, concurrent routing/negotiation and lifecycle remain future slices. Core commands, genuine store/recovery outcomes and all four actual clients remain the original ticket's gates. Permanent Delete/admin authority and unchanged data after rejected domain requests require the eventual real facade; this unit result does not replace them.

The signed reader remains a native gate. A host-access read-only signing inventory found zero valid signing identities on 2026-10-09. The built app has only ad hoc signing and no provisioned App Group/application identity. The [existing Apple test access inputs](../setup/apple-test-access.md#human-inputs-and-actions) need the user's selected signing team and actual identifiers before those capability checks; no credential/certificate values belong in chat or source. Local HTTP qualification can continue independently. Do not weaken Data Protection Keychain/App Group requirements or the accepted reader checks to obtain a passing result.
