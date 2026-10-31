# Repairing scalar flags from proven completion history

This Q155 A follow-up fixes an independently delivered native completion flag that disagrees with an already saved contextual history. Before the fix, a single membership did not trigger consolidation, so bootstrap could succeed while export failed with recoveryIntegrityFailure: saved local completion disagreed with its declared canonical history. The scalar mismatch is not evidence of another explicit user action.

Maintenance admission now compares exact existing membership, direct-entry and expanded-completion lifetimes with the accepted history winner. When they disagree, the existing coordinated maintenance path stages the history-backed flags, durably prepares the complete graph and commits/publishes the repair. The causal winner and initial-alias algorithms remain unchanged. No aliases or completion-change identities are invented from the stale scalar.

Canonical snapshots and native staging now carry the corrected direct-entry flag as well as membership and expanded flags. Source content, global Done, order and user-edit timestamps stay unchanged. Existing explicit provenance stays intact; previously implicit live bindings are retained only when their generation actually undergoes consolidation or suppression. A scalar-only repair does not materialize unnecessary provenance. There is no model, portable format, public command, package, target or test-only production-hook change.

## Public storage qualification

The first-history tracer now includes a divergent variant for six scopes, with and without the existing completion-preparation obstruction. These twelve cases join its original twenty-four first-assertion and Complete/Reopen cases, giving 36 executions. After an explicit Reopen, a separate native fixture write changes only the selected scalar flag to Done. Reopening must repair it and return the exact complete export captured before that write. Later smaller-root delivery, independent repeated branches and exact applied replay retain their earlier checks.

All twelve new cases failed on preceding production. The first diagnostic surfaced CancellationError from its export guard; the second retained the actual recoveryIntegrityFailure. The initial repair corrected state but ten byte-identical-export checks caught an extra live membershipProvenance record. The original checkpoint, maintenance preparation and exact field difference are retained. Limiting new binding retention to actual consolidation/retirement generations then passed all 36 cases without relaxing any export, history, timestamp or scope assertions. Other consolidation test bodies remain unchanged.

## Final local checkpoint

The matched verification records 256 functions, 90 suites and 800 invocations on each of Mac and iPhone Simulator, with no skips or SQLite lifetime diagnostics. All 809 Core inputs match; the full phone manifest contains 1,148 inputs. Actual source/product hashes, all four changed Swift files' strict formatting, 514 unchanged frozen fixtures and nineteen unchanged model source files are checked.

Seven existing real MCP HTTP regressions and matching Mac app/Share/fixture builds pass. A separate isolated native bulk save-failure test uses final Mac products and proves rollback/retry for three command scopes; its actual child log is retained. That command test does not establish fault injection for this exact automatic flag-repair path.

Eight retained phases include the original failures, the extra-provenance failure and final passing platform/adapter/native-save checks. Only closed marked stores from original passing logs are removed after host and handle verification.

## Remaining scope

This slice repairs existing rows from complete proven history. Missing completion rows, partial history delivery, repair-specific write/interruption faults, active-orphan/legacy-barrier admission, changed entry/source lifetimes and broader restoration-family/reference reconciliation remain open. Other prepared command families, alias-specific HTTP/native journeys and native committed-maintenance Retry controls need their own evidence. Actual Mac UI, signed shared storage, installed Share, CloudKit, physical performance and system invocation retain separate gates. Q155 and the map remain open; signing stays deferred.

The later [missing expanded-row checkpoint](native-missing-expanded-completion.md) extends repair to absent completed expanded rows with exact live bindings. The [native Retry checkpoint](native-committed-maintenance-retry-ui.md) also qualifies the maintenance recovery control on phone and dark iPad. The earlier results above retain their original scope.
