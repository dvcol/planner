# Native saved-webpage reader

## Context and current outcome

Q132 A and Q133 A make ordinary saved websites open inside Planner. Previously, the text link and rich card immediately opened the system browser. Planner now hosts Apple's SwiftUI `WebView`/`WebPage` in the detail area on wide layouts and a pushed page on compact layouts. Native icon controls provide webpage Back, Forward, Reload and Return to the originating Item or Itinerary.

This is the first reader slice. The broader [accepted browser workflow](../native-map-browser-workflow-review.md) remains open: normal external opening, failed-load recovery, cookies, new-window links, download fallback, external-app navigation and source removal require their own qualification. Aggregate Map presentation remains separate.

## Ready and done criteria

The accepted workflow supplies the goal, previous state, target state and required native evidence. This slice reuses the existing actual native UI seam and exercises real WebKit network I/O. It adds no direct controller test boundary, production test injection, target or package.

Its local done criteria are actual page rendering, history/reload, unchanged original bookmarks, exact valid source return, affected draft/creation regressions, strict Swift lint and platform compilation. A build alone does not establish native interaction. Signing and physical acceptance remain deferred.

## Implementation

Each saved bookmark supplies its exact link identity, owner kind/identity/lifetime, optional contextual appearance and current dataset namespace. Each link owns its URL-opening environment; duplicate URLs cannot resolve the request by selecting the first matching bookmark. Maps links retain their existing behavior. A text-link contextual action can still open the default browser.

One reading session owns one WebPage configured with Apple's default persistent website store. This configuration does not itself prove login persistence. Browsing never changes the saved URL or copies webpage state into Planner data. Explicit Planner navigation closes the page through the existing draft guard. Compact ordinary details use an explicit native NavigationStack; Calendar reuses its existing stack rather than nesting another one.

Calendar's first real journey exposed the absent reader host. After adding that host, Return still left the reader visible because a second navigation stack owned the presentation. Reusing the existing Calendar stack fixes the unchanged journey. An Itinerary journey similarly exposed an incorrect Item return label; the label now follows the actual owner kind. Switching to an empty Lists catalog also restores the native catalog column rather than leaving only an Item placeholder.

## Executed TDD and fixture

The private UI-test HTTP listener binds loopback with an ephemeral port and serves actual HTML to WebKit. It handles HEAD and GET, bounds request headers to 8 KiB, records request lines and closes connections. The fixture has a viewport and light/dark color-scheme metadata. Production has no injected HTML, network callback, ATS exception or test-only browser control.

Page A links to Page B. Tests observe actual GET requests, rendered headings, Back/Forward and another GET after Reload. Return preserves the original saved bookmark's identity and URL. Other native cases exercise text and rich-card opening, a scheduled Item opened from Calendar, an Itinerary bookmark, and a locally completed List appearance whose global Item remains Todo.

The [function reconciliation](evidence/navigation/native-itinerary-window-compatibility/native-browser-final-phone/tdd-function-reconciliation.json) verifies unchanged test bodies for these red/green pairs:

| Behavior | Observed failure | Passing correction |
| --- | --- | --- |
| Page history | [Missing Back control](evidence/navigation/native-itinerary-window-compatibility/native-browser-history-red/test-summary.json). | [Native history and reload](evidence/navigation/native-itinerary-window-compatibility/native-browser-history-and-draft-green/test-summary.json). |
| Calendar return | [No Calendar reader host](evidence/navigation/native-itinerary-window-compatibility/native-browser-calendar-red/test-summary.json); the following host attempt could not close its nested stack. | [Existing Calendar stack](evidence/navigation/native-itinerary-window-compatibility/native-browser-calendar-existing-stack/test-summary.json). |
| Itinerary return | [Incorrect Item return label](evidence/navigation/native-itinerary-window-compatibility/native-browser-itinerary-red/test-summary.json). | [Actual plan return scope](evidence/navigation/native-itinerary-window-compatibility/native-browser-itinerary-return-scope/test-summary.json). |

Early compilation failures, an accessibility element-type mismatch and a hidden-catalog row assertion are retained without behavioral red credit. The trial reading-session stack workaround was reverted. An owned-window capture showed Add present: its test checked too early and incorrectly fell through to overflow. No extra production navigation state was kept to accommodate that lookup.

The old draft test also looked only for a Cancel control after creation had moved to a pushed editor with Back. The [exact committed pre-browser baseline](evidence/navigation/native-itinerary-window-compatibility/native-browser-draft-baseline/baseline-source-verification.json) reproduces that obsolete lookup, with all 1,068 source/configuration/resource inputs matching committed blobs. The driver now uses the actual Back/Cancel control, explicitly discards an edited draft and waits for the catalog before creating again. This is not credited as a production draft fix.

## Qualification checkpoint

