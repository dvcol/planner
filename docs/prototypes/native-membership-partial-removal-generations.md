# Partially informed membership additions

This Q155 A follow-up handles a new Add that observed one strict removal but missed a second concurrent removal for the same Item/List lifetimes. The second removal suppresses that Add. A later Add observing both removals remains eligible and starts Todo. Signing stays deferred.

The retained real-store tracer first reproduced readUnavailable because the suppressed generation had no earlier closed membership with its observation basis. Canonical maintenance now retains that generation's original context and completion history without inventing a user Remove marker or moving its history into an informed membership. A retained canonical context can be inactive only when validated strict-removal authority proves its membership ineligible. A missing live canonical membership without that authority still rejects.

The follow-up round-trip test found import review still requiring a live context owner. Import now excludes proven suppressed history from live-owner conflict comparisons, while retaining it for the selected owner. Existing closure, provenance, exact scope and projected-graph validation remain required. The change adds no portable field, schema, public operation, target or production test control.

## Public behavior checked

The production Planner interface reads a real schema-19 store. Test-owned native input represents the second independent removal; it creates no successful command receipt. The test runs with a standalone List and with that List appearing twice in an Itinerary.

- The partially informed membership disappears. Its exact provenance, initial contributions and explicit completion changes remain, including both independent itinerary contexts.
- Item content and source timestamps remain unchanged. No extra deletion marker is fabricated for the suppressed membership.
- Reopen preserves the exact export. An informed Add observes both removals and remains Todo in the List and both itinerary branches.
- Reading or completing the suppressed public appearance cannot target the informed membership. The rejected action leaves the export unchanged.
- Removing the second strict barrier from the exported graph makes its absent canonical context invalid.
- Reviewed restoration into an empty dataset preserves the complete export byte for byte.

The first attempt had test compilation errors and executed no tests. The corrected standalone tracer failed at runtime before implementation. Its first implementation passed that tracer; expanded-context/round-trip qualification then failed, and the retained diagnostic located the import-review failure. The corrected round-trip and exact-action-scope runs pass separately. Earlier failures remain recorded as failures.

## Qualification and remaining scope

The matching Mac/iPhone checkpoint passes 196 functions in 79 suites and 572 invocations per platform. All 806 Core inputs match, the full phone manifest contains 1,145 inputs, and both actual products per platform are verified. All 512 frozen fixture inputs and nineteen model source files stay unchanged. No SQLite lifetime diagnostics or skipped tests occur. Strict formatting passes for all six changed Swift files.

The nine recorded attempts retain their compiler/runtime distinctions. After process and file-closure checks, 1,113 distinct marked disposable stores from passing runs are removed. Failed fixtures and verification evidence remain retained. No physical reclaimed-byte claim is made.

These are Core/store/import and compiler checks. No new native UI, MCP HTTP or installed-extension journey is claimed for this follow-up. Actual Mac UI, installed Share, protected signed storage, CloudKit delivery/convergence and physical performance remain separate gates. This follow-up does not complete Q155. Move/Overwrite/Capture observations and evidence, broader lifetime/family reconciliation, exact eligible-alias actions and interruption/recovery controls remain local work.
