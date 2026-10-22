# Native collection Map location controls

## Context and accepted behavior

Q135 and Q143 already approve temporary location resolution, exact-row Maps-link and address-candidate choices, and Retry. The complete loader implements these commands, and its controlled-provider tests qualify input binding, ambiguity, delayed results and occupied-slot bounds. Native Locations currently opens exact details but has no controls for those decisions.

The next vertical slice adds a native Location options menu beside the existing detail-opening row. Reuse the detail viewer's Map link wording and saved label/original-URL presentation. A native Picker selects among that row's saved Maps bookmarks. A small production reader on the already approved SavedMapCollection interface supplies its currently bound request and saved options, so the UI never guesses a selected bookmark from a URL. Owned pin/address precedence remains intact. Selection changes only temporary Map state. Address choices and Retry follow through the same native options surface, with provider attribution and uncertainty preserved.

## Definition of ready and required /tdd

Use the existing approved PlannerNavigationUITests seam and actual Item creation/edit/save. Save two coordinate-bearing Maps links with an explicit Alternate pin label. The native journey must first fail at the absent Location options control. Add only the bound reader and native controls needed to choose the alternate pin. Observe the new literal coordinate, disappearance of the previous pin, and both unchanged saved bookmark identities/original URLs in Item details. No new target, provider injection, test-only parameter, Core/MCP declaration or backup change is proposed.

## Definition of done and limits

Qualify the real Picker interaction on phone/dark iPad, affected exact-choice regressions, strict lint and matching Mac compilation. Preserve original captures and source/product comparisons. Then qualify native Retry and place-choice presentation where the service can reproduce the state; the approved controlled-provider module cases remain the repeatable evidence for delayed/ambiguous outcomes. Live provider/physical scale, actual Mac UI, accessibility/resizing and whole-app polish remain separate. Do not report an unexecuted service state as a native UI pass.

## First native execution

The [phone red](evidence/native-map-collection/native-map-link-picker-phone-red/failure-boundary.json) saves and reads both actual bookmarks, displays the first coordinate and reaches the missing Location options control. The [first implemented phone journey](evidence/native-map-collection/native-map-link-picker-phone-green/qualification.json) passes with the unchanged test: its native menu/Picker selects Alternate pin, the collection moves to the second literal coordinate, and both saved bookmark identities/original URLs remain unchanged. The bound reader uses the selected production request and saved options; it does not infer bookmark identity from URL equality. A native stale-choice explanation belongs to the presented Locations sheet, where its controls are active. The following qualification checks that presentation placement plus affected exact-choice workflows.

## Dark iPad and production-loader qualification

The [dark iPad cohort](evidence/native-map-collection/native-map-link-picker-dark-tablet/qualification.json) passes four native functions: the new Maps-link Picker, coincident source choices, direct repeated itinerary stops and repeated List branches. All four original captures are inspected. The Picker moves only the temporary collection pin; opening Item details retains both exact saved bookmark identities and URLs. The independent detail preview can still use its first saved bookmark. That is separate temporary presentation state.

The [production-loader regression](evidence/native-map-collection/native-map-link-picker-loader-regressions-mac/qualification.json) passes all twelve functions against actual Mac-hosted Planner storage and the existing controlled providers. Its thirteen marked fixture directories are removed only after successful completion, host exit and closed-database verification. All represented source/product comparisons pass with no SQLite unlink diagnostics. [Matching Mac app/Share/UI-test compilation](evidence/native-map-collection/native-map-link-picker-mac-compiler-authorized/qualification.json) also passes, with no Mac UI runtime credit.

Two initial final-check attempts ended before compilation or native execution because the sandbox denied Xcode cache and Simulator access. Their exit-74 packets remain recorded with no passing credit. The supported tool-access retries require no signing change. Actual stale-choice alerts, address ambiguity/Retry controls, refresh/draft behavior, layout/accessibility and physical/provider scale remain open.

## Final saved-link Picker checkpoint

The [final phone cohort](evidence/native-map-collection/native-map-link-picker-final-phone-authorized/qualification.json) passes the same four functions as dark iPad, with zero failures/skips or SQLite unlink diagnostics. Its four original captures are inspected. [Exact comparison](evidence/native-map-collection/native-map-link-picker-final-phone-authorized/source-epoch-comparison.json) establishes the same 1,074 input hashes across final phone, dark iPad, the twelve-function production-loader regression and matching Mac compilation. Simulator packets retain four products each, direct Mac execution three and Mac compiler evidence nine. The earlier initial phone green precedes the sheet-alert placement change and is credited separately. Actual stale-choice alert execution and the remaining acceptance gates stay open.

## Next native Retry slice

Use the same approved native UI seam and actual saved content. A Google Maps search URL with a textual query produces a temporary search candidate with no coordinate through the real resolver. It gives a reproducible unresolved state without replacing providers or forcing a service outage. The journey will retain the saved bookmark identity, reach Locations, first fail at its absent Retry control, then exercise Retry and verify the original URL and absence of an invented pin. The loader's existing direct tests remain the evidence for actual provider retry, deadline and draining-slot behavior. Provider attribution and uncertainty presentation follow separately.
