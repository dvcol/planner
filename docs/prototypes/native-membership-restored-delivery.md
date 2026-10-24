# Restored membership delivery after Undo

This Q155 A follow-up keeps an original-ID Undo readable when an offline-style native copy of the removed membership later arrives. Undo already restores the public identity under a fresh lifetime and observes strict removal history. Consolidation previously rejected the closed old copy during record decoding, before it could evaluate that history.

Membership closure liveness is now checked at complete graph validation. Native candidate decoding can therefore reach consolidation; portable imports, acknowledged recovery and proposed snapshots still require a valid complete graph. Consolidation applies strict-removal eligibility before deciding whether two live lifetimes compete. Same-binding source-pair validation remains in place, and multiple eligible lifetimes still reject without an invented winner. The now-unused membership argument is removed from the internal record-validator call.

The public real-store tracer retains the restored membership's exact identity, fresh lifetime, rank and Todo state after a Done copy of its old lifetime arrives. Source content/timestamps, deletion history, membership observations and explicit completion history stay unchanged. Reopen retains the normalized export. Public import and acknowledged-recovery reads reject a legacy-format payload containing the closed membership, even when the envelope's checksum matches; the expected membership-lifetime error path proves graph validation remains active.

A repeated-route tracer restores two appearances of the same List. The first branch stays Done, the second Todo, and standalone List completion stays Todo after both old expanded records arrive alongside their old membership. Existing aliases and current source, route and completion data remain intact. A separate unproven-lifetime test keeps both conflicting inputs unavailable through query and fresh bootstrap, without creating or changing recovery files.

## Test fixture lifetime

The first broader phone run passed its assertions but reported twelve SQLite unlink diagnostics in four additional recovery suites. Running the five unchanged recovery suites against the preceding c6165cc6 production revision reproduced all twelve diagnostics. All five used immediate directory deletion. Their factories now use the existing marked-store helper; assertions and deadlines remain unchanged. Cleanup waits for host exit and open-file checks. The baseline and warning-bearing run are retained, without an additional cleanup attempt against their logs.

## Local qualification

The [final matched checkpoint](evidence/native-membership-consolidation/restored-membership-validation.json) passes 246 functions in 88 suites and 688 invocations on each of Mac and iPhone Simulator. It includes the preceding membership/import/Undo/Capture cohort plus five recovery-integrity suites. All 808 Core inputs match between platforms; the full phone manifest contains 1,147 inputs. Both actual Core test products per platform are verified. Final runs have no skipped tests or SQLite unlink diagnostics. Strict formatting passes for all nine changed Swift files.

All 514 frozen fixture inputs and nineteen model source files remain unchanged. Byte comparison proves that every pre-existing consolidation test stays unchanged and the five additional recovery test bodies differ only in their directory-lifetime statements. Their assertions and deadlines are retained.

Six real MCP functions pass, and the Mac app, Share extension and fixture app compile. Current production, app and MCP inputs match that adapter execution. Five Core test-factory files subsequently changed; the adapter build log proves its scheme did not compile that test target or those files. Their lifetime fix is qualified by the final matched Core runs rather than repeating an unaffected adapter build. Actual application product hashes remain verified. System linkd connection diagnostics do not qualify Shortcuts/Siri invocation, and this checkpoint adds no native UI journey.

[Fifteen completed phases](evidence/native-membership-consolidation/restored-membership-attempts.json) retain actual source manifests, products and statuses, including the two initial test-compilation errors and the separate failing real-store tracer. Some historical phase names contain red although those additional scenarios passed; their notes preserve that distinction. After host-exit and open-file checks, 1,831 distinct marked disposable stores from passing runs are removed. The warning-bearing run is not subjected to an extra cleanup attempt, and no reclaimed-byte estimate is claimed.

## Remaining scope

This slice covers strict closure and original-ID Undo while source Items/Lists survive. Both old expanded records arrive with their old membership. Expanded-only delivery, independent expanded-context closure admission, legacy closure without a strict pair barrier, exact eligible-alias actions and broader lifetime/family/reference reconciliation remain local work. The historical expanded-closure phase name does not qualify an independent expanded-completion marker case. Remaining maintenance failure/native controls and prepared-only Capture interruption also stay open.

No schema, public command, evidence-wrapper format, target or test hook is added. Actual Mac UI, signed shared storage, installed Share, CloudKit convergence, physical performance and system invocation keep their separate gates. Q155 and the implementation map remain open; signing stays deferred.
