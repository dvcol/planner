# Native Calendar local-clock alignment

## Context and goal

Before: Day/Week positions and hour rows use elapsed time since midnight. New York's 25-hour Sunday puts equal local clock times on different rows across days, and two 01:30 appointments appear one hour apart. The human accepted Q83 A on 15 October 2026.

After: every day uses the same 24-hour civil-clock scale. Equal local times align; repeated times retain separate collision lanes and explicit timezone captions. A span covers its local-clock bounds, including each side of a backward change. A forward change preserves its actual end, and a clipped next-midnight end reaches 24:00. This drawing describes clock positions, not elapsed duration. Saved instants, planning zones, Schedule/source identities and all-day dates are unchanged.

## Definition of ready

The [accepted Q83 rules](../calendar-time-grid-alignment-question.md) govern this slice. Q81/Q82 continue to govern date-window matching. Reuse production views in the approved separate fixture host, seed actual saved Schedules through public Core commands and test at the established native UI seam. No new public interface, persistence field or test-only production parameter is needed.

## Required TDD and definition of done

- Reproduce repeated-time misalignment and a forward-span height mismatch before changing their production behavior.
- Qualify Day/Week alignment with ordinary days, forward/backward changes, half-hour changes, exact transition endpoints, midnight clipping and start-only entries.
- Preserve distinct repeated-hour identities, readable painted timezone captions and selected source Schedule details. Keep the final 23:59 card scrollable into view.
- Inspect original phone/tablet captures, pass affected strict lint and compile the shared Mac implementation. Retain separate Mac runtime, broad accessibility/adaptive, scale, physical-device and whole-app polish gates.

## Native qualification

Three native tracers reproduce production errors. The two 01:30 cards first differ by 90 vertical points. A spring 01:00-to-04:00 card is 180 rather than 270 points high. Review then finds the exact 01:00 EST-to-03:00 EDT transition endpoint drawn at 02:00; its new native case fails at 90 rather than 180 points. Each correction passes its affected tracer or follow-up. The same endpoint correction preserves 24:00 for Nuuk's transition at the end of 28 March 2026.

The fixture covers New York's short/long days, Lord Howe's half-hour changes, an incoming overnight segment and the Nuuk midnight boundary. Existing journeys retain Day/Week/Month descriptions, repeated Schedule identities, source-row planning zones, native Vision assertions for painted EDT/EST endpoints and the complete late-night card.

Each initial eight-function run has seven passes and one failed new assertion. Apple uses a narrow space before AM; the assertion is corrected to normalize whitespace without changing product formatting. The autumn journey then passes on each simulator. Phone additionally reruns the half-hour/overnight/midnight function after its viewport assertions are strengthened. An initial iPad spring Week screenshot shows later hours despite XCTest reporting the appointment hittable. The spring journey gains explicit visible-frame checks and is rerun on both devices. These are test corrections, not additional product red/green claims.

The stronger spring journey passes once on each simulator, with zero failures or skips, and both original recaptures show the actual appointments on aligned rows. Across the separate recorded runs, all eight unique temporal functions have a successful execution on each device. No final eight-function green bundle is claimed. The final iOS fixture/test products and shared Mac fixture/test host compile; affected strict Swift and Markdown lint pass. Standards and Spec reviews found no remaining source correctness issue after the two endpoint findings were resolved.

## Evidence and remaining gates

The [execution record](evidence/navigation/native-clock-alignment/execution.json) retains exact commands, summaries/trees, source/product hashes, source snapshots for the test revisions and original filtered PNG/TXT exports. Automatic failure videos/event traces are excluded. The initial full phone qualification was deliberately interrupted to address the endpoint review finding and is excluded from pass counts.

Core, HTTP, schema 18 and portable version 2 are unchanged; this UI slice receives no new Core/HTTP test credit. Mac compilation is separate from native Mac runtime. Other temporal variants, VoiceOver/keyboard, Dynamic Type, compact/adaptive layouts, performance, physical sync/account/Share and whole-app polish remain open. Apple Calendar export stays outside the map.
