# Container estimates and calendar

## Context and before state

The native app can save timed and all-day assignments to Items and Itineraries, but has no Calendar destination or appointment grid. Lists and Itineraries lack overall estimate metadata. Existing progress counts effectively Done children, including hidden and archived appearances in the denominator. The latest accepted decisions amend that progress rule without changing stored Done flags. Implementation and native runtime qualification remain outstanding.

## Accepted goal and end state

Q60/Q61 require a main Calendar destination with Day, Week and Month modes, adapted to each platform through native tabs/sidebar navigation. Both Items and Itineraries retain their original identities and live content. Estimates never fill an absent Schedule end or change a booked instant. Apple Calendar export remains outside the map.

Q59/Q62 require full estimate and remaining time on Lists and Itineraries. Calculate automatically where unambiguous. Q63 counts each appearance, including intentional repeats and List expansions. Q64 shows a known subtotal and missing-estimate warning, with native duration pickers for an optional manual overall estimate. No raw duration inputs are introduced.

Q66 keeps a manual estimate until an explicit Use calculated estimate action. Q67 defines remaining as total minus completed estimates; the unallocated manual difference contributes while work remains and drops to zero once all children are finished. Full manual metadata stays intact. Q70 clamps a negative remaining result to zero, warns that completed estimates exceed the manual total, and keeps unfinished Items visibly unfinished.

Q65 excludes archived children from remaining time. Q68 counts archived children as finished in derived container progress without rewriting global or local Done flags. Q69 applies this retirement to an archived List branch inside an itinerary; an active direct appearance of the same Item remains independent. Unarchiving restores the retained completion behavior. Effective Done remains global Item Done OR appearance-local Done. Finished additionally accounts for the accepted archive context. Empty containers retain No items and are not completed.

Q71 uses a List's effective overall estimate once per List appearance in an itinerary. Its children are not added again. Deduct finished child estimates while the branch is partial; once all its itinerary appearances are finished, account for its whole effective List budget. Standalone List completion never substitutes for completion inside an itinerary.

Q72 B is accepted. An archived container keeps its own child-based progress while showing zero remaining time. Its archived branch still counts as finished in a parent itinerary. Archive changes neither child Done flags nor the full estimate. Missing estimates remain visibly uncertain; a manual total does not manufacture a shared Item estimate. Checked arithmetic must report an unavailable/uncertain aggregate rather than overflow or invent a duration.

## Concrete before and after fixtures

| Before and action | Required end state |
| --- | --- |
| Active List contains Museum 120 minutes and Lunch 60 minutes, both Todo. | Full automatic estimate 180 minutes; remaining 180; 0 of 2 finished. |
| Complete Museum locally in that List. | Full estimate remains 180; remaining 60; 1 of 2 finished. Item global Done and other contexts remain unchanged. |
| Archive Lunch while its global/local Done flags remain false. | Full estimate remains 180; remaining 0; 2 of 2 finished. Unarchive restores remaining 60 and 1 of 2 finished. |
| Same List has manual total 240 minutes. Itinerary adds this List and Hotel 30 minutes. | Itinerary calculated total is 270, not 450. Its own appearance completion determines remaining. |
| Complete only Museum inside that itinerary. | Completed contribution 120; remaining 150. Standalone List flags are unchanged. |
| Finish Lunch too, leaving Hotel unfinished. | Whole List budget 240 is accounted for; itinerary remaining is 30. |
| Set itinerary manual total to 300, with the List branch finished and Hotel Todo. | Remaining 60, including the unallocated manual difference. Finish Hotel: remaining and unallocated remaining difference become 0; manual total stays 300. |
| Two Hotel appearances each estimate 30 minutes; complete only one locally. | Both contribute to full estimate; only that appearance contributes to completed time. Global Done finishes both; global Reopen restores their retained local distinction. |
| Archive the referenced List while its Items remain active. | Its itinerary branch is finished with no remaining budget. A separate direct appearance of an active Todo Item remains unfinished. Unarchive restores the branch's retained flags. |
| Archive a List with two active Todo children. | Its own progress stays 0 of 2 finished and remaining is 0; its archived branch is finished inside an itinerary. Unarchive restores child-based remaining without changing Done flags. |
| Manual total 120; completed child estimates 180; another child remains Todo. | Estimated remaining is 0 with a warning. The plan remains unfinished; no negative duration or silent manual reset. |
| Museum estimate 120; Lunch has no estimate. | Show a known 120-minute subtotal and one missing estimate. The picker may set a manual overall estimate without changing Lunch's shared content. |
| Manual total 240; Lunch is finished with no estimate; Museum is unfinished with estimate 120. | Q76 A: show up to 240 remaining after deducting only known finished estimates, with one missing-finished-estimate warning. Retain the full manual 240 and do not manufacture Lunch's estimate. |
| Supply Lunch's missing estimate as 60, leaving Museum unfinished. | Remaining becomes 180 under total minus completed; no missing-finished-estimate warning remains. Finish Museum too: remaining becomes 0 and the manual total stays 240. |

## Definition of ready

- Q72 B is settled in the [decision register](open-decisions.md); retain the distinct own-progress and parent-branch behavior.
- Q76 A is settled. A partial manual budget deducts known finished estimates and displays an upper bound when finished estimates are missing. Apply the same rule to a referenced List's budget under Q71; no child estimate is manufactured.
- Review concrete public input/read/query contracts for manual estimate fields, derived summaries and calendar windows before new-field /tdd work. Existing Core read/query/execute, actual HTTP and native UI boundaries remain the agreed test seams.
- Declare persistence and portable-format evolution. Manual estimates are owned data; derived totals and device presentation preferences are not additional saved authorities.
- Specify controlled calendar fixtures for overlaps, start-only entries, multi-day all-day spans, travel and daylight-saving boundaries. Signed physical sync/account/Share gates retain their separate prerequisites.

## Definition of done and required /tdd checks

- Unit and actual-store read/reopen tests prove every numeric fixture above, global/local precedence, per-appearance state, archive/unarchive and ordinary removal/re-add. Queries and filters do not silently change the full plan's totals or saved order.
- Tests cover missing estimates, explicit clearing, manual reset, live child/List estimate changes, partial and fully finished branches, empty containers and checked sums. No child flags or other contexts are changed by a derived calculation.
- The Q76 fixtures must cover local Done, global Done and archive retirement of the unknown-duration child, a partial manual List branch inside an itinerary, supplying the missing estimate, and the all-finished zero rule. Qualify the accepted numeric/unknown display and native warning at the established Core and UI boundaries.
- Native phone/tablet/Mac journeys show compact full/remaining metadata, useful warnings and native pickers. Accessibility exposes complete labels; zero remaining must not imply completion when unfinished children remain.
- Calendar Day/Week/Month tests preserve source/Schedule identities, fixed timed instants, original planning zones, inclusive all-day civil dates and unspecified ends. Overlap/overflow, selection and adaptive layouts receive runtime proof at the native UI seam.
- Manual data survives versioned backup/import and supported migrations. Source/content edits remain live; unrelated fields, reference identities, local flags and device preferences survive unchanged.
- Whole-app SwiftUI polish follows feature completion. Compilation, pure calculations and simulator runs do not substitute for native Mac runtime or signed physical sync/account/Share evidence.
