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

This qualifies picker cancellation and the represented Tag Skip/Overwrite workflow. Native empty-dataset additions, identical-state reimport, review cancellation, malformed/unsupported/dependency-invalid file presentation, restored/deleted identity fixtures, distinct reference/dependency details, stale review, read/save/termination and incomplete-recovery presentation still need their own runtime evidence. Earlier Core qualification is retained at its own boundary. Broad graph/family/scale, Mac runtime, signed physical sync/account/Share and whole-app polish stay open. Q83 Calendar alignment remains unanswered.
