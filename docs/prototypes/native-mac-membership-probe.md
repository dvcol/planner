# Native Mac membership runtime probe

## Context, before and goal

Mac app and UI-host compilation does not establish native navigation or persistence. This probe attempts the existing production-view Item/List membership journey on macOS 27.0.1, independently of pending Q85 catalog sorting.

## Definition of ready and required qualification

The native UI is an accepted test boundary. The existing journey creates an Item and List, cancels the first association, adds the same shared Item, repeats Add without duplication and verifies the saved membership and global Item after relaunch. No new test seam, production behavior or permission change is needed to attempt it.

Runtime completion requires the actual journey to execute and pass, original native capture inspection, and the map's separate keyboard/adaptive/accessibility checks. A build or runner launch cannot satisfy those requirements. Signing and physical-device setup remain deferred by the human.

## Execution and result

The focused command built the Mac app/test products and launched the UI-test runner. No journey function or assertion appeared during the observation. After more than five minutes, the agent sent SIGINT to the verified agent-owned xcodebuild process. The process terminated with exit 75 and TEST INTERRUPTED. Its terminal result tree contains only a synthetic System Failures runner case saying Testing was canceled. Raw summary counts are zero passed, one failed and zero skipped; the intended journey executed zero functions and receives no pass or assertion-failure credit.

Read-only developer-security status reports disabled. Filtered runner/testmanager error logs contain only their output header. Neither observation establishes why startup did not reach the journey. The interruption itself is agent-requested, not a naturally observed startup timeout. No developer-security, automation, signing or system setting was changed. No native Computer Use was invoked.

The execution record retains the exact command, raw summary/tree, lossless original log, pre-run source/configuration hashes, stop observation and product hashes. The pre-run 94 source/configuration files remain unchanged. The later unavailable-store fixture work is outside those recorded native app/test sources.

## Remaining gates

Mac runtime remains unqualified. This probe adds no Core/HTTP or simulator pass credit. Further runner diagnosis and actual native journeys, human layout review, keyboard/accessibility/adaptive behavior, scale, physical sync/account/Share and whole-app polish remain open. The independent simulator recovery qualification has its own report and results.
