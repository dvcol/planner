# Native saved List completion and details

## Context and starting state

The accepted completion policy keeps each appearance's local state independent. Global Done takes precedence, and Global Reopen reveals the retained local values. Normal details show useful content and context, with explicit navigation to the global Item. Earlier phone/tablet journeys exercise these saved workflows; broader Mac runtime qualification remains open after the catalog-sorting slice at 37d479a.

## Goal and definition of ready

Run the two existing saved-data public UI journeys on native Mac, using disposable local datasets and production views. The native Xcode project, shared PlannerNavigation scheme, locally signed app/test host and unlocked/idle Mac are available. No account, CloudKit or signing changes are required. Existing fixtures, actions and expected values define the test boundary before any controller correction.

## Required tests and definition of done

- Create one Item and two Lists through native forms. Complete only the first List appearance, verify Global Done affects both displays, and verify Global Reopen restores their independent values. Relaunch, reopen and change local completion without altering the other List.
- Select an Item appearance and verify its notes and List context in normal details. Technical completion fields and the old Open source Item button remain absent. Use Item actions to reach the same global Item, then relaunch and recover contextual details.
- Pass the complete represented Mac functions, inspect original fixture-window captures, record exact commands/results and preserve any failed diagnostic epochs separately.
- Run strict affected Swift lint and report Markdown lint. If shared controller code changes, qualify affected compatibility paths without counting compilation as runtime proof.

These tests qualify the represented local saved workflows. Broader navigation, accessibility, keyboard/resizing, performance, signed sync/account/Share and final human UI acceptance remain separate map gates.

## Execution

The initial focused Mac run uses the existing source unchanged. Both functions fail before the List behavior under review, in 38.064 and 37.377 seconds. The native query for Show Sidebar matches a toolbar Button and a View menu item. No completion or persistence failure is established by that ambiguity.

The controller correction is limited to Mac: use the identified New List control when directly available, otherwise the own window's native toolbar overflow and New List menu item. Section changes activate the app and wait for foreground readiness. The existing mobile actions and all journey assertions remain unchanged. Both Mac functions pass on that controller in 144.379 and 45.013 seconds. All three original own-window captures were individually inspected. This is native-controller qualification, with no product red-green claim.

Spec review found that the completion journey observed Wishlist while Global Done was active, but revisited Tokyo Food only after Global Reopen. The strengthened shared journey now opens Tokyo Food while Global Done is still active and requires Completed, disabled control, the globally completed accessibility label and full progress before reopening. The prior restoration/relaunch assertions remain.

The first rerun with this extra assertion fails at foreground readiness before either data journey, in 14.578 and 13.952 seconds. It overlapped the iPhone simulator build/startup; that is a known execution condition, not proof of the cause. A registry query reports only an on-console boolean and supplies no lock-state evidence. Mobile qualification is completing before an isolated final Mac retry. Earlier function passes do not qualify the newly added assertion.

## Adaptive controller corrections

The strengthened phone-only completion function passes in 195.801 seconds. The first iPad attempt fails before completion in 37.175 seconds because its helper cannot reveal New List. Switching iOS section navigation to the existing floating-tab/sidebar helper passes both phone functions in 194.400 and 58.185 seconds, but iPad still fails both creation prefixes in 29.877 and 29.944 seconds.

Original automatic iPad app-hierarchy attachments identify the missing control in a native More toolbar menu. The first overflow correction passes the detail journey in 65.988 seconds, while completion fails in 63.295 seconds when creating the second List. The own-window failure hierarchy identifies two different panes: the generic overflow query chose the selected List pane rather than the Planner catalog. The final regular-width controller scopes More to the Planner navigation bar. No production correction was needed.

## Qualified results

| Platform and source epoch | Completion function | Detail function | Failures / skips |
| --- | --- | --- | --- |
| Mac, isolated serialized run | 144.543 s | 46.010 s | 0 / 0 |
| Portrait phone, adaptive section helper | 194.400 s | 58.185 s | 0 / 0 |
| Tablet, scoped catalog toolbar | 201.643 s | 65.752 s | 0 / 0 |

These are two unique public native functions on each platform. All three runs execute the explicit Global Done checks in both Lists before Global Reopen, plus the preserved local-state/relaunch and normal-detail assertions. Historical passing prefixes and earlier full passes are not added to these qualification counts.

The tablet run compiles the final test source. Folding every platform conditional leaves every active Mac source line identical to the isolated Mac pass. The later regular-width iPad creation branch is the only source difference from the passing portrait-phone file; the phone's existing creation actions remain its other branch. Exact source comparisons are retained. This reuses the represented Mac/phone runs and credits no additional invocation after the iPad-only correction. Each of ten epochs retains 214 source/configuration hashes, original logs, command/results and three product hashes. Actual current Mac and final tablet products are checked separately; earlier test-without-building product equality belongs to its historical epochs.

All 20 original named native captures, including historical attempts, were individually inspected. They agree with contextual/global completion, normal details and notes. Only explicitly named own-app/window images are shared. Automatic desktop captures remain private. Narrow text truncation, toolbar overflow, spacious empty panes and overall visual hierarchy retain the final polish gate; these checks do not establish accessibility, keyboard/resizing, physical latency or cloud convergence.

## Checks and limits

Strict affected Swift lint, report Markdown lint, source/product/capture verification and whitespace checks pass. Independent source/evidence reviews record their results separately. Production views, Core, HTTP, schema and configuration remain unchanged from 37d479a. No Core/HTTP repeat is credited. Runtime warnings remain in their original summaries and do not establish performance qualification.

The user subsequently accepted Q88-Q92 in [the creation and selection record](../native-creation-and-selection.md). Those new creation, deletion-replacement and saved-Maps-card behaviors remain separate implementation work. This report qualifies the existing saved completion/detail workflows, not those requested changes or the whole map. Fixture datasets remain local; cleanup is not claimed. Signing, physical sync/account/Share, accessibility, performance and whole-app polish remain open.
