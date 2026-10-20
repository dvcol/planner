# Native backup import

## Context and goal

Settings can export a complete JSON backup, but it cannot select, review or import one. Core already decodes the versioned graph, reviews Skip/Overwrite against the selected dataset and executes the confirmed whole-owner plan.

The end state uses the native file picker and a grouped review form. Skip is the default. Changing mode or authorizing restoration obtains a new review before confirmation. The preview distinguishes additions, unchanged records, conflicts, dependent skips, replacements, restorations, deletions and reference changes. Cancel changes nothing. The applied summary and recovery outcome come from Core.

## Definition of ready

The accepted portable-data contract and native administration scope apply. Reuse public Core decode/review/execute and actual native UI/file I/O seams. Keep backup administration absent from agent interfaces. Apple's [fileImporter](https://developer.apple.com/documentation/swiftui/view/fileimporter%28ispresented%3Aallowedcontenttypes%3Aoncompletion%3A%29) provides scoped URLs whose access must be released after reading. No schema, wire contract, dependency or test-only production parameter is needed.

## Required TDD and definition of done

- Start with a native Settings import cancellation tracer that fails at the missing control. Canceling the system picker preserves the saved dataset and enables another attempt.
- Export a real backup, edit current data, then select that file through the native picker. Skip preserves the complete current owner; Overwrite previews and replaces the represented owner after explicit confirmation. Retain its identity through relaunch and reimport without duplication.
- Keep the selected bytes immutable during review. Reject malformed/unsupported/dependency-invalid input before a mutation. Refresh stale reviews without automatically applying them.
- Show explicit restoration/deletion impact and the actual applied summary. Applied but incomplete recovery must remain visibly applied and block later mutations; unverified outcomes must not claim success.
- Verify original native phone/tablet captures, strict affected lint and app/test-host compilation. Record actual tests and failures. Keep broader import/family, save-failure/termination, Mac runtime, physical sync/account/Share and whole-app polish gates open until their own evidence exists.

## Execution

The missing Settings import control supplied the first native red. Reading and decoding now run off the main actor; coordinated file access is released after reading. The decoded backup remains immutable during mode/restoration review. Only the explicit Import action executes Core's token through the existing reviewed writer. A superseded review cannot publish, and a stale execution refreshes the impact without applying it automatically. An applied result replaces the review with its recorded summary; incomplete recovery and unverified results retain the existing write-blocking behavior.

The native grouped form presents all eight impact categories. Names and context remain primary. Expandable details preserve exact source/reference identities, lifetimes, dependencies, input paths and before/after association identities so similarly named records or repeated references can be distinguished. Result presentation returns to the top of the Form. These details are manual backup administration, with no new agent interface.

Two native functions pass on each simulator in paired runs, with zero failures or skips: system-picker cancellation/relaunch and a real exported-file Skip/Overwrite journey. That journey creates a Tag, exports its actual backup, renames the current Tag, confirms Skip and verifies the current name survives, then confirms Overwrite and verifies the incoming name and original identity survive relaunch without a duplicate. The expanded preview journey then passes again once per device with visible before/after names, a visible replacement count and the exact record identity before confirmation. The five production Swift files are identical across these paired and expanded runs; later changes affect only the native picker/visibility test helper.

The initial implementation build failed because it attempted to construct Core's internal failure value; the corrected native adapter uses a local Cocoa error without changing Core. Initial journey failures came from a Button query for native LabeledContent, an offscreen virtualized count and platform-specific Files navigation. The iPad mixed bundle has one cancellation pass and one file-selection failure; a subsequent expanded run failed before review because Recents did not yet show the newly saved file. The actual 833-byte export exists with the expected Tag and identity. The final helper chooses the native local Files location when needed and submits search rather than relying on the Recents index. Those failures remain excluded from passing qualification.

Original phone/tablet Skip, Overwrite, applied-result, before/after and identity captures were inspected separately. The early iPad Overwrite capture does not show its offscreen replacement row; the later visible-detail captures supply that proof. Strict lint passes for six Swift files. The affected Mac app/UI-test host compiles, with zero Mac runtime functions. Core, HTTP, schemas and portable format are unchanged; no new Core/HTTP invocations are attributed to this UI step.

[Execution evidence](evidence/navigation/native-backup-import/execution.json) retains exact commands, raw summaries/trees, compressed logs, original captures, the delayed-index export and source/product hashes.

## Remaining gates

This qualifies picker cancellation, the represented Tag Skip/Overwrite workflow, the single-Tag empty-dataset/reimport and replacement-cancellation journeys, and malformed-file rejection/retry below. The later [unsupported-version qualification](native-backup-version-rejection.md) adds phone/tablet error, retry and retained-Tag evidence. The [unresolved-reference checkpoint](native-backup-unresolved-reference.md) qualifies a declared List's missing external Item, disabled confirmation and no partial List import. Other invalid bindings, restored/deleted identity fixtures, distinct reference/dependency details, stale review, read/save/termination and incomplete-recovery presentation still need their own runtime evidence. Earlier Core qualification is retained at its own boundary. Broad graph/family/scale, Mac runtime, signed physical sync/account/Share and whole-app polish stay open. Q83 is settled in the [current decision register](../open-decisions.md); earlier pending wording is historical.