The [initial complete iPhone run](evidence/navigation/native-itinerary-window-compatibility/native-browser-final-phone/test-summary.json) passes all seven functions, with zero failures/skips. It includes five reader journeys and the existing fresh-creation and draft/global-completion journeys. Its original owned-window captures and hashes are retained in the packet.

The [first dark iPad run](evidence/navigation/native-itinerary-window-compatibility/native-browser-final-tablet/test-summary.json) passes three functions and fails four. Two failures check Add before its visible toolbar settles; List creation bypasses the existing overflow-aware helper; the draft test uses a phone-only section lookup. Its original captures/hierarchies and appearance observations remain recorded. The corrected driver waits for toolbar availability, uses native catalog/section helpers and handles an iPad sidebar covering the target. The [corrected native driver run](evidence/navigation/native-itinerary-window-compatibility/native-browser-tablet-navigation-driver/test-summary.json) passes all seven functions with zero failures/skips. It preserves the failed epoch. A blank first-frame Itinerary capture is not accepted as visual proof. The first screenshot assertion attempted to read a remote DOM frame inside an XCTest waiter; its failed accessibility lookup and subsequent test-service failure are retained in `native-browser-tablet-painted-reader`. The Simulator was then found shut down and booted without resetting its data. That failed run records unsuccessful final appearance observation rather than claiming restoration.

The next `native-browser-tablet-native-paint-frame` attempt uses native navigation-pane bounds, but its pure-white/pure-black sample requirement incorrectly rejects readable downsampled text. The [actual CoreGraphics probe](evidence/navigation/native-itinerary-window-compatibility/native-browser-tablet-native-paint-frame/pixel-probe.json) compares retained original readable and blank dark captures: the readable pane has 86 contrasting samples and no pure-white samples; the blank pane has no contrasting samples. The corrected UI assertion samples contrast against the background, waits asynchronously and retains the actual screenshot before asserting. Neither failed assertion attempt supplies production-failure or passing visual credit.

The [final dark iPad reader run](evidence/navigation/native-itinerary-window-compatibility/native-browser-tablet-painted-regression/test-summary.json) passes all five browser functions with the corrected native-pane paint check, zero failures/skips and zero SQLite unlink diagnostics. All 1,070 source/configuration/resource inputs and four actual products reconcile. Its [five original captures](evidence/navigation/native-itinerary-window-compatibility/native-browser-tablet-painted-regression/capture-manifest.json) were inspected individually. The Calendar portrait capture retains an open sidebar overlay and crowded inspector controls; it does not close final toolbar/width polish. This newer browser epoch is separate from the earlier seven-function iPad interaction/draft epoch.

The [Mac build](evidence/navigation/native-itinerary-window-compatibility/native-browser-reader-final-mac-build/exit.json) passes for the native app and Mac Share extension. Its [reconciliation](evidence/navigation/native-itinerary-window-compatibility/native-browser-reader-final-mac-build/qualification.json) confirms unchanged production/configuration/resources and all six recorded products; later screenshot-helper changes affect only an unbuilt UI-test input. This is compilation-only evidence. Actual Mac browser layout, toolbar title width, resizing, keyboard and window behavior remain open; no unchanged failed Mac automation startup was repeated.

The [final iPhone regression](evidence/navigation/native-itinerary-window-compatibility/native-browser-phone-painted-regression/test-summary.json) passes all seven functions with the same final source snapshot and the corrected light-mode paint check, zero failures/skips and zero SQLite unlink diagnostics. All 1,070 inputs and four products reconcile. The four reader captures and List-return capture were inspected individually; two additional captures retain the global completion/reopen journey. Original captures establish light presentation.

The [final Mac build-for-testing](evidence/navigation/native-itinerary-window-compatibility/native-browser-mac-ui-compiler/exit.json) also compiles the affected UI-test target, with all 1,070 inputs and nine recorded products reconciled. It deliberately does not start Mac UI automation. Strict affected Swift/Markdown lint and whitespace checks pass. These results do not close Mac runtime or the broader browser policies below.

## Remaining acceptance

- Add and qualify the ordinary browser external-opening control and rich-card secondary action.
- Exercise load failure, repeated Retry, cancellations and a late response.
- Prove website cookie/login persistence across reader closure and app relaunch without changing Planner backups.
- Implement and qualify reported new-window navigation, download/unsupported-content fallback and direct-click versus automatic external-app handoff.
- Keep reading after source/appearance removal, then return to the valid collection with an explanation and no retargeted action.
- Finish native Map loading/presentation after Q143's concrete seam review. Complete whole-app light/dark, contrast, larger text, keyboard/VoiceOver, resizing and physical acceptance after features are complete.

These gaps remain on the map. The reader checkpoint does not establish Safari-equivalent behavior, signed Agent Control storage, installed Share, CloudKit/account transitions or release completion.
