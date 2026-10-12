# Core container estimates

## Context, before and goal

At `492b558`, Items have positive minute/display-unit estimates, and container progress distinguishes Done from archive retirement. Lists and Itineraries still expose no aggregate or remaining duration. Their content has no manual overall estimate field. The goal is to implement the accepted fixtures in [Container estimates and calendar](../container-estimates-and-calendar.md) at the shared Core boundary, then present them through native controls.

## Public read and input contract

The native read values are:

```swift
public enum PlannerDurationTotal: Sendable, Equatable {
  case exact(minutes: Int64)
  case lowerBound(minutes: Int64, missingEstimateCount: Int64)
  case upperBound(minutes: Int64, missingFinishedEstimateCount: Int64)
  case unavailable
}

public struct PlannerContainerEstimates: Sendable, Equatable {
  public let calculatedEstimate: PlannerDurationTotal
  public let fullEstimate: PlannerDurationTotal
  public let remainingEstimate: PlannerDurationTotal
  public let completedExceedsTotal: Bool
}
```

`PlannerListSourceRead.estimates` and `PlannerItinerarySourceRead.estimates` return that summary. An itinerary's calculated estimate includes each referenced List's effective budget under Q71. Empty automatic plans return exact zero duration while their separate progress remains empty, without a completion percentage.

- List and Itinerary source reads gain an `estimates` summary. It carries the calculated full total, effective full total, remaining total and a completed-exceeds-total warning. These values describe the entire plan, independently of search, display filters or paging.
- A duration total is typed as exact minutes, a known lower bound with missing-estimate count, an upper bound with missing-finished-estimate count, or unavailable after checked arithmetic fails. All numeric wire values use exact decimal strings. Provider caches and device preferences are absent.
- Container content gains optional `manualEstimate: PlannerEstimate` through existing create/edit commands and a typed guarded field change. Nil selects calculation. A set value retains its display unit until explicitly cleared; child edits never clear it. Item estimates remain shared content, not per-appearance copies.
- Count every appearance. A referenced List contributes its effective full budget once per entry. For partial branches, deduct finished child estimates; account for the entire effective branch budget once its itinerary children are finished. Standalone List Done flags never supply itinerary completion.
- Automatic remaining includes unfinished appearances only. Archive retirement follows Q68/Q69; an archived container's own remaining is zero under Q72, while its own progress stays child-based. Manual remaining follows total minus known completed contribution, including Q76 upper bounds. Clamp negative remaining to zero with a warning; all-finished remaining is zero without clearing the manual total.

## Definition of ready and persistence evolution

- Q48/Q63-Q76 settle the required conversions, repeats, missing values, archive contexts and manual persistence. Existing public Core execute/read/query, actual HTTP and native UI seams remain the test boundaries.
- First implement derived automatic summaries without changing stored authorities. Then add owned manual fields through versioned schema 15, defaulting existing containers to nil. Physical CloudKit qualification remains separate.
- Portable format 2 carries manual container estimates. Continue reading format 1 as valid legacy data with nil manual fields; reject unsupported versions and invalid imports together. Recovery must retain original acknowledged backup bytes and interpret supported versions explicitly.
- Preserve legacy operation replay when new manual fields are nil. Existing command digests and unrelated field hashes must not change merely because the app adds an optional field. A nonnil manual value must participate in the command digest and guarded field hash.
- Derived summaries are excluded from backups and recovery content. No additional saved total, remaining counter or Done flag is introduced.

## Definition of done and required /tdd

- Prove literal 120+60=180 totals and 60 remaining after the first appearance finishes. Missing children yield the known subtotal and warning. Repeated appearances contribute separately. Empty containers remain No items and not completed.
- Prove archive/unarchive, global Done/Reopen, local completion and filtered query stability through store/reopen reads. Checked sums report unavailable instead of overflowing; zero remaining cannot hide unfinished progress.
- Prove manual 240-minute List plus 30-minute direct Item gives itinerary 270, not 450. Partial finished contribution 120 leaves 150; finishing the List branch leaves 30. An itinerary manual 300 leaves 60 until the last child finishes, then zero.
- Prove Q76's manual 240 with a finished unknown Lunch and unfinished 120-minute Museum shows up to 240 remaining. Setting Lunch to 60 produces 180 remaining; finishing Museum produces zero. Cover the same partial manual branch inside an itinerary.
- Prove manual reset, live child/List edits, too-small manual totals, preserved exact display units, migrations, legacy replay and both import modes. No derived calculation rewrites source or appearance state.
- Qualify exact HTTP summaries and native full/remaining captions, uncertainty warnings and inline unit/remainder controls. Inspect actual phone/tablet captures; report Mac compilation and runtime separately.

This is the implementation contract for the next estimate slices. It does not claim runtime support or completion of the estimate/calendar ticket.
