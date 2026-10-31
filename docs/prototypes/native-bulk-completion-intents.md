# Native reviewed bulk completion

## Context, starting state and goal

Q120 A approves three focused Shortcuts actions and direct tests of the production store's review/submission interface. Before this slice, native UI and MCP could review full-context completion, but Shortcuts could change only individual appearances. The store's ordinary Intent writer accepted no review token.

The app now exposes List, Itinerary and exact Itinerary List-entry child-completion actions. Each reads the current target name, obtains Core's exact review, and requests native confirmation with the full appearance count. Hidden, archived and repeated children remain included. Submission carries that review's token through the existing writer and recovery handling. A stale review returns to preparation and system confirmation before any new attempt. A thrown confirmation or cancelled task applies no subsequent write. No cancellation check discards an already applied result.

The branch action retains the complete saved entry identity, including parent and source. Its dependent picker offers List stops in the selected Itinerary, and execution validates the exact saved entry again. It never substitutes the standalone List, another repeated stop or global Item completion. Empty results say No items rather than claiming completion.

## Definition of ready and tested boundaries

The [accepted contract](../native-bulk-intent-contract-review.md) precedes implementation. Q112 covers production Intent invocation and EntityQuery reads. Q120 additionally covers the actual SavedPlannerStore preparation/submission interface. Tests use real local Core persistence, Apple's dependency manager and actual filesystem obstructions in the existing app-hosted target. There is no injected confirmation handler, fabricated approval Boolean, alternate writer, test-only factory or new target.

## Local results

The final hosted invocation passes **72 tests, 0 failures and 0 skipped**, including 14 new bulk cases and 58 affected completion, route-query and ordinary-write regressions. Its original log, selected command, source hashes, actual result summary and closed-fixture disposition are in the final packet.

The new cases establish:

- A List review includes an archived child, writes every local flag together and preserves shared content, archive and other contexts after reopening storage.
- Global Done takes precedence over clearing a local flag; global reopening exposes that retained local flag without rewriting other contexts.
- An Itinerary's five appearances and its two repeated List branches remain distinct. One branch's bulk action changes only its two children. Another Itinerary referencing the same List remains unchanged.
- A changed target set and a missing token reject without partial changes. Preparing a refreshed review does not apply it; a separate submission is required. Empty containers remain empty and unfinished.
- Wrong parent/kind, missing or removed references, restored owner/branch lifetimes, precancellation and unavailable storage reject without redirection or resurrection.
- Actual precommit recovery-filesystem failure leaves every target unapplied. Actual post-save failure retains the whole bulk result for each scope, blocks further changes and acknowledges the original operation only through explicit native recovery retry.
- Production Intent calls reject invalid, cancelled and unavailable requests before confirmation. These calls do not prove system confirmation behavior.

All prior 72 action contracts, entity properties, queries, enums and four discoverable shortcuts remain unchanged. The three new actions have required typed targets and a required completion Boolean. The branch retains the existing route-entry query. Mac, Simulator and unsigned-device builds and metadata verify 75 actions from the same 1,051 hashed source inputs. Strict lint on the four affected Swift files, documentation lint and whitespace checks pass. The final validation records their commands and exits.

## Red/green and failed attempts

The first local runner was stopped by sandboxed compiler-cache permissions before compilation. It supplies no semantic red evidence. The subsequent compiler run found the missing production store interfaces and one invalid Equatable assertion. The isolated red retains only the missing approved interfaces; the first List store case then passes.

An expanded nine-case invocation initially failed two test expectations. Creating local completion records legitimately adds expanded-completion references; removing a branch reports missingReference. The corrected tests preserve the original topology while allowing intentional completion records and assert the existing missing-reference outcome. No production behavior was changed to satisfy those corrections. The failed invocation remains failed, with its separate closed-fixture cleanup and no passing credit. All nine store cases then pass.

The List action red and Itinerary action red retain missing-action compiler failures before their implementations. Their green runs precede the final 72-case qualification. The earlier store-qualified invocation ran only the original List case; it receives one-case credit only.

## Remaining acceptance

Actual Shortcuts confirmation, pressing system Cancel, changed-target reconfirmation, continuation/retry and dependent picker injection remain open. Task cancellation is not evidence of pressing Cancel. Production store tests do not establish user approval in Shortcuts. The existing Customer-build system-testing rejection remains unresolved; these results do not establish that paid signing fixes it.

Signed/shared storage, CloudKit/account transitions, installed Share, physical performance, actual Mac window interactions and final whole-app polish remain separate map gates. No prototype issue is closed by this local slice.
