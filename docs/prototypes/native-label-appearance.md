# Native label appearance

## Context, starting state and goal

Q121 A approves a small native symbol picker and optional color editing for Categories and Tags. Before this slice, Manage Labels created and edited names, and referenced-label details used fixed kind icons. Core already stored optional sRGB color and symbol names.

The grouped editor now offers a native ColorPicker and a named symbol menu with Default. Existing symbols outside the small set appear as Current icon and survive untouched saves. Color is explicitly enabled or removed. Save applies the shared label edit; Cancel discards the draft. Icon-only and color-only edits enable Save. Referenced-label details use the current shared symbol and color, while names keep their semantic text styling.

The store submits only changed name/color/icon fields with existing field hashes. A name-only Save retains the original PlannerColor Double values directly. A changed native color is converted to sRGB, checked for finite components within range and saved through normal Core validation. There is no Float-based resolution or manual clamping of stored components.

## Definition of ready and boundaries

The [appearance review](../native-label-appearance-review.md) and Q121 A precede implementation. This slice uses the existing native UI, Core data and actual delivered-backup boundaries. No private color-helper tests, new test target, test-only dependency, symbol library, Core/MCP schema or backup format is introduced.

## Native and delivered-data evidence

The native symbol journey verifies staged creation, Cancel, Save, an independent icon-only edit and persistence after relaunch. The optional-color journey verifies staged creation, Cancel, Save, cancelled removal and explicit removal after relaunch. Existing Category creation/rename remains a regression.

A [deterministic complete backup](../fixtures/native-label-appearance-backup.json) adds custom Category/Tag symbols and color components requiring more precision than Float to the established seven-source graph. The native file journey imports it, renames both labels without touching their appearance, exports, cancels an attempted appearance reset, explicitly clears only the Category, exports again and relaunches. Shared Item details retain both live label names.

Both actual iPhone exports match every expected record and field. Binary-rational comparison establishes exact preservation of all original color components and custom symbols on name-only Save. The second export clears only the Category's appearance. Tag appearance, owner content/timestamps, stable IDs/lifetimes, memberships, scoped completion, order, schedules, labels, links and deletion/history records remain exact. The only representation migration is version 1 to 2 with null manualEstimate for Lists/Itineraries; expected edit timestamps are validated against the actual journey/delivery interval.

The same complete journey and three editor cases pass on dark-mode iPad: **4 tests, 0 failures and 0 skipped**. Both iPad exports also match their full expected graphs exactly. The original simulator appearance is restored after testing. [Phone](evidence/navigation/native-itinerary-window-compatibility/native-label-appearance-phone-valid/) and [dark iPad](evidence/navigation/native-itinerary-window-compatibility/native-label-appearance-tablet-dark/) packets retain actual commands, original captures, result summaries, delivered JSON and comparison recipes. Original light/dark captures were visually inspected.

## Failures and corrections

The first symbol test reaches the missing control in the original editor and fails before implementation; its green journey then passes. Early color attempts used the shared button-only query and then tapped a compound Toggle row instead of its actual inner native switch. Their original failures remain failed. The corrected switch test also fails against the committed pre-feature editor, then passes against the implementation. Production Toggle behavior was not changed to accommodate the locator.

The first complete-graph fixture included unsupported content-origin keys for color/icon fields. Native import correctly rejected it with This backup property is not supported. The rejected bytes and actual failed capture are retained. The corrected fixture keeps the existing name-only origin contract; no import implementation changed.

System-panel probes retain their original failed label/target assumptions separately from editor/data qualifications. A ColorPicker's visible well opens the native panel; the current SDK's labels differ from earlier assumed wording. The final [system-picker journey](evidence/navigation/native-itinerary-window-compatibility/native-label-system-picker-rgb/) passes. It enters 4080C0 through the actual native Sliders panel, saves, edits the saved color to 204060, saves again and verifies native RGB values 32, 64 and 96 after relaunch. Its original panel capture was visually inspected. Failed probes retain their original outcomes.

## Affected checks

The four affected shared-label Intent suites pass **34 tests with 0 failures and 0 skipped** against real disposable storage. All 37 marked datasets were removed only after the host and SQLite handles closed. Mac app/UI-test and unsigned device compilation pass. The final phone native run supplies Simulator compilation and runtime evidence. Reconciliation verifies identical production/configuration inputs across those epochs and both complete-graph mobile journeys; only later UI-test sources differ. All 81 action contracts, entities, queries, enums and four App Shortcuts remain unchanged on all platforms. Affected strict Swift lint, Markdown lint and whitespace checks pass. These checks do not credit actual Mac UI interaction or signed device execution.

## Remaining acceptance

Native editor and file results do not establish actual Mac interaction, installed physical-device behavior, CloudKit/account transitions or signed/shared storage. Whole-app UI polish remains its own map work after features. No prototype issue is closed by this slice.
