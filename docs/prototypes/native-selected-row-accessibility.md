# Selected Item presentation accessibility

Status: a reproducible dark iPad contrast finding remains open for Q99. All temporary production row/style probes have been reverted. No passing contrast result or final UI acceptance is claimed.

## Context and goal

Selected collection rows must keep compact metadata readable while native selection and details retain their source identity. A recent Maps capture showed pale secondary metadata over a blue selected row. The review uses the existing public native UI seam and isolated `list-windows` fixture, with real saved Items, source identities and five-minute estimates.

Before: selected-row contrast had no automatic audit evidence. The intended outcome is readable selected content, supported by native contrast checks and inspection in light/dark appearance without changing completion, navigation or paging. The current checkpoint establishes the finding and isolates its cause; the correction still needs the Q99 selection-treatment decision.

## Executed diagnosis

XCTest's unfiltered `performAccessibilityAudit(for: .contrast)` flags the selected title. The issue says, "Contrast is not high enough for SwiftUI.AccessibilityNode unless font size is larger." The original [full presentation](evidence/navigation/native-selected-row-accessibility/tablet-selected-contrast-dark-retry/A33A8D05-5511-4606-ADA8-F65354266E4D.png) and [flagged element](evidence/navigation/native-selected-row-accessibility/tablet-selected-contrast-dark-retry/A917C6B7-2387-4399-872D-EDD2B82ADFD0.png) are retained. Pale metadata remains a visual finding; it is not the element identified by this audit.

Ranked hypotheses considered selection tint, title typography and foreground inheritance. Native indigo tint, headline typography, bold headline typography and automatic List styling all retained the title failure. A minimal stock `NavigationLink(title, value:)` row also fails in the same saved scene, both with plain and sidebar List styles. Those reductions remove Planner's metadata, custom accessible row value and completion button. The [stock sidebar capture](evidence/navigation/native-selected-row-accessibility/tablet-selected-contrast-stock-sidebar-dark/D9612F09-3D43-4016-851F-02C7C8547796.png) shows the native rounded selection treatment.

This supports the selected foreground/background combination as the remaining problem. It does not establish an Apple-confirmed operating-system defect, or prove every platform/appearance has the same failure. No probe is shipped as a fix.

| Diagnostic | Runtime result |
| --- | --- |
| Real saved row | Contrast failure, 12.716 seconds |
| Native indigo tint | Contrast failure, 12.349 seconds |
| Headline title | Contrast failure, 12.462 seconds |
| Bold headline title | Contrast failure, 12.330 seconds |
| Automatic List style | Contrast failure, 12.223 seconds |
| Minimal stock plain row | Contrast failure, 13.883 seconds |
| Minimal stock sidebar row | Contrast failure, 12.128 seconds |

All corresponding mobile compilations pass. The earlier 20.912-second attempt expected the wrong fixture note, `Window notes 001` rather than `Window notes 1`, and failed before the audit. It is a test assertion mistake, not product-red evidence. The [literal results](evidence/navigation/native-selected-row-accessibility/results.json), compressed logs, source/product hashes, diagnostic source and original issue descriptions preserve every attempt. Each runtime verifies frozen source/products and restores Simulator appearance afterward.

## Native design constraint and open choice

Apple's [background prominence](https://developer.apple.com/documentation/swiftui/environmentvalues/backgroundprominence) lets semantic styles adapt to an accent background; it exposes no selection color or contrast ratio. Resolving the accent color does not prove it equals a List's rendered selection. AppKit has [selected-content text color](https://developer.apple.com/documentation/appkit/nscolor/alternateselectedcontroltextcolor), but it supplies no cross-platform contrast policy for arbitrary colors.

Q99 asks whether to retain native List/navigation controls with an app-controlled selected background/foreground treatment, or retain the exact system appearance with this contrast limitation open. The recommendation is controlled contrast, preserving native selection, keyboard, navigation and action semantics. No new Core, provider or test-only interface is proposed. Its actual appearance still needs light/dark and accessibility qualification before acceptance.

The diagnostic function is retained as compressed evidence rather than a permanently failing, filtered, skipped or expected-failure test in the ordinary suite. A correction can reuse the same already accepted native UI boundary. The [visual review](evidence/navigation/native-selected-row-accessibility/visual-review.json) names only inspected originals; additional exported captures have no implied visual acceptance.

## Completion limits

This checkpoint is dark iPad evidence only. Phone selection opens details and cannot establish a persistent row's contrast. Mac runtime, physical devices, VoiceOver, keyboard, maximum text size, Reduce Transparency/Motion, other scenes and full light/dark contrast remain open. A native audit of one visible screen is not whole-app accessibility acceptance. Ticket 23 and the implementation map remain open.
