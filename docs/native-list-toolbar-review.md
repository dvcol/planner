# Compact List toolbar review

Status: Q113 A is implemented and locally qualified on phone/tablet. Mac and unsigned device products compile. Current Mac UI retries fail before reaching Lists and remain an open qualification gap; an idle-session request is pending. Signing remains deferred.

## Context and starting state

Filters, Sort, Edit, Add and List actions crowd the 402-point phone bar and its inline List title disappears. The content header retains the full name. Lowering native visibility priorities did not fix the observed title loss; that reverted experiment remains in `phone-list-title-native-priority`. Q113 A explicitly chooses native More for compact layouts.

## Goal and expected end state

Keep Filters and the accepted Add menu directly visible in compact layouts. Put Sort, native Edit/Done and List actions in the system More menu. The full compact title must fit beside the controls. Regular iPad and Mac retain ordinary toolbar items; Apple's automatic overflow still applies when a particular column cannot fit them. The full List name remains available in the content header.

Preserve existing action validation, cumulative filters, progress, estimates, selection, source/appearance identities, saved order and Save/Cancel behavior. This changes presentation only, with no Core, persistence, package, target or entitlement change.

## Definition of ready

Q113 A settles placement. Existing native UI and disposable real-data fixtures are approved test boundaries. The installed iOS 27 SDK supplies `ToolbarOverflowMenu`; Mac uses its existing ToolbarItems. Signing/account setup remains deferred. No production test controls or new test boundary is needed.

## Required tests and definition of done

- First reproduce the missing compact title, then qualify its native width and non-overlap with bar buttons after the change.
- Verify directly reachable Filters/Add and Add-existing Cancel, plus Sort, disabled non-Manual Edit, Manual restoration, Edit/Done and List-action Cancel through the actual native menu.
- Qualify regular iPad's readable name and native control reachability. Check light/dark appearances and inspect original own-app captures.
- Run the existing production filtered Manual drag journey, preserving hidden membership completion, original identities, full progress and order after relaunch.
- Compile the actual Mac and unsigned device products, run affected strict Swift/Markdown lint and Git whitespace checks, and retain exact source/results.

Final whole-app polish, broader layout/accessibility matrices and physical-device behavior remain separate map work.

## Implementation

The compact branch uses `ToolbarOverflowMenu` with the same Sort menu, native EditButton and List-actions menu. Filters and Add stay ordinary visible toolbar items. Shared view definitions keep the existing validation and callbacks on both layout paths.

UIKit overflow entries can expose their native labels while omitting SwiftUI identifiers. The existing UI controller now follows those actual menu labels, including Edit/Done and List-action submenus. Production controls gain no automation hooks. Existing sorting/reorder callers use that same traversal.

## Recorded qualification

All packets below are under the compatibility evidence. Each retains its original source epoch, command, log and result; a later passing invocation does not change an earlier failure.

| Check | Result | Packet |
| --- | --- | --- |
| Original compact title reproduction | Fails, 19.484 s | `q113-phone-title-red` |
| Native More title/Add/Cancel after implementation | Passes, 29.182 s | `q113-phone-title-green` |
| Phone light toolbar class | Three pass, zero failures/skips; Item/Inbox titles, More interactions and List title/Add | `q113-phone-more-actions-qualified` |
| Phone dark More interactions and title/Add | Both pass, 55.921 and 30.275 s | `q113-phone-dark-toolbar-qualified` |
| iPad Sort/Manual/Edit/Done/List-action Cancel | Passes, 45.323 s; following compact-only title assertion fails in this same invocation | `q113-tablet-direct-controls` |
| iPad readable header, direct Filters/Sort/Edit and native Add/Cancel | Passes, 27.941 s | `q113-tablet-native-layout-qualified` |
| Production phone dark filtered drag and relaunch | Passes, 144.726 s | `q113-phone-filtered-drag-dark-qualified` |
| Focused phone fixture title after relaunch | Passes, 47.121 s | `q113-phone-relaunch-title-observation` |

The compact native title measures 133.333 points against a 133.031-point minimum and does not overlap any hittable bar button. Original light phone and regular iPad captures were inspected. The iPad's 340-point content column retains the readable full heading and direct Filters/Sort/Edit, while native overflow handles excess controls. The initial probe incorrectly required its compact inline-title policy there; the corrected assertion does not change the iPad app or its spacing.

The More journey verifies Title/Descending order, disabled Edit outside Manual, restored Manual order, Edit/Done and canceled estimate editing with both original appearance identities retained. Its earlier failures, in `q113-phone-more-actions` and `q113-phone-more-native-labels`, locate test-controller identifier assumptions at actual native menu boundaries. They are not additional production corrections or successful runs.

The first production UI compile, `q113-phone-filtered-drag-dark`, catches a stale test-local variable left by the traversal update. Removing that obsolete assertion allows the actual journey to run. The passing journey retains a hidden Done Hotel, reorders Cafe before Museum, restores all rows and keeps Hotel/Cafe/Museum order, completion, original identities and 1-of-3 progress after relaunch. Its inspected originals show native dark surfaces and readable controls.

## Remaining qualification

One production relaunch capture has a blank inline title while its full content name remains readable. The smaller fixture passes, and the original production journey also passes with an explicit title wait in 144.160 seconds. Its inspected final capture shows Tokyo in the bar and content header. No repeatable defect or cause is established by those observations, and no extra production correction is applied. The iPad dark name/Add/Cancel check also passes in 29.470 seconds. Both Simulators return to their original light appearance. Final Mac/device checks retain their own source epochs. No whole-app dark-mode, accessibility, physical-device or Navigation prototype completion is claimed. Full-display diagnostic recordings are not published.

## Final compiler and Mac UI status

The final generic iOS device build passes without signing or installation. The app embeds one mobile Share extension; both executable products contain arm64. The final device, production phone and Mac-retry packets each retain 983 inputs that match the current source/configuration files. Affected strict Swift formatting, Markdown lint and Git whitespace checks pass.

Both current Mac invocations compile the actual app and UI target with the existing local ad hoc configuration. Their UI journeys fail before List creation, first while locating the global Add control, then while waiting for the first saved Item's notes. Each original failure hierarchy contains the disabled application and system menu, with no app Window/Sheet/Dialog. A separate read reports an unlocked, logged-in console session. These observations establish neither a Q113 List regression nor an environment root cause. No passing Mac List interaction is claimed. The user is asked whether the Mac can remain idle for a focused retry; independent local work can continue.

The packets `q113-mac-filtered-manual-qualified` and `q113-mac-filtered-manual-retry` retain these actual failed outcomes. System menu contents are omitted from published text diagnostics, and full-display recordings remain local. The Navigation map stays open. This checkpoint does not establish whole-app layout/accessibility completeness, physical behavior, iCloud/account-bound storage or signed Agent Control acceptance.

## Actual narrow-pane follow-up, 23 October 2026

The [pane-width compatibility checkpoint](prototypes/native-list-toolbar-compatibility.md#final-local-checkpoint) extends native More to a narrow List pane even when the device size class is regular. It reproduces hidden Add, then qualifies direct Filters/Add, actual secondary controls and representative production drag/relaunch state on phone/tablet. Mac compilation passes. The retained default-velocity drag failure remains a stability finding; actual Mac UI and final visual acceptance remain open.
