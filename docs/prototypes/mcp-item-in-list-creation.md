# Ordinary Item creation in a List over MCP

Status: the Q93 MCP adapter passes focused real HTTP qualification. Native creation integration remains open.

## Context and expected state

The [approved Q93 contract](../create-item-in-list-contract-review.md) extends ordinary Item creation with an optional List destination. The previous HTTP command rejects that property and offers no ordinary creation review.

`planner_execute` now accepts an omitted or null `listId` for global creation, or a UUID for atomic creation in an active List. It preserves separately authored bookmarks with the same URL. Core supplies the same source, membership and operation-replay guarantees as native callers. Existing HTTP restrictions on unsupported creation fields remain unchanged.

`planner_prepare_review` advertises destination-bearing creation. Its normalized command can be passed directly to execution. Review binds the complete authored command, List lifetime and name-field hash. Changed content, omitted destination or a renamed List invalidates the token. Preparation saves no domain data. Global creation requires no review and is rejected as a nonreviewable preparation request.

## Definition of ready and required tests

Q93 approves the public MCP HTTP boundary. Tests use the real loopback listener, authenticated HTTP requests, tool discovery, public Planner reads and saved datasets. No private parser tests or production test parameters are introduced. Named fixture stores remain available for external cleanup after test-process exit.

The journey must observe duplicate bookmarks, generated source/membership identities, local Todo progress, replay after membership removal, omitted/null compatibility, a directly reusable review command, stale review rejection, and atomic rejection of malformed/missing/archived destinations.

## Results

The [evidence packet](evidence/navigation/mcp-item-in-list-creation/) records commands, source exports, overlays, binaries and original output for every epoch. Exports use committed base `e3426aa` with only the two MCP production files and the new HTTP test file overlaid; unfinished native UI code is excluded.

`creation-behavior-red` reaches the real listener and fails because destination-bearing creation is rejected. `creation-green` passes after decoding the optional destination. `review-red` keeps that first journey passing and fails because ordinary creation has no HTTP review. `review-qualified` passes both journeys after routing and roundtrip encoding are added.

The final `http-review-qualified` batch passes 12 functions in five suites in 1.572 seconds, with zero failures or skips. It includes three new Q93 functions and existing label admission/live edits, membership creation/order and Capture create/reuse/review/replay journeys. Strict Swift lint passes the three affected files. The Mac app and HTTP test host compile and execute; this is not foreground UI automation.

`creation-red` initially fails to build because the isolated export omitted a bundled backup fixture. The export was repaired before the behavioral red run. `review-green` contains an error-initializer label compiler failure, corrected before `review-qualified`. Neither compiler failure receives runtime credit.

Standards review found a multiline ternary in schema assembly. It now uses an explicit conditional, and its recheck is clear. Spec review reports no confirmed findings. The final compatibility batch follows that correction.

## Limits

This slice does not complete native creation/navigation, Mac UI runtime, signed-device sync/account/Share, named external client lifecycle tests, accessibility, performance or final UI polish. No map gate is closed by these HTTP checks.
