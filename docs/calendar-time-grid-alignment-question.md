# Calendar hour alignment decision

Status: the human accepted Q83 A on 15 October 2026. Day/Week must align local clock times. Implementation and native qualification remain open.

## Context and goal

The repeated-hour native fixture stores two start-only Schedules at 05:30 and 06:30 UTC on 1 November 2026, both displayed as 01:30 in New York. Native timezone names now distinguish EDT from EST. Each Schedule retains its own identity and instant.

The Week screenshots also expose the current elapsed-time layout. Sunday has 25 hours and Monday has 24, so Sunday's 02:00 line appears beside Monday's 03:00 line. The end state needs a deliberate, readable way to compare appointments during clock changes while preserving every saved instant, endpoint and Schedule identity.

## Question and impacts

A. Align Day/Week by local clock time. Every 02:00 lines up with 02:00. Repeated 01:30 appointments appear in separate lanes with EDT/EST labels. This aids comparison; spans crossing the clock change need careful rendering of their actual endpoints and elapsed duration.

B. Keep repeated hours as separate rows and align Week through a common row set. Other days have a blank space at the extra row. A skipped hour leaves a gap on its affected day. This preserves chronological placement and aligns later hours, but adds visible gaps on ordinary days.

C. Retain elapsed-time columns. Repeated appointments remain vertically separated and each day shows its actual length. This requires less work, but equal clock times do not align across the week after a change.

Accepted: A. Repeated clock times use separate lanes with explicit timezone names. Saved instants, planning zones, Schedule identities and all-day dates stay unchanged.

## Definition of ready

Q83 A is accepted. Use the same midnight-to-midnight civil-clock scale for every day. Skipped clock times do not shift later appointments; repeated times share their clock position and use separate collision lanes. Clip spans to the displayed day, and use their covered local-clock range when a backward transition reverses the displayed endpoints. Retain both actual endpoints and timezone names in the caption and accessibility description. Apply the actual offset change, including half-hour transitions, without assuming every change is one hour. An end at the next midnight reaches the bottom of the day. Keep the final start-only card scrollable in full. Core date-window matching and saved Schedule forms remain governed by Q81/Q82; this question does not approve a scheduling-data change.

## Required TDD and definition of done

At the approved native UI seam, seed actual saved Schedules through public Core commands. Verify distinct repeated-hour identities, short/long days, a half-hour change, ordinary-day comparison, start-only entries, spans crossing a change and the last selectable appointment. Keep full descriptions available to accessibility, readable compact previews, adequate hit targets and correct selected-entry details.

Inspect original Day/Week captures on phone and tablet; compile the shared Mac implementation and retain its separate native runtime gate. Verify that switching views and display zones does not edit source forms. Pass affected lint/type checks and targeted regressions. Keep Core window, physical sync/account, broad accessibility/adaptive and whole-app polish gates open until their own evidence exists.
