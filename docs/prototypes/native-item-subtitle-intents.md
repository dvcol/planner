# Item subtitle Intents

Status: optional Subtitle creation/editing, all 22 affected Item cases and Mac/Simulator/unsigned device builds pass locally. Actual system invocation remains open.

## Context, starting state and goal

At `249936f7`, Core and the native editor support Item subtitles, but Shortcuts creation/editing accepts only title and notes. Add Subtitle to those existing actions without changing their identities or required inputs. It remains separate from notes. Creation preserves the supplied optional text exactly; editing follows the existing optional Notes convention: omitted keeps the current value and empty explicitly clears it.

## Definition of ready

Q33 approves the complete Item content catalog and guarded ordinary edits. Q112 A approves the production Intent invocation boundary with Apple's dependency manager and disposable real storage in the existing app-hosted target. Reuse that boundary, the current source read and existing changed-field hashes. No new Core command, target, dependency, test hook or confirmation policy is required.

## Required tests and definition of done

Record missing-field reds for creation and editing before their respective implementations. Reopen real Core storage to verify exact subtitle text and its distinction from notes. Subtitle-only edits must preserve every other content field, source identity/lifetime, completion, archive and references. Omitted subtitles remain untouched; explicit clearing and a title/notes/subtitle patch succeed together. Invalid combined edits leave every field unapplied. Extend actual recovery-failure evidence to include subtitles and rerun existing Item adapter cases.

Finish with affected lint, actual Mac/Simulator/unsigned device compilation, metadata compatibility, exact source-epoch verification and guarded fixture disposal. System invocation/picker presentation and physical devices remain separate open gates. This slice does not select the pending duration parameter presentation.

## Implemented behavior and test-first evidence

Create Item now accepts optional Subtitle alongside Title and Notes. It preserves exact supplied text, including whitespace, Unicode and empty versus omitted values. Edit Item accepts an optional Subtitle patch: omission retains the current subtitle; empty clears it; a nonempty string sets it. Subtitle-only requests are valid. The same current source read and changed-field hashes guard a combined title/subtitle/notes edit, with no post-save read that can misreport an already applied change.

Creation first fails compilation at its missing Subtitle parameter, then passes in 0.044 seconds. Subtitle-only editing likewise fails at its missing parameter, then passes in 0.088 seconds. The rich edit fixture reopens the same source and preserves its lifetime, creation date, every other content hash, reference identities, independent membership completion, archive state and all-day booking. Cached entity display/state values do not overwrite current content.

Five subtitle cases then cover exact creation, omitted versus empty creation, subtitle-only edits, omitted edit fields, explicit clearing, all-or-nothing combined text validation and precancelled editing. The existing real recovery-file obstruction now includes Subtitle in the applied patch: the subtitle survives reopening and native acknowledgement, with the original operation retained and later explicit editing allowed. Existing missing/deleted source, unavailable store, creation/read/query, archive, completion and notes/title cases remain in the focused regression run.

## Combined qualification

All 22 affected Item/subtitle cases pass with zero failures/skips in 7.752 seconds of XCTest execution. The actual summary and original log are retained, with no compiler diagnostics or SQLite lifetime warnings in the final run. All 22 final fixtures and three earlier passing fixtures are disposed only after verified host exit and closed database handles. Compiler missing-field reds retain their actual failed exits and carry no runtime credit.

Mac metadata preserves all 34 action, seven entity and seven query identities, plus every prior enum case. Create Item retains required Title and optional Notes; Edit Item retains its required Item and optional Title/Notes. Both add optional String Subtitle. All 1003 frozen inputs match current source; the 1002-input baseline has two deliberately changed files, one added subtitle test file and 1000 unchanged inputs. Broader unrelated runtime evidence is retained without claiming another full-suite rerun.

The actual Simulator app/native UI-test target and unsigned generic iOS-device builds pass with identical catalogs, enum cases and Subtitle parameter contracts. The device app embeds exactly one mobile Share extension; both executables are arm64. Current source verification passes for all 1003 inputs in every platform packet. Strict affected Swift/Markdown lint, platform type checks and staged Git whitespace checks pass. No Core/schema, command, dependency, target, entitlement or native UI changes are introduced. The existing ad hoc Mac configuration is reused; no account/signing setup, physical installation or system invocation is claimed.

The evidence directory retains `app-intent-item-subtitle-*` packets with commands, original logs, actual exits, source hashes, metadata, result summary and fixture verification. Metadata/type checks do not establish actual Shortcuts picker presentation, persisted system workflows, background/locked behavior or physical performance.

The [Q115 duration-input review](../native-estimate-intent-input-review.md) remains a separate pending presentation choice. Remaining richer content, estimates, scheduling/capture/bulk Intents, actual system invocation, signed Agent Control, shared/account-bound storage and CloudKit proof, installed Share, physical qualification and feature-complete UI polish stay open. This is local feature progress, not completion of the map; signing remains deferred.
