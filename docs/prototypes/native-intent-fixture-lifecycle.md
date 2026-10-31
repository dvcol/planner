# Native Intent fixture lifetime

Status: corrected at the existing test boundary. All 69 affected adapter tests pass with zero lifetime diagnostics and no compiler warnings. All 71 owned fixtures are verified removed after host exit. Production code is unchanged.

## Context and starting state

At `935d2803`, all 69 affected adapter tests pass, but their original log contains 229 SQLite unlink/integrity diagnostics and 228 invalidated-descriptor diagnostics. Each test removes its disposable directory in a method-scope defer while SQLite connections can outlive that method. Apple's public AppDependencyManager interface provides registration but no dependency-reset method. App code must not gain a test-only close hook.

## Goal and expected end state

Keep the actual Q112 SDK/Core test boundaries and behavior assertions. Retain owned fixtures through the test-host lifetime, then verify host exit and database-handle closure before removing only those recorded disposable directories. Preserve the original log; require zero lifetime diagnostics rather than filtering them. Keep failed or unverified fixtures for inspection.

## Definition of ready

- Existing App Intent invocation, real temporary Core storage and actual filesystem checks are approved under Q112 A. No new app or domain test interface is introduced.
- The local Mac app-hosted target and read-only process/file-handle inspection are available. Signing remains deferred.
- The completed test log supplies exact fixture records; a matching directory marker identifies ownership. Every directory and host must validate before cleanup begins.

## Required tests and definition of done

Use the same diagnostic verifier against the original five-case run, the narrowed single cancellation journey and the corrected run. Require the actual SDK cases to pass, their unmodified logs to contain no SQLite lifetime diagnostics, every recorded host to have exited, and database handles to be closed before cleanup. Verify removed directories are absent. Rerun all 69 affected adapter cases after migrating fixture setup. Run affected Swift/Python/Markdown checks and record source epochs and actual outcomes.

## Diagnosis

Five passing completion cases reproduce 16 diagnostics of each kind. One passing cancellation case reproduces three of each kind. Retaining only that fixture through host exit, without changing commands/assertions, eliminates all three kinds. After the recorded host exits, lsof reports no database owner, a diagnostic-only SQLite structural check returns `ok`, and removing that exact fixture succeeds. This supports premature test cleanup as the cause. It does not prove general production shutdown or substitute for Core's behavior reads.

The shared test helper records a canonical UUID directory under `PlannerIntentFixtures`, its host identifier and an ownership marker. The runner rejects diagnostic-bearing or unsuccessful logs, mismatched/unsafe paths, live hosts and open/unverifiable database handles. It validates all fixtures before deletion. Tests run directly in Xcode retain their disposable directories until the same runner is given their complete log; app data and backups are unaffected.

## Executed correction

Migrating the five completion cases gives five passing tests, zero diagnostics and five verified fixture removals after host exit. The first 69-case migration still reports nine diagnostics because four older cleanup statements use `fixture.directory` rather than the tuple-bound `directory`. Its verifier correctly rejects the log and removes nothing. That unsuccessful epoch is retained; after inspection, its 67 surviving owned directories are separately disposed only after host/handle closure. Four directories had already been removed by the old test statements.

Removing those remaining early deletions gives all 69 cases passing with zero failures/skips in 21.230 seconds, zero SQLite lifetime diagnostics and no compiler warnings. The shared helper creates 71 distinct fixtures because two recovery cases each exercise two independent datasets. The runner verifies ownership, host exit and database-handle closure, removes all 71 and verifies their absence. Existing SDK bindings that the compiler identifies as immutable now use `let`; behavior assertions and commands remain unchanged.

Thirteen controlled CLI filesystem/process checks pass separately. They verify rejection of diagnostic-bearing/failed logs, a live recorded host, another open database owner, paths outside the owned namespace, mismatched ownership, symlinks and one invalid fixture alongside a valid one. The positive closed-owned case is removed successfully. Report destinations cannot overwrite the original log, its hard link or fixture metadata.

The additional unavailable-report check first exposes a runner defect: cleanup precedes the failed report write. Its recorded red removes only its disposable control fixture. Establishing the audit report before deletion corrects that result; the same failed report destination then preserves the fixture. The final runner records disposal progress and reports partial filesystem errors truthfully. Five actual SDK cases are rerun against this reporting-safe version, with zero diagnostics and five verified removals. These control checks claim no App Intent execution credit; separate actual XCTest summaries establish the 69-case run and this five-case repeat.

## Running and evidence

After the XCTest host exits, preserve its complete original log and run:

```sh
python3 scripts/verify-intent-fixtures.py /path/to/xcodebuild.log --report /path/to/fixture-lifecycle.json
```

The report must be outside fixture storage and must not alias the original log. Unsuccessful tests or failed preconditions leave fixtures untouched. A filesystem error during disposal reports completed removals and the active directory for inspection. Re-running verification after successful disposal is unnecessary; the recorded report lists exactly what was removed. Exported Xcode logs must include their completed root suite and fixture records, and the recorded host must have exited.

Packets under the compatibility evidence use `app-intent-fixture-cleanup-*` names. They retain unfiltered original logs, source epochs, commands, diagnostic reports, the retained-store structural observation, the unsuccessful migration, disposal reports and controlled CLI checks. The `final-qualified` packet's actual XCTest summary proves 69 passes with zero failures/skips; `report-qualified` records the final reporting-safe five-case repeat. All 990 frozen build/test inputs match this checkpoint, and production inputs match `935d2803` exactly. Strict affected Swift lint, Python compilation/Ruff and Markdown lint pass. The existing app-hosted Mac build supplies type-checking; no unchanged mobile/device build is repeated or credited anew.

This fixes test fixture lifetime. It does not establish production shutdown, actual Shortcuts/Siri invocation, CloudKit/account transitions, installed Share, signed Agent Control or physical performance. Their existing gates and the feature-complete whole-app polish remain on the map; signing stays deferred.
