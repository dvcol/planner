# Native webpage app-link policy review

Status: Q145 A accepted on 22 October 2026. Confirm every supported external-app link, revising Q140's direct-click convenience. Implementation and qualification remain pending.

## Observed API limit

Q140 accepts direct supported Mail/Phone/Maps clicks using the system, while automatic app redirects require an explicit Open action. The public SwiftUI `WebPage.NavigationAction` has no explicit user-gesture field. An actual installed-SDK [loopback probe](prototypes/evidence/native-webpage-activation/installed-mac-probe/observations.json) shows that autonomous `HTMLElement.click()` and an untrusted synthetic mouse event both report `.linkActivated`, with zero mouse metadata and no recorded user activation. A script-generated `_blank` click does the same. `location.assign` reports `.other`. All app URLs are cancelled by the probe; it opens no other app and supplies no Planner acceptance.

The [actual output](prototypes/evidence/native-webpage-activation/installed-mac-probe/probe-output.jsonl) retains those independent observations. Genuine native mouse input was not exercised; zero mouse metadata must not be assumed to exclude legitimate touch, keyboard or accessibility activation. A mouse-only heuristic would not establish the required cross-device distinction.

WebKit's primary [navigation construction](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/loader/NavigationAction.cpp), [Cocoa mapping](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebKit/UIProcess/API/Cocoa/WKNavigationAction.mm) and [simulated click implementation](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/dom/SimulatedClick.cpp) explain why a generated activation can carry the same reported type. These current source references explain the observed result; the archived installed-runtime output, rather than a claim that main matches the shipped build, establishes the concrete finding.

## Q145 choices and effects

A. Require one native Open action for every supported external-app URL, including ordinary Mail/Phone/Maps taps. This revises Q140's direct-click convenience but gives one predictable interaction across mouse, touch, keyboard and accessibility. It uses public SwiftUI/WebKit APIs and avoids automatic app switching based on an ambiguous reported activation type.

B. Use reported `.linkActivated` as the direct-opening rule and confirm other reported app navigations. Ordinary clicks stay immediate, but autonomous generated clicks may also switch apps. This retains the convenient interaction with an explicit limitation to the automatic-navigation policy. It must not be described as proof of human initiation.

Accepted: A. The user approved one native Open action for every supported external-app URL. The existing native UI and real loopback HTTP boundaries are authorized for implementation and tests. Unknown, executable and file URL schemes remain unsupported under either option, and website browsing does not create Planner data commands or bookmarks.

## Existing test boundaries and remaining gates

Use the already approved native UI and real loopback HTTP seams for the selected behavior, including a generated click and an ordinary redirect, exact targets, cancellation, retained guide and original bookmark. No new direct controller test or production injection is proposed. Actual system handoff and supported mouse/touch/keyboard/accessibility journeys remain separate executed gates. SDK facts do not replace those tests.
