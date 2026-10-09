# Native row contract review

Follow-on review for [Navigation prototype](https://github.com/dvcol/planner/issues/14). Q38 A, Q39 B, Q40 A, Q41 A and Q42 A are accepted in the [navigation review](navigation-prototype-review.md#accepted-row-decisions-and-their-consequences). On 2026-10-09 the human selected A for Q43, Q44, Q45 and Q46. This packet records accepted declarations and test expectations, not executable behavior.

## Context, starting state and goal

Rows need compact owned location, contextual dates, activity estimates, a completion control and an optional link image. Before this amendment, RowRead carried only location/link presence. It could not supply the address, chosen link or Schedule form needed for this presentation. The actual Core package currently supports Item source reads and a limited Item-only query; the full graph, contextual rows and organization/completion/Schedule commands remain unimplemented declarations.

The goal is to settle the remaining row contract and interaction cases before their /tdd slices. The accepted end is a lightweight read shape, observable row completion behavior under global precedence, deterministic date selection and one preview-link selection rule. The public [Core declaration](architecture-review-packet.md#typed-commands-and-queries) and [adapter declaration](adapter-contract.md#row-presentation-context-and-schedule-summary) carry the amendment. It does not establish saved row mutations or provider availability.

## Accepted public row-read amendment

Q43 A extends the existing public query/row-window read boundary. Keep current RowRead fields and add these read-only values:

| Added value | Accepted meaning |
| --- | --- |
| `ownedLocation: PlannerOwnedLocation?` | Existing independently supplied name/address/coordinate value. No geocoded candidate or fetched provider description. |
| `previewLink: PlannerOwnedLinkRead?` | At most one selected owned link with its stable identity, exact original URL and retained classification/reference. No fetched image/title or complete link collection. Selection follows Q46. |
| `scheduleSummary: PlannerRowScheduleSummary` | `none`, `directItem`, `itinerarySpan`, `inScheduledPlan` or `unresolved`. A selected direct/plan case supplies one Schedule identity, owner source, existing typed ScheduleForm and nonnegative additional Schedule count. |

ScheduleForm remains the declared timed/all-day union. Timed values retain fixed instants and planning zone; all-day values retain inclusive civil dates. Native views format those values in their accepted display zone. They never persist a display string or convert an all-day date to a saved midnight instant.

Bind the row presentation's reference instant and display timezone consistently across all windows of one query generation using `PlannerRowPresentationContext`. The query supplies this optional context or Core captures its default once. The snapshot returns the resolved context, and row-window reads never select a new clock/zone. A time/day/zone change affecting presentation requires a new query; relevant graph changes invalidate the old generation. No window may combine a newly selected date with identities from a stale generation. The [exact native/wire declaration](adapter-contract.md#row-presentation-context-and-schedule-summary) is read/presentation context, not editable Planner content or backup data.

Core row reads perform no preview/geocoding request. Native provider lookup starts only under the accepted row/detail triggers. Cache results remain local and bind the current dataset, source lifetime, link/address identity and current input. Obsolete results cannot change a current row/detail or saved content. Keep full notes, links, field hashes and every Schedule in their existing detail reads rather than loading them for each row.

## Accepted question round and alternatives

The human answered A to each question below. The alternatives are retained to explain the tradeoffs; no answer is inferred from a recommendation.

### Q43: How should rich rows read their data?

The previous row declaration exposed only hasLocation/hasLinks. It could not show Meeting point A, choose an owned preview URL or distinguish a timed appointment from an all-day plan. The accepted amendment returns those small, read-only values through the existing query/window boundary.

- A. Extend RowRead as proposed. Core supplies owned location, one preview link and a typed date summary; native views handle formatting and temporary previews. This keeps one shared data boundary and avoids full-detail reads for each row.
- B. Keep RowRead unchanged and load source details/Schedules for each visible row. Fewer contract edits, but more data loading and presentation-side joins to validate during scrolling and refresh.
- C. Add a separate native-only rich-row read. This isolates the change from adapter rows but adds another public contract to maintain and test.

Accepted A. Existing generation/appearance rules remain authoritative, and richer metadata uses the same lightweight read.

### Q44: What does the completion circle do when global Done wins?

Hotel is globally Done but locally Todo in Tokyo Food. It must display Done. A local uncheck cannot make it appear Todo, and Q8 allows global reopening only in the Item view. A later global Reopen must reveal the retained local state.

- A. Disable the contextual circle while global Done applies, with Completed globally help/accessibility text. The ordinary Item-view route handles global Reopen; the row never changes another scope. Local bulk Undone remains permitted under Q8.
- B. Make the control show and edit the retained local flag, beside a separate effective Done indicator. Local edits remain available, but every affected row needs two distinguishable states.
- C. Keep the circle active; clearing local state leaves it visually Done and explains why. Fewer controls, but a click may produce no visible completion change.

Accepted A. One truthful indicator, with independent local flags preserved and no global action in a container. The disabled contextual control exposes Completed globally through help and accessibility text. Local bulk Undone still clears only local flags, including hidden/archived targets; global Done continues to win visibly. Global Reopen remains an Item-view action.

### Q45: Which date wins when a Schedule is ongoing or several exist?

At 10:30 Tokyo, Hotel has today's 10:00-11:00 appointment and another at 14:00. An itinerary may also have separate 9-11 and 16-18 October spans. Q40 selects a compact contextual date, but did not specify whether an ongoing span outranks a future one or whether separate plan spans should be combined.

- A. Show an ongoing span first, otherwise the next future start, otherwise the most recent past start. Apply this to direct appointments and this itinerary's Schedules, retaining one actual Schedule instead of merging gaps. If several are ongoing, choose the latest start. `+N` counts other retained Schedule records, including past ones; a three-day span is one record. Stable identity breaks equal-date ties.
- B. Show the next future start first, using the most recent past start only when no future Schedule exists. Use the same one-record and additional-count rules. At 10:30 this shows 14:00 while the 10:00 appointment is still running.
- C. Show the ongoing rule for direct appointments but aggregate the itinerary's earliest start/latest end. This gives one overall plan range, but can display unscheduled gaps as part of that span.

Accepted A. This refines Q40's next-future rule to ongoing, then next future, then latest past. The row represents one actual assignment and keeps independent plan spans visible in details. Its additional count concerns other retained Schedule records for the same summary owner, including past records, not days or all other itineraries.

### Q46: Which link supplies the row's thumbnail?

Nezu Museum owns a Google Maps link first and a Menu website link second. Q41 enables lazy previews, but a compact row has room for one thumbnail. Automatically trying every link increases lookup work; storing a preferred link adds user data and editing controls.

- A. Use the first non-Maps website bookmark in saved order. This row previews Menu; a Maps-only Item uses its useful link/map presentation without a website thumbnail. No image/error retains the selected link fallback without trying all remaining links. Details retain every link.
- B. Use the first owned link in saved order, including Maps. This follows order literally, but a Maps link can take the thumbnail position ahead of the Menu site, subject to its provider rules.
- C. Let each Item store a chosen preview link. This gives explicit control but adds a persisted preference, editor and backup/hash requirements.

Accepted A. It provides a predictable website image without adding an Item setting or fetching several sites per row. Saved order means logical link order with the existing identity tie rule, not asynchronous lookup order. Eligible bookmarks retain their existing non-Maps web classifications; Apple Maps and Google Maps links never displace the selected website thumbnail.

## Literal before/action/after expectations

Use the existing [full graph](fixtures/portable-backup-v1.json). Abbreviations in this table identify that file's fixed UUID suffixes, not new identities: Item 101, Lists 201/202, itinerary 301, memberships 401/403, expanded appearance 452/401, direct Schedule 701, itinerary Schedule 702, Maps link 751 and Menu link 752. Every query context below uses Asia/Tokyo and the stated 2026 civil date/time. Additional records are explicit recipe inputs for the later public tests.

| Initial data and public action | Exact required end |
| --- | --- |
| Full graph, 9 October 09:30; read membership 401 and expanded appearance 452/401. | Both return owned Meeting point A and the separate 120-minute estimate; previewLink is 752 with exact `https://example.com/menu`. Membership 401 returns directItem Schedule 701 owned by Item 101, additionalCount 0. Expanded 452/401 returns itinerarySpan Schedule 702 owned by itinerary 301, additionalCount 0, inclusive 9-11 October dates. Notes, all links and hashes stay outside RowRead. |
| Add Item Schedule 703, 9 October 14:00-15:00 Tokyo. Query at 10:30. | Standalone row selects ongoing 701, additionalCount 1. At 11:00 it selects future 703, additionalCount 1. At 15:30 it selects latest-past 703, additionalCount 1. The estimate never changes either Schedule. |
| Add overlapping Item Schedules 705 and 706, each 9 October 10:15-10:45 Tokyo, alongside 701/703. Query at 10:30. | Both later-starting ongoing records outrank 701; UUID ascending breaks their equal start, so 705 wins with additionalCount 3. Each surviving Schedule occurs once. |
| Give Schedule 701 no end while retaining 703. Query at 10:00, then 10:30. | At its exact start, 701 is the next start with additionalCount 1. At 10:30, future 703 wins with additionalCount 1. A start-only record has no invented ongoing span; 701 remains available in details with no supplied end. |
| Add itinerary Schedule 704 for 16-18 October inclusive beside 702. Query at 9 October 10:30, then 15 October 10:30, then 19 October 10:30. | Itinerary rows select 702, then 704, then 704, each with additionalCount 1. They never display 9-18 October as a continuous plan. Each three-day span is one Schedule. |
| Remove direct 701 from the original full graph, leaving itinerary 702. Read membership 401; then remove 702 too and query again. | First read is inScheduledPlan. The next is none. No fabricated direct appointment, false empty progress or change to the Item's local/global completion. |
| Set Item 101 globally Done; retain 401 locally Done and 403 locally Todo. Inspect both contextual circles, then globally Reopen in Item view and reopen the store/app. | Both circles show Done, are disabled and expose Completed globally; inspecting them changes no data. After global Reopen, 401 is Done and 403 is Todo, with retained identities/local flags. This itinerary returns its previous independent state. |
| Same global-Done variant; confirm List 201 bulk Undone before global Reopen. | Bulk clears List 201's local flags only. Item 101 still appears Done until Item-view global Reopen. List 202 and itinerary flags do not change. After Reopen, List 201 is 0/2, List 202 is 0/1 and itinerary is 0/3. |
| Owned links remain 751 Maps then 752 Menu. Read previewLink; realize the row/open details with image, no-image and error I/O outcomes. | Only 752 supplies the website thumbnail. No-image/error retains Menu's useful original link and triggers no fallback website request. A Maps-only variant has previewLink null and retains its Maps link/map affordance. Full details retain all owned links. |
| Start a delayed lookup for 752, then replace/remove it, change dataset or delete/recreate its source. | The obsolete result cannot install a thumbnail, mutate owned content or cross the new lifetime. The next row generation uses the current selected owned link. |
| Change an owned address/link/Schedule after obtaining a generation; request its old window. | Typed staleSnapshot or a newly queried coherent generation, never old identities with newly computed summary data. Changing the display zone or reference context creates a fresh query; all its windows return one resolved context. |

Schedule 703 uses UUID/lifetime suffixes 703/873; 704 uses 704/874; 705 uses 705/875; 706 uses 706/876, in the full graph's existing `00000000-0000-4000-8000-000000000...` namespace. Use valid existing source/lifetime references and the accepted timed/all-day forms. Ties use the canonical UUID ascending order. This catalog is an acceptance recipe, not a new portable schema or runtime test pass.

## Definition of ready

- [x] Recover the original Q38-Q42 options and record the human's A/B/A/A/A choices without substituting recommendations.
- [x] Inspect the accepted contracts and actual Core implementation, keeping declarations distinct from runtime evidence.
- [x] Record the human's Q43-Q46 A choices and update the affected public declarations and literal fixture expectations before writing their behavior tests.
- [ ] Confirm real disposable full-graph persistence/recovery and native provider I/O test boundaries for saved mutations and lookups; a read-only fixture projection cannot acknowledge a save.

## Required /tdd and other validation

| Public level and fixed input | Action | Required output under accepted choices |
| --- | --- | --- |
| Core row/read plus native UI; full graph membership 401 versus itinerary 452/401 | Read/render both windows at a fixed Tokyo reference time before S1 starts. | Owned Meeting point A, separate 120-minute estimate, direct S1 versus inclusive S2 plan span, correct appearance/local flags and no fetched metadata in the read. No complete notes/link/hash payload in each row. |
| Core row/read; same graph and generation | Change an owned address/link/Schedule, then request an old window. | Typed stale result or a new consistent generation, never a mixed old identity/new summary. Progress remains complete-scope and independent of filters. |
| Core/store and native completion; X globally Done, 401 locally Done and 403 locally Todo | Inspect the disabled contextual circles and Completed globally accessibility/help; then globally reopen from Item view and reopen the store/app. Separately exercise local bulk Undone. | Exact retained local values and effective A Done/B Todo distinction; only the explicit bulk changes local flags. No contextual control targets global completion. Saved acknowledgement follows actual persistence/recovery. |
| Core date summary unit plus native UI; literal 701/703/704/705/706 recipes above | Query the fixed times, ongoing boundaries and separate all-day spans. | Ongoing 701 before future 703; latest-start/tie 705; latest-past 703; separate plan 702 or 704. Exact additional counts, no false continuous span or invented start-only end. Cover zero/one/several/mixed/all-day inputs, end boundaries, zone/day refresh and unresolved references. |
| Core owned-link selection plus native provider I/O; links 751 Maps and 752 Menu | Read one preview link, realize the row/open detail, remove/change the selected link while its lookup is delayed. | Literal Q46 selection and one chosen row preview. Old callback is ignored; image/no-image/error keep useful links. Capture still makes no ordinary-page request; owned content/backup values remain unchanged. |
| Native integration and long-list review; existing 5,000-Item fixture | Traverse rows and refresh selection, inspect portrait/landscape/Mac window layouts, keyboard and accessibility. | No eager whole-collection lookup or full-detail payload per row. Record measured latency/memory and actual native screenshots. Keep the accepted physical 300 ms gate; simulator results do not replace it. |

Each executable slice uses one failing behavior test and minimum implementation through the approved public seams. Mock only real external I/O, and use real temporary stores for persistence/reopen. Document-only checks here are affected Markdown lint, internal link/diff review and matching tracker publication; no new unit/UI test pass is claimed.

## Definition of done

- [x] Human decisions and exact public declarations/fixtures are recorded in this packet for publication in Navigation prototype and committed source.
- [ ] Implemented slices have focused red/green, affected compilation/lint, real-store/provider-I/O and native UI evidence on the required destinations.
- [ ] Human reviews the actual row/detail interactions; remaining physical, accessibility, sync/Share and full navigation gates remain explicit before resolving the prototype.
