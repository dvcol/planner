# Native List notes

## Context and starting state

The accepted [content contract](../content-and-reader-review.md) gives Lists optional notes. Core, backups, MCP and the native List App Intents already support them. At starting revision 22c986e1, the native List form exposes only its name and manual estimate, and its opening action is labeled Edit estimate.

## Goal

Allow native List creation and editing to save or clear notes through the existing guarded commands. Cancel must discard the unsaved draft. Editing another field must preserve unchanged notes and the List's existing relationships, order, completion and metadata.

## Test boundary

Use the existing approved native UI journey boundary and disposable local Planner dataset. Exercise production Form controls, Save/Cancel and relaunch. Observe saved notes by reopening the same List editor; do not inspect private persistence or add a test-only input. Existing public Core command and HTTP tests retain their separate coverage. No additional test boundary, schema, package, target or agent contract is proposed.

The recorded toolchain is Xcode 27.1, build 27A9275, with macOS SDK 27.0 and iOS device/Simulator SDKs 27.1. The phone and tablet run iOS 27.0; the Mac runs macOS 27.0.1. Exact destinations and commands are retained with each result.

## Change

The shared native List form now includes a multiline Notes field and opens through Edit list. Name, notes and manual estimate participate in Save eligibility. A notes-only edit can save; an unchanged editor cannot.

Creation writes empty notes as absent. Editing unchanged notes sends unchanged, preserving the original optional value. A changed empty field explicitly clears notes; other text is saved verbatim. The existing field hashes, operation identity, recovery checks and save-failure presentation remain in use. This adds no Core, schema, backup, MCP, target or dependency change.

## Phone execution

The first tracer fails at the absent native Notes field in 22.336 seconds, then passes after implementation in 60.225 seconds. It cancels one unsaved draft, saves another and reopens the saved text after relaunch.

The expanded editing controller needed two corrections: selecting the nested mobile switch rather than its row container, and opening the catalog normally before capturing its source identity. The failed outcomes remain failed in their evidence packets. Production code did not change for either correction.

The final editing journey passes in 115.692 seconds. It verifies canceled changes, a notes-only multiline save, preservation during an independent name change, an explicit clear, unchanged-editor Save disabling, the original source identity, the same one-hour manual estimate and relaunch.

The unchanged creation and original empty-List journeys also pass in the earlier combined invocation, in 59.945 and 27.004 seconds. That invocation remains failed because its editing controller had not yet been corrected. [Function-level source reconciliation](evidence/navigation/native-itinerary-window-compatibility/native-list-notes-edit-phone-final/retained-function-evidence.json) confirms those passing functions and all affected production inputs are unchanged; they are retained without repeating them solely for a clean aggregate.

The original phone captures were inspected. They show readable native Form controls, exact multiline notes, an explicitly cleared field, the retained estimate controls and disabled Save for an unchanged editor.

## Tablet dark mode

All three selected iPad functions pass with zero failures/skips. The existing exact-remainder estimate regression takes 107.137 seconds; notes editing takes 140.581 seconds; notes creation takes 77.955 seconds. All frozen inputs match the current source. The original dark-mode captures were inspected and show readable native controls and the saved multiline text. The simulator's initial light appearance is restored and verified.

## Mac gate

The app, native UI target and Mac Share extension compile using the existing local ad hoc configuration. The runner then times out while enabling automation mode, before any journey method starts. The actual result is exit 65 with zero passes and one runner-initialization failure. This is not a passing Mac UI run. No signing/account change was attempted, and this error does not establish that paid signing would fix the automation gate.

## Final validation and limits

The unsigned generic iOS build passes. Its arm64 app embeds exactly one arm64 mobile Share extension. Mac, tablet and device epochs each match all 1040 current inputs. The Mac rebuild re-emits source warnings already recorded in the baseline; no introduced source diagnostic is found. Affected strict Swift lint, Markdown lint and Git whitespace checks pass, and the manual source/specification review records no remaining finding for this slice.

Actual Mac editing remains unqualified because of the runner gate. No signing/account setup, physical installation, sync behavior or feature-complete whole-app polish is claimed. The map remains open. Label appearance and the remaining Intent decisions are separate work; no unanswered choice is implemented here.

The [evidence directory](evidence/navigation/native-itinerary-window-compatibility/) retains the `native-list-notes-*` commands, frozen input hashes, original logs, actual XCTest summaries and named captures. Full-display recordings are not published. Test datasets use the existing unique local prototype path; this report does not claim the guarded App Intent fixture cleanup procedure applies to native UI datasets.
