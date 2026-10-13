# Native Calendar Item deletion

## Context and goal

Calendar reuses Item details and the existing confirmed Delete flow. This route had no native deletion qualification. The risk is retaining an invalid selected Schedule or Item after deletion, especially while the phone agenda is behind a pushed detail view. The required end state is a usable empty agenda with no stale actions, followed by no deleted Item in an unrestricted catalog after relaunch.

## Definition of ready

R10/R14 retain explicit confirmed deletion and reference removal without Trash. A3 requires invalid selection to clear. The existing native UI seam is approved. This step exercises those settled rules independently of pending Q78–81; it adds no production data, API or layout decision.

## Definition of done for this step

- Create an Item and an actual all-day assignment through native forms. Open that Schedule's Calendar entry into its existing Item details.
- Cancel Delete after reviewing its one saved reference. Preserve the original Schedule identity/description and usable Item actions.
- Confirm Delete. Remove the entry, dismiss the review, clear stale Item actions and expose a usable native date picker with an empty agenda.
- Relaunch the same dataset. Calendar stays empty, and the Item is absent after clearing all filters, including the default Active restriction. This distinguishes deletion from merely hiding an archived Item.
- Run the focused journey on phone and tablet, strict lint and the Mac app/test-host build. Record the actual results, source revision and native captures.

## Tests and qualification

The first runs reached successful cancellation, deletion, selection cleanup and Calendar relaunch. Their final assertion used No Items yet, while the default Active filter correctly displays No matching items. That test selector was corrected; it was not a production deletion failure. The corrected journey passed on both simulators. The final version additionally checks a hittable date-control button and clears all catalog filters before asserting absence. Final qualification passes one native function on each simulator, with no failures or skips. Strict lint passes the new Swift test file; the Mac app/test host builds with zero Mac UI functions. [Execution evidence](evidence/navigation/native-calendar-item-deletion/execution.json) records actual result trees, verified source hashes, commands and two inspected original native captures. The phone capture shows the returned empty agenda; the tablet shows both the empty agenda and cleared Choose a schedule detail pane.

No production implementation changed. Existing Core deletion and Schedule contracts retain their earlier evidence; this native journey qualifies their Calendar integration at the public UI seam.

## Remaining work

External/cross-device deletion refresh, other Calendar removal paths, cloud deletion-wins, save/termination failures, Mac runtime and signed physical sync/account/Share remain open. Pending Calendar layout/query choices and Day/Week/Month work keep their separate gates.
