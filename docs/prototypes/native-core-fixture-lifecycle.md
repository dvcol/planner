# Core import fixture lifecycle

## Context and goal

The known-restoration-family import checkpoint passes its functional assertions, but its raw iPhone log contains 443 SQLite unlink-while-open diagnostics. Those assertions do not establish safe fixture teardown. Several import and bookmark tests delete their disposable directories in a function's `defer`, while SwiftData can retain SQLite connections after that function returns.

The goal is to preserve every existing public-interface assertion and remove disposable stores only after their test host exits and their SQLite handles close. This changes test infrastructure, not Planner data, import behavior, signing or the public Core interface.

## Definition of ready and done

Use the already approved real Core storage/recovery tests and actual filesystem/process boundaries. Reproduce the diagnostics on the committed baseline before attributing them to older setup. Keep source and fixture inputs fixed during each runtime. Retain failed attempts as failures.

Completion requires the affected Mac package and iPhone Simulator cases to pass without SQLite lifetime diagnostics. Verify marked ownership, host exit and closed database handles before cleanup. Exercise the cleanup CLI's positive and refusal paths, preserve its existing Intent-fixture protections, and run focused Swift formatting, platform compilation and Python syntax checks. These checks do not qualify UI automation, physical CloudKit, signed shared storage or system Intents.

## Correction

The affected 25 test files now obtain a directory from one test-only helper. The helper creates a marked parent and returns an absent `dataset` child, so genuine fixture copying and decoder assertions about absent storage remain valid. It records the filesystem's canonical path and the actual host process identifier. No test deletes that directory during teardown.

The existing `verify-intent-fixtures.py` also recognizes these Core markers and a completed nonzero Swift Testing run. A zero-test XCTest prelude is insufficient. The verifier retains exact namespace/marker matching, canonical-path and symlink checks, refusal on failed or diagnostic runs, report-location protection, host-exit checks and actual `lsof` verification. It validates all records before removing any fixture.

## Executed evidence

- The [committed-baseline iPhone run](evidence/navigation/core-native-import-fixture-lifecycle-base/) passes seven functions and 21 invocations, but emits 77 unlink-while-open diagnostics. It uses `867d3a7b`, before the family-binding implementation. This establishes the older fixture-lifecycle failure without relying on an assumed baseline.
- The [cleanup CLI cycle](evidence/navigation/core-native-import-fixture-verifier/) first rejects a valid completed Swift Testing fixture because only XCTest execution was recognized. After the extension, eight new real CLI/process/filesystem checks and twelve existing safety checks pass. They cover exited/live hosts, an open SQLite connection, mixed fixture kinds, mismatched namespaces, protected report storage and zero/failed runs. These are tooling checks, not Planner feature tests.
- The [initial marked Mac run](evidence/navigation/core-native-import-fixture-lifecycle-package/) passes all 57 functions with no SQLite diagnostics, but the verifier refuses its `/var` alias paths and removes nothing. The helper is corrected to record `realpath`; the verifier's protections are not weakened. A separate closed-host/closed-file disposition removes only those 228 owned fixtures, retaining the failed verifier result and original log. Their measured nominal size is 172,739,251 bytes; this does not promise the same APFS free-space increase.
- The [canonical-path Mac run](evidence/navigation/core-native-import-fixture-lifecycle-package-canonical/) passes 57 functions and 228 invocations, with no failures, skips or SQLite lifetime diagnostics. The unchanged public assertions cover complete graphs, both import modes, restoration families, recovery, replay, reopen, genuine receipt fixtures and large decoding. Its normal verifier then removes exactly 228 marked fixtures after checking host and database closure.
- The [first marked iPhone run](evidence/navigation/core-native-import-fixture-lifecycle-ios/) passes 57 functions with no failures, skips or unlink diagnostics. It uses the pre-canonical-path helper; final-source iPhone qualification is recorded separately below.

The [final-source iPhone run](evidence/navigation/core-native-import-fixture-lifecycle-ios-canonical/) passes the same 57 functions and 228 invocations, with zero failures, skips or SQLite lifetime diagnostics. Its normal verifier removes exactly 228 fixtures after host/file closure. All 740 Core inputs match the workspace and final Mac package; the complete native epoch contains 1,062 inputs. Structured argument counts agree with the Mac run. The genuine native receipt fixture and absent-dataset decoder checks remain included.

Strict formatting passes all 26 affected Swift files. The final helper also type-checks against the iPhone Simulator SDK. Ruff lint/format, Python syntax, the twenty CLI safety checks, focused Markdown lint and Git whitespace checks pass. This closes the represented import-test lifecycle gate. Other test families, Mac UI automation, physical behavior and the broader map remain open.
