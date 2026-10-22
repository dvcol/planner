# Native failed-webpage context

## Context and required /tdd

The ordinary failure overlay still opens `page.url` when available. After Museum loads and Garden fails, that can send the external-browser action to Museum. The accepted reader behavior requires the actual requested destination while preserving the original saved bookmark. The displayed failure also exposes WebPage's generic wrapper instead of its underlying connection description.

Use the already approved native UI and real loopback HTTP seams. Save Museum, render it, select an unavailable Garden link and first observe the missing exact target in the failure UI. Require the external action's accessible value and visible URL to name Garden, with a readable connection error. Retry must load Garden after the fixture becomes available; returning must retain Museum's original bookmark identity and URL. No external browser is launched and no direct controller test, hook, target or package is introduced.

## Definition of done and limits

Run the focused phone red/green cycle, then phone/dark-tablet failure/recovery and unsupported-response regressions with matching Mac compilation. Inspect original captures, reconcile exact source/product inputs and strictly lint the changed Swift/docs. This qualifies the displayed/bound target and recovery context, not actual system-browser invocation, removed origins, external-app policy, Mac UI or physical acceptance.

## First native execution

The [actual phone red](evidence/native-webpage-failure-target/failure-target-phone-red/failure-boundary.json) renders Museum, selects the unavailable Garden link, and fails because the external action has an empty accessible target instead of Garden's exact URL. Workspace/frozen sources and actual products match before the fix. The existing action's code also selected the last committed page rather than the attempted page.

The implementation shares the existing requested destination between Retry, the external-opening closure, its accessible value and the visible error URL. It displays the underlying provisional connection error instead of WebPage's generic wrapper. It preserves the expected policy-cancellation guard and does not write the saved bookmark. Actual native qualification follows before passing credit; no external system invocation is claimed.

## Final local qualification

The unchanged new journey passes on [phone](evidence/native-webpage-failure-target/failure-target-phone-green/qualification.json) and [dark iPad](evidence/native-webpage-failure-target/failure-target-dark-tablet/qualification.json). The latter also passes toolbar recovery and unsupported-response cancellation followed by a genuine network failure. Both affected [phone regressions](evidence/native-webpage-failure-target/failure-target-phone-regressions/qualification.json) pass. Together these are six native executions across three functions, with no failures, skips or SQLite unlink diagnostics. All six original native captures were inspected; the failed page shows Garden's exact URL and a readable connection description in both appearances. Retry reaches Garden and Return preserves the saved Museum bookmark.

[Source comparison](evidence/native-webpage-failure-target/source-epoch-comparison.json) reconciles all 1,074 inputs across the final native runs and [Mac compilation](evidence/native-webpage-failure-target/failure-target-mac-compiler/qualification.json). The nine Mac app/Share/test products compile; no Mac runtime or external-system invocation is credited. The original failing run and unchanged test comparison remain archived. Broader browser policies, removed origins, resizing/accessibility, Mac UI and physical-device acceptance stay open.
