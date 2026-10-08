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

The test filter discovers and executes AuthenticationTests in PlannerMCPTests. Xcode's XCTest compatibility layer separately reports zero XCTest cases; Swift Testing and the xcresult summaries report the actual one/two tests above. None is skipped or an expected failure. Test execution launches the signed native test host, not a protocol mock. It does not establish a reviewed UI or a live listener.

For each row, run this affected-target command with its distinct result bundle and capture the actual exit code. Red exits 65 on its assertion failure; green exits zero. Missing source, compiler errors and zero discovered tests do not count as red.

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Planner.xcodeproj -scheme Planner -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:PlannerMCPTests/AuthenticationTests -onlyUsePackageVersionsFromResolvedFile -clonedSourcePackagesDirPath /private/tmp/PlannerMCPSourcePackages -derivedDataPath /private/tmp/PlannerMCPDerivedData -resultBundlePath /private/tmp/PlannerMCPWrongCredentialGreen.xcresult
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool get test-results summary --path /private/tmp/PlannerMCPWrongCredentialGreen.xcresult --format json
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift format lint --strict Planner/AgentControl/PlannerMCPRequestHandler.swift PlannerMCPTests/AuthenticationTests.swift
```

Results use the Mac/toolchain in the build evidence. Full xcresult bundles and logs remain machine-local under /private/tmp/PlannerMCPAuthenticationRed, PlannerMCPAuthenticationGreen, PlannerMCPWrongCredentialRed and PlannerMCPWrongCredentialGreen, with xcresult/log extensions. Committed JSON summaries come directly from xcresulttool; they preserve the executed counts and observed failing assertion. They are not regenerated expectations or fabricated passing results.

## Remaining scope

Authorized requests still return 501 because SDK dispatch is not implemented. The app has no listener or Enable/Stop implementation. These two tests prove only their rejection observations through the native handler. Valid authenticated SDK ping, Origin/Host/version/media/path validation, revoked access, concurrent routing/negotiation and lifecycle remain future slices. Core commands, genuine store/recovery outcomes and all four actual clients remain the original ticket's gates. Permanent Delete/admin authority and unchanged data after rejected domain requests require the eventual real facade; this unit result does not replace them.

The next independently specified behavior is a valid authenticated SDK ping with its matching request ID and admitted access-window header. Do not manufacture successful protocol replies or weaken the reader checks to obtain a passing result.
