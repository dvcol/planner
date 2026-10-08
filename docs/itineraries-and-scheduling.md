# Itineraries and scheduling

Decision record in progress for [Itineraries and scheduling](https://github.com/dvcol/planner/issues/9). The human confirmed the first round on 2026-10-08. This ticket remains open; the pending policies below are not accepted answers or approved production interfaces.

The [product brief](product-brief.md), [Planner vocabulary](planner-vocabulary.md) and [Duration and search](duration-and-search.md) establish stable references, independent item states and estimates separate from calendar spans. The [Native calendar date capabilities report](https://github.com/dvcol/planner/blob/31a31448c96329647b4ca38ac0f0e0230ab4f00a/docs/research/native-calendar-date-capabilities.md) supplies Foundation/DST/EventKit facts and unexecuted native checks. Planner remains the canonical calendar.

## Confirmed first-round choices

- Itineraries contain existing items and lists. Nested itineraries are unnecessary and excluded from the chosen composition; lists provide reuse.
- References are live. Source edits and list membership/order changes update their uses without copying items, lists or their content. List expansion uses saved Manual order; temporary UI sorting does not rewrite that order.
- The human subsequently clarified completion in [Completion scopes and derived progress](https://github.com/dvcol/planner/issues/22). Lists and itineraries complete when their contextual child items are effectively done. Mark Done/Undone is a bulk child operation; it is not a separate parent completion override. Global and contextual completion differ while archive stays separate.
- Lists need Mark all Done/Undone and full-list Archive/Delete actions. Itinerary completion prompts must reflect the derived model. Bulk completion includes archived children and ignores current UI filters; it changes completion only in the current context. Full-list Archive/Delete effects and recovery belong to [Offline conflicts and recovery](https://github.com/dvcol/planner/issues/10).
- The same item or itinerary can have several independently reschedulable schedule entries. Each entry retains its own identity and references the same source. Automatic recurring series are deferred from the first release. Scheduling does not introduce visit history or automatically reopen a done source.
- Support all-day dates/ranges and timed entries with a required start and optional end. An omitted end stays unspecified; an activity estimate does not silently supply it. Named flexible slots such as morning are deferred.
- An item is scheduled if any retained schedule references it directly or through an itinerary, including live list membership and past dates. Completion/archive filters remain separate.
- Timed entries preserve a fixed instant with an explicit planning timezone, initially the device's current zone at creation. Another planning zone can be chosen. Device timezone changes do not reschedule an entry.

The original explicit itinerary-status recommendation is superseded by the later derived-completion clarification. [Completion scopes](completion-scopes.md) records effective/local states, confirmed archive/empty behavior and still-open initialization/inheritance/counting cases. All-day endpoint conventions, calendar display policy, DST validation and the export contract remain under discussion.

## Reference and form examples

Use the nine existing items A through I from [Search fixtures](search-fixtures.md). These letters stand for distinct stable source identities, not proposed Swift signatures. Tokyo Food has saved Manual order D, G, A, C, B. Each row below starts from its stated fixture.

Museum Morning has two ordered entries: an item reference to F, Nezu Museum, followed by a list reference to Tokyo Food. Membership expansion currently refers to F and the list's D, G, A, C, B. This names the referenced sources; the current round has not selected the rendered visibility or progress count.

| Action | Before | Required end state already accepted |
| --- | --- | --- |
| Edit a source title | Museum Morning references existing item F, titled Nezu Museum. | Rename F to Nezu Museum afternoon. The itinerary still refers to F and reads its current title. The number of items remains nine. |
| Add a live list member | E belongs to no list; Museum Morning references Tokyo Food. | Add E to Tokyo Food and explicitly place it last. Saved list order becomes D, G, A, C, B, E. The same itinerary list reference includes E; the number of items remains nine. |
| Remove a live list member | C belongs to Tokyo Food and Weekend. Museum Morning references Tokyo Food, with no separate C reference. | Remove only the Tokyo Food membership. C remains in Weekend and retains its identity/content; that itinerary list reference no longer includes C. |
| Reorder a source list | Tokyo Food order is D, G, A, C, B and Museum Morning references it. | Explicitly move B to the front. Saved list order becomes B, D, G, A, C and its live itinerary use follows it. No item identity or membership changes. |
| Reorder itinerary entries | Museum Morning entry order is item F, list Tokyo Food. | Move the list entry first. Order becomes list Tokyo Food, item F. Entry/source identities and the list's saved order are unchanged. |
| Attempt nesting | Museum Morning contains an item and a list reference. | Adding another itinerary as an entry is unsupported. Existing entries and sources remain unchanged. The public rejection shape belongs to command contracts. |
| Archive an itinerary | Museum Morning is Todo + Active. | It becomes Todo + Archived. Archiving does not complete it. This case does not prescribe any bulk child action. |
| Finish the last child | A nonempty active itinerary has one remaining effectively unfinished contextual item. | Complete that item in this itinerary or globally. The itinerary derives completion from its now-completed children; archive stays Active. |
| Request itinerary completion | A nonempty active itinerary has unfinished contextual children. | Prompt for its bulk completion action. Target all contextual children, including archived/hidden ones. Effective completion still follows the global/local rule; prompt presentation and globally overridden Undone behavior remain open. |
| Schedule twice | Existing source F has no schedule entries. | Create entries S1 and S2 on different supplied dates. There are two schedule identities referencing F and still nine item identities. F's completion/archive state is unchanged. |
| Reschedule one occurrence | S1 references F with start 2026-10-09 10:00 Asia/Tokyo, 01:00Z; S2 references F with start 2026-10-11 10:00 Asia/Tokyo, 01:00Z. | Move S1 to 2026-10-10 11:00 Asia/Tokyo, 02:00Z. S1 retains its identity/source reference; S2's identity and supplied fields are unchanged. |
| Keep a timed end unspecified | A source has a one-hour estimate; its timed schedule starts at 10:00 with no end. | The end remains absent. Editing the estimate does not fill an end or reschedule the entry. |
| Choose a supported form | An existing item or itinerary is being scheduled. | A single all-day date, an all-day date range, a timed start-only form and a timed form with an end are supported. Endpoint validity, included-day and timezone policies remain pending. |

The rescheduling example uses Gregorian dates and explicit Asia/Tokyo offsets, independently supplied as future test inputs. Native conversion remains unexecuted. Source removal and unscheduling consequences require the remaining resolution; no deletion result is inferred here.

## Pending policy owners

| Open behavior | Owner and required outcome |
| --- | --- |
| Global/contextual completion, overlapping references and derived progress | [Completion scopes and derived progress](https://github.com/dvcol/planner/issues/22) must resolve inheritance, initialization, duplicate counts and effective-state outcomes. Archived children count; empty means No items and not completed. |
| Completion prompt and local bulk behavior | Completion scopes and the navigation prototype must define completion/Undone behavior, confirmation and globally overridden states. Parent completion is derived; there is no independent parent completion checkbox. |
| Bulk list Archive/Delete, shared-source impact, undo and partial/concurrent failure | [Offline conflicts and recovery](https://github.com/dvcol/planner/issues/10) must distinguish container actions from source actions and provide exact retained memberships, references, states and recovery. Include a source shared with another list/itinerary/schedule and membership changes during a bulk action. |
| Scheduled/unscheduled through live itinerary references | Direct/indirect retained schedules and past dates count. This ticket must finish exact live membership, status-change and unscheduling examples. |
| Time-zone travel, all-day ranges, supplied-end validation and DST gaps/repeats | Fixed instants with planning zones are accepted. This ticket must finish exact display, all-day and invalid/ambiguous input outcomes using the capability report. |
| One-way EventKit access, repeated export, missing endpoints and external changes | This ticket must choose create/update ownership, permission/error outcomes, explicit export behavior and canonical-data preservation. Native save/readback remains required. |
| Storage, observation and public operation interfaces | [Core architecture](https://github.com/dvcol/planner/issues/12) and [Shared command contracts](https://github.com/dvcol/planner/issues/13) must propose and confirm itinerary/schedule/bulk-action seams before implementation tests. |
| Native prompts, layouts and interactions | [Navigation prototype](https://github.com/dvcol/planner/issues/14) must demonstrate the agreed journeys on iPhone, iPad and Mac, with native accessibility and exact fixture observations. |

## Required later test evidence

These are future /tdd obligations. Agree public interfaces before writing Swift tests, then implement one failing behavior and its minimum passing implementation at a time. No Swift code, runtime tests or Calendar writes are claimed by this record.

| Level | Concrete input/action | Required observation or remaining gate |
| --- | --- | --- |
| Domain unit | Edit F, add E, remove C and reorder Tokyo Food using the independent fixtures above. | Query the same source/entry identities and exact membership/order changes. No source copies appear; C retains Weekend membership. |
| Domain unit | Reorder Museum Morning and attempt to insert an itinerary entry. | Query the reversed existing entry order; reject nesting without changing sources or entries. |
| Domain unit | Archive an unfinished itinerary and complete its last unfinished contextual child. | Archive stays separate; nonempty container completion follows the effective contextual children. An empty container has no percentage and is not completed. |
| Unit and native UI | Request itinerary completion and invoke list Mark all Done/Undone with archived/hidden children. | Include the full contextual target set regardless of UI filters. Assert local/global/effective states and unchanged archive states after remaining scope/prompt choices are confirmed. |
| Domain unit | Create S1/S2 for F, reschedule only S1 and change F's estimate. | Source count remains nine; references and S2 are preserved; supplied Tokyo/UTC values match the example; no end is synthesized from the estimate. |
| Persistence integration | Save/reopen itinerary entries, list membership/order and repeated schedule references. | Retain source/entry identities, accepted ordering and live edits. Observe remote CloudKit changes in the sync prototype; documentation does not prove convergence. |
| Calendar conversion and EventKit integration | Exercise the report's Tokyo/Paris, New York gap/repeat and Friday-Sunday candidates; export each supported form. | First accept exact display/UTC/validation/export expectations. Then verify native inputs, save errors, normalized fields and readback separately on each OS 27 platform. |
| Recovery integration | Bulk completion or full-list Archive/Delete with shared/hidden items and a concurrent membership change. | Recovery must supply exact target sets, local failure behavior, converged states and retained references before tests. Do not assume an atomic cross-device transaction. |
| Native UI/manual | Build a flat itinerary, edit a referenced list, reorder, schedule twice, reschedule once and request bulk completion. | Follow the accepted examples and remaining approved policies on every native layout. Preserve reference identity, accessible actions and clear action scope. |

Document checks validate this record and its local links. They do not replace the required unit, persistence, UI, physical-device or EventKit evidence.