The later [full-graph native file checkpoint](native-backup-full-graph-file.md) qualifies empty import and delivered export for the committed seven-source fixture, including all relationship/history tables and independent completion. It does not close nonempty graph conflicts, restoration families, stale review, recovery failures, physical scale or actual Mac interaction. Its captures identify a standalone List metric-title contrast defect for immediate follow-up.

## Empty-dataset restoration and identical reimport

Before this qualification, the native import journey covers only an existing Tag. The next end state is a selected empty local dataset whose review lists one addition, restores the exported Tag with its original identity, and then classifies the identical backup as unchanged. Confirming that reimport and relaunching must retain one Tag with the same name and identity.

Readiness comes from the accepted full-backup, empty-restore, default Skip and no-duplicate rules. Tests use the approved native UI and real exported-file boundary. The dataset switch is an existing local prototype launch option; it does not qualify an iCloud account change or independent recovery restoration.

The required test creates/exports through native controls, verifies the new target has no Tags, reviews and confirms its addition, reimports the same file, and verifies zero additions plus one unchanged record. It must retain the identity and count through relaunch. Recheck the existing Skip/Overwrite workflow after extracting their shared export setup, run affected lint and compile the Mac host. Preserve graph-wide, invalid-input, restoration/deletion and failure gates.

Both affected native journeys pass on each simulator, with two functions per device and zero failures or skips. The new journey reviews one addition into the empty target, imports the original Tag identity, then reviews one unchanged record and zero additions from the same file. After confirmation and relaunch it retains exactly one matching Tag with the original name and identity. The existing Skip/Overwrite journey passes after extracting the shared native export setup.

The five production files are unchanged from the native import implementation. Original addition, unchanged and retained-Tag captures were inspected separately on both devices. Strict lint passes for the changed Swift test and this report. The affected Mac app/test host compiles; no Mac runtime function runs. This step adds no Core or HTTP invocations and does not qualify graph-wide restoration, deleted-identity restoration, an account transition or the independent recovery copy.

[Restoration execution evidence](evidence/navigation/native-backup-restore/execution.json) records the two completed native runs, original captures, exact commands and frozen source/product hashes.

## Canceling a reviewed replacement

The earlier cancellation tracer closes the file picker before decoding. The next goal is to cancel a prepared Overwrite review without replacing the current Tag. The before state has a backup of the original Tag and a newer current name. Canceling its one-replacement review must preserve that current name and identity through relaunch and leave Settings able to import again.

The accepted explicit-confirmation rule and the same native UI/real-file seam provide readiness. The required journey creates and exports the original Tag, edits its current name, selects Overwrite, verifies the replacement impact, then cancels without invoking Import. Verify the retained current name after relaunch, inspect native captures on both devices, and run affected lint plus Mac app/test-host compilation.

The journey passes once per simulator, with zero failures or skips. Both original replacement-review and retained-current-Tag captures were inspected. The five production files remain unchanged. Strict affected Swift/Markdown lint and Mac app/test-host compilation pass; zero Mac runtime functions and no new Core/HTTP invocations are credited. This closes the represented Tag review-cancellation check, while stale-review, invalid-input, broader graph and recovery-failure gates remain open.

[Cancellation execution evidence](evidence/navigation/native-backup-cancel/execution.json) retains the actual results, commands, original captures and frozen source/product hashes.

## Malformed-file rejection and retry

The native journeys above select valid exported files. This next qualification selects a deliberately truncated JSON file and requires a native failure before an import review or mutation. Settings must permit another selection, a valid backup must remain reviewable, and the existing Tag must retain its name and identity after relaunch.

The accepted reject-together and useful-error rules apply at the same native UI/real-file seam. Stage the independent [truncated fixture](../fixtures/native-malformed-backup.json.invalid) as `Planner malformed backup.json` in the disposable simulator's local Files location before running. Fixture preparation writes only external input bytes; outcome assertions use native controls, not store inspection. Preserve the selected bytes and provenance in execution evidence.

Required qualification selects the broken file through the system picker, verifies its specific JSON error and absent confirmation control, dismisses the failure, selects the actual valid export and verifies one unchanged Tag. Cancel that review and confirm the original identity/name after relaunch. Recheck Overwrite cancellation after splitting file selection from valid-review waiting, inspect phone/tablet captures, lint affected files and compile the Mac host. Unsupported versions, graph-invalid input, missing dependencies and recovery failures remain separate gates.

Both affected native journeys pass per simulator, with two functions on each device and zero failures or skips. The broken file reaches the native read/decode path and shows "The backup contains an invalid JSON value." before a confirmation control exists. After dismissing it, the real exported file reviews one unchanged Tag. Canceling and relaunching preserves the original Tag identity/name. Overwrite review cancellation also passes after the selection-helper split.

The exact 11-byte fixture and both staged copies have the same hash. Original native error, valid retry and retained-Tag captures were inspected separately. Strict affected Swift/Markdown lint and Mac app/test-host compilation pass. The five production files remain unchanged; zero Mac runtime functions and no new Core/HTTP test runs are credited. Other structural/dependency/version failures, full-graph restoration, stale review and recovery failures retain their gates.

[Malformed-input execution evidence](evidence/navigation/native-backup-malformed/execution.json) retains the fixture bytes/provenance, completed results, commands, original captures and frozen source/product hashes.
