# Itineraries and scheduling

Decision record in progress for [Itineraries and scheduling](https://github.com/dvcol/planner/issues/9). The human confirmed the first round on 2026-10-08. Scheduling Q5/Q6 are accepted through the question tool, and the human accepted revised Q7 by explicitly deferring Apple Calendar export outside the map. Scheduling Q9 display behavior is also accepted. This ticket remains open; Scheduling Q10/Q11 below still await human answers. No public Swift interfaces or runtime outcomes are approved by this record.

The [product brief](product-brief.md), [Planner vocabulary](planner-vocabulary.md) and [Duration and search](duration-and-search.md) establish stable references, independent item states and estimates separate from calendar spans. The [Native calendar date capabilities report](https://github.com/dvcol/planner/blob/31a31448c96329647b4ca38ac0f0e0230ab4f00a/docs/research/native-calendar-date-capabilities.md) supplies Foundation/DST facts and unexecuted native checks for this effort. Its EventKit observations remain historical reference outside the amended scope. Planner remains the canonical calendar.

## Confirmed first-round choices

- Itineraries contain existing items and lists. Nested itineraries are unnecessary and excluded from the chosen composition; lists provide reuse.
- References are live. Source edits and list membership/order changes update their uses without copying items, lists or their content. List expansion uses saved Manual order; temporary UI sorting does not rewrite that order.
- The human subsequently clarified completion in [Completion scopes and derived progress](https://github.com/dvcol/planner/issues/22). Lists and itineraries complete when their contextual child items are effectively done. Mark Done/Undone is a bulk child operation; it is not a separate parent completion override. Global and contextual completion differ while archive stays separate.
- Lists need Mark all Done/Undone and full-list Archive/Delete actions. Itinerary completion prompts must reflect the derived model. Bulk completion includes archived children and ignores current UI filters; it changes completion only in the current context. [Offline conflicts and recovery](offline-conflicts-and-recovery.md) now settles full-list Archive/Delete effects: containers preserve source Items/Lists, Archive preserves references, and confirmed Delete removes only the selected entity and its references. There is no Trash. Native confirmation/presentation remains a Navigation prototype decision.
- The same item or itinerary can have several independently reschedulable schedule entries. Each entry retains its own identity and references the same source. Automatic recurring series are deferred from the first release. Scheduling does not introduce visit history or automatically reopen a done source.
- Support all-day dates/ranges and timed entries with a required start and optional end. An omitted end stays unspecified; an activity estimate does not silently supply it. Named flexible slots such as morning are deferred.
- An item is scheduled if any retained schedule references it directly or through an itinerary, including live list membership and past dates. Completion/archive filters remain separate.
- Timed entries preserve a fixed instant with an explicit planning timezone, initially the device's current zone at creation. Another planning zone can be chosen. Device timezone changes do not reschedule an entry.

The original explicit itinerary-status recommendation is superseded by the later derived-completion clarification. [Completion scopes](completion-scopes.md) records the accepted effective/local states, new local Todo initialization, independent itinerary contexts, unique-item progress, archive/empty behavior and local-only bulk actions. Inclusive all-day civil dates and preservation across travel are now accepted in Scheduling Q5 below. An absent timed end is valid; a supplied end must be a strictly later instant, with invalid edits preserving saved data. Calendar display follows the device zone with an optional per-device override under accepted Q9. DST validation remains open. Apple Calendar export and its endpoint conversion are outside this map under accepted Scheduling Q7.

## Reference and form examples

Use the nine existing items A through I from [Search fixtures](search-fixtures.md). These letters stand for distinct stable source identities, not proposed Swift signatures. Tokyo Food has saved Manual order D, G, A, C, B. Each row below starts from its stated fixture.

Museum Morning has two ordered entries: an item reference to F, Nezu Museum, followed by a list reference to Tokyo Food. Membership expansion currently refers to F and the list's D, G, A, C, B, six unique items. Itinerary progress uses those six identities and their effective completion in Museum Morning, including archived children. Each new itinerary-context state starts Todo; Tokyo Food's own local completion does not contribute. Detailed row presentation belongs to the navigation prototype.

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
| Request itinerary completion | A nonempty active itinerary has unfinished contextual children. | Prompt for its local bulk completion action. Target all contextual children, including archived/hidden ones. Undone changes local completion only; a global Done source can keep a child effectively Done. Do not offer global actions in this view. |
| Schedule twice | Existing source F has no schedule entries. | Create entries S1 and S2 on different supplied dates. There are two schedule identities referencing F and still nine item identities. F's completion/archive state is unchanged. |
| Reschedule one occurrence | S1 references F with start 2026-10-09 10:00 Asia/Tokyo, 01:00Z; S2 references F with start 2026-10-11 10:00 Asia/Tokyo, 01:00Z. | Move S1 to 2026-10-10 11:00 Asia/Tokyo, 02:00Z. S1 retains its identity/source reference; S2's identity and supplied fields are unchanged. |
| Keep a timed end unspecified | A source has a one-hour estimate; its timed schedule starts at 10:00 with no end. | The end remains absent. Editing the estimate does not fill an end or reschedule the entry. |
| Choose a supported form | An existing item or itinerary is being scheduled. | A single all-day date, an all-day date range, a timed start-only form and a timed form with an end are supported. All-day ranges include both selected civil dates and retain them across travel. A timed end may be absent; when supplied it must be a strictly later instant. Q9 settles calendar display; DST policies remain pending, and native Planner date controls/persistence require proof. |

The rescheduling example uses Gregorian dates and explicit Asia/Tokyo offsets, independently supplied as future test inputs. Native conversion remains unexecuted. Removing one schedule preserves its source and other schedule identities; Scheduled anywhere follows the accepted remaining direct/indirect references. Source/container deletion follows the accepted recovery record. Apple Calendar events and their lifecycle are outside this map; deleting or moving a Planner schedule affects Planner data only.

## Accepted prerequisites and remaining policy owners

| Open behavior | Owner and required outcome |
| --- | --- |
| Global/contextual completion, overlapping references and derived progress | Use the accepted [Completion scopes](completion-scopes.md) fixtures: global OR local, retained local states, new local Todo, independent itinerary states and unique reachable items. Archived children count; empty means No items and not completed. |
| Completion prompt and local bulk behavior | Local Done/Undone affects contextual children only, with no global actions proposed in a list/itinerary. The navigation prototype owns simple native confirmation/presentation. Parent completion is derived; there is no independent parent completion checkbox. |
| Bulk list Archive/Delete, shared-source impact, undo and partial/concurrent failure | Use accepted [Offline conflicts and recovery](offline-conflicts-and-recovery.md): Archive plus confirmed Delete, container-only effects, reference removal, ordinary re-add/local-state retention, all-or-nothing local bulk actions and deletion precedence. Native presentation belongs to Navigation prototype; actual concurrency/durability proof belongs to Sync and share prototype. |
| Scheduled/unscheduled through live itinerary references | Direct/indirect retained schedules and past dates count. This ticket must finish exact live membership, status-change and unscheduling examples. |
| Time-zone travel, all-day ranges, supplied-end validation and DST gaps/repeats | Fixed instants/planning zones, Q5 civil dates, Q6 supplied-end validity and Q9 display behavior are accepted. This ticket must finish only the missing/repeated local-time policies using the capability report. |
| Storage, observation and public operation interfaces | [Core architecture](https://github.com/dvcol/planner/issues/12) and [Shared command contracts](https://github.com/dvcol/planner/issues/13) must propose and confirm itinerary/schedule/bulk-action seams before implementation tests. |
| Native prompts, layouts and interactions | [Navigation prototype](https://github.com/dvcol/planner/issues/14) must demonstrate the agreed journeys on iPhone, iPad and Mac, with native accessibility and exact fixture observations. |

## Accepted all-day choice, Scheduling Q5

The human accepted "Include Friday-Sunday; preserve dates across travel" through the single-question tool prompt. An all-day range includes both selected civil dates: Friday 2026-10-09 through Sunday 2026-10-11 covers Friday, Saturday and Sunday in Tokyo and Paris. A single date covers that one day. An end before the start is rejected; an invalid edit preserves the previously saved schedule. Activity estimates do not define these date-only spans.

Core architecture and Shared command contracts must confirm Planner civil-date/calendar interfaces before /tdd. Navigation prototype must demonstrate native date controls and the accepted included days on each platform; real persistence/reopen tests must retain date-only meaning without an assumed fixed-seconds day. Specification handoff audits that evidence. No Foundation conversion, persistence or native UI test ran.

| Future test boundary | Exact before/input/action | Accepted Q5 observation |
| --- | --- | --- |
| Civil-range unit and save/reopen | Each case starts independently: Gregorian 2026-10-09 through 2026-10-11; 2026-10-09 alone; reversed 2026-10-11 through 2026-10-09. | The range includes exactly 2026-10-09, 2026-10-10 and 2026-10-11. The single-day case includes only 2026-10-09. Reversed input creates zero schedules or leaves the previous saved edit unchanged. No Item/Itinerary source is copied. |
| Civil-date persistence and native travel UI | Save the Friday-Sunday range in Tokyo; reopen with a Paris device/display zone. Repeat for Gregorian 2026-03-06 through 2026-03-08 and 2026-10-30 through 2026-11-01. | Each range retains its original schedule/source identity and exactly its three civil dates. No travel shift, estimate-based end or fixed-seconds definition of a calendar day is introduced. The native UI displays the same included dates; runtime proof remains required. |

## Accepted timed-end choice, Scheduling Q6

The human accepted an optional end that must resolve to an instant strictly later than the start when supplied. Start-only entries remain valid; estimates never fill an end. Equal/earlier or invalid ends require correction. An invalid new form creates no schedule; an invalid edit preserves the existing schedule. An end on a later date is valid when its instant is later. Different timezone offsets must be resolved before comparing endpoints; wall-clock ordering alone is insufficient. Missing/repeated-time resolution still awaits Scheduling Q10/Q11.

| Future test boundary | Exact before/input/action | Accepted Q6 observation |
| --- | --- | --- |
| Timed validation unit and save/reopen | Each case independently starts with S1 at 2026-10-09 10:00 Asia/Tokyo, 01:00Z, with no end. Try an absent end, same-day 11:00, 10:00 or 09:59. | Absent remains absent and valid. 11:00 saves as 02:00Z under the same S1 identity. Equal 01:00Z and earlier 00:59Z candidates are rejected, preserving S1's previous fields/end and creating zero new schedules. Source completion/archive and estimate remain unchanged. |
| Native form and cross-date validation | Start 2026-10-09 23:00 Asia/Tokyo, 14:00Z; supply end 2026-10-10 01:00 Asia/Tokyo, 16:00Z on 9 October. | The cross-midnight span is valid because the end instant is later. Native date/time pickers preserve the entered dates, with no estimate-based end. Public interface and native conversion tests remain required before claiming success. |

## Accepted export scope, Scheduling Q7

The human explicitly chose "Defer it outside map" after reviewing the two boundaries: outside the entire current V0-V3 map, or retained in V3. Apple Calendar/EventKit export is outside this effort. This supersedes the earlier V2 export commitment in Release goals; it is not moved to V3 or into the map's fog. Revisit it only through a future explicit scope decision.

Planner's own calendar, all-day/timed schedules, fixed instants, date-only travel behavior, iCloud synchronization and full JSON portability remain included. Remove EventKit permissions/setup checks, export/update commands and interfaces, external-event ownership, export UI, and Calendar-specific test/handoff gates. No speculative EventKit adapter is required. Native Planner date/instant/DST validation, UI and persistence quality gates remain mandatory.

Scheduling Q8 about exporting a start-only entry and the later export ownership/retry discussions are withdrawn. A start-only Planner entry remains valid without adding an end or requesting Calendar access. Completion Q8's local-only actions are unaffected. Previous EventKit research remains documentary reference and does not create a runtime requirement.

## Accepted display zone, Scheduling Q9

The human accepted "Follow device; allow a display-zone override" through the contextual question tool. Planner's calendar uses one display timezone. It initially follows the current device zone; an explicit override remains selected per device until changed or returned to following the device. Details retain the entry's planning zone and show it when it differs from the calendar zone. A display/device-zone change never reschedules a fixed instant or shifts an all-day civil date. Preferences on another device remain independent.

| Future test boundary | Exact before/input/action | Accepted Q9 observation |
| --- | --- | --- |
| Display/query and native UI | S1 is 2026-10-09 10:00 Asia/Tokyo, 01:00Z. Follow a Europe/Paris device zone, then select Asia/Tokyo override. | Paris display is 03:00 with Tokyo planning-zone detail; override displays 10:00. Source instant stays 01:00Z, with one schedule/source identity and unchanged completion/archive/end. All-day dates remain exactly their selected civil dates. |
| Device preference and reopen | Save the Tokyo override on device A; change A's device zone to Paris and reopen. Device B has follow-device mode in Paris. Then return A to follow-device mode. | A initially still displays 10:00 through its override; B displays 03:00. Switching A to following the device displays 03:00. None of these preference changes mutates S1 or affects B's preference. Exact storage/observation interfaces remain architecture/contracts gates. |

## Pending scheduling round, Q10-Q11

These two recommendations concern Planner's own date/time validation and use the accepted fixed-instant, optional-end, civil-date and display choices. Q10/Q11 remain unanswered. Q5/Q6/Q7/Q9 do not select a DST gap/repeat policy.

| Question | Concrete situation | Recommendation to confirm |
| --- | --- | --- |
| Scheduling Q10: Missing wall-clock time | Enter 2026-03-08 02:30 in America/New_York, where that local time does not exist. | Reject the missing time and ask for a valid choice without silently moving it to another hour or day. Saving an invalid edit changes nothing. Apply the same rule to supplied starts and ends. |
| Scheduling Q11: Repeated wall-clock time | Enter America/New_York 2026-11-01 01:30, which occurs twice. | Require an explicit earlier/later occurrence choice when creating or changing the ambiguous date/time. Preserve the selected instant and planning zone across save/sync; an existing occurrence stays selected when unrelated fields change. No silent first/last default or repeated prompt for an unchanged stored occurrence. Native labels should distinguish the offsets clearly. |

The [resolved capability report](https://github.com/dvcol/planner/blob/31a31448c96329647b4ca38ac0f0e0230ab4f00a/docs/research/native-calendar-date-capabilities.md) supplies the facts behind these questions. Its UTC arithmetic is documentary evidence, not an executed Foundation test. Later public interfaces must specify civil-date/calendar input, existence/ambiguity validation and display queries before /tdd.

| Future test boundary | Exact before/input/action | Proposed observation, pending Q10-Q11 |
| --- | --- | --- |
| Existence-validation unit and native form | Existing valid schedule; edit its start or end to America/New_York 2026-03-08 02:30. | Reject the nonexistent civil time. No 03:00, 03:30, 01:30 or different-day substitution; prior schedule values remain exact and a new invalid form creates zero schedules. |
| Ambiguity unit, persistence/sync and native form | New York 2026-11-01 01:30; choose earlier versus later; reopen on a different-zone device and edit notes. | No save before explicit choice. Earlier maps to 05:30Z, UTC-04:00; later maps to 06:30Z, UTC-05:00. Reopen/notes edits retain the selected instant without choosing again. Every conversion remains an unexecuted expectation until native tests run. |

Finish the remaining DST choices with the human, then audit concrete live-reference and unscheduling examples against accepted scheduling and recovery rules. Exact public interfaces and native interactions remain architecture/contracts/prototype gates. Export-specific discussion and tests leave this effort under Q7.

## Required later test evidence

These are future /tdd obligations. Agree public interfaces before writing Swift tests, then implement one failing behavior and its minimum passing implementation at a time. No Swift code or runtime tests are claimed by this record.

| Level | Concrete input/action | Required observation or remaining gate |
| --- | --- | --- |
| Domain unit | Edit F, add E, remove C and reorder Tokyo Food using the independent fixtures above. | Query the same source/entry identities and exact membership/order changes. No source copies appear; C retains Weekend membership. |
| Domain unit | Reorder Museum Morning and attempt to insert an itinerary entry. | Query the reversed existing entry order; reject nesting without changing sources or entries. |
| Domain unit | Archive an unfinished itinerary and complete its last unfinished contextual child. | Archive stays separate; nonempty container completion follows the effective contextual children. An empty container has no percentage and is not completed. |
| Unit and native UI | Request itinerary completion and invoke list Mark all Done/Undone with archived/hidden children. | Include the full contextual target set regardless of UI filters. Assert the accepted Q8 local/global/effective states and unchanged archive values. Navigation prototype confirms exact native presentation; scope is already settled. |
| Domain unit | Create S1/S2 for F, reschedule only S1 and change F's estimate. | Source count remains nine; references and S2 are preserved; supplied Tokyo/UTC values match the example; no end is synthesized from the estimate. |
| Persistence integration | Save/reopen itinerary entries, list membership/order and repeated schedule references. | Retain source/entry identities, accepted ordering and live edits. Observe remote CloudKit changes in the sync prototype; documentation does not prove convergence. |
| Planner date conversion, persistence and native UI | Exercise the report's Tokyo/Paris, New York gap/repeat and Friday-Sunday candidates through Planner's supported forms. | Q5/Q6 supply accepted date-range/end validity. Q9 supplies display behavior; first accept Q10/Q11 DST expectations, then verify native input, validation, persistence/reopen and display on each OS 27 platform. No EventKit export gate remains. |
| Recovery integration | Bulk completion or full-list Archive/Delete with shared/hidden items and a concurrent membership change. | Use the accepted recovery fixtures for exact target sets, all-or-nothing local failure, deletion/membership precedence and retained source references. Architecture/contracts must confirm store checkpoints before tests; no atomic cross-device transaction is assumed. |
| Native UI/manual | Build a flat itinerary, edit a referenced list, reorder, schedule twice, reschedule once and request bulk completion. | Follow the accepted examples and remaining approved policies on every native layout. Preserve reference identity, accessible actions and clear action scope. |

Document checks validate this record and its local links. They do not replace the required unit, persistence, UI or physical-device evidence.
