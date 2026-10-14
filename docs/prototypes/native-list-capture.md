# Native List capture

## Context and goal

The saved app can review direct text/link capture from Items and Inbox, including owned fields and shared labels. An active List has no capture action. Capturing there therefore cannot start with its current List selected or keep the resulting Item in membership detail scope.

This slice adds Capture Text or Link to the native List actions menu, reusing the same review and Core apply command. The first review from an active List selects that List. Each List identity remembers its own successful destination choices per device and dataset; global capture retains its existing separate preference. Cancel does not change either saved data or remembered choices. After Add, the parent List remains selected and refreshes its live memberships.

## Definition of ready

- C3–C6 and C14–C16 in [URL and Share capture](../url-and-share-capture.md) fix explicit review, destinations, reuse, cancellation and save validation.
- Q33/Q34 accept native journeys through visible controls and normal saved views. Existing Core capture tests cover identity, reviewed apply and local atomicity.
- The shared native review and List membership navigation are implemented. The new entry point must preserve existing global capture behavior and local completion scope.
- The Maps/Calendar choices Q78–Q81 do not govern this direct-input List entry point. Maps lookup work is excluded from its build and commit.

## Definition of done for this slice

- An active List exposes native Capture Text or Link in its actions menu. The action is disabled for an archived List.
- Review preselects the current active List when this entry point has no successful remembered choice. Later reviews restore this List's last successful destinations. Renaming the List retains its identity and preferences.
- Global capture and different Lists do not overwrite one another's remembered choices. Cancel/dismissal never updates those choices.
- Missing or archived remembered destinations fall back to no selected Lists. Core still validates every explicitly selected destination at reviewed save; a stale target cannot silently become an Inbox capture.
- Unavailable destination loading disables Add and offers Retry. A failed read cannot silently discard the List context and save into Inbox.
- Add keeps native List navigation. A saved row opens membership details, with local Item actions and stable shared bookmark identity after relaunch.
- Native journeys prove the required defaults, cancellation, preference separation and persistence. Affected global capture regressions, lint and platform builds pass. Recorded outcomes remain distinct from physical Share/iCloud and Mac UI runtime qualification.

## TDD and qualification

The first iPhone journey failed at the absent List capture action before implementation. The first build caught a remaining alert guard referring to the replaced Boolean. Early native attempts exposed a destination hidden behind the title keyboard, a compact-phone Back control, and the originating toolbar button disappearing while its menu was open. The helpers now finish title editing with the native Return action, navigate through Back/Show Sidebar, and relaunch after checking the archived action. The first iPad run exposed the native toolbar's More overflow; the helper now opens that control before List actions. Product assertions were retained.

Each simulator qualified ten distinct functions in four suites, with ten selected passing invocations and no selected failures or skips. Qualification combines eight unaffected global/owned-field regressions from the initial run with both List journeys from the final follow-up. The initial iPhone run passed all ten functions; its earlier List results are excluded from the final selection. The initial iPad run passed the eight regressions and failed both List journeys at toolbar navigation. Only the corrected follow-up counts for those two journeys. This is not a claim that the initial iPad run passed.

The List journeys prove staged destinations through Cancel/Add, one persisted membership, local detail/action scope and bookmark identity after relaunch. They also prove separate successful choices for two Lists and global capture, persistence after relaunch, a disabled entry point for an archived List, and fallback to no selected Lists when a remembered destination is archived.

Three affected Swift files passed strict lint. The final Mac app and test host built successfully; Mac UI runtime was not executed. The three affected prototype reports passed Markdown lint. [Execution evidence](evidence/navigation/native-list-capture/execution.json) records actual outcomes, the qualified selection, source/artifact hashes and original inspected screenshots. Product hashes match the regression build; final source hashes were checked after all build/test processes exited. Maps lookup work was excluded.

## Remaining map work

The destination-read failure guard and Retry are source-reviewed but still require a native failure fixture; the passing journeys do not prove that runtime path. Provider intake/lookup/preview/retry, Share and Intents, full candidate inspection, changed-target/failure/termination native fixtures, Mac UI runtime, physical-device qualification and whole-app polish remain open. Core behavior checks do not substitute for those native and physical journeys.
