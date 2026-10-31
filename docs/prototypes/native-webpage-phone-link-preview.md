# Native Phone-link preview investigation

## Actual iPad finding

The Q145 direct-link function passes Mail, then an actual ordinary Phone-link tap opens WebKit's own Call/Message/Add to Contacts menu. The Planner confirmation is not reached. The original failed run, derived recording frame and provenance retain this finding. The generated app-link and three existing fallback functions passed in that cohort; the whole run failed and receives no final acceptance.

This is not the initially suspected unreachable Open control. The native Phone menu appears before that control exists. No Call or Message action was pressed and no other app was controlled.

## Bounded public-API probe

Try the installed public `webViewLinkPreviews(.disabled)` modifier with the unchanged existing native direct-link function. This is a reversible local probe, not an accepted global reader setting. Apple's [disabled-preview documentation](https://developer.apple.com/documentation/webkit/webview-swift.struct/linkpreviewbehavior/disabled) states that it prevents destination previews when pressing a link. Its actual effect on this Phone path must be executed, not inferred. The SDK confirms the public modifier and behavior value exist.

The grilling facts task separately checks primary source and installed declarations for a narrower public control. If suppressing this Phone menu requires disabling ordinary webpage previews, that is a user-visible tradeoff to review before shipping. Q144 and Q130 remain independently approved work.

## Probe outcome and public API limit

The unchanged direct-link test fails again at the missing Planner confirmation after the Phone tap (53.873 seconds). Its boundary validation records 1,074 matching workspace/frozen inputs and four matching executable products. Disabling previews did not establish a supported workaround. The reversible modifier was removed, preserving ordinary webpage previews. No Call or Message action was selected.

The installed iOS `WebPage.Configuration.dataDetectorTypes` exists, with an empty default. Apple documents it as adding links to recognized text, rather than intercepting actions on an explicit telephone anchor. The failed source uses the default. The installed iOS overlay marks the SwiftUI context-menu modifier unavailable; navigation/dialog protocols expose no dedicated telephone action callback. Upstream WebKit checks for DataDetectors presentation before ordinary anchor navigation, which can explain the observed menu, but that source revision is not asserted to match the installed runtime. Sources: [Apple detector configuration](https://developer.apple.com/documentation/webkit/webpage/configuration/datadetectortypes), [pinned anchor handling](https://github.com/WebKit/WebKit/blob/a689b3f7b2d7af7be96d88106c34d1cc1b55299e/Source/WebCore/html/HTMLAnchorElement.cpp#L543), [detector check](https://github.com/WebKit/WebKit/blob/a689b3f7b2d7af7be96d88106c34d1cc1b55299e/Source/WebCore/editing/cocoa/DataDetection.mm#L203).

Q146 A accepts Apple’s native Phone menu when WebKit intercepts a telephone tap, while retaining Planner confirmation for reported app-link navigation. The actual native menu cancellation still needs qualification. The existing iPhone successes, iPad four passing cases and Mac compiler result remain scoped evidence; the failed iPad case is not waived. Q144 and Q130 proceed independently.
