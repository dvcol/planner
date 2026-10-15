# Container catalog sorting over HTTP

## Context and starting state

Q85, Q86 and Q87 approve shared container catalog sorting and its concrete contract. Core sorting is implemented in commit 628316d. The HTTP adapter still rejects catalog `sort` as an unknown field and advertises only alphabetical catalogs.

## Goal and definition of ready

Expose the approved optional sort through the existing actual MCP HTTP boundary. Keep format version 1, omitted alphabetical defaults, strict admission, compact generation-bound rows and all existing Item/non-container behavior. The approved test boundary is the real loopback listener, official SDK dispatch, JSON request/response and public Core store. No private parser test seam is added.

## Required tests and definition of done

Create seven containers of each kind in this order: Zulu, Alpha, CAFÉ, cafe, Partial, Overflow and Other partial. Their full estimates are exact 60, exact 120, exact 0, manual exact 90 with an unknown child, at least 30, unavailable, and at least 60 minutes. Other partial is archived. Edit Zulu's notes last so its Last updated order differs from Created. All fixtures use real Core commands.

The required ascending Full estimate order is CAFÉ, Zulu, cafe, Alpha, Partial, Other partial, Overflow. Descending is Alpha, cafe, Zulu, CAFÉ, Other partial, Partial, Overflow. Both certainty-group placements remain fixed. Title uses independent alphabetical sequences with ascending UUID ties for the folded Café pair. Created follows creation order; Last updated puts edited Zulu last ascending. Require all four modes in both directions for both kinds, complete two-row paging with an empty terminal window, retained earlier generations, cumulative active/insensitive search and byte-identical exported data. Inspect the advertised schema and text/structured result equality over HTTP.

A following admission cycle must reject null/non-object/missing/unknown/mistyped/unsupported sort fields with the approved exact error code and escaped property path. Category, Tag and Schedule may not acquire sort support; their omitted behavior and existing Item sorting must retain their meaning. Invalid reads must not alter saved content or invalidate earlier generations.

Retain raw red/green logs, source/product hashes, exact commands and post-process fixture cleanup receipts. Run affected strict Swift/Markdown checks and source/specification review before the logical commit. Native controls/preferences, physical performance, Mac UI runtime, signed CloudKit/account/Share and whole-app polish remain separate map gates.

## Execution

The first route run failed in 3.704 seconds with four missing-schema expectations, a rejected sort request and a secondary test-helper JSON error. MCP failures carry plain text, so the helper was corrected to compare JSON text only for successful envelopes. With production still unchanged, the clean red failed in 2.515 seconds on the four missing schema properties, rejected request and absent rows. The initial route implementation then passed one function in 3.325 seconds.

The admission cycle added fifteen malformed sort forms per container kind, twelve explicit-sort requests across Category/Tag/Schedule, their omitted reads, Item omitted/descending sorting and the existing Item-catalog rejection. It failed in 0.214 seconds with six incorrect unsupported-kind property paths. Rejecting unsupported catalog sorts before decoding their fields corrected those paths.

The admission green passes both functions in 5.564 seconds. A later evidence audit found that the collector had used the wrong test-product path and silently recorded only the app launcher hash. Historical product manifests retain that limited coverage; they have not been backfilled with overwritten binaries. The corrected collector requires the actual nested test executable, app launcher and production debug library. Its qualified rerun passes two functions in one suite on macOS 27.0.1, zero failures and skips, in 3.560 seconds. The route function takes 3.343 seconds and admission takes 0.216 seconds. All three final product hashes are retained. The native result summary independently records two passing tests and no runtime warnings. The actual app and test host were built and executed with signing disabled. This is HTTP runtime evidence, not a Mac UI journey.

Both named final SQLite fixtures existed after the test process exited. The external runner then removed only those generated UUID directories. Failed-run fixtures remain retained. Raw logs include system connection diagnostics and skipped App Intents metadata extraction warnings; no affected-source compiler warning was reported. Strict Swift lint passes the two changed Swift files. The report and adapter contract pass Markdown lint.

The [evidence packet](evidence/navigation/mcp-container-catalog-sorting/) retains all six run revisions, exact commands, compressed raw output, source and product hashes, native result summary, historical and corrected runners, and cleanup receipts. The initial dirty-helper red is historical and does not establish final source qualification. Final standards and specification source reviews found no confirmed source findings. The standards artifact audit identified the collector issue described above, then verified the correction and all 68 artifact hashes. No confirmed findings remain.

## Remaining map gates

The optional catalog sort now works through Core and actual MCP HTTP. Native menus, per-device/dataset/catalog preferences, selection retention and rapid-request qualification remain pending. No phone/tablet sorting runtime, physical scale/memory/latency, Mac UI runtime, signed CloudKit/account/Share or whole-app polish claim is made. The existing map remains open.
