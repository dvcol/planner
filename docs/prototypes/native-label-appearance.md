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

The same complete journey and three editor cases pass on dark-mode iPad: **4 tests, 0 failures and 0 skipped**. Both iPad exports also match their full expected graphs exactly. The original simulator appearance is restored after testing. Phone and dark iPad packets retain actual commands, original captures, result summaries, delivered JSON and comparison recipes. Original light/dark captures were visually inspected.

## Failures and corrections

The first symbol test reaches the missing control in the original editor and fails before implementation; its green journey then passes. Early color attempts used the shared button-only query and then tapped a compound Toggle row instead of its actual inner native switch. Their original failures remain failed. The corrected switch test also fails against the committed pre-feature editor, then passes against the implementation. Production Toggle behavior was not changed to accommodate the locator.

The first complete-graph fixture included unsupported content-origin keys for color/icon fields. Native import correctly rejected it with This backup property is not supported. The rejected bytes and actual failed capture are retained. The corrected fixture keeps the existing name-only origin contract; no import implementation changed.

System-panel probes retain their original failed label/target assumptions separately from editor/data qualifications. A ColorPicker's visible well opens the native panel; the current SDK's labels differ from earlier assumed wording. The final system-picker journey passes. It enters 4080C0 through the actual native Sliders panel, saves, edits the saved color to 204060, saves again and verifies native RGB values 32, 64 and 96 after relaunch. Its original panel capture was visually inspected. Failed probes retain their original outcomes.

## Affected checks

The four affected shared-label Intent suites pass **34 tests with 0 failures and 0 skipped** against real disposable storage. All 37 marked datasets were removed only after the host and SQLite handles closed. Mac app/UI-test and unsigned device compilation pass. The final phone native run supplies Simulator compilation and runtime evidence. Reconciliation verifies identical production/configuration inputs across those epochs and both complete-graph mobile journeys; only later UI-test sources differ. All 81 action contracts, entities, queries, enums and four App Shortcuts remain unchanged on all platforms. Affected strict Swift lint, Markdown lint and whitespace checks pass. These checks do not credit actual Mac UI interaction or signed device execution.

## Remaining acceptance

The initial native editor and file results did not establish actual Mac interaction. The follow-up below supplies the represented Mac name/icon/optional-color journeys. Installed physical-device behavior, CloudKit/account transitions and signed/shared storage remain open. Whole-app UI polish remains its own map work after features. No prototype issue is closed by this slice.

## Mac driver and execution follow-up, 21 October 2026

The first three actual Mac journeys fail at native lookups, with their original results and hierarchies retained. The Category navigation rows are native Buttons, not separate StaticText elements. The optional-color Toggle is a native Switch, not a CheckBox.

Only the UI-test driver changes. A saved-Category query uses the existing public identifier prefix and accessible name/value, including negative Cancel checks. Mac color activation selects the observed Switch. Production rendering, commands, validation, persistence and color conversion are unchanged. The test boundary remains the approved real native UI.

The corrected Mac invocation passes all three cases with zero failures/skips: optional color in 45.450 seconds, name creation/rename in 40.919 seconds, and independent icon edits in 41.530 seconds. Each covers explicit Save/Cancel and relaunch. All six original dark Mac captures were inspected, including the native ColorPicker well, cleared-color editor and saved Museum/Dining choices.

The phone regression invocation passes all four Category cases. The tablet invocation passes name, icon and optional-color cases, then fails the RGB case when looking for a Close button. Its original capture shows a normal native color popover with no Close button, with the entered 4080C0 visible in its controls.

The driver now uses Close for the phone sheet or the scoped native PopoverDismissRegion for the tablet popover, then requires the picker to disappear. No coordinate-dismissal workaround or production change is added. The focused tablet RGB journey passes in 82.263 seconds; the affected phone sheet regression passes in 72.408 seconds. Both enter 4080C0, save, change to 204060, save and relaunch, then read RGB 32/64/96 through the native picker. Their final original readback captures were inspected.

The eleven distinct represented Category cases now have passing results across Mac, phone and tablet. The earlier tablet invocation remains failed; its three passing sibling cases have unchanged test bodies and saved-row logic. Final RGB results use the corrected helper, and the Mac helper is unaffected by the iOS-only dismissal change. The validation packet records these exact source differences and production/configuration equality, rather than claiming one eleven-case invocation.

At this checkpoint, the Mac cases did not enter an RGB value through the Mac system Color panel or execute the complete Mac file-import/export journey. The follow-up below supplies the RGB-panel evidence. Earlier complete-graph and adapter results retain their own recorded epochs. Physical, signed/shared storage and whole-app acceptance remain separate.

## Mac RGB-panel follow-up, 21 October 2026

The remaining local gap was actual color input through Apple's Mac panel, rather than merely enabling the optional ColorPicker. The existing native UI journey now runs on Mac as well as mobile. It opens Color Sliders, selects RGB Sliders, types into the system hexadecimal field and closes the owned Colors window before saving. After a second edit and app relaunch, it reads the panel's native Red, Green and Blue fields. No AppKit color setter, production test hook, new target or storage-side observation substitutes for that interaction.

