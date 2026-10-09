# Native row contract review

Follow-on review for [Navigation prototype](https://github.com/dvcol/planner/issues/14). Q38 A, Q39 B, Q40 A, Q41 A and Q42 A are accepted in the [navigation review](navigation-prototype-review.md#accepted-row-decisions-and-their-consequences). Q43-Q46 below are proposals, not accepted answers or executable code.

## Context, starting state and goal

Rows need compact owned location, contextual dates, activity estimates, a completion control and an optional link image. The accepted RowRead declaration currently carries only location/link presence. It cannot supply the address, chosen link or Schedule form needed for this presentation. The actual Core package currently supports Item source reads and a limited Item-only query; the full graph, contextual rows and organization/completion/Schedule commands remain unimplemented declarations.

The goal is to settle the remaining row contract and interaction cases before their /tdd slices. The expected end is an accepted lightweight read shape, observable row completion behavior under global precedence, deterministic date selection and one preview-link selection rule. It does not establish saved row mutations or provider availability.

## Proposed public row-read amendment

Q43 A would extend the existing public query/row-window read boundary rather than introduce a second UI-only service. Keep current RowRead fields and add these read-only values:

| Added value | Proposed meaning |
| --- | --- |
| `ownedLocation: PlannerOwnedLocation?` | Existing independently supplied name/address/coordinate value. No geocoded candidate or fetched provider description. |
| `previewLink: PlannerOwnedLinkRead?` | At most one selected owned link with its stable identity, exact original URL and retained classification/reference. No fetched image/title or complete link collection. Selection follows Q46. |
| `scheduleSummary: PlannerRowScheduleSummary` | `none`, `directItem`, `itinerarySpan`, `inScheduledPlan` or `unresolved`. A selected direct/plan case supplies one Schedule identity, owner source, existing typed ScheduleForm and nonnegative additional Schedule count. |

ScheduleForm remains the declared timed/all-day union. Timed values retain fixed instants and planning zone; all-day values retain inclusive civil dates. Native views format those values in their accepted display zone. They never persist a display string or convert an all-day date to a saved midnight instant.

Bind the row presentation's reference instant and display timezone consistently across all windows of one query generation. A time/day/zone or relevant graph change invalidates the summary projection before refresh. No window may combine a newly selected date with identities from a stale generation. The concrete typed context and wire declaration must be updated together with the accepted adapter contract before implementation; they are read/presentation context, not editable Planner content or backup fields.

Core row reads perform no preview/geocoding request. Native provider lookup starts only under the accepted row/detail triggers. Cache results remain local and bind the current dataset, source lifetime, link/address identity and current input. Obsolete results cannot change a current row/detail or saved content. Keep full notes, links, field hashes and every Schedule in their existing detail reads rather than loading them for each row.

## Remaining question round

### Q43: How should rich rows read their data?

Current row reads expose only hasLocation/hasLinks. They cannot show Meeting point A, choose an owned preview URL or distinguish a timed appointment from an all-day plan. The proposal above returns those small, read-only values through the already accepted query/window boundary.

- A. Extend RowRead as proposed. Core supplies owned location, one preview link and a typed date summary; native views handle formatting and temporary previews. This keeps one shared data boundary and avoids full-detail reads for each row.
- B. Keep RowRead unchanged and load source details/Schedules for each visible row. Fewer contract edits, but more data loading and presentation-side joins to validate during scrolling and refresh.
- C. Add a separate native-only rich-row read. This isolates the change from adapter rows but adds another public contract to maintain and test.

Recommendation: A. Existing generation/appearance rules remain authoritative, and richer metadata uses the same lightweight read.

### Q44: What does the completion circle do when global Done wins?

Hotel is globally Done but locally Todo in Tokyo Food. It must display Done. A local uncheck cannot make it appear Todo, and Q8 allows global reopening only in the Item view. A later global Reopen must reveal the retained local state.

- A. Disable the contextual circle while global Done applies, with Completed globally help/accessibility text. The ordinary Item-view route handles global Reopen; the row never changes another scope. Local bulk Undone remains permitted under Q8.
- B. Make the control show and edit the retained local flag, beside a separate effective Done indicator. Local edits remain available, but every affected row needs two distinguishable states.
- C. Keep the circle active; clearing local state leaves it visually Done and explains why. Fewer controls, but a click may produce no visible completion change.

Recommendation: A. One truthful indicator, with independent local flags preserved and no global action in a container.

### Q45: Which date wins when a Schedule is ongoing or several exist?

At 10:30 Tokyo, Hotel has today's 10:00-11:00 appointment and another at 14:00. An itinerary may also have separate 9-11 and 16-18 October spans. Q40 selects a compact contextual date, but did not specify whether an ongoing span outranks a future one or whether separate plan spans should be combined.

- A. Show an ongoing span first, otherwise the next future start, otherwise the most recent past start. Apply this to direct appointments and this itinerary's Schedules, retaining one actual Schedule instead of merging gaps. If several are ongoing, choose the latest start. `+N` counts other retained Schedule records, including past ones; a three-day span is one record. Stable identity breaks equal-date ties.
- B. Show the next future start first, using the most recent past start only when no future Schedule exists. Use the same one-record and additional-count rules. At 10:30 this shows 14:00 while the 10:00 appointment is still running.
- C. Show the ongoing rule for direct appointments but aggregate the itinerary's earliest start/latest end. This gives one overall plan range, but can display unscheduled gaps as part of that span.

Recommendation: A. The row represents an actual current/next assignment and keeps independent plan spans visible in details.

### Q46: Which link supplies the row's thumbnail?

Nezu Museum owns a Google Maps link first and a Menu website link second. Q41 enables lazy previews, but a compact row has room for one thumbnail. Automatically trying every link increases lookup work; storing a preferred link adds user data and editing controls.

- A. Use the first non-Maps website bookmark in saved order. This row previews Menu; a Maps-only Item uses its useful link/map presentation without a website thumbnail. No image/error retains the selected link fallback without trying all remaining links. Details retain every link.
- B. Use the first owned link in saved order, including Maps. This follows order literally, but a Maps link can take the thumbnail position ahead of the Menu site, subject to its provider rules.
- C. Let each Item store a chosen preview link. This gives explicit control but adds a persisted preference, editor and backup/hash requirements.

Recommendation: A. It provides a predictable website image without adding an Item setting or fetching several sites per row.

## Definition of ready

- [x] Recover the original Q38-Q42 options and record the human's A/B/A/A/A choices without substituting recommendations.
- [x] Inspect the accepted contracts and actual Core implementation, keeping declarations distinct from runtime evidence.
- [ ] Settle Q43-Q46 and update the affected public declarations and literal fixture expectations before writing their behavior tests.
- [ ] Confirm real disposable full-graph persistence/recovery and native provider I/O test boundaries for saved mutations and lookups; a read-only fixture projection cannot acknowledge a save.

## Required /tdd and other validation

| Public level and fixed input | Action | Required output after choices are accepted |
| --- | --- | --- |
| Core row/read plus native UI; full graph membership 401 versus itinerary 452/401 | Read/render both windows at a fixed Tokyo reference time before S1 starts. | Owned Meeting point A, separate 120-minute estimate, direct S1 versus inclusive S2 plan span, correct appearance/local flags and no fetched metadata in the read. No complete notes/link/hash payload in each row. |
| Core row/read; same graph and generation | Change an owned address/link/Schedule, then request an old window. | Typed stale result or a new consistent generation, never a mixed old identity/new summary. Progress remains complete-scope and independent of filters. |
| Core/store and native completion; X globally Done, 401 locally Done and 403 locally Todo | Use Q44's accepted row affordance; then globally reopen from Item view and reopen the store/app. | Exact retained local values and effective A Done/B Todo distinction. No contextual control targets global completion. Saved acknowledgement follows actual persistence/recovery. |
| Core date summary plus native UI; Tokyo 9 October 2026 10:30, direct 10:00-11:00 and 14:00-15:00 | Read standalone row; separately read an itinerary with 9-11 and 16-18 October spans. | Literal Q45 winner, correct additional-record count, no false continuous span. Test zero, one, several, equal-date and all-day/timed inputs, and reference-time/display-zone refresh. |
| Core owned-link selection plus native provider I/O; links 751 Maps and 752 Menu | Read one preview link, realize the row/open detail, remove/change the selected link while its lookup is delayed. | Literal Q46 selection and one chosen row preview. Old callback is ignored; image/no-image/error keep useful links. Capture still makes no ordinary-page request; owned content/backup values remain unchanged. |
| Native integration and long-list review; existing 5,000-Item fixture | Traverse rows and refresh selection, inspect portrait/landscape/Mac window layouts, keyboard and accessibility. | No eager whole-collection lookup or full-detail payload per row. Record measured latency/memory and actual native screenshots. Keep the accepted physical 300 ms gate; simulator results do not replace it. |

Each executable slice uses one failing behavior test and minimum implementation through the approved public seams. Mock only real external I/O, and use real temporary stores for persistence/reopen. Document-only checks here are affected Markdown lint, internal link/diff review and matching tracker publication; no new unit/UI test pass is claimed.

## Definition of done

- [ ] Human decisions and exact public declarations/fixtures are recorded in Navigation prototype and committed source.
- [ ] Implemented slices have focused red/green, affected compilation/lint, real-store/provider-I/O and native UI evidence on the required destinations.
- [ ] Human reviews the actual row/detail interactions; remaining physical, accessibility, sync/Share and full navigation gates remain explicit before resolving the prototype.
