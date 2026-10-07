# Duration and search fixtures

Discussion inputs for [Duration and search](https://github.com/dvcol/planner/issues/8), prepared on 2026-10-08 after [Planner vocabulary](planner-vocabulary.md) was accepted. These are fictional local fixtures, not captured provider data or passing application tests. They make the remaining duration/filter choices concrete without selecting their outcomes for the human.

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

The estimates above use only unambiguous minutes/hours. The meaning of day, half-day, weekend, week and month remains a human decision; this dataset does not assign them numeric defaults.

A has a manually entered address `Ginza fixture address`, notes `Check vegetarian options` and a link labelled `Menu` at `https://example.com/ramen`. F has a manually entered address `Museum fixture address` and a link labelled `Museum website` at `https://example.com/museum`. The other items have no address or links. These are exact test strings and do not claim real venue addresses or URLs.

## Already fixed observations

The accepted vocabulary supplies these outcomes independently of the remaining search choices:

- There are nine item identities. Global scope must not duplicate A or C because each has two memberships.
- Ordinary todo + active scope can show A, B, C, D, E and F. G is done; H is archived; I is both done and archived.
- E and I have no memberships and remain retained items. They can be found in Inbox/All Items when the corresponding state filters permit them.
- A category rename `Food` to `Dining` updates A, B, C, D, E, G and I through the same category object. Their identities, state pairs and memberships remain intact.

## Outcomes still to decide

| Scenario | Known distinction to resolve |
| --- | --- |
| Food plus a two-hour maximum in ordinary todo scope | A and B are below the limit, C is exactly at it, D exceeds it, and E has no estimate. Decide inclusive boundaries and unknown handling. |
| Food plus rainy-day and reservation-required tags | C has both tags; A has only rainy-day and D only reservation-required. Choose any/all matching and its default. |
| Search text `cafe` | C and G use an accented spelling. Decide case/accent matching and how the selected state scope controls results. |
| Search text `vegetarian menu` | A splits these words between notes and a link label. Decide token matching across searchable fields. |
| Search `Ginza` or filter has-address/has-links | A supplies the exact address text, while A/F have addresses and links. Define text fields and boolean filter combinations. |
| Done and Archive sections | G is done + active, H todo + archived, I done + archived. Decide whether I appears in both dedicated sections and how each section initializes filters. |
| Global versus Tokyo Food scope | E belongs to no list; A belongs to two. Define explicit scope, unchanged item identity and user-visible scope controls. |
| Shared category rename while a category filter is selected | The filter refers to the same category object. Define text matching after the rename and refresh behavior without stale copied labels. |

The accepted ticket resolution will supply exact expected sets for these cases and the remaining duration/sort/performance examples. Query results, real-store reopening, UI controls and remote-change refresh must later agree on that one meaning. This document does not invent expected results where the human's answer is still pending.
