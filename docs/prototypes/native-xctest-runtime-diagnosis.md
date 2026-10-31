# Native XCTest runtime diagnosis

Status: both unchanged phone controls and all 13 cases through Xcode's ordinary
Mac hosted workflow pass. The Mac guarded-draft journey now passes twice using
an explicit native filled-window setup. Its separate 860/1200-point resizing and
rich-content relaunch journey also passes. Earlier failures remain recorded;
actual external-request/system and signing gates stay open.

## Context, starting state and goal

The directed-opening implementation compiles, but Xcode stalls before entering
its 13-case suite. A native landscape journey reaches No items and both estimate
metrics, then times out during teardown. The goal is executable verification of
the complete map, with product failures, controller failures and unavailable
infrastructure distinguished. Signing stays deferred.

Current process inspection finds no live build/test job at the start of this
diagnosis. Existing failed invocations remain failed. Body assertions and
compiler success cannot substitute for a completed passing native journey.

## Definition of ready and approved feedback loops

Q126 approves the real coordinator and Intent interfaces; the existing native UI
seam covers actual creation, orientation and navigation. Reuse the exact
existing PlannerMCPTests bundle and SavedAppearanceJourneyTests journeys. The
direct XCTest mode was already established for native Item windows and clock
inputs. No new package, target, production test control, fake window callback or
alternate implementation is added.

The native landscape loop creates a disposable local dataset, launches
landscape, creates its first List through the real UI, checks No items and both
estimate identities, captures the own-app window and restores Portrait. A second
existing control clears Inbox search and switches to Items. That control has no
rotation or custom teardown. Both must complete normally to supply passing
native evidence.

## Executed observations and probes

| Check                                                     | Prediction or purpose                                                                                       | Actual result                                                                                                                                                                                                                                                                             |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Unchanged Xcode 13-case baseline                          | Establish current IDE-session execution before changes.                                                     | Zero cases; stopped at its four-minute bound, exit -15. Packet.                                                                                                                                                                                                                           |
| Existing direct XCTest mode                               | Execute the same compiled production interfaces independently of the stalled IDE-session workflow.          | All 13 cases pass, zero failures/skips, 0.539 seconds. Exact source and binaries match before/after. Packet.                                                                                                                                                                              |
| Restart only the task iPhone Simulator, retaining data    | If stale per-device runtime state causes the failure, the unchanged journey should complete.                | Restart/boot succeed; all body checks complete in 20.98 seconds, then Portrait teardown times out. Restart and failed journey.                                                                                                                                                            |
| Temporary GUI-user developer directory                    | Test the tools-context mismatch for one unchanged invocation, then restore it.                              | Native timeout persists. The prior unset value is restored and verified. Before/after and failed journey.                                                                                                                                                                                 |
| Synchronous successful restoration, asynchronous fallback | If asynchronous native restoration is the problem, perform and verify it within the test body.              | Actual Portrait restoration/assertion completes in 18.47 seconds, then the asynchronous fallback's orientation read stalls. The invocation remains failed. Packet.                                                                                                                        |
| Local-state fallback                                      | Avoid a native read after successful restoration.                                                           | The first XCTestCase capture is a non-Sendable compiler failure, with zero native test credit. The safely isolated state variant compiles and executes, but still times out at teardown. Compiler failure and executed failure.                                                           |
| Synchronous teardown callback                             | Use XCTest's documented main-thread callback with checked actor isolation and actual Portrait verification. | Body assertions complete; teardown still times out. Packet.                                                                                                                                                                                                                               |
| Unchanged non-rotating Inbox control                      | Distinguish an orientation/controller-only explanation from broader completion failure.                     | All body checks and the selected Items capture complete in 29.09 seconds, then Tear Down times out. Packet.                                                                                                                                                                               |
| Same Inbox control on committed pre-handoff 654d22fc      | Determine whether newer window/Open wiring is necessary for the failure.                                    | All body checks complete in 28.64 seconds, then Tear Down also times out. App, View, test and project bytes match the commit; all four newer handoff files are absent. The actual compiled product has 81 actions and neither Open action. Source/product verification and failed result. |

The installed XCTestCase header states: "Registered blocks are run on the main
thread but can be registered from any thread." XCUIDevice is main-actor
annotated. That justified the checked synchronous callback probe; its failure
means no controller correction is accepted. Temporary state helpers, deferred
restoration and callback changes are all reverted.

## What the evidence establishes

The 13-case direct-module result qualifies the approved production interfaces
and ordinary dependency-initializing SDK calls, including the final
inactive-window fix. It does not repair Xcode's IDE-session workflow or prove
actual window activation, system invocation or physical behavior. Its original
fixture-disposal rejection and separately guarded canonical-path cleanup remain
recorded in the handoff report.

