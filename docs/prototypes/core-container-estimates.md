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

## Automatic summary execution

List and Itinerary source reads now calculate automatic full and remaining estimates at the existing public Core boundary. Each appearance contributes separately; global/local Done and archive retirement remove its remaining contribution. An archived container retains its full estimate and child-based progress while showing zero remaining. No stored estimate, Done flag, reference order, timestamp or backup authority is added by calculation.

The known List fixture retains 180 minutes full and moves through 180, 60 and zero remaining. Missing estimates yield a known lower bound; finishing an unknown child never manufactures its duration. Empty automatic plans are exact zero with empty progress. Checked overflow makes the affected total unavailable while other valid totals and source data remain readable.

The itinerary fixture counts a direct 120-minute Museum plus two 180-minute List branches as 480 minutes. Its local completion is independent from the standalone List; global Done/Reopen and branch archive/unarchive preserve that distinction. Editing the shared Museum to 150 changes full to 570 and remaining to 420, despite a narrowed query. The itinerary's hashes/timestamp and booked start-only Schedule remain unchanged.

Sixteen Core functions pass across eight focused suites, with nineteen case executions. Ten actual HTTP functions pass across three suites, with eleven case executions. Wire reads retain exact decimal minutes, missing-estimate bounds, exact empty-itinerary totals and null summaries for Items. The actual HTTP red exposed the missing summary/key. Initial List/Itinerary failures were missing public declarations, not executed runtime tests. A zero-case HTTP selector attempt is excluded; the supported suite selector then executed the red. The [execution record](evidence/core/automatic-container-estimates/execution.json) preserves these boundaries and source hashes.

Nine affected Swift files pass strict lint. Mac app/MCP host and iOS app/native test host compile. This slice executes no new native UI journeys. That automatic-only slice used storage schema 14 and portable format 1. The following persistence slice advances those versions; manual budgets, Q76 upper bounds, native captions/pickers, Calendar, scale, Mac UI runtime, physical sync/account/Share and whole-app polish remain open. The estimate/calendar ticket is not complete.

## Manual field persistence execution

Lists and Itineraries now own an optional manual estimate through public create/edit/read commands and the same guarded field changes. Exact positive Int64 minutes and the selected display unit survive save, independent recovery, reopen and version-2 backup decoding. Explicit clear persists nil; invalid or stale edits leave the whole patch unapplied, and operation replay retains the original result without restoring later-cleared values. The actual HTTP adapter supports the same content and returns the current estimate/hash in stale-edit details. Adapter format remains 1; portable format advances to 2 and still decodes legacy format 1.

Schema 15 adds nullable manual fields and leaves historical schemas 1–14 frozen. A genuine schema-14 store produced by `a47caea` migrates with content, references, local states, schedules, identities and existing field-hash values intact. Both old List and Itinerary creation receipts replay successfully. Share refuses the upgrade until the main app completes it, then saves through the normal commands. Historical acknowledged backup bytes remain unchanged.

Sixty Core functions pass across thirty focused suites, with 139 case executions. Fifteen actual HTTP functions pass across six suites, with 23 case executions and no failures or skips. Thirty-four changed Swift files pass strict lint. Mac app/MCP host and mobile app/native test host compile; this slice executes no native UI journey. The [execution record](evidence/core/manual-container-estimate-fields/execution.json) records source hashes, the fixture and excluded failure attempts. The initial runtime save exposed a missed recovery schema allowlist; the first HTTP execution exposed discarded input values. Both were corrected before qualification.

At that persistence step, derived full/remaining summaries still used automatic calculations. The calculation slice below implements manual budgets, nested List contribution and Q76 upper bounds. Native controls/warnings and all Calendar/physical-device/polish gates remain open. Import decoding and review regression proof does not claim complete import application or restoration.

## Manual budget execution

Saved manual estimates now supply full totals and remaining time for Lists and Itineraries. Partial budgets subtract known finished contributions; Q76 missing finished estimates return an upper bound with the exact missing count. Local Done, global Done and archive retirement follow the same rule. Supplying the missing estimate resolves the bound; finishing every child returns zero without clearing the manual total. A smaller manual budget clamps remaining to zero and sets the exceeded-total warning while progress remains unfinished. Explicit reset returns to calculation.

An itinerary counts each List's effective full budget once per appearance. Its own contextual child flags determine partial deductions, independently of standalone List completion. Once a branch finishes or is archived, its whole budget is accounted for, including any travel allowance. The literal 240-minute branch plus a 30-minute Item totals 270; partial completion leaves 150, finishing the branch leaves 30, and a manual itinerary total of 300 leaves 60 until its final Item finishes. A repeated List produces 510 full minutes with independent local flags. The missing-finished-estimate policy also holds inside a partial manual branch.

Empty manual containers retain No items and their budget; they do not become completed. An empty branch does not prevent a parent whose Item appearances are all finished from reaching zero remaining. Checked sums never wrap; a saved manual value can remain exact when calculation overflows. Combining incompatible upper and lower bounds returns unavailable rather than inventing a one-sided numeric estimate. Derived reads preserve references, source state, timestamps and the saved manual representation.

Fourteen Core functions pass across six focused suites, with seventeen case executions. Eleven actual HTTP functions pass across three suites, with twelve case executions and no failures or skips. HTTP reads verify upper-bound minutes/missing counts, whole-branch accounting, all-finished zero and independent standalone List remaining time. Five changed Swift files pass strict lint. Mac app/MCP host and mobile app/native test host compile; no new native UI journey executes. The [execution record](evidence/core/manual-container-budgets/execution.json) includes the real-store red runs, qualified results and source hashes.

Root List/Itinerary captions, warnings and duration controls are now implemented in the [native container slice](native-container-estimates.md). Catalog/group metadata and further native context fixtures remain open. Calendar, full manual administration/restoration, scale, native Mac UI runtime, physical iCloud/account/Share and whole-app polish remain open. This calculation slice adds no persisted counter, duplicate source data or calendar mutation.
