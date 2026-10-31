# Skip older versions of restored records

## Context and starting state

The accepted Skip mode keeps matching current records and their complete owned contents while importing eligible independent data. Explicit Delete followed by reviewed backup restoration preserves an object's public identity but creates a fresh lifetime so stale changes cannot revive its deleted predecessor.

At `1a08607e`, reviewing that object's valid older backup under Skip fails with `unavailable` at `/sources/0/lifetimeId`. A real public Create, Export, confirmed Delete and explicit Restore sequence reproduces this on Mac. The isolated probe and its unchanged repeat fail in 0.086 and 0.082 seconds. The first repeat preflight uses incorrect executable filenames and starts no test; its separate record carries no runtime credit.

The current resolver rejects differing lifetimes before reaching its Keep current branch. Skip needs that branch, not an incoming-version replacement. Overwrite and broader incoming-reference/family reconciliation remain separate implementation gates.

## Goal and end state

Allow Skip to retain the currently live restored record, its current lifetime, fields, references, completion and protective history. The existing conflict preview must identify that current binding and report keeping the complete current record. Review changes nothing; executing the retained-only import leaves exported Planner data byte-identical. Eligible independent imports must also apply without changing the retained graph. This slice does not authorize restoring closed data, replacing lifetimes or consolidating unknown families.

## Definition of ready

- Keep the accepted whole-owner Skip, explicit restoration and deletion-precedence policies.
- Use the existing public Core review, execute, export, replay and recovery seams with disposable real storage. No new test boundary, production test hook, package or target is needed.
- Preserve schema 18, portable format 1 and existing native result forms. The native preview already describes `matchingRecordConflict` as keeping the complete current record and labels lifetime differences as Restoration.
- Establish an actual failing native regression before changing production. Retain the diagnostic source overlays and distinguish compiler/preflight failures from executed test failures.

## Definition of done and required /tdd

- Preview and apply the older valid backup after real Delete/Restore. Keep its live current binding in the conflict entry, with no replacement/restoration proposal or partial mutation.
- Exercise Items, Lists, Itineraries, Categories and Tags with the complete planning graph. Preserve owned references, schedules, labels, independent completion and closed history through review/apply. Keep native and import-deletion family checks afterward.
- Import eligible independent data alongside the retained owner, then verify idempotent reimport, reopen, recovery and exact operation replay. A retained owner cannot be reported as a newly generated object.
- Preserve malformed/foreign reference and conflicting-family rejection, explicit restoration authorization, current Overwrite gates and all-or-nothing failure behavior. Do not loosen broader rebinding merely to admit a backup.
- Run the affected native import/restoration tests and platform compilation, inspect actual result counts and run strict affected lint. Native file-picker/preview presentation, signed synchronization and physical acceptance remain separate gates.

## First tracer

The permanent Item regression first fails at the public review gate. Moving the unsupported replacement check after the existing Skip branch, and using the current source binding in that branch, then passes review, execution and byte-identical export in 0.150 seconds. The original restoration suite also passes its three functions, including the full-graph restoration matrix's ten cases and the foreign-owned-candidate safeguard. Its grouped native report counts functions separately from argument invocations.

The strengthened full-graph Skip matrix initially fails compilation because `PlannerPortableSource` does not expose a common lifetime property. Its version assertion now reads the public exported backup format. Against baseline production, all ten native cases then fail at the older-backup Skip review. Corrected production passes the same ten cases in 1.038 seconds, with unchanged frozen inputs.

## Mixed import and final qualification

A separate public Create, Export, Delete and Restore tracer changes the current Item's global completion, then reviews its older backup alongside a new independent Tag. Baseline production rejects the review at the same lifetime gate. Corrected production keeps the complete current graph and imports the Tag with its supplied identity and fields. Preview leaves data unchanged. Apply, acknowledged recovery, reopen, exact operation replay and repeated Skip all retain the saved result without duplicate data.

The first corrected-production run fails only its byte-equality assertion between recovery and ordinary export. The contract concerns complete data, and the established recovery tests compare parsed public JSON. The final tracer uses that same comparison, preserving every source, field, association and history record. Its corrected comparison passes in 0.214 seconds without another production change. The final test then fails against baseline production in 0.074 seconds before the same source passes in the affected suite. The earlier failed assertion remains retained as a test correction, not a production recovery defect.

The affected Mac import run passes 53 functions in 24 suites, comprising 221 executions, with zero failures or skips. Its native summary reports 8.362 seconds. This includes the complete-graph restoration matrix, independent import, malformed input, foreign candidates, conflicting history, source/reference deletion, owned data, recovery preparation/failure/retry and exact replay. Its 739 frozen Core inputs match the final workspace. The iOS Simulator build also succeeds with all 1,061 inputs reconciled. The current Mac app build uses the same production resolver; the final store-test additions are separately compiled and executed by the Mac package run.

Affected strict Swift formatting, Markdown lint and Git whitespace checks pass. No public form, dependency, package, target, migration or new test boundary is added. Native import-picker/preview presentation, physical convergence and the whole-app visual review retain their separate gates. This local correction does not complete the broader import implementation.

This slice does not reduce the accepted import scope. Different-live-lifetime Overwrite, broader reference rebinding and family reconciliation remain implementation gates on the overall map.

Native evidence packets use the `core-native-import-live-lifetime-` prefix. Source overlays and native logs/results retain each distinct epoch. The first baseline runner captures a working overlay before replacing production with its baseline version; the corrected retained source comes from the unchanged executed root and matches its recorded hash. The unused overlay and collection note are kept separately. No passing outcome is inferred from an unexecuted build or an unavailable operation.
