# Duration and search fixtures

Accepted inputs for [Duration and search](https://github.com/dvcol/planner/issues/8), finalized on 2026-10-08 after [Planner vocabulary](planner-vocabulary.md) was accepted. These are fictional local fixtures, not captured provider data or passing application tests. [Duration and search](duration-and-search.md) records the human's confirmed query, sort and duration choices and assigns downstream implementation work.

There is no application or approved public code-test interface yet. Duration normalization, matching, filter composition, section defaults, sorting and measurable responsiveness are accepted. Core architecture and Shared command contracts confirm the public interfaces before later `/tdd` tests, one failing behavior and its minimum passing implementation at a time.

## Initial dataset

Each letter denotes one distinct item identity. A runnable prototype must assign and preserve stable UUIDs for these items and the referenced lists/categories/tags. `Food`, `Museum` and `Shopping` each denote one shared category object, and repeated tag names denote the same shared tag object.

After the [Completion scopes and derived progress](https://github.com/dvcol/planner/issues/22) clarification, this baseline explicitly sets contextual completion to Todo for each referenced item, consistent with the accepted new-local-state rule. The completion column below is the global source state; effective contextual completion is global Done OR contextual Done. This preserves the accepted result sets/sequences. [Completion scopes](completion-scopes.md) supplies separate local-state cases, including Global Reopen revealing retained contextual completion.

| Fixture | Item, category and tags | Estimated minutes | Completion / archive | Lists |
| --- | --- | --- | --- | --- |
| A | `Ramen lunch`; Food; rainy-day | 30 | Todo / active | Tokyo Food, Wishlist |
| B | `Rooftop brunch`; Food; outdoor | 60 | Todo / active | Tokyo Food |
| C | `Café tasting`; Food; rainy-day, reservation-required | 120 | Todo / active | Tokyo Food, Weekend |
| D | `Dinner reservation`; Food; reservation-required | 180 | Todo / active | Tokyo Food |
| E | `Unestimated lunch`; Food; no tags | Unknown | Todo / active | None |
| F | `Nezu Museum`; Museum; rainy-day | Unknown | Todo / active | Wishlist |
| G | `Finished café`; Food; rainy-day | 60 | Done / active | Tokyo Food |
| H | `Archived shop`; Shopping; ceramics | 60 | Todo / archived | Tokyo Shopping |
| I | `Finished archived dinner`; Food; outdoor | 30 | Done / archived | None |

The estimates above use minutes/hours. Fixed day/week/month/year estimate units are 24 hours / 7 days / 30 days / 365 days, with native pickers and one-minute precision. Half-day/full-day/weekend shortcuts are 12 / 24 / 48 hours. Known estimates are positive; No estimate clears the value. Calendar scheduling uses actual spans. The [accepted decision record](duration-and-search.md) gives exact normalization and maximum/unknown results.

A has a manually entered address `Ginza fixture address`, notes `Check vegetarian options` and a link labelled `Menu` at `https://example.com/ramen`. F has a manually entered address `Museum fixture address` and a link labelled `Museum website` at `https://example.com/museum`. The other items have no address or links. These are exact test strings and do not claim real venue addresses or URLs.

## Sort inputs

Use these literal UTC timestamps as independent created/updated sort inputs. They do not change membership, state, duration or text. E/F deliberately share an updated timestamp, so their title tie-break is exercised.

| Fixture | Created at | Last updated at |
| --- | --- | --- |
| A | 2026-10-01T09:00:00Z | 2026-10-03T09:00:00Z |
| B | 2026-10-01T09:01:00Z | 2026-10-02T09:00:00Z |
| C | 2026-10-01T09:02:00Z | 2026-10-04T09:00:00Z |
| D | 2026-10-01T09:03:00Z | 2026-10-01T10:00:00Z |
| E | 2026-10-01T09:04:00Z | 2026-10-05T09:00:00Z |
| F | 2026-10-01T09:05:00Z | 2026-10-05T09:00:00Z |
| G | 2026-10-01T09:06:00Z | 2026-10-06T09:00:00Z |
| H | 2026-10-01T09:07:00Z | 2026-10-06T09:00:00Z |
| I | 2026-10-01T09:08:00Z | 2026-10-07T09:00:00Z |

Tokyo Food's saved Manual sequence is D, G, A, C, B. In ordinary todo + active scope it is D, A, C, B. Choosing another sort and switching back must recover that sequence without writing new manual positions. Saved per-list sort preferences use list identity and survive its rename/reopening. Accepted architecture A2 keeps display preferences per device: with both state filters Any, Mac Duration ascending returns A, G, B, C, D while iPhone Manual remains D, G, A, C, B. G precedes B at 60 minutes by title. Architecture A6 governs which subsequent mutations change Item Last updated; these initial timestamps remain literal independent fixture inputs.

## Already fixed observations

The accepted vocabulary supplies these outcomes independently of the remaining search choices:

- There are nine item identities. Global scope must not duplicate A or C because each has two memberships.
- Ordinary todo + active scope can show A, B, C, D, E and F. G is done; H is archived; I is both done and archived.
- E and I have no memberships and remain retained items. They can be found in Inbox/All Items when the corresponding state filters permit them.
- A category rename `Food` to `Dining` updates A, B, C, D, E, G and I through the same category object. Their identities, state pairs and memberships remain intact.

## Scenario coverage

| Scenario | Known distinction to resolve |
| --- | --- |
| Food plus a two-hour maximum in ordinary todo scope | The inclusive maximum returns A/B/C; enabling Include unknown estimates adds E. D exceeds the maximum. Clearing only the duration group returns A/B/C/D/E. |
| Food plus rainy-day and reservation-required tags | Any returns A/C/D; All returns C in ordinary scope. Any is the confirmed default; groups narrow cumulatively. |
| Search text `cafe` | Insensitive matching returns C in ordinary scope and C/G when both state filters are Any. |
| Search text `vegetarian menu` | All words may match across fields of one item, so A matches notes plus link label. |
| Search `Ginza` or filter has-address/has-links | Saved address text matches A; requiring both an address and links returns A/F in ordinary scope. |
| Done and Archive sections | Done includes G/I; Archive includes H/I. Completion and archive filters remain independent. |
| Global versus Tokyo Food scope | Ordinary global scope returns A/B/C/D/E/F once each; Tokyo Food returns A/B/C/D. |
| Shared category rename while a category filter is selected | ID-based selection is unchanged; the current name Dining participates in text matching. See the exact state-scoped sets in the accepted decision record. |

The accepted decision record supplies exact sets and ordered sequences and the 5,000-item / 200-list, 300 ms responsiveness target. Query results, real-store reopening, UI controls and remote-change refresh must later agree on that meaning. Loading/refresh implementation and public interfaces remain in their named downstream owners; no runtime result is claimed.

## Additional validation inputs

These cases are separate from the nine-item dataset above; they do not change its accepted identity sets.

- Maximum boundary: three ordinary items estimated at 119, 120 and 121 minutes. A 120-minute maximum includes the first two and excludes the third.
- One-minute precision: pick 1 hour and 31 minutes, save/reopen and compare as 91 minutes without rounding to a quarter hour. No estimate clears it; zero and negative command values are rejected without changing the existing estimate.
- Fixed-unit comparison: two days are 2,880 minutes, one week is 10,080, one month is 43,200, one year is 525,600 and twelve months are 518,400. Calendar-span interpretation is independent.
- Shortcuts: half-day is 720 minutes, full-day is 1,440 and weekend is 2,880. Choose/save/reopen each and compare against those literal amounts.
- Ordered fixtures: use the timestamp/manual inputs above and exact decision-record sequences. Unknown estimates are last in both duration directions; equal primary values use title ascending, then stable identity ascending, without rewriting manual list order.
- Identity tie: in an isolated dataset, two todo/active items titled `Same title` have 60-minute estimates and UUIDs `00000000-0000-0000-0000-000000000002` and `00000000-0000-0000-0000-000000000001`. Feed them in that order; both duration directions return the UUID ending in 1 first. Reopening and changing a row window preserve the order.
- Literal query: `vegetarian` followed by a tab/newline and `menu` matches A. `rainy-day` matches A/C/F in ordinary scope, `/ramen` matches A, and `rainy*`, `cfae` and `meal` match none. Empty/whitespace-only text leaves the other constraints intact. A decomposed-accent version of `Café` must have the same insensitive result as the precomposed version.
- Long-list completeness: use 5,000 stable item identities and 200 list identities. Put a sole text match beyond the initial row/data window; the complete-scope query still finds it. Traverse every matching result forward and back and compare against the independently specified sequence, once sorting/window policy is agreed.
- Window refresh: alter a matching item's title, category, duration or state while scrolled away. Test the architecture's approved refresh rule, cancellation and selection preservation rather than inventing a cursor/snapshot policy here.
