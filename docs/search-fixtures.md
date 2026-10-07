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

The estimates above use minutes/hours. The human has now approved fixed day/week/month/year estimate units of 24 hours / 7 days / 30 days / 365 days, with native pickers and one-minute precision. Calendar scheduling uses actual spans. Half-day/full-day/weekend shortcut values remain a human decision. The [partial decision record](duration-and-search.md) gives exact normalization and maximum/unknown results.

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
| Food plus a two-hour maximum in ordinary todo scope | The inclusive maximum returns A/B/C; enabling Include unknown estimates adds E. D exceeds the maximum. Clearing only the duration group returns A/B/C/D/E. |
| Food plus rainy-day and reservation-required tags | Any returns A/C/D; All returns C in ordinary scope. Any is the confirmed default; groups narrow cumulatively. |
| Search text `cafe` | Insensitive matching returns C in ordinary scope and C/G when both state filters are Any. |
| Search text `vegetarian menu` | All words may match across fields of one item, so A matches notes plus link label. |
| Search `Ginza` or filter has-address/has-links | Saved address text matches A; requiring both an address and links returns A/F in ordinary scope. |
| Done and Archive sections | Done includes G/I; Archive includes H/I. Completion and archive filters remain independent. |
| Global versus Tokyo Food scope | Ordinary global scope returns A/B/C/D/E/F once each; Tokyo Food returns A/B/C/D. |
| Shared category rename while a category filter is selected | ID-based selection is unchanged; the current name Dining participates in text matching. See the exact state-scoped sets in the partial decision record. |

The partial decision record supplies the confirmed expected sets and the accepted 5,000-item / 200-list, 300 ms responsiveness target. The final ticket resolution must add shortcut/sort and engine-dependent examples after the human decides them. Query results, real-store reopening, UI controls and remote-change refresh must later agree on that one meaning. Pending decisions are not executable test expectations yet.

## Additional validation inputs

These cases are separate from the nine-item dataset above; they do not change its accepted identity sets.

- Maximum boundary: three ordinary items estimated at 119, 120 and 121 minutes. A 120-minute maximum includes the first two and excludes the third.
- One-minute precision: pick 1 hour and 31 minutes, save/reopen and compare as 91 minutes without rounding to a quarter hour. Clearing and zero behavior await the next answer.
- Fixed-unit comparison: two days are 2,880 minutes, one week is 10,080, one month is 43,200, one year is 525,600 and twelve months are 518,400. Calendar-span interpretation is independent.
- Ordered fixtures: add fixed created/updated timestamps and stable identity ties when chronological modes and tie behavior are confirmed. Assert exact sequences in both directions, including unknown estimates, without rewriting manual list order.
- Long-list completeness: use 5,000 stable item identities and 200 list identities. Put a sole text match beyond the initial row/data window; the complete-scope query still finds it. Traverse every matching result forward and back and compare against the independently specified sequence, once sorting/window policy is agreed.
- Window refresh: alter a matching item's title, category, duration or state while scrolled away. Test the architecture's approved refresh rule, cancellation and selection preservation rather than inventing a cursor/snapshot policy here.
