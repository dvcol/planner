# Create Item in a selected List through Shortcuts

Status: six destination cases, 43 affected native/HTTP tests and Mac/Simulator/unsigned device builds pass locally. Signing remains deferred.

## Context, starting state and goal

At `84679b79`, Core, MCP and native forms support Q93's atomic ordinary Item creation in a List. Shortcuts Create Item accepts Title, Subtitle and Notes, but cannot supply a List. A separate Add Item to List action can leave the Item without its intended membership if that second operation fails.

Add an optional native List parameter to the existing Create Item action and pass its stable identity to the existing Core command. Omission retains ordinary destination-free creation. A supplied active List receives one new local Todo membership at its saved end, together with the Item in one local transaction. Preserve existing source/reference identities, local completion and order. Do not resolve a destination from cached names or archive flags.

## Definition of ready

The [Q93 contract](../create-item-in-list-contract-review.md) already approves the optional destination, identity resolution, atomic save and invalid-destination rules. Q33 permits ordinary Intent mutations. [Q112](../native-app-intent-test-contract-review.md) approves calling production Intents through Apple's public invocation interface and dependency manager, using disposable real Planner storage and actual filesystem failures. No new public Core contract, test boundary, target, dependency, persistence path or test-only control is needed. Q115 and Q117 govern separate pending choices.

## Required tests and definition of done

Record a failing destination creation test before implementation. Verify the returned Item and its sole intended membership after reopening, exact Subtitle/Notes, insertion after an existing independently Done appearance, and a same-named unrelated List remaining untouched. Missing, deleted, archived and wrong-kind destinations or invalid content must create no orphan source or partial membership. Omitted/cleared optional destinations retain global creation. Precancellation and real unavailable bootstrap must preserve data.

An actual post-save recovery filesystem obstruction must retain the saved Item and membership, return their truthful applied outcome, block later mutation and acknowledge the original operation through native recovery without duplication. Run affected Item/List/Subtitle Intent and real HTTP creation regressions, strict Swift/Markdown lint and Mac, Simulator and unsigned generic-device compilation. Inspect extracted metadata for the one optional typed List parameter and unchanged prior action/entity/query/enum and result contracts. Record frozen source hashes and verify fixture disposal after host exit and closed SQLite handles.

Actual Shortcuts picker presentation, persisted system workflows, background/locked execution and physical qualification remain separate gates. This slice does not implement deferred content properties or estimate input, finish the map, or change signing/account setup.

## Executed vertical slice and safety results

The initial compiler red reports the missing List parameter and receives no runtime credit. With the parameter declared, the runtime red saves an Item without its intended membership and fails in 0.564 seconds. Passing the optional List UUID to Core's existing createItem command makes that test pass in 0.231 seconds. The production change adds no second save or fallible lookup after mutation.

The positive fixture reopens the returned source and its one new local Todo membership. The membership follows an existing locally Done appearance in saved Manual order. Exact multiline Notes and non-ASCII Subtitle survive. A same-named other List stays empty, while stale cached destination name/archive values cannot replace its selected identity or current saved state.

All six new cases pass in 0.410 seconds. Missing, deleted, archived and wrong-kind destinations, invalid title and precancellation preserve the exported dataset exactly. Omitting the optional List or explicitly clearing it creates global Items in Inbox, while the intervening destination-bearing invocation creates exactly one membership. An actual file obstructing store setup remains intact and the action reports failure instead of acknowledging creation.

An actual post-save recovery obstruction retains both the Item and its membership. The returned Item is usable and later creation is blocked until native recovery. After restoring the filesystem, native acknowledgement completes the original operation without changing source hashes/timestamps, membership identity, List timestamp or Item count. No extra Item or membership is created by recovery.

## Affected regression and platform qualification

The final source passes 39 XCTest adapter cases in 12.628 seconds and four real HTTP creation/status declarations in 0.317 seconds. The actual result bundle reports 43 passes, zero failures and zero skips. All 39 final native fixture stores are removed only after host exit and verified closed SQLite handles. The earlier passing runs also safely dispose 46 fixtures; the expected runtime red separately disposes its one fixture without qualification credit.

The first Simulator build surfaces an unnecessary mutable binding in the existing Get Item query. Changing it to let retains its dependency binding and behavior. The 43 affected tests and platform builds are rerun against that final source. The initial warning and earlier source epochs remain in the evidence, rather than receiving clean final-source credit.

Final Mac, Simulator app/native UI-test target and unsigned generic-device builds pass with zero compiler diagnostics. Extraction preserves all 53 action identities and adds only the optional typed List parameter on Create Item. Every prior parameter, output type, entity definition, query and enum remains unchanged. All 1028 current input hashes match across platforms; only PlannerItemIntents.swift changes among the prior 1027 inputs, with one destination test file added. The device app embeds exactly one mobile Share extension, and both executables are arm64. Strict affected Swift/Markdown lint and Git whitespace checks pass.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains the app-intent-item-destination packets with original commands/logs, actual exits, source hashes, metadata, result summaries and fixture verification. These are production-interface and compilation results. Actual system picker resolution/invocation, physical installation and device performance remain unqualified. The existing ad hoc Mac test configuration is reused without developer signing/account setup changes.

[Q115 estimate input](../native-estimate-intent-input-review.md) and [Q117 saved-content properties](../native-deferred-content-read-contract-review.md) still await their decisions. Remaining native fields/reads, scheduling/capture/bulk actions, actual system invocation, Agent Control, shared/account-bound storage and CloudKit implementation/proof, installed Share, physical qualification and feature-complete whole-app native polish keep the map open.