The native failures do not require rotation, custom teardown or the newer
handoff integration. This contradicts the narrower controller-only and
new-integration-only explanations. It does not establish a particular
OS/framework cause or exclude every possible older app interaction. No failed
invocation is reclassified as passed.

Ambient xcode-select points to Command Line Tools, and ordinary xcrun cannot
find simctl. Explicit DEVELOPER_DIR selects Xcode 27.1 and finds it. Xcode's
read-only first-launch check succeeds. No Simulator GUI app is found in the
selected Xcode bundle or by its Spotlight bundle-identifier query; that
observation alone does not establish the cause. The temporary GUI environment
probe does not establish the environment of an already running broker. No global
xcode-select, signing or security setting changes.

## State after diagnosis

The repository's production and UI-test source are restored to committed code.
The latest app/test targets compile after the intentionally older comparison.
All 1,061 frozen inputs match the repository. The current app is reinstalled
only on the task's iPhone Simulator, retaining its data; installed metadata
matches the product and contains all 83 expected actions. Restore/build/install
verification. This supplies no runtime interaction credit.

## Earlier required action and definition of done

The protected user test broker remains the long-running process recorded during
the earlier macOS refusal. No alternate mechanism attempts to bypass that
refusal. A normal user-driven Mac restart and reopening Xcode is the next
meaningful runtime change. Signing/account setup remains deferred. Request
readiness after source/evidence is pushed, rather than repeating unchanged
native runs.

After refresh, revalidate live processes and tool selection, then rerun the
unchanged native completion control and orientation journey before broader
Mac/mobile qualification. This gap is resolved only when the required
current-source native journeys complete successfully with their actual results
retained. The passing module cases do not replace actual window activation,
system Intents, signed/physical checks or the final feature-complete UI review.
This runtime gap and the overall map remain open.

## Executed retries after readiness

The user confirmed readiness on 21 October. The execution host still reports the
earlier boot time and protected broker identity, so these results do not
establish that a full host restart occurred or identify what repaired execution.
No developer, signing or security setting changes were made during these
retries.

| Unchanged check                      | Actual result                                                                                                                                                                                                                                                                                 |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nonrotating Inbox search/tab control | Passes, including normal completion, in 31.927 seconds. Result and original captures.                                                                                                                                                                                                         |
| First List creation in landscape     | Passes, including Portrait cleanup, in 35.715 seconds. The original capture shows the ready empty List and both estimate metrics. Result and capture.                                                                                                                                         |
| Xcode-hosted SavedPlanOpeningTests   | All 13 cases pass, zero failures/skips, in 1.434 seconds. The existing strict verifier safely disposes all 17 closed, owned fixtures with no lifetime diagnostics. Result and disposal.                                                                                                       |
| Mac app/UI products                  | Current source builds successfully. Source and product hashes.                                                                                                                                                                                                                                |
| Mac guarded draft navigation         | Automation starts and reaches Keep editing, invalid Save and a later valid Save. A subsequent Items-sidebar click fails to find a hit point for its ScrollView. The 65.304-second invocation completes with exit 65 rather than timing out. Failure and original window hierarchies/captures. |

All 1,061 inputs of each passing retry match the current repository. The Mac UI
invocation additionally checks its compiled products before and after execution.
Its failure supplies no complete draft-navigation credit. The ordinary
hosted-startup and represented phone-completion gaps now have passing reruns;
their original failed invocations remain failed. Next diagnose the Mac
interaction through the existing native UI seam. Actual external-request/window
behavior, system invocation, signed/physical qualification and final whole-app
review remain open.

## Mac draft and resize qualification

The unchanged repeat fails earlier, with the untouched editor's Cancel control
absent from its query, in 25.578 seconds. A test-only diagnostic captures the
expected Cancel and native confirmation sheet in Planner's own window, but that
invocation fails querying the sheet, in 34.559 seconds. These are different
observations from the first post-Save hit-point failure. They do not establish a
persistence defect or one proven accessibility cause. Unchanged repeat and
diagnostic source/captures retain the failures.

Remove the temporary captures and give this ordinary draft-guard test an
explicit wide-window precondition through the existing native Window Fill
helper. Keep every assertion and the production implementation unchanged. This
three-line Mac-only setup is separate from compatibility coverage; it cannot
establish that every restored or narrow geometry works.

The full guard journey then passes in 79.072 seconds, including untouched
Cancel, Keep editing, invalid Save, valid Save and the original List's
contextual appearance. First pass retains its actual xcresult. The original
wrapper incorrectly labels passingCredit false because test-without-building
prints TEST EXECUTE SUCCEEDED. Its original record is preserved; the separate
actual-result verification checks exit zero, the exact passing case and all
xcresult counts. The subsequent wrapper recognizes both successful completion
markers.

