# Compact List toolbar review

Status: Q113 is pending. The ineffective priority trial is reverted. No new toolbar workflow is accepted or implemented yet.

## Context and observed state

The existing native content header shows the full List name. On the 402-point phone, Filters, Sort, Edit, Add and List actions occupy the navigation bar; its inline title is absent. The approved native UI boundary records the real UIKit hierarchy. The initial inline-title probe fails in 16.999 seconds. Lowering Sort, Edit and List-action visibility priorities compiles, but the same probe still fails in 16.429 seconds. The retained screenshot shows the current layout. This trial is not a UI fix.

The installed iOS 27 SDK provides ToolbarOverflowMenu for explicitly placing content in the native overflow menu. It is unavailable on Mac. The existing List Add menu and cumulative filters are already accepted; the remaining decision concerns compact presentation.

## Q113 choices and impact

A. Native More on compact layouts. Keep Filters and Add visible; place Sort, Edit and List actions in the system overflow menu. Wide iPad and Mac keep direct controls. This reserves title space, but those secondary actions take another tap. I recommend this for a less crowded bar.

B. Retain the full name in the content header and keep every action directly visible. Accept that the inline title can disappear. This preserves the current workflow.

C. Use the native large scrolling navigation title instead of the duplicate content-heading title. The full name is available at the top; after scrolling, the inline title can still disappear among the five actions. Progress and estimates remain below it.

## Readiness and completion

Choose the intended compact presentation before implementing it or turning the diagnostic inline-title expectation into a product requirement. The native UI test boundary remains the existing one. No Core contract, package or persistence change is needed.

Qualify the chosen title/header, native action reachability and Add/Cancel. If actions move to overflow, also qualify Sort and Edit/Done through that actual menu, then the existing filtered Manual drag journey. Check phone and tablet, appearance/contrast and resizing as appropriate; retain the source identities, selection, progress and saved order. Mac's ordinary toolbar remains independently qualified. Final whole-app polish still follows feature completion.

Evidence is retained in `docs/prototypes/evidence/navigation/native-itinerary-window-compatibility/phone-list-title-native-measurement-red` and `phone-list-title-native-priority`. Their failures describe the observed layout, not an accepted requirement or completed fix.

The [diagnostic source](prototypes/experiments/ListToolbarTitleProbe.swift) is retained outside default test targets until the intended presentation is accepted.
