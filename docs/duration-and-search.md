# Duration and search

Accepted decision record for [Duration and search](https://github.com/dvcol/planner/issues/8), confirmed by the human on 2026-10-08 after reviewing the [nine-item fixtures](search-fixtures.md) and the final five-question round. It defines the product behavior and concrete future test expectations. It is not evidence of an executable search implementation or the completed application specification.

## Context and before state

[Planner vocabulary](planner-vocabulary.md) fixes stable item identity, shared category/tag objects, and independent completion and archive states. The repository has no app, search implementation or approved public code-test seams. The original brief requires fast duration selection, global and list-local search, and composed filters. Before this round, duration meaning, filter composition, insensitive matching and the dedicated Done/Archive sections were unresolved.

The confirmed behavior below supplies concrete expected results for later `/tdd` work. The human accepted a native lexical baseline; selecting its storage/observation implementation and proving persistence, responsiveness, native controls and cross-device refresh remain separate work.

## Activity estimates and calendar spans

An activity's duration estimate describes how much time it takes. Calendar scheduling uses a span with actual dates or times. These concepts remain separate even when an estimate helps plan a span.

The human requires native pickers for hours/minutes, days, weeks, months and years, with one-minute precision and no raw duration input. Native hours/minutes controls support short estimates; quantity/unit controls support longer estimates. The exact picker arrangement, range and accessible interaction must be demonstrated on each platform in [Navigation prototype](https://github.com/dvcol/planner/issues/14).

Activity units have accepted fixed elapsed-time conversions, independent of a start date:

| Estimate unit | Fixed value | Comparable minutes |
| --- | --- | --- |
| Minute | 1 minute | 1 |
| Hour | 60 minutes | 60 |
| Day | 24 hours | 1,440 |
| Week | 7 days | 10,080 |
| Month | 30 days | 43,200 |
| Year | 365 days | 525,600 |

These are estimate units, not calendar arithmetic. For example, two days compare as 2,880 minutes even across daylight saving; a scheduled span still uses actual dates. Twelve estimate months equal 360 days, while one estimate year equals 365 days. Preserve the chosen human representation rather than silently rounding one into the other. The storage schema and numeric validation limits belong to Core architecture.

Named shortcuts are half-day = 12 hours / 720 minutes, full-day = 24 hours / 1,440 minutes, and weekend = 48 hours / 2,880 minutes. Known estimates must be positive whole minutes. Zero is invalid; No estimate clears the optional value. Picker controls must make both ordinary selection and explicit clearing possible without raw duration input. Reject an invalid command value rather than silently converting zero to unknown or rounding it to a positive estimate.

A maximum-duration filter is an inclusive comparison, such as "activities taking up to two hours." An estimate of exactly 120 minutes matches. Unknown estimates are excluded while a duration constraint is enabled unless the human explicitly enables Include unknown estimates. Without a duration constraint, an unknown estimate imposes no exclusion. The filter does not impose a maximum schedule length or picker value.

| Before state and action | Expected matching item identities |
| --- | --- |
| Ordinary scope; Food plus maximum two hours | A, B, C |
| Enable Include unknown estimates in that query | A, B, C, E |
| Clear only the maximum, keeping Food | A, B, C, D, E |
| Ordinary scope; maximum two hours without a category | A, B, C |
| Enable Include unknown estimates without a category | A, B, C, E, F |
| Both state filters Any; maximum two hours | A, B, C, G, H, I |
| Done section; maximum two hours | G, I |
| Archive section; maximum two hours | H, I |

## Cumulative filter composition

Each enabled filter group narrows the current results. Text, categories, tags, duration, membership, completion, archive state and the other supported groups combine with AND. Clearing one group removes only that constraint. An empty group imposes no restriction.

Category, tag and multiple-list selections support Any or All within that group, defaulting to Any. Any admits an item matching at least one selected object. All requires it to match every selected object. Selected categories, tags and lists are identified by their shared identity rather than copied names.

Common filters should be available through a native dropdown, menu or popover alongside simple search. The human suggested categories, tags and duration as common controls. The exact control arrangement belongs to Navigation prototype; both simple and advanced controls must express the same query meaning.

| Before state and action | Expected matching item identities |
| --- | --- |
| Ordinary todo + active scope; no other constraints | A, B, C, D, E, F |
| Add Food category | A, B, C, D, E |
| Add rainy-day tag to Food | A, C |
| Clear only Food, keeping rainy-day | A, C, F |
| Food plus Any of rainy-day and reservation-required | A, C, D |
| Change that tag group from Any to All | C |
| Any of Food and Museum categories, ordinary scope | A, B, C, D, E, F |
| All of Food and Museum categories, ordinary scope | None; each fixture has only one category |
| Any of Tokyo Food and Wishlist memberships, ordinary scope | A, B, C, D, F |
| All of those memberships, ordinary scope | A |
| Add has-address and has-links, ordinary scope | A, F |
| Add Food to those address/link constraints | A |

These are sets; the accepted sort rules determine their order.

## Text matching

Matching is case- and accent-insensitive. All typed words must match, and they may match across different searchable fields of the same item. The accepted fields are title, subtitle, notes, current category/tag names, link labels and URLs, and saved location text. A shared-label rename therefore changes searchable text immediately without changing the item's identity or its selected label filter.

Split the query at whitespace, discard empty parts, and require every remaining part to match as a substring. Keep punctuation literal. For example, `rainy-day` is one part, `/ramen` matches a saved URL, and `museum` matches `Museums`. Repeated whitespace, tabs and newlines do not add constraints. Empty or whitespace-only text imposes no text restriction. There is no special text-query operator or wildcard grammar; the native filter controls provide advanced composition.

Matching must be consistent across device languages. Core architecture must choose an explicit Foundation comparison/normalization policy and test it rather than rely on each device's current locale defaults. The required case/accent and literal-punctuation examples are the public behavior; the exact API and any internal cache remain implementation choices. Preserve original text for display.

The human accepted a reliable native lexical baseline for the first daily-use release. [Native search capabilities](https://github.com/dvcol/planner/issues/19) documents that path and the limits of indexed/semantic alternatives. Fuzzy/semantic expansion is deferred until concrete missing-search examples justify a new decision. No typo correction, synonym expansion, third-party fuzzy library or system-index dependency is required by this baseline. All control surfaces must retain these lexical and structured-filter semantics.

| Before state and action | Expected matching item identities |
| --- | --- |
| Ordinary scope; query `cafe` | C |
| Same query with both completion and archive filters set to Any | C, G |
| Ordinary scope; query `CAFÉ` | C |
| Ordinary scope; query `vegetarian menu` | A; one word is in notes, the other in a link label |
| Ordinary scope; query `Ginza` | A |
| Ordinary scope; query `rainy-day` | A, C, F |
| Ordinary scope; query `/ramen` | A |
| Ordinary scope; query `rainy*` | None; the asterisk is literal |
| Ordinary scope; query `cfae` or `meal` | None; no typo or synonym expansion |
| Ordinary scope; empty or whitespace-only text | A, B, C, D, E, F |
| Ordinary scope; query `Food` before renaming the shared category | A, B, C, D, E |
| Rename Food to Dining; keep an ID-based filter on that category | A, B, C, D, E |
| After the rename, ordinary scope; query `Dining` | A, B, C, D, E |
| After the rename, all states; query `Dining` | A, B, C, D, E, G, I |

The item's list memberships are not searchable fields in this accepted field set. Consequently `Food` after the category rename has no lexical match merely because a list is named Tokyo Food. Any future broader matching must have its own approved examples.

## Completion, archive and scope

Ordinary todo views initialize completion to Todo and archive state to Active. Done initializes completion to Done and archive state to Any, so it includes archived completed items. Archive initializes archive state to Archived and completion to Any, so it includes both todo and done items. These are independently editable state filters. Search inherits the selected view's filters and displays the current scope.

The later [Completion scopes and derived progress](https://github.com/dvcol/planner/issues/22) clarification adds contextual completion. Global item views use the source's global completion; a list/itinerary item view uses its effective contextual completion. Local completion alone does not change the global source or other contexts. See [Completion scopes](completion-scopes.md) for the accepted override/restore rule and exact local-state query fixtures. The original fixture observations remain valid with explicitly Todo contextual states; additional local-state examples must be tested separately.

| Before state and action | Expected matching item identities |
| --- | --- |
| Open Done without other constraints | G, I |
| Open Archive without other constraints | H, I |
| In Done, narrow archive state to Active | G |
| In Archive, narrow completion to Todo | H |
| Ordinary scope; choose Tokyo Food list | A, B, C, D |
| Ordinary scope; switch to global All Items | A, B, C, D, E, F, each once |
| Ordinary scope; choose Inbox | E |
| Inbox with both state filters set to Any | E, I |

Global scope spans all lists and unlisted retained items. An item appears once even when it has several memberships. List scope restricts results to that list. Searching and changing scope must not modify memberships, completion or archiving.

## Sort controls

The human accepted Title, Created date, Last updated and Duration, plus Manual within lists. Title/date/duration modes have ascending/descending controls. Chronological distinguishes creation from last update; scheduled-date ordering belongs to calendar views and is defined in Itineraries and scheduling. Lists initially use saved Manual order; global results initially use Title ascending. Remember the chosen mode/direction per list identity and for the global view across reopening. A list rename must not reset its sort choice. Accepted A2 in [Core architecture](core-architecture.md) makes these display preferences per device; saved Manual order remains shared data. A6 defines Item Last updated as changes to the Item's own content, label associations, global completion or archive state, excluding contextual organization/completion and shared-label renames.

Unestimated items remain last in duration sorting in both directions. For equal primary values, order by title ascending, then stable item identity ascending; identical titles therefore have a deterministic final tie-break. Title ordering must use a consistent comparison/collation policy selected in Core architecture, including case/accent equivalence and duplicate-title tests. The fixture sequences below are the expected order for the supplied titles and dates.

Changing sort order changes the presentation sequence, not the matching identity set, manual memberships/order, completion or archive state. Switching back to Manual restores the saved list order. The UI treatment of direction and reordering in Manual mode belongs to Navigation prototype; a temporary duration, date or alphabetical sort must not silently rewrite a list.

| Scope and selected order | Expected ordered fixture identities |
| --- | --- |
| Ordinary global scope; Title ascending, the initial default | C, D, F, A, B, E |
| Ordinary global scope; Title descending | E, B, A, F, D, C |
| Ordinary global scope; Created ascending / descending | A, B, C, D, E, F / F, E, D, C, B, A |
| Ordinary global scope; Last updated ascending / descending | D, B, A, C, F, E / F, E, C, A, B, D |
| Ordinary global scope; Duration ascending | A, B, C, D, F, E |
| Ordinary global scope; Duration descending | D, C, B, A, F, E |
| Both state filters Any; Duration ascending | I, A, H, G, B, C, D, F, E |
| Both state filters Any; Duration descending | D, C, H, G, B, I, A, F, E |
| Tokyo Food ordinary scope; initial Manual order | D, A, C, B |
| That list; choose Title ascending, then return to Manual | C, D, A, B, then D, A, C, B |
| Tokyo Food, both state filters Any; Mac Duration ascending and iPhone Manual under architecture A2 | Mac A, G, B, C, D; iPhone D, G, A, C, B. Relaunch/List rename retains each device's choice and the saved Manual order. |

The timestamp/manual-order fixture inputs are specified in search-fixtures.md. These are independent worked expectations, not output copied from an implementation.

## Responsiveness and long lists

The human approved 5,000 items and 200 lists as an acceptance-test dataset, with current filtered results visible within 300 ms after final input on iPhone, iPad and Mac, and smooth scrolling. This is a measured acceptance gate, not an observed result or a maximum storage size. Include debounce, query work, fetching and first-visible-result rendering in the elapsed measurement.

The human requests infinite loading with moving windows or virtual scrolling where possible. Prefer native mechanisms that render/load the visible rows and necessary surrounding content. The completed [Native long-list capabilities](https://github.com/dvcol/planner/issues/20) research distinguishes lazy row rendering from bounded data fetching and documents each platform's capabilities. Core architecture chooses the data/query strategy; Navigation prototype measures and demonstrates it. No custom pagination layer, window size or memory budget is selected by this document.

Every filter and sort applies to the complete selected scope, including items beyond the visible or initially fetched rows. Loading optimization must preserve the complete logical ordered result, stable identities, selected item and independently editable filters. Traversing the result forward and back must not skip or duplicate matching items. Obsolete query results must not replace the current query after a filter/sort change. The architecture must specify refresh behavior during concurrent edits and then verify it through real-store and UI tests.

## Required implementation tests

The rows above are independently specified unit-test expectations for the future public query interface, not tests already written or passed. Before writing code, confirm the public duration-comparison and query seams under `/tdd`, then work one failing behavior and its minimum passing implementation at a time.

- Unit tests must cover every accepted set and ordered sequence, empty and conflicting filter groups, Any/All selection, distinct identity, insensitive literal matching across fields, whitespace/punctuation cases, independent state filters and shared-label renames. Test every fixed unit/shortcut conversion, one-minute precision, positive/zero/clearing behavior, 119/120/121-minute boundaries, unknown exclusion/inclusion, both sort directions and duplicate-title identity ties. Assert literal typo/synonym exclusions; no fuzzy behavior is implemented in this baseline.
- Integration tests must save the fixture identities and relationships in a real temporary store, reopen it and reproduce the accepted results, estimates, manual order and per-view sort choices. Rename a list without losing its chosen sort. Rename the shared category and verify ID-based filters remain selected while current text matches change. Local and remote edits must refresh results under the policy decided by [Core architecture](https://github.com/dvcol/planner/issues/12).
- UI tests must compare simple and advanced controls, clear only one constraint, show global/list scope and both state filters, and choose/edit estimates with native pickers. Verify the sort selector/direction controls, accessible names, keyboard operation on Mac and native layouts on all devices through Navigation prototype.
- Any future index or fuzzy candidate needs a new accepted behavior contract and its own stale/fresh-entry, cancellation and matching tests. It must not bypass current structured filters or replace authoritative item data; it is not a required dependency of this lexical baseline.
- Window/paging tests must compare the traversed identities with the complete logical result, find a sole match beyond the initial window, revisit earlier rows without lost selection or duplicates, and ignore results from an obsolete query. Real-store mutation tests must use the refresh/cursor policy accepted in Core architecture.
- Performance tests must use 5,000 items and 200 lists and measure the approved 300 ms final-input-to-current-results-visible target on iPhone, iPad and Mac. Record cold/warm searches, supported sorts, scrolling hitches and peak/steady memory through repeated traversal. No responsiveness, memory or smooth-scrolling result has been measured yet.
- Scheduled/unscheduled predicates and date-aware calendar spans depend on [Itineraries and scheduling](https://github.com/dvcol/planner/issues/9). That ticket must specify exact reference, date and time-zone examples before implementation. Capture and provider-retention rules continue to govern which location text is saved.

## Downstream ownership

The human has confirmed all choices in this ticket. The following implementation and dependent-domain work remains in its named owner:

- Core architecture chooses storage/display representation, numeric representability limits, local preference storage/account scope, explicit Foundation matching/title comparison, actor/observation ownership and the complete-scope loading/refresh contract. Accepted A2 fixes per-device sort scope, A3 fixes valid selection during refresh and A6 fixes Item Last updated meaning. The remaining choices must preserve this record's exact public behavior and ordered examples.
- Core architecture and [Shared command contracts](https://github.com/dvcol/planner/issues/13) propose and confirm public duration, query and sorting interfaces before implementation tests under `/tdd`. This decision writes no code and does not claim that signatures were approved.
- Navigation prototype owns native picker range/interaction, filter/sort control layout, Manual-mode interaction, selection/anchor behavior and measured scrolling/memory/latency evidence on all devices.
- Itineraries and scheduling defines calendar spans, scheduled-date sorting, and scheduled/unscheduled predicates with exact reference/date/time-zone examples. Their groups use the accepted cumulative composition.
- [Offline conflicts and recovery](https://github.com/dvcol/planner/issues/10) defines deletion/conflict behavior for references and selected label/list identities. Category/tag renames preserve selections and refresh current text as specified here.
- Fuzzy/semantic matching is deferred until a demonstrated search gap justifies a new decision; it is not unresolved work required to implement this accepted baseline.

## Validation status

This decision changes planning documents only. The actual checks are affected Markdown lint, local-link checks, whitespace checks and committed-artifact inspection. Swift type checks and application tests are inapplicable because no Swift implementation exists. Product choices and concrete acceptance examples are confirmed; downstream runtime obligations remain explicit and unexecuted.
