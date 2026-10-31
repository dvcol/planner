# Native booked spans across clock changes

## Context and goal

Before: the native Calendar formats booked spans with DateIntervalFormatter without timezone names. A saved New York appointment from 05:30 to 06:30 UTC on 1 November 2026 has endpoints 01:30 EDT and 01:30 EST. The existing formatter shows one 01:30 value, concealing the end and the one-hour elapsed span. Even a timezone template collapses those equal local clock values to the first endpoint in the inspected native Foundation runtime.

After: Calendar and the source Schedule row describe both endpoints with native timezone names when a span crosses an offset change or either endpoint falls on a clock-change day. Compact grid previews retain readable times; full agenda and accessibility descriptions retain dates. Ordinary intervals continue using the native interval formatter. Saved instants, source/Schedule identities and planning zones remain unchanged.

## Definition of ready

Q60/Q61 require native Day/Week/Month, Q9 defines the display timezone, and Q81/Q82 define saved forms and window matching. The established native UI and public Core commands remain the approved /tdd boundaries. Reuse the existing separate fixture app and native zone/date controls. No new test-only production parameter, dependency, schema or public command is required.

[Q83 hour alignment](../calendar-time-grid-alignment-question.md) remains pending. This step changes descriptions only and leaves elapsed-time placement intact.

## Required TDD and definition of done

- Seed the literal saved start/end through public Core commands. Reproduce the ambiguous description through the native UI before changing production formatting.
- Show both EDT and EST in the booked span's full descriptions across Day, Week and Month, preserving its Schedule identity.
- Open the selected source's Schedule row and preserve both endpoint names and the original planning timezone.
- Inspect original grid and agenda captures for readable compact endpoints. Keep start-only and late-point regressions qualified.
- Qualify a ten-minute repeated-hour span, whose 44-point minimum can otherwise clip the new caption. Read visible endpoint text from the original native screenshot at the appointment's frame, rather than accepting a complete accessibility value as proof that it is painted.
- Compile affected native products, pass strict Swift and Markdown lint, and review source and evidence. Preserve the broader temporal, accessibility/adaptive, Mac runtime and physical-device gates.

## Qualification

Three separate native tracers establish red/green. The Calendar span first failed because its full description contained neither endpoint's timezone name. After explicit endpoint formatting passed, opening the retained source Schedule reproduced the same collapse there; the source row now reuses that formatter in its original planning zone. Review then identified the 44-point short-card limit. The ten-minute fixture reproduced painted text `1:55 AM EDT - 1:0...`, hiding EST despite a complete accessibility value. All timed cards now share the existing scaled 80-point minimum and matching scrollable footer.

The short-card assertion reads the original screenshot within the appointment's visible frame using Apple's native [Vision text recognition](https://developer.apple.com/documentation/vision/vnrecognizetextrequest). It asserts independent EDT/EST literals from the saved fixture. The original screenshots are retained without editing. The standalone Foundation probe compares the existing formatter and timezone templates; it is API investigation, not native UI qualification.

Four fixture functions pass on both simulators, with no failures or skips: booked Day/Week/Month and source descriptions, painted short-span endpoints, independent repeated-hour appointments, and the complete 23:59 card. Inspection found that the first phone Month capture's caption sat under the floating native tab bar. A test-only visibility check now scrolls until the complete agenda row clears a bottom tab bar. The booked journey then passed again on each device, with readable full captions in the retained captures. Production source was unchanged by that stricter check; the other three functions were unchanged between runs. The phone check preceded an added existence guard for layouts without a tab bar; the tablet check includes it.

One existing ordinary Schedule edit function also passes on iPad, covering Cancel, clearing the end, identity preservation and relaunch. The affected native app/fixture/test products and Mac app/UI-test host compile. Five changed Swift files pass strict lint, and the report/decision register pass Markdown lint. Whitespace checks and both source review axes are clear. Core and HTTP code are unchanged; no new Core/HTTP invocations are attributed to this UI step.

Execution evidence records exact commands, raw summaries/trees, compressed logs, source/product hashes, the three red failures, Vision's recognized text and original captures. New booked/short-span, source and late-card captures were inspected individually at original resolution. The earlier repeated-hour qualification remains in [its report](native-calendar-repeated-times.md).

The subsequent [start-only source-row slice](native-source-clock-change-points.md) distinguishes its repeated-hour descriptions with its own red/green evidence.

## Remaining gates

Q83 alignment remains pending. Other transitions, half-hour changes, overnight spans, Dynamic Type, VoiceOver/keyboard, compact/adaptive layouts and Mac runtime retain separate qualification. Physical sync/account/Share and whole-app polish remain open. This step does not change saved scheduling semantics or complete those gates. Apple Calendar export stays outside the map.
