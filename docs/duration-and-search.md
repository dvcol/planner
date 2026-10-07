# Duration and search

Working record for [Duration and search](https://github.com/dvcol/planner/issues/8), updated on 2026-10-08. The human confirmed the choices below after reviewing the [nine-item fixtures](search-fixtures.md). The ticket remains open for the questions listed at the end. This document is a partial decision record, not a completed specification or evidence of an executable search implementation.

## Context and before state

[Planner vocabulary](planner-vocabulary.md) fixes stable item identity, shared category/tag objects, and independent completion and archive states. The repository has no app, search implementation or approved public code-test seams. The original brief requires fast duration selection, global and list-local search, and composed filters. Before this round, duration meaning, filter composition, insensitive matching and the dedicated Done/Archive sections were unresolved.

The confirmed behavior below supplies concrete expected results for later `/tdd` work. Choosing an engine and proving persistence, responsiveness, native controls and cross-device refresh remain separate work.

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

These are estimate units, not calendar arithmetic. For example, two days compare as 2,880 minutes even across daylight saving; a scheduled span still uses actual dates. Twelve estimate months equal 360 days, while one estimate year equals 365 days. Preserve the chosen human representation rather than silently rounding one into the other. Half-day/full-day/weekend shortcut values still need confirmation. The storage schema and numeric validation limits belong to Core architecture.

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

These are sets; the remaining sort choices determine their order.

## Text matching

Matching is case- and accent-insensitive. All typed words must match, and they may match across different searchable fields of the same item. The accepted fields are title, subtitle, notes, current category/tag names, link labels and URLs, and saved location text. A shared-label rename therefore changes searchable text immediately without changing the item's identity or its selected label filter.

The human permits fuzzy matching through native APIs or a well-tested, widely used library and prefers an out-of-the-box capability. The completed [Native search capabilities](https://github.com/dvcol/planner/issues/19) research documents a native lexical path and the limits of indexed/semantic alternatives. Typo behavior, tokenization details and indexed-query semantics are not inferred from that permission. The required insensitive lexical matches below must survive any engine choice.

| Before state and action | Expected matching item identities |
| --- | --- |
| Ordinary scope; query `cafe` | C |
| Same query with both completion and archive filters set to Any | C, G |
| Ordinary scope; query `CAFÉ` | C |
| Ordinary scope; query `vegetarian menu` | A; one word is in notes, the other in a link label |
| Ordinary scope; query `Ginza` | A |
| Ordinary scope; query `Food` before renaming the shared category | A, B, C, D, E |
| Rename Food to Dining; keep an ID-based filter on that category | A, B, C, D, E |
| After the rename, ordinary scope; query `Dining` | A, B, C, D, E |
| After the rename, all states; query `Dining` | A, B, C, D, E, G, I |

The item's list memberships are not searchable fields in this accepted field set. Consequently `Food` after the category rename has no required lexical match merely because a list is named Tokyo Food. Any broader or fuzzy matching must have its own approved examples.

## Completion, archive and scope

Ordinary todo views initialize completion to Todo and archive state to Active. Done initializes completion to Done and archive state to Any, so it includes archived completed items. Archive initializes archive state to Archived and completion to Any, so it includes both todo and done items. These are independently editable state filters. Search inherits the selected view's filters and displays the current scope.

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

The human requires a native sort selector with alphabetical, chronological and duration choices, plus ascending/descending controls. A single fixed order is insufficient. The next live round asks which dates chronological sorting uses, the available modes/defaults, whether selections persist by view, and placement of unknown estimates. Stable tie behavior and exact ordered fixture results must be specified before sorting is implemented.

Changing sort order changes the presentation sequence, not the matching identity set, manual memberships/order, completion or archive state. An explicit Manual option and its interaction with saved list order are still a proposal; a temporary duration or alphabetical sort must not silently rewrite a list.

## Responsiveness and long lists

The human approved 5,000 items and 200 lists as an acceptance-test dataset, with current filtered results visible within 300 ms after final input on iPhone, iPad and Mac, and smooth scrolling. This is a measured acceptance gate, not an observed result or a maximum storage size. Include debounce, query work, fetching and first-visible-result rendering in the elapsed measurement.

The human requests infinite loading with moving windows or virtual scrolling where possible. Prefer native mechanisms that render/load the visible rows and necessary surrounding content. [Native long-list capabilities](https://github.com/dvcol/planner/issues/20) investigates the distinction between lazy row rendering and bounded data fetching, and what each platform documents. Core architecture chooses the data/query strategy; Navigation prototype measures and demonstrates it. No custom pagination layer, window size or memory budget is selected by this document.

Every filter and sort applies to the complete selected scope, including items beyond the visible or initially fetched rows. Loading optimization must preserve the complete logical ordered result, stable identities, selected item and independently editable filters. Traversing the result forward and back must not skip or duplicate matching items. Obsolete query results must not replace the current query after a filter/sort change. The architecture must specify refresh behavior during concurrent edits and then verify it through real-store and UI tests.

## Required implementation tests

The rows above are independently specified unit-test expectations for the future public query interface, not tests already written or passed. Before writing code, confirm the public duration-comparison and query seams under `/tdd`, then work one failing behavior and its minimum passing implementation at a time.

- Unit tests must cover each accepted result set, empty and conflicting filter groups, Any/All selection, distinct identity, insensitive matching across fields, independent state filters and shared-label rename behavior. Test each fixed unit conversion and one-minute precision, 119/120/121-minute maximum boundaries, unknown exclusion/inclusion and clearing the duration constraint. Add approved shortcut, sort and typo examples before those behaviors are implemented.
- Integration tests must save the fixture identities and relationships in a real temporary store, reopen it and reproduce the accepted results. Rename the shared category and verify ID-based filters remain selected while current text matches change. Local and remote edits must refresh results under the policy decided by [Core architecture](https://github.com/dvcol/planner/issues/12).
- UI tests must compare simple and advanced controls, clear only one constraint, show global/list scope and both state filters, and choose/edit estimates with native pickers. Verify the sort selector/direction controls, accessible names, keyboard operation on Mac and native layouts on all devices through Navigation prototype.
- A selected index or fuzzy candidate needs its own tests for stale entries, cancellation and typo outcomes. It must not bypass current structured filters or replace the authoritative item data.
- Window/paging tests must compare the traversed identities with the complete logical result, find a sole match beyond the initial window, revisit earlier rows without lost selection or duplicates, and ignore results from an obsolete query. Real-store mutation tests must use the refresh/cursor policy accepted in Core architecture.
- Performance tests must use 5,000 items and 200 lists and measure the approved 300 ms final-input-to-current-results-visible target on iPhone, iPad and Mac. Record cold/warm searches, supported sorts, scrolling hitches and peak/steady memory through repeated traversal. No responsiveness, memory or smooth-scrolling result has been measured yet.
- Scheduled/unscheduled predicates and date-aware calendar spans depend on [Itineraries and scheduling](https://github.com/dvcol/planner/issues/9). That ticket must specify exact reference, date and time-zone examples before implementation. Capture and provider-retention rules continue to govern which location text is saved.

## Remaining decisions

- Native picker range and detailed interaction belong to Navigation prototype; storage/display representation and numeric validation limits belong to Core architecture. One-minute precision and all named units are accepted.
- Values and labels for half-day, full-day and weekend shortcuts from the brief.
- Positive/zero estimate validation and explicit clearing behavior.
- Default order within a list and globally, supported alternate sorts and stable tie handling.
- Query tokenization/locale policy and whether a fuzzy gap must be addressed in the first release.
- Native long-list implementation details and measured proof belong to Core architecture and Navigation prototype, using the new research report.
- Final shared-understanding confirmation and any public test seams needed before code-producing work.

## Validation status

This round changes planning documents only. The actual checks are affected Markdown lint, local-link checks, whitespace checks and committed-artifact inspection. Swift type checks and application tests are inapplicable because no Swift implementation exists. The decision ticket closes only after its remaining product choices and acceptance examples are confirmed; downstream runtime obligations remain explicit.
