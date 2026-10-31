# Native Capture estimate shortcuts

Status: the corrected-source journey passes on both simulators. Mac compilation passes; Mac runtime, Q94 label presentation and signing remain open.

## Context and starting state

The shared native estimate editor already provides the accepted fixed Half-day, Full-day and Weekend shortcuts in Capture. Item, List and Itinerary results do not qualify this caller. The existing reviewed Capture journey checks cancellation, one Inbox Item, notes and its original bookmark through relaunch, but does not select the shortcuts.

## Goal and expected end state

Stage Half-day as 12 Hours and Cancel without creating an Item. Open a fresh Capture and select Full-day as 1 Day, then Weekend as 2 Days. Add one reviewed Item with notes and the original URL. Its exact saved estimate is 2,880 minutes. Relaunch preserves that estimate, the two-day representation and bookmark identity, with exactly one Inbox Item and no canceled Item. The shortcut does not create a Schedule.

## Definition of ready

Accepted duration conversions and the approved production native UI boundary define literal outcomes. Use the existing disposable dataset, actual Capture review/Add/Cancel, saved Item details, Item editor and relaunch. No internal persistence reads, mock navigation, schema, command or HTTP change is needed. This qualifies existing behavior and does not claim a missing-feature red. Q94 is unrelated to these controls.

## Required tests and definition of done

- Extend the existing reviewed Capture journey at its native UI boundary, retaining original URL, notes, canceled-Item absence and one-Item checks.
- Select each named shortcut through its actual Menu and verify literal quantity/unit values.
- Verify exact saved minutes before and after relaunch, retained bookmark identity and two-day representation on reopening the Item editor. Cancel inspection without editing.
- Verify no Schedule is created. Build affected app/UI targets on both platforms, run the focused journey on both simulators, inspect named own-window captures and run affected Swift/report lint.

Core and HTTP behavior remain unchanged and receive no new qualification. Native compiler results supply no Mac runtime credit. Capture Share, physical devices, accounts, CloudKit, signing, accessibility, performance and whole-app native polish remain separate gates. Earlier packets retain their own source epochs.

## Controller correction

The initial phone invocation fails in 59.215 seconds at the first exact ungrouped saved-minute comparison. Review identified that this rejects native grouping separators already observed in the earlier Item shortcut journey. Only the three saved-minute assertions change: they require a full match of the literal 2,880-minute value with an optional whitespace/comma separator. The original failed source, build and result remain separate; they receive no corrected-source pass credit. No product behavior changes.

Both corrected affected app/UI compiler targets pass. Source reviewers report no remaining Standards/controller or Spec/oracle finding; runtime credit comes only from the completed invocations below.

## Recorded results

| Boundary | Result | Scope |
| --- | --- | --- |
| iPhone corrected native journey | Pass, 75.044 seconds | One function, zero failures or skips. |
| iPad corrected native journey | Pass, 72.908 seconds | The same function and outcomes, zero failures or skips. |
| Corrected iOS Simulator app/UI compiler | Pass | Affected app and focused UI target. |
| Corrected Mac app/UI compiler | Pass | Compilation only, no new Mac runtime invocation. |

Each completed native journey selects Half-day, Full-day and Weekend through the actual native Menu. Half-day is canceled without a saved Item. Add persists Weekend as exactly 2,880 minutes. Relaunch retains one Inbox Item, notes, original URL and bookmark identity; the saved Item editor shows two Days and Cancel preserves the value. No Schedule is created.

Both named original own-window captures were inspected individually. They show the saved two-day duration, notes and original-link presentation in native grouped details. The link preview fallback is visible; these journeys do not require or qualify a live preview service. The iPad shows the Item catalog and details side by side.

The final builds each record 945 compiler inputs and six products. Each native invocation freezes 469 source/configuration inputs and those six products. The audit compares them with current source and build outputs before commit. The initial failed source/result stays separate and receives no corrected-source pass credit. Unit and HTTP behavior did not change, so no unit or HTTP suite is rerun or credited by this slice. Affected Swift/report lint and source reviews pass.

## Evidence and remaining gates

The evidence packet retains literal exits, compressed logs, source/product hashes, original named captures and the bounded audit. [Itinerary qualification](native-itinerary-estimate-shortcuts.md) links the earlier rich-draft resizing, Item and List results, each with its own source epoch. The extended Capture test replaces the earlier test name; earlier passing packets remain historical evidence of their original test source.

Q94 label navigation is the next pending presentation choice. Whole-app polish follows feature completion. Mac UI automation remains unqualified for this slice, and compiler success does not replace it. Signing, physical devices, account transitions, CloudKit convergence, Share, accessibility, large-catalog retention/memory, scrolling hitches and physical latency remain open. No issue or whole-map gate is closed by these checks.
