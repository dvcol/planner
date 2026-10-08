# Itineraries and scheduling

Accepted decision record for [Itineraries and scheduling](https://github.com/dvcol/planner/issues/9). The human confirmed the first round on 2026-10-08. Scheduling Q5/Q6 are accepted through the question tool, and the human accepted revised Q7 by explicitly deferring Apple Calendar export outside the map. Scheduling Q9 display behavior is also accepted. Scheduling Q10/Q11 DST policies are now accepted. Q12 now accepts repeated live references with independent local completion and Q13 accepts instant-preserving planning-zone edits. The human accepted Q14 as 1 of 3, completing the remaining progress choice. All in-scope composition/date/display policies are settled; public Swift signatures and runtime evidence remain downstream requirements. No runtime test is claimed by this record.

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

The original explicit itinerary-status recommendation is superseded by the later derived-completion clarification. [Completion scopes](completion-scopes.md) records the accepted effective/local states, new local Todo initialization, independent per-appearance local states, archive/empty behavior and local-only bulk actions. Accepted Q14 counts item appearances separately, including repeats. Inclusive all-day civil dates and preservation across travel are now accepted in Scheduling Q5 below. An absent timed end is valid; a supplied end must be a strictly later instant, with invalid edits preserving saved data. Calendar display follows the device zone with an optional per-device override under accepted Q9. Q10 rejects nonexistent local times; Q11 requires an explicit earlier/later choice for repeated times. Apple Calendar export and its endpoint conversion are outside this map under accepted Scheduling Q7.

## Reference and form examples

Use the nine existing items A through I from [Search fixtures](search-fixtures.md). These letters stand for distinct stable source identities, not proposed Swift signatures. Tokyo Food has saved Manual order D, G, A, C, B. Each row below starts from its stated fixture.

Museum Morning has two ordered entries: an item reference to F, Nezu Museum, followed by a list reference to Tokyo Food. Membership expansion currently refers to F and the list's D, G, A, C, B, six unique items. This fixture has six child appearances and six source identities, so its progress denominator is six under accepted Q14, including archived children. Each new itinerary-context state starts Todo; Tokyo Food's own local completion does not contribute. Detailed row presentation belongs to the navigation prototype.

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
| Choose a supported form | An existing item or itinerary is being scheduled. | A single all-day date, an all-day date range, a timed start-only form and a timed form with an end are supported. All-day ranges include both selected civil dates and retain them across travel. A timed end may be absent; when supplied it must be a strictly later instant. Q9 settles calendar display; Q10/Q11 settle DST validation, and native Planner date controls/persistence require proof. |

The rescheduling example uses Gregorian dates and explicit Asia/Tokyo offsets, independently supplied as future test inputs. Native conversion remains unexecuted. Removing one schedule preserves its source and other schedule identities; Scheduled anywhere follows the accepted remaining direct/indirect references. Source/container deletion follows the accepted recovery record. Apple Calendar events and their lifecycle are outside this map; deleting or moving a Planner schedule affects Planner data only.

## Accepted prerequisites and remaining policy owners

| Open behavior | Owner and required outcome |
| --- | --- |
| Global/contextual completion, overlapping references and derived progress | Use the accepted [Completion scopes](completion-scopes.md) fixtures: global OR local, retained local states, new local Todo and independent local states for each itinerary appearance under Q12. Accepted Q14 counts each effectively Done appearance once toward all child appearances. Archived children count; empty means No items and not completed. |
| Completion prompt and local bulk behavior | Local Done/Undone affects contextual children only, with no global actions proposed in a list/itinerary. The navigation prototype owns simple native confirmation/presentation. Parent completion is derived; there is no independent parent completion checkbox. |
| Bulk list Archive/Delete, shared-source impact, undo and partial/concurrent failure | Use accepted [Offline conflicts and recovery](offline-conflicts-and-recovery.md): Archive plus confirmed Delete, container-only effects, reference removal, ordinary re-add/local-state retention, all-or-nothing local bulk actions and deletion precedence. Native presentation belongs to Navigation prototype; actual concurrency/durability proof belongs to Sync and share prototype. |
| Scheduled/unscheduled through live itinerary references | Direct/indirect retained schedules and past dates count. The exact live membership, status-change and unscheduling identity sets below define the accepted query results. |
| Time-zone travel, all-day ranges, supplied-end validation and DST gaps/repeats | Fixed instants/planning zones, Q5 civil dates, Q6 supplied-end validity and Q9 display behavior are accepted. Q10/Q11 now settle missing/repeated times; Q13 preserves start/end instants when only the planning zone changes. |
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

The human accepted an optional end that must resolve to an instant strictly later than the start when supplied. Start-only entries remain valid; estimates never fill an end. Equal/earlier or invalid ends require correction. An invalid new form creates no schedule; an invalid edit preserves the existing schedule. An end on a later date is valid when its instant is later. Different timezone offsets must be resolved before comparing endpoints; wall-clock ordering alone is insufficient. Q10/Q11 below settle missing/repeated-time resolution before instant ordering is validated.

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

## Accepted DST policies, Scheduling Q10-Q11

The human accepted both recommendations. Reject nonexistent local times without substituting another hour/day. Require an explicit earlier/later occurrence when creating or changing a repeated local time; retain the chosen instant across reopen/sync and unrelated edits. Apply these rules to both starts and supplied ends. A new invalid or unresolved form creates no schedule; an invalid edit or cancelled occurrence choice preserves the saved schedule.

| Decision | Concrete situation | Accepted outcome |
| --- | --- | --- |
| Scheduling Q10: Missing wall-clock time | Enter 2026-03-08 02:30 in America/New_York, where that local time does not exist. | Reject the missing time and ask for a valid choice without silently moving it to another hour or day. Saving an invalid edit changes nothing. Apply the same rule to supplied starts and ends. |
| Scheduling Q11: Repeated wall-clock time | Enter America/New_York 2026-11-01 01:30, which occurs twice. | Require an explicit earlier/later occurrence choice when creating or changing the ambiguous date/time. Preserve the selected instant and planning zone across save/sync; an existing occurrence stays selected when unrelated fields change. No silent first/last default or repeated prompt for an unchanged stored occurrence. Native labels should distinguish the offsets clearly. |

The [resolved capability report](https://github.com/dvcol/planner/blob/31a31448c96329647b4ca38ac0f0e0230ab4f00a/docs/research/native-calendar-date-capabilities.md) supplies the facts behind these questions. Its UTC arithmetic is documentary evidence, not an executed Foundation test. Later public interfaces must specify civil-date/calendar input, existence/ambiguity validation and display queries before /tdd.

| Future test boundary | Exact before/input/action | Accepted Q10/Q11 observation |
| --- | --- | --- |
| Existence-validation unit and native form | Existing valid schedule; edit its start or end to America/New_York 2026-03-08 02:30. | Reject the nonexistent civil time. No 03:00, 03:30, 01:30 or different-day substitution; prior schedule values remain exact and a new invalid form creates zero schedules. |
| Ambiguity unit, persistence/sync and native form | New York 2026-11-01 01:30; choose earlier versus later; reopen on a different-zone device and edit the referenced source Item's notes. | No save before explicit choice. Earlier maps to 05:30Z, UTC-04:00; later maps to 06:30Z, UTC-05:00. Reopen/notes edits retain the selected instant without choosing again. Each explicit choice retains one schedule/source identity and the supplied planning zone. These are unexecuted expectations until native tests run. |

A coupled endpoint test starts at America/New_York 2026-11-01 01:45 in the earlier occurrence, 05:45Z, and explicitly ends at 01:15 in the later occurrence, 06:15Z. The span is valid even though the end's wall-clock time looks earlier. Selecting the earlier 01:15 end instead gives 05:15Z and must be rejected under Q6 without changing the saved entry. Each repeated endpoint needs its explicit occurrence; no test assumes a silent default.

## Scheduled-anywhere and recovery fixtures

These observations derive from the already accepted direct/indirect scheduling, live-reference, completion and recovery rules. They introduce no new status or visit lifecycle. Each case starts independently with the nine source Items A-I. Museum Morning directly references F and Tokyo Food in saved order D, G, A, C, B. S1 directly schedules F at 2026-10-09 10:00 Asia/Tokyo, 01:00Z, with no end. S2 schedules Museum Morning for the past all-day date 2026-10-07. There are no other schedules. Identity sets below describe Scheduled anywhere before separate completion/archive/search filters; they do not prescribe result sorting.

| Unit/query and persistence action | Exact required observation |
| --- | --- |
| Query the unchanged fixture | Scheduled Item identity set is {A, B, C, D, F, G}; unscheduled is {E, H, I}. S1/S2 retain their distinct IDs and source references. S2's past date still counts. |
| Add E last to Tokyo Food | Source count stays nine; list order becomes D, G, A, C, B, E. Scheduled set becomes {A, B, C, D, E, F, G}; unscheduled is {H, I}. S2, itinerary and E use their existing identities; new itinerary E context starts Todo. |
| Remove C's Tokyo Food membership | Scheduled set becomes {A, B, D, F, G}; C is unscheduled in this fixture. C remains a source and retains its other memberships/content. S1/S2 dates and identities do not change. |
| Unschedule S1 only | S1 is absent; S2 and all nine sources remain. F is still scheduled through Museum Morning. Scheduled and unscheduled sets remain the unchanged fixture's sets; completion/archive and contextual states are untouched. |
| Unschedule S2 only | S2 is absent; S1 and all nine sources remain. Only F is scheduled; {A, B, C, D, E, G, H, I} are unscheduled. Museum Morning/Tokyo Food entries and contextual states remain exact. |
| Unschedule both S1 and S2 | All nine Items are unscheduled. Both sources/containers, their entries/memberships and contextual states remain. No completion, archive or content mutation is implied. |
| Complete or archive F, or archive Museum Morning/Tokyo Food | Retained schedules/references still yield the unchanged fixture's scheduled identity set. Ordinary visibility/progress follows independent completion/archive rules; these actions do not cancel dates or introduce visit states. |
| Confirm Delete of Tokyo Food | All nine Items and S1/S2 remain. Museum Morning retains its direct F entry; the deleted List entry/memberships are absent. Only F is scheduled. Other source memberships remain; cancel retains the full fixture. |
| Confirm Delete of Museum Morning | S2 and that itinerary's entries/context are absent. All nine Items, Tokyo Food and S1 remain; only F is scheduled. Cancel retains the full fixture. |
| Confirm Delete of F | F, S1 and Museum Morning's direct F entry/context are absent. Eight source Items, Tokyo Food and S2 remain. Scheduled set is {A, B, C, D, G}; unscheduled is {E, H, I}. |
| Remove Museum Morning's F and Tokyo Food entries without deleting their sources | The itinerary is empty, No items, no percentage and not completed. S2 remains assigned to the same empty itinerary/date; S1 and all sources remain. Only F is scheduled through S1. No source or schedule is automatically deleted. |

Repeat the applicable public queries after real-store reopen. Sync and share prototype must prove the accepted deletion/merge and live-reference outcomes on physical devices; it must not treat documentary fixtures as convergence proof. Reordering changes ordered references while preserving these identity sets and completion states. Ordinary removal/re-add and retained-path completion follow the exact accepted recovery fixtures.

## Accepted repeated references, Scheduling Q12

The human chose the simplest model with independent completion per list/itinerary item while retaining global Item precedence. One source Item supplies shared content. Each itinerary item appearance has its own retained local Todo/Done state, including direct repeats, appearances through different Lists and children of repeated List entries. A source List's local completion stays separate. Global Done overrides every appearance; Global Reopen reveals each retained local value. Local actions never change the global source. This explicitly supersedes the earlier one-local-state-per-Item-within-an-itinerary choice in Completion scopes, while preserving Completion Q8's action scope and OR rule.

Hotel -> Museum -> Hotel has three ordered entry identities referencing only two source Item identities. Completing the first Hotel entry leaves the second Todo when Hotel is globally Todo. Editing Hotel's content updates both. Repeated List entries each expand live memberships in saved Manual order, with independent local child states. Reordering retains entry identities and their local states; ordinary removal/re-addition creates a new local Todo state while original-association Undo retains its prior state. No source content is copied and no repeat-visit lifecycle is added. Standalone List membership uniqueness remains the accepted one-membership-per-Item/List-pair rule.

Intentional separate additions may produce separate itinerary entries for one source. Replaying the same logical addition must retain its original entry rather than create another; contracts and the sync prototype must prove the operation-identity/reconciliation behavior. The architecture owns the storage representation, not another completion rule.

Accepted Scheduling Q14 below counts completed item appearances out of all item appearances. The itinerary completes only when all child appearances are effectively Done; a List entry's displayed completion derives from its children in that occurrence, with no extra container count.

| Future unit/store/UI or sync boundary | Exact before/input/action | Accepted Q12 observation |
| --- | --- | --- |
| Repeated direct entries and global precedence | Hotel and Museum are globally Todo. Add Hotel -> Museum -> Hotel as three distinct entries, all locally Todo; complete only the first Hotel entry. Then complete and reopen Hotel globally in the Item view. | Source count stays two, entry count three and order stays exact. Before the global action, first Hotel is effectively Done and second Hotel Todo, progress 1 of 3. Global Done shows both Done without changing local Done/Todo, progress 2 of 3; Global Reopen restores that effective Done/Todo distinction and 1 of 3 progress. Museum stays Todo throughout. Editing Hotel's title updates both and changes no state. |
| Repeated List expansion and live updates | The nine-Item fixture has two itinerary entries referencing the same Tokyo Food List, initially containing D, G, A, C, B. Complete D only inside the first List entry. Then append existing E to the source List. | Initially two List entries expand to ten item appearances over five source identities. Only the first entry's D becomes Done; second D stays Todo, progress 1 of 10. Appending E produces twelve appearances over six source identities, with E locally Todo in both entries and progress 1 of 12. Source Item count stays nine, source List identity remains one, and D's differing local flags survive. Source List completion is unchanged by the itinerary action. |
| Reorder, removal and ordinary re-addition | The first Hotel entry is locally Done and the second Todo, with global Hotel Todo. Reorder them; remove the locally Done entry; ordinarily add Hotel again. | Reorder retains both entry IDs and their local flags. Removal leaves the surviving entry Todo. Ordinary addition has a new entry ID and local Todo, even though another appearance survives. Approved Undo of the original removal restores its original identity/local Done instead. No source is duplicated or deleted. |
| Local bulk success, cancellation and failure | The repeated direct fixture has local Done/Todo/Todo, global Todo, with Museum archived and hidden. Confirm itinerary Mark all Done or Undone; separately cancel or inject local save failure. | Successful Done sets all three local flags Done, progress 3 of 3 and complete; successful Undone clears all three, progress 0 of 3 and unfinished. Archive, globals and source/entry IDs remain exact. Cancellation/failure retains the entire pre-action local state. Target every appearance regardless of filters; native confirmation must not propose global completion. |
| Operation replay and offline intentional additions | Re-deliver the same logical addition; separately add Hotel in two different offline operations and reconnect. | Replay retains one entry identity for that operation. Two intentional operations retain two distinct ordered entries referencing one Hotel source, each with independent local Todo. Both devices converge with every surviving entry once; competing order follows the accepted consistent-order rule. Public operation identity and physical-device evidence are required before claiming this passes. |

## Accepted planning-zone edit, Scheduling Q13

The human accepted preserving instants. Changing only an existing timed entry's planning zone preserves its start and any supplied end instants, source/schedule identity and the separate calendar display-zone preference. With Gregorian 2026-10-09 10:00-11:00 Asia/Tokyo, the stored instants remain 01:00Z-02:00Z after changing the planning zone to Europe/Paris. Details show 03:00-04:00 Paris. A Paris calendar grid stays at 03:00-04:00; a Tokyo display override stays at 10:00-11:00. This does not move the appointment to 08:00Z-09:00Z. An absent end remains absent, and other schedules, source content, completion and estimates are unchanged.

Creating a schedule interprets an entered local date/time in its chosen planning zone. Explicitly editing an existing date/time reschedules and applies Q6/Q10/Q11 validation. A zone-only edit changes the description of already resolved instants and does not request another ambiguity choice for an unchanged instant. Invalid zone input leaves saved values unchanged. Contracts must confirm exact operation and error shapes before /tdd; native controls and span-preservation presentation retain their Navigation prototype review gate.

| Future test boundary | Exact before/input/action | Accepted Q13 observation |
| --- | --- | --- |
| Unit, real-store save/reopen and native UI | Save the Tokyo 10:00-11:00 example; change only the planning zone to Paris with a Paris grid, then repeat with a Tokyo display override. | Same schedule/source IDs and 01:00Z/02:00Z instants; planning zone becomes Europe/Paris, details show 03:00-04:00. Grid stays 03:00-04:00 or 10:00-11:00 respectively. Another schedule for the source retains every field. |
| Unit and persistence validation | Repeat the zone-only edit for a start-only entry; separately submit an invalid zone. | Start-only remains 01:00Z with no end. Invalid input changes no saved field. Item identity/content/global/local completion and estimate stay exact. |
| DST persistence and UI | A stored New York repeated-time occurrence has an explicit chosen instant; change only its planning zone, reopen, then edit source notes. | Retain the chosen start/end instants and identity without selecting another occurrence. Explicit date/time edits still require Q10/Q11 validation; documentary examples are not runtime proof. |

## Accepted entry progress, Scheduling Q14

The human chose "1 of 3" for Hotel -> Museum -> Hotel with only the first Hotel locally Done. Progress counts effectively Done item appearances out of all item appearances. Each independent appearance contributes once; repeated source identities are not deduplicated for progress. A referenced List contributes its current live child item appearances, without an extra count for the container itself. Archived/hidden children remain included and UI filters do not shrink progress or bulk targets. This explicitly supersedes the earlier unique-item counting choice in Completion scopes. Scheduled anywhere remains a query over unique source identities, separate from container progress.

Global Item Done makes every appearance of that Item effectively Done without rewriting local flags. A nonempty itinerary/list completes only when every child appearance is effectively Done. An empty container shows No items, no percentage and not completed. Adding a new Todo child can make a previously complete container unfinished; it does not reopen or change existing local/global states.

Each row below resets independently unless it explicitly continues another row. Public unit/query, real-store save/reopen and native UI tests must assert these exact counts, effective/local/global states and retained identities before any physical sync result is claimed.

| Before and action | Accepted unit/query, persistence and native UI observation |
| --- | --- |
| Hotel -> Museum -> Hotel, all sources globally Todo and all three local flags Todo; complete only the first Hotel entry. | One shared Hotel source, one Museum source and three ordered entry identities remain. Local Done/Todo/Todo yields 1 of 3, unfinished. |
| Continue with first Hotel Done; complete second Hotel, then Museum locally. | Hotel Done/Todo/Done gives 2 of 3, unfinished. Done/Done/Done gives 3 of 3, complete. Source/global states, order and identities stay exact. |
| Reset local Done/Todo/Todo and all globals Todo; complete Hotel globally, then reopen it globally. | Global Hotel Done yields 2 of 3, unfinished; retained locals stay Done/Todo/Todo. Global Reopen reveals 1 of 3. Museum remains Todo. Global controls belong only in the Item view. |
| Hotel is globally Done, Museum globally Todo; invoke itinerary Mark all Undone. Then explicitly reopen Hotel globally in the Item view. | Local bulk clears all three local flags while effective progress stays 2 of 3. It offers no global action. The later Item-view Global Reopen yields 0 of 3. No source content/archive mutation occurs. |
| X/Y are globally Todo. An itinerary contains direct X, List A with X/Y and List B with X, all four appearances locally Todo; complete only direct X, then globally complete X. | Local action gives 1 of 4, unfinished. Global X Done gives 3 of 4 while all local values remain exact. Global Reopen restores 1 of 4. A List entry contributes only its contained item appearances. |
| Two live Tokyo Food List entries each expand D, G, A, C, B; all global/local states Todo; complete only D in the first entry, then append existing E to the source List. | First local completion gives 1 of 10. Live insertion adds two local Todo appearances and yields 1 of 12. Source Item count stays nine; source List identity stays one; neither stored D flag changes. |
| Museum is Archived/hidden in the three-entry Hotel fixture with only first Hotel locally Done; query filtered views, reorder entries, then invoke itinerary bulk Done. | Filters/reorder leave progress 1 of 3. Local bulk targets all three appearances, including Museum, and yields 3 of 3 without unarchiving it. Failure or cancellation retains 1 of 3 and every prior flag/identity. |
| Empty itinerary, including an itinerary referencing only empty Lists. | No items, no percentage and not completed. No container count or completion override is introduced. |

These expectations settle policy, not execution. Shared command contracts must approve concrete public progress/query and mutation interfaces before /tdd. Navigation prototype owns native labels, layout, accessibility and confirmation presentation. Sync and share prototype must verify retained per-appearance states/counts after real device convergence.

## Public test boundary proposal and owners

These are behavior-level proposals for later confirmed interfaces, not Swift signatures or an approved storage schema. Core architecture and Shared command contracts must present the exact types, validation/error observations and concurrency/save checkpoints for human confirmation before code-producing /tdd.

| Candidate public behavior | Required observation and evidence owner |
| --- | --- |
| Create/edit an itinerary; add/remove/reorder existing Item/List references | Query stable sources/entry IDs, saved order, live expansion and independent appearance states. Q12 permits repeated references; Q14 counts item appearances separately, including expanded List children. Core architecture/Shared command contracts own boundaries; Navigation prototype owns native editing. |
| Complete/reopen contextual children and apply a local bulk action | Assert Completion Q8 and recovery target sets/atomic local outcomes; query global/local/effective states and unchanged archive/source identities. Use accepted completion/recovery fixtures. |
| Validate and create/update/remove a schedule reference | Query civil dates or fixed instants, planning zone, absent/explicit end, identity and source retention. Apply accepted Q5/Q6/Q10/Q11/Q13; reject invalid/unresolved input without saved mutation. |
| Query Scheduled anywhere and calendar display | Reproduce the exact identity sets and Q9 zone/override observations, including live edits, past/archived/completed sources, unscheduling and real-store reopen. |
| Observe remote scheduling/source changes | Sync and share prototype proves stable identities, live expansion, deletion precedence and account recovery on physical OS 27 devices. Local unit/temporary-store tests do not establish CloudKit convergence. |

Export-specific discussion and tests remain outside the map under Q7.

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
| Planner date conversion, persistence and native UI | Exercise the report's Tokyo/Paris, New York gap/repeat and Friday-Sunday candidates through Planner's supported forms. | Q5/Q6 supply accepted date-range/end validity. Q9 supplies display behavior, Q10/Q11 supply DST expectations and Q13 supplies zone-only edit behavior; verify native input, validation, persistence/reopen and display on each OS 27 platform. No EventKit export gate remains. |
| Recovery integration | Bulk completion or full-list Archive/Delete with shared/hidden items and a concurrent membership change. | Use the accepted recovery fixtures for exact target sets, all-or-nothing local failure, deletion/membership precedence and retained source references. Architecture/contracts must confirm store checkpoints before tests; no atomic cross-device transaction is assumed. |
| Native UI/manual | Build a flat itinerary, edit a referenced list, reorder, schedule twice, reschedule once and request bulk completion. | Follow the accepted examples and remaining approved policies on every native layout. Preserve reference identity, accessible actions and clear action scope. |

Document checks validate this record and its local links. They do not replace the required unit, persistence, UI or physical-device evidence.