The Mac RGB journey passes in 64.568 seconds with zero failures/skips. It enters 4080C0, saves, changes the same Category to 204060, saves again and verifies 32/64/96 after relaunch. Its original readback capture was inspected. Production color conversion, persistence and commands are unchanged; this adds platform execution to the approved UI boundary.

The shared driver retains the phone's native sheet and tablet's popover dismissal. The affected phone regression passes in 73.221 seconds and the tablet regression in 82.003 seconds, both with zero failures/skips. Both original readback captures were inspected and show 32/64/96 and hexadecimal 204060.

The final Mac driver restricts hierarchy attachments to the owned Colors panel. Two earlier broad hierarchy attachments remain local, with their exclusion and original hashes recorded; their original owned-panel images remain retained. The final owned-panel run passes in 64.718 seconds early on 22 October, again with zero failures/skips. Production/configuration inputs match across these runs. The exact test-only diagnostic delta distinguishes the final Mac capture scope and failed-lookup message from the mobile driver; RGB input, persistence and assertions retain their executed behavior. Strict affected Swift/Markdown lint and whitespace checks pass.

The exploratory panel inspections establish native control names only and receive no saved-data acceptance credit. At this RGB checkpoint, Mac file-import/export, physical devices, signed/shared storage and final whole-app review remain open. The file follow-up below supplies later local evidence.

## Mac file follow-up, 22 October 2026

Before this follow-up, native Mac label editing and RGB input were qualified while actual Mac file import/export remained open. This follow-up uses the existing native backup journey and literal seven-source fixture. It imports through the real Open panel, renames both labels, exports, cancels an attempted appearance reset, explicitly clears only the Category, exports again and relaunches. The original shared Item must display both live renamed labels.

The existing approved native UI and delivered-file boundaries are ready for this work. The same case now compiles for Mac, with panel-scoped confirmation controls, native path entry, Mac Switch access and ordinary Settings-window closure. Mobile retains its native document picker and nested Switch. No production source, schema, public command, target, package or test-only production parameter changes.

Completion requires the full native journey, both Cancel regressions, two actual delivered backups matching the complete expected graphs, affected mobile regressions, scoped capture inspection and narrow compiler/lint checks. Renaming alone must preserve exact custom symbols and every Double color component including alpha. Cancel must save nothing; explicit clearing must affect only the chosen Category. Saved identities, relationships, local completion, order and other content remain exact.

The final Mac invocation passes all three cases with zero failures/skips: export Cancel in 26.593 seconds, import Cancel in 15.689 seconds, and label appearance/file/relaunch in 104.928 seconds. Both actual delivered files exactly match the expected complete graphs under the established typed verifier. It distinguishes booleans from numbers, compares colors as exact binary rationals and checks every record collection, identity, lifetime, rank, completion, history and owned value. The only expected edit changes are the declared label names, validated edit timestamps and the later explicit Category color/icon clear.

The version-1 fixture exports through the existing version-2 format, adding null manualEstimate to Lists/Itineraries. This is the established format migration, with no invented budget. Both original delivered files and their hashes are retained. Four final original dark Mac captures were inspected: returned Settings after Cancel, custom Category appearance after rename, retained custom Tag appearance after Category clearing/relaunch, and the original Item's live label names.

The iteration record retains earlier failed drivers and separately identified passing invocations. Earlier driver attempts remain failed. The first assumes a combo box for Go to Folder and fails in 14.149 seconds; the observed control is PathTextField. The next looks for Save and fails in 44.879 seconds; the native panel's OKButton is titled Export. A later global Open query matches an extra control and fails in 16.251 seconds; confirmation is now scoped to the open-panel. The first Cancel invocation passes export Cancel but fails import Cancel in 17.625 seconds because its mobile label predicate does not identify the Mac button. Final confirmation/cancellation use the observed panel identifiers. Broad automatic diagnostics and remembered file-location values remain private; retained panel observations contain identifiers and state only.

The final light-phone regression passes in 113.991 seconds, and the final dark-iPad regression passes in 135.097 seconds, each with zero failures/skips. All four actual mobile exports match the complete expected graphs under the same verifier. Six final mobile captures were inspected. The final shared-Item check requires both live labels to be hittable and within the window; the phone scrolls them above its floating tab bar and checks their frames against that bar. This replaces a weaker capture where the Tag was partly obscured.

An initial phone port incorrectly used the button-oriented helper for the additions count and fails in 50.960 seconds. The original mobile StaticText lookup is restored, while Mac keeps its all-type query and value assertion. Earlier corrected-phone/dark-tablet runs pass before the stronger visibility checks, with their actual outcomes preserved. No failed invocation receives passing credit.

The five final executions of three distinct cases pass across all three platforms. Their 1,061 frozen inputs reconcile with the current workspace, including the final Mac build and both mobile epochs. Affected strict Swift/Markdown lint and whitespace checks pass. The validation packet retains exact source and original-attachment verification. Production interfaces, persistence and rendering remain unchanged. Broader Mac import-conflict/restoration, signed/shared storage, physical devices and whole-app polish retain separate gates; Q127 is still pending for Calendar.
