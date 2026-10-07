# Duration and search fixtures

Discussion inputs for [Duration and search](https://github.com/dvcol/planner/issues/8), prepared on 2026-10-08 after [Planner vocabulary](planner-vocabulary.md) was accepted. These are fictional local fixtures, not captured provider data or passing application tests. [Duration and search](duration-and-search.md) records the human's confirmed query choices and the remaining decisions.

There is no application or approved public code-test interface yet. The ticket must settle duration normalization, matching, filter composition, section defaults, sorting and measurable responsiveness before implementation expectations are complete. Later `/tdd` tests use confirmed public seams, one failing behavior and its minimum passing implementation at a time.

## Initial dataset

Each letter denotes one distinct item identity. A runnable prototype must assign and preserve stable UUIDs for these items and the referenced lists/categories/tags. `Food`, `Museum` and `Shopping` each denote one shared category object, and repeated tag names denote the same shared tag object.

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

The estimates above use only unambiguous minutes/hours. The meaning of day, half-day, weekend, week, month and year remains a human decision; this dataset does not assign them numeric defaults. The human requires native pickers for activity estimates, while calendar scheduling uses spans.

A has a manually entered address `Ginza fixture address`, notes `Check vegetarian options` and a link labelled `Menu` at `https://example.com/ramen`. F has a manually entered address `Museum fixture address` and a link labelled `Museum website` at `https://example.com/museum`. The other items have no address or links. These are exact test strings and do not claim real venue addresses or URLs.

## Already fixed observations

The accepted vocabulary supplies these outcomes independently of the remaining search choices:

- There are nine item identities. Global scope must not duplicate A or C because each has two memberships.
- Ordinary todo + active scope can show A, B, C, D, E and F. G is done; H is archived; I is both done and archived.
- E and I have no memberships and remain retained items. They can be found in Inbox/All Items when the corresponding state filters permit them.
- A category rename `Food` to `Dining` updates A, B, C, D, E, G and I through the same category object. Their identities, state pairs and memberships remain intact.

## Scenario coverage

| Scenario | Known distinction to resolve |
| --- | --- |
| Food plus a two-hour maximum in ordinary todo scope | A and B are below the limit, C is exactly at it, D exceeds it, and E has no estimate. Decide inclusive boundaries and unknown handling. |
| Food plus rainy-day and reservation-required tags | Any returns A/C/D; All returns C in ordinary scope. Any is the confirmed default; groups narrow cumulatively. |
| Search text `cafe` | Insensitive matching returns C in ordinary scope and C/G when both state filters are Any. |
| Search text `vegetarian menu` | All words may match across fields of one item, so A matches notes plus link label. |
| Search `Ginza` or filter has-address/has-links | Saved address text matches A; requiring both an address and links returns A/F in ordinary scope. |
| Done and Archive sections | Done includes G/I; Archive includes H/I. Completion and archive filters remain independent. |
| Global versus Tokyo Food scope | Ordinary global scope returns A/B/C/D/E/F once each; Tokyo Food returns A/B/C/D. |
| Shared category rename while a category filter is selected | ID-based selection is unchanged; the current name Dining participates in text matching. See the exact state-scoped sets in the partial decision record. |

The partial decision record supplies the confirmed expected sets. The final ticket resolution must add duration/sort/performance and engine-dependent examples after the human decides them. Query results, real-store reopening, UI controls and remote-change refresh must later agree on that one meaning. Pending decisions are not executable test expectations yet.
