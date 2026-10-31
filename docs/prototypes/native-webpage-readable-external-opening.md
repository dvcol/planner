# External opening from a readable webpage

## Approved behavior and current gap

Q132 A requires a small native reader toolbar covering history, reload, return and external opening. Q133 A also keeps explicit external opening available. The current readable page exposes history/reload/return only. External actions exist for failed or unsupported content and saved bookmarks, but reaching a readable linked page should not require returning to its original bookmark to open a different URL.

Reuse the already approved actual native UI, real loopback HTTP and system-browser handoff seams. Save Museum, navigate inside Planner to Garden, then require a native external-opening action. Explicitly activate it, verify Safari foreground and an actual Garden request from Safari, then return to Planner and its unchanged reading page. Return to the exact original Museum bookmark and verify its identity/URL. No new Core/MCP contract, test boundary, package, target or production hook is needed. Signing stays deferred.

## Implementation and qualification plan

Record the actual missing-action failure before production changes. Add the action through the existing native toolbar overflow component, preserving direct history/reload controls. The action uses the same current requested destination as Retry and existing external fallbacks. It must not change saved bookmarks or reopen their original URL instead of the visible linked page.

Qualify phone and dark-iPad native handoff, existing failed-page external opening and ordinary new-window history, then compile the same inputs for Mac. Inspect original captures and exact request provenance, reconcile source/products and run narrow lint/formatting checks. Actual Mac external invocation, every website/redirect and physical acceptance remain separate. Scripted-popup qualification remains open; finding this action gap supplies no popup credit.

## Missing action and native-menu diagnostics

The first phone failure reaches Garden and fails at the missing More action in 42.140 seconds. Its retained native hierarchy has Garden's rendered heading and history/reload/return controls, with no external action. Xcode restarts its harness after that assertion and later fails to find simctl for diagnostic collection; neither the empty restarted harness nor the recording, which ends before the failed check, receives passing/visual credit.

The first overflow attempt also fails, in 42.298 seconds. Its actual native hierarchy exposes Open in default browser as a native menu Button without the SwiftUI identifier/value. Correct the test driver to select that visible label and retain the actual Safari request as destination evidence. Recheck the corrected driver against pre-fix production before applying the smaller native action without ineffective menu metadata. Both initial failures remain recorded; the directory named green is a failed attempt, not passing evidence.

The corrected driver on pre-fix production reproduces the missing-action failure in 39.271 seconds. Its unchanged body then passes the first corrected phone run in 47.142 seconds. The two preliminary phone regressions also pass. The first Mac compiler fails because ToolbarOverflowMenu is unavailable on macOS. Use that native component only on iPhone/iPad and a standard native toolbar item on Mac; the action uses the same current URL on all platforms. The preliminary passes retain their own source epoch and do not replace final matching-source checks.

## Final local checkpoint

The final phone and dark iPad cohorts each pass all three functions: readable-page external opening, failed-page external opening and ordinary new-window history. The new action opens the current Garden URL through Safari, not the original Museum bookmark. Returning keeps Garden readable inside Planner, then restores the exact saved Museum bookmark identity/URL. The failed-page and history workflows retain their previous behavior. Six final native executions have zero failures/skips, SQLite unlink diagnostics or harness restarts.

The checkpoint reconciliation verifies 1,102 identical inputs across both final runtimes and successful Mac app/Share/UI-test compilation, including nine Mac products. It also proves the corrected test file is unchanged from its pre-fix failure; only the production reader differs. Four actual external request observations distinguish Planner's user agent from Safari and preserve the original/linked URL pair. All twelve final original captures were inspected. Safari's captures remain in loading state, so they supply no external-page rendering claim. The iPad retains its original dark appearance; affected Swift formatting and Markdown/whitespace checks pass.

This qualifies the represented phone/iPad action and actual system handoff. Mac interaction, physical devices, broader websites/redirects, scripted popups and the feature-complete whole-app visual pass remain open. The short phone browser title can truncate beside the native controls; full browser/title/accessibility polish remains part of that final pass. Q155 A is accepted independently, and signing stays deferred.

The guarded duplicate-export cleanup removes seven redundant attachment exports after verifying retained originals and the diagnostic hierarchy. It removes 25,193,284 nominal bytes while preserving all original result bundles and packet captures. Physical APFS free-space gain is not measured.
