# Native webpage download fallback

## Context and accepted behavior

Q139 A keeps Planner focused on reading. A requested download or unsupported response must explain the limitation and offer explicit opening in the default browser. Integrated downloading and file saving are outside this slice. Q133's ordinary webpage behavior and the exact saved bookmark/source context remain unchanged.

The installed WebKit 27 interface exposes `WebPage.NavigationAction.shouldPerformDownload` and the existing navigation-decider boundary. The first vertical slice covers an explicitly selected same-origin HTML download link. Unsupported response types and actual system-browser handoff remain separate checks; no full download manager is assumed.

## Required /tdd and definition of ready

Use the already approved native UI and loopback HTTP boundaries. Add a same-origin download link to the existing test server, with a small text response available at its exact destination. Open the saved guide, activate the download link and first fail at the absent native fallback explanation. Add only the native download-action interception and system presentation required for that case.

The explanation must offer Open in default browser for the exact download URL and a native cancellation action. Expose the destination to accessibility so the user can identify what would open. The journey verifies that target, cancels the explanation, retains the rendered guide and returns to the original Item/bookmark. It does not launch or automate another application, write a downloaded file or claim that system handoff was executed.

Reuse the production WebPage session/navigation-decider boundary. No test-only callback, new controller test seam, target, package or library is proposed. Repeatable positive behavior comes from the real HTML link and WebKit action, not an injected navigation event.

## Definition of done and limits

Qualify this requested-download explanation and cancellation on phone/dark iPad, affected reader-history/cookie regressions and matching Mac compilation. Inspect original rendered captures, compare exact source/product inputs and strictly lint affected Swift/docs. Preserve failed attempts separately. Unsupported content, initial versus linked response behavior, external app policies, actual default-browser handoff, Mac UI and physical-device behavior stay open until separately executed.

## First native execution

The [actual phone red](evidence/native-webpage-download/requested-download-phone-red/failure-boundary.json) renders the saved guide and activates its real same-origin HTML download link, then fails at the missing native explanation. Its structured result records one failed function and xcodebuild exits 65; misleading passed-suite footer lines do not override that failure. The implementation intercepts WebKit's HTTP/HTTPS `shouldPerformDownload` action before opening a new page, presents a native alert with the exact URL and an explicit browser action, and offers Keep reading. It adds no download manager or saved-content write. Runtime qualification follows before passing credit.

The [unchanged phone journey](evidence/native-webpage-download/requested-download-phone-green/qualification.json) passes in 40.618 seconds. Its original native alert capture is inspected: the exact loopback download URL is readable, Open in default browser is available, and Keep reading preserves the original rendered guide without a Page unavailable overlay. Returning retains the saved bookmark's public identity and original guide URL. [Red/green comparison](evidence/native-webpage-download/requested-download-phone-green/red-green-comparison.json) confirms unchanged test bytes and matching [Mac compiler sources](evidence/native-webpage-download/requested-download-mac-compiler/qualification.json). No external-browser action or file save is executed by this journey. The WebKit navigation-stream error handling remains unchanged. Dark-tablet and affected native browser regressions follow.

## Final requested-download checkpoint

The [dark iPad cohort](evidence/native-webpage-download/requested-download-dark-tablet/qualification.json) passes all four functions: the requested-download explanation/cancellation, persistent-cookie relaunch, recovery/history and ordinary reported new-window links. The [phone regressions](evidence/native-webpage-download/requested-download-phone-regressions/qualification.json) pass those three existing functions. Together with the initial phone download green, there are eight native executions across four functions. All eight selected original captures are inspected. The native alert exposes the exact download destination and Keep reading preserves the rendered guide and saved bookmark.

[Exact comparison](evidence/native-webpage-download/requested-download-phone-regressions/source-epoch-comparison.json) matches 1,074 inputs across the native cohorts and Mac compilation. Simulator packets retain four products each, Mac compilation nine. Passing native runs have zero failures/skips or SQLite unlink diagnostics, and dark appearance is observed and restored. The missing-alert red remains failed. Actual default-browser handoff, unsupported responses, automatic external-app navigation, Mac UI and physical behavior remain separate gates. This checkpoint does not add file saving.

## Next unsupported-response slice

The accepted Q139 behavior also covers an ordinary webpage link whose HTTP response has a MIME type WebKit cannot display. The existing fixture can serve one such response with a known exact destination and no HTML download attribute. Use the same native UI/HTTP seams. First observe the missing native explanation, then intercept the actual `WebPage.NavigationResponse.canShowMimeType` result. Keep the exact unsupported URL separate from the saved guide URL. A native cancellation must preserve the previously committed guide and its bookmark. No general download-result API or frame identity is assumed from the response type. Initial unsupported bookmarks and any necessary native return presentation follow as a separate behavior.