The next two-case compatibility invocation passes with zero failures/skips. The
unchanged rich-draft journey takes 156.018 seconds. It actually resizes to 860
and 1200 points, hides/shows the native sidebar, retains title/subtitle/notes,
exact duration, address and ordered bookmark fields, saves to the original List,
and verifies source/appearance/bookmark identities and content after relaunch.
The filled-window guard repeats successfully in 67.946 seconds. Source and
product hashes are checked before and after execution.

The inspected original narrow and expanded captures show the native sidebar,
content pane and editor, with Save/Cancel and rich fields present. The narrow
capture contains dashed overlay lines, so it is compatibility evidence rather
than a final polished presentation. Strict Swift formatting and the current Mac
app/UI compilation pass. No production behavior correction, complete
accessibility acceptance or external-request injection is inferred. Continue the
remaining native window/feature checks; signing and account setup remain
deferred.

The unchanged two-window selection journey also passes, in 94.272 seconds.
Deleting the source from a second real window replaces the original window's
selected appearance with its first visible sibling in the same List, preserving
that surviving association identity and contextual notes rather than selecting
an unrelated global Item. The second window closes independently. Its original
window identities, hierarchy and capture remain retained. This qualifies that
ordinary shared-data/window interaction, not external Intent focus targeting.

## Mac automation and Item startup follow-up, 22 October 2026

### Current starting state and next goal

After the
[Calendar mode checkpoint](native-calendar-day-week.md#mac-runtime-follow-up-22-october-2026),
the next local checks are native Schedule Edit/Cancel/Clear End and confirmed
removal, followed by Mac all-day date entry and spans. The map remains open and
signing is deferred. Separately, the first iPad Calendar group had failed before
creation because its Add-menu helper found no available control; its unchanged
complete retry passed without establishing a cause.

### Actual Mac outcome

The two-case Mac request validates the existing source/product hashes, then ends
with xcodebuild exit 65 and no requested test function started. XCTest reports
“Timed out while enabling automation mode.” Its summary counts one
runner-initialization error; that is not an executed Schedule case. Neither
requested editing/removal journey receives passing or failing product credit.

A read-only, filtered session observation establishes only that the session is
on-console. It does not establish that the Mac is unlocked or idle. Current
readiness is requested through the question tool. No signing, global tool
selection, protected broker or security setting is changed. A fresh
current-source Mac app/UI build succeeds later, providing compilation evidence
only.

### Startup tracer and required tests

Use the already approved public native UI seam to minimize the mobile startup
path: launch an isolated dataset, select Items, use the native Add menu, open an
untouched New Item editor, verify its Title field is usable and leave through
the native cancellation control. Failure-only diagnostics at the existing
unavailable-menu guard capture Planner's owned window and its window-scoped
hierarchy. They add no production flag, dependency injection, package or target.

The Definition of Ready is the existing native UI boundary and accepted
Add/draft-navigation behavior. The Definition of Done for this diagnostic tracer
is current-source compilation on both platforms, actual phone/tablet execution,
a recorded cold-boot precondition on the dedicated iPad Simulator and an honest
distinction between this result and the original failure. No production
correction or complete startup-stability gate is claimed merely because the
tracer passes.

The initial cold-boot iPad case passes in 20.529 seconds. The first phone
attempt reaches the editor and then fails in 17.623 seconds because the new test
used the older Cancel-only identifier. Its scoped original observation shows the
compact editor's native Back button. The final selector reuses the existing
draft journeys' accepted Back/Cancel representations; production navigation is
unchanged.

The final phone case passes in 19.192 seconds. The final iPad case passes in
29.333 seconds after a second controlled cold boot. Both boot records show
shutdown, boot and successful bootstatus for the dedicated test device; neither
erases data. The original Add-menu failure is not reproduced in these
observations and remains unclassified. The new missing-menu capture branch has
not been exercised by a reproduced failure.

The verification packet reconciles all 1,061 inputs across the final two mobile
runtimes and current Mac compilation. It verifies two passing executions of one
tracer, zero requested Mac Schedule cases executed and no production changes
relative to `2d360504`. Affected strict Swift/Markdown and whitespace checks
pass. The initial compiler, failed phone driver, cold-boot records and Mac
startup error retain their actual outcomes.

### Remaining gates and required input

The Mac Schedule actions and all-day span/date-input journeys remain unexecuted
in this follow-up. Current Mac readiness is needed before another UI attempt.
Q127 separately asks the human to choose the Mac Calendar details presentation
after the proven resize crash; that decision is restated through the question
tool. The iPad startup cause, wider native accessibility/keyboard and window
checks, actual system Intents, signed/physical qualification and final whole-app
polish remain open. These compiler/tracer results do not close those gates or
imply that a paid developer account repairs UI automation.
