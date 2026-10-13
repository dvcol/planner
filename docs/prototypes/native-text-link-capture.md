# Native text and link capture

## Context and goal

Core already prepared, edited and applied capture drafts. The saved native app had no capture entry point or Add/Cancel review. This slice adds “Capture Text or Link” to the Items and Inbox toolbars, using native SwiftUI navigation, grouped Forms, Pickers, Toggles and progress feedback.

The expected end state is one explicitly reviewed Item per invocation. The user may enter a title and notes, retain the original links, choose an exact existing Item and select active List destinations. Capture cancellation must leave saved data unchanged. Reuse must preserve the existing Item's content, completion, archive state and existing references.

## Definition of ready

The accepted C1–C7 choices in [URL and Share capture](../url-and-share-capture.md) and the [capture facade](../adapter-contract.md#capture-preparation-and-apply) define the behavior. Q33 accepted the Core facade and native UI test boundaries. This slice takes independently pasted or entered text through the direct-input API. It does not choose the pending Q78 HTTP transport boundary or implement Share extension deployment.

## Definition of done for this slice

- Review appears before Add, with editable owned title/notes and exact original links. Parsing, opening and cancelling never save an Item.
- An unambiguous exact-link candidate defaults to Use existing; Create new remains available. Reuse calls Core's reviewed command and preserves existing content and state.
- Active List destinations use live stable identities. Global capture remembers successful destinations per device and dataset; Cancel does not update that preference. Invalid remembered destinations fall back to no selected Lists. A new Item with no selected Lists goes to Inbox.
- Add and Cancel are disabled during preparation/save. Interactive dismissal discards an unsaved draft. Applied recovery-incomplete outcomes retain their saved result and show Core's warning rather than inviting another Add.
- Native journeys prove cancellation, one saved Inbox Item, original URL spelling, notes, stable link identity across relaunch, and exact reuse of a completed archived Item with its remembered destination.
- Strict lint and affected mobile/macOS builds pass. Native Mac UI runtime remains a separate gate.

## TDD and qualification

The first iPhone journey failed because the capture entry point did not exist. After implementation, the cancellation and save/relaunch journey passed. A first build diagnostic exposed an invalid Form Section initializer; the corrected native initializer compiled and the same journey passed.

Spec review found that Add submitted an empty edit when the parsed title and notes were unchanged. The untouched-link journey failed before the fix. The form now skips that update and proceeds directly to reviewed apply. Standards review replaced nested notes-change control flow with explicit branches and strengthened reuse to check one total Item with every catalog filter cleared.

Each final mobile run passed four functions in two suites, with four invocations, zero failures and zero skips. The journeys cover edited URL capture and cancellation/relaunch, an unchanged Saved link, unchanged plain-text title/notes without invented links, and reuse of an archived completed Item with its remembered List destination, stable link and no duplicate Item. Six affected Swift files passed strict lint. The macOS app and test host built successfully; no Mac UI runtime was executed. Both review rechecks found no remaining confirmed findings in this slice.

[Execution evidence](evidence/navigation/native-text-link-capture/execution.json) records the narrow commands, source hashes, completed result summaries and original native screenshots. Final source hashes were checked after every build/test process exited. The unrelated pending Maps HTTP lookup work was excluded from qualification and the commit.

## Remaining map work

This is the direct text/link path. Native provider intake, preview presentation, per-input retry, location/label/estimate editing, ambiguous candidate inspection, List-context capture, remembered destinations for other entry points, changed-destination native fixtures, Share and Intents, MCP capture encoding, interrupted-operation recovery presentation, and physical device qualification remain open. Existing Core tests cover some of those domain behaviors; they do not prove their native presentation. Q78–Q81 remain pending. Calendar Day/Week/Month overview and whole-app native polish are still required.
