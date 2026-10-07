# Duration and search

Working record for [Duration and search](https://github.com/dvcol/planner/issues/8), updated on 2026-10-08. The human confirmed the choices below after reviewing the [nine-item fixtures](search-fixtures.md). The ticket remains open for the questions listed at the end. This document is a partial decision record, not a completed specification or evidence of an executable search implementation.

## Context and before state

[Planner vocabulary](planner-vocabulary.md) fixes stable item identity, shared category/tag objects, and independent completion and archive states. The repository has no app, search implementation or approved public code-test seams. The original brief requires fast duration selection, global and list-local search, and composed filters. Before this round, duration meaning, filter composition, insensitive matching and the dedicated Done/Archive sections were unresolved.

The confirmed behavior below supplies concrete expected results for later `/tdd` work. Choosing an engine and proving persistence, responsiveness, native controls and cross-device refresh remain separate work.

## Activity estimates and calendar spans

An activity's duration estimate describes how much time it takes. Calendar scheduling uses a span with actual dates or times. These concepts remain separate even when an estimate helps plan a span.

The human requires native pickers for hours, days, weeks, months and years, with no raw duration input. The brief's sub-hour estimates remain in scope. Minute precision and the exact picker arrangement are awaiting confirmation. The native layout and accessibility of these controls must be demonstrated on each platform in [Navigation prototype](https://github.com/dvcol/planner/issues/14).

No day/week/month/year conversion or half-day/weekend preset value is accepted yet. A maximum-duration filter is a comparison, such as "activities taking up to two hours"; it does not impose a maximum schedule length or picker value. Inclusion at the exact boundary and treatment of unknown estimates remain open.

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

These are sets; result ordering remains a separate open choice.

## Text matching

Matching is case- and accent-insensitive. All typed words must match, and they may match across different searchable fields of the same item. The accepted fields are title, subtitle, notes, current category/tag names, link labels and URLs, and saved location text. A shared-label rename therefore changes searchable text immediately without changing the item's identity or its selected label filter.

The human permits fuzzy matching through native APIs or a well-tested, widely used library and prefers an out-of-the-box capability. [Native search capabilities](https://github.com/dvcol/planner/issues/19) investigates those facts. Typo behavior, tokenization details and indexed-query semantics are not inferred from that permission. The required insensitive lexical matches below must survive any engine choice.

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

## Required implementation tests

The rows above are independently specified unit-test expectations for the future public query interface, not tests already written or passed. Before writing code, confirm the public duration-comparison and query seams under `/tdd`, then work one failing behavior and its minimum passing implementation at a time.

- Unit tests must cover each accepted result set, empty and conflicting filter groups, Any/All selection, distinct identity, insensitive matching across fields, independent state filters and shared-label rename behavior. Add approved duration boundary, unknown, normalization, sorting and typo examples before those behaviors are implemented.
- Integration tests must save the fixture identities and relationships in a real temporary store, reopen it and reproduce the accepted results. Rename the shared category and verify ID-based filters remain selected while current text matches change. Local and remote edits must refresh results under the policy decided by [Core architecture](https://github.com/dvcol/planner/issues/12).
- UI tests must compare simple and advanced controls, clear only one constraint, show global/list scope and both state filters, and choose/edit estimates with native pickers. Verify accessible names, keyboard operation on Mac and native layouts on all devices through Navigation prototype.
- A selected index or fuzzy candidate needs its own tests for stale entries, cancellation and typo outcomes. It must not bypass current structured filters or replace the authoritative item data.
- Performance tests must use a human-approved dataset and latency budget on iPhone, iPad and Mac. No responsiveness or smooth-scrolling result has been measured yet.
- Scheduled/unscheduled predicates and date-aware calendar spans depend on [Itineraries and scheduling](https://github.com/dvcol/planner/issues/9). That ticket must specify exact reference, date and time-zone examples before implementation. Capture and provider-retention rules continue to govern which location text is saved.

## Remaining decisions

- Fixed conversions for activity day/week/month/year, or another explicit interpretation.
- Native picker precision, range and representation; the human has required year support as well as the shorter units.
- Values and labels for half-day, full-day and weekend shortcuts from the brief.
- Maximum boundary and unknown-estimate inclusion.
- Default order within a list and globally, supported alternate sorts and stable tie handling.
- Measurable query/scrolling acceptance budget and dataset scale.
- Native matching capabilities, any fuzzy behavior, and query tokenization after the research report.
- Final shared-understanding confirmation and any public test seams needed before code-producing work.

## Validation status

This round changes planning documents only. The actual checks are affected Markdown lint, local-link checks, whitespace checks and committed-artifact inspection. Swift type checks and application tests are inapplicable because no Swift implementation exists. The decision ticket closes only after its remaining product choices and acceptance examples are confirmed; downstream runtime obligations remain explicit.
