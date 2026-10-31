# Native start-only source descriptions

## Context and goal

Calendar now distinguishes the two New York 01:30 appointments on 1 November 2026, but the source Schedule rows still use an abbreviated date/time without the endpoint's timezone name. Two saved instants can therefore have identical source descriptions despite retaining distinct Schedule identities.

The end state adds the native specific timezone name on a planning-calendar day whose clock offset changes. Source rows retain their original planning timezone identifier and start-only label. No end is supplied, no saved instant changes, and no Calendar placement policy is selected.

## Definition of ready

The shared Item/Itinerary Schedule row and existing public Core/native UI test seams are approved. Reuse the existing literal repeated-hour fixture and native controls. The existing clock-change helper and Foundation format symbol already have their qualified Calendar uses. No new provider, production test parameter, dependency, schema or public command is needed. Q83 remains pending.

## Required TDD and definition of done

- Extend the repeated-hour native journey to open the source after Day/Week/Month and verify both retained Schedule identities.
- Reproduce missing EDT/EST in the source rows before changing production formatting.
- Verify both timezone names, the original planning-zone identifiers and start-only presentation in the source rows on phone and tablet.
- Preserve ordinary source descriptions and booked-span behavior. Compile the affected native targets, pass strict Swift/Markdown lint and review source/evidence.
- Retain original screenshots and exact execution results. Preserve the separate Q83, broader temporal, accessibility/adaptive, Mac runtime and physical-device gates.

## Qualification

The extended native journey first failed at the missing EDT source description, after both source Schedule identities matched the Calendar identities. Its original source capture shows two identical 01:30 descriptions. The production row now adds Foundation's native specific timezone name on a clock-change day in its original planning calendar.

Two selected fixture functions pass on both iPhone and iPad simulators, with no failures or skips. They cover distinct repeated-hour appointments through Day/Week/Month and their source rows, plus the existing booked-span endpoint descriptions. The source rows retain both Schedule identities, Start only labels and America/New_York suffixes. Both new source captures were inspected individually at original resolution and show readable EDT/EST captions.

One ordinary start-only Schedule edit journey also passes on iPad, covering Cancel, saving with no end and relaunch. The affected iOS products and Mac app/UI-test host compile; zero Mac runtime functions ran. The two changed Swift files pass strict lint. The affected reports and decision register pass Markdown lint, and whitespace checks pass. Core/HTTP code is unchanged, with zero new Core/HTTP invocations attributed to this step.

Execution evidence retains exact commands, raw summaries/trees, compressed logs, original fixture captures and source/product hashes. Final phone/tablet fixture runs use the same frozen source and products. The earlier booked-span and painted short-card qualification remains in [its report](native-calendar-booked-clock-change.md).

## Remaining gates

Q83 alignment remains unanswered. Other transitions, half-hour changes, overnight spans, Dynamic Type, VoiceOver/keyboard, adaptive layouts and Mac runtime retain separate qualification. Physical sync/account/Share and whole-app polish remain open. This formatting fix does not complete those gates or change saved scheduling semantics.
