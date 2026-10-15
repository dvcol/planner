# Saved Maps preview lifecycle

Status: four controlled lifecycle journeys and three affected production rendering journeys pass on each simulator. This follow-up addresses the remaining saved-card lifecycle cases from [Q92's first native slice](native-saved-maps-preview.md). It does not complete ordinary Item creation or the whole native map gate.

## Context, starting state and goal

Saved Maps cards already render temporary Apple/Google previews and preserve their owned bookmarks. The first slice leaves controlled native Retry, stale responses during URL edits/removal, and retained-view reappearance unqualified. Unit cache coverage cannot establish SwiftUI task ownership.

The new Retry journey witnesses an unintended third provider call after one explicit Retry. The failure hierarchy contains the fixture's `Unrequested lookup` response. The loading task was attached to a Group whose different states expand into multiple Form rows. The expected end state is one task owner, explicit independent Retry and link actions, and no obsolete result replacing a selected or edited link.

## Definition of ready

Q50 already approves controlled results at the production preview provider boundary and native UI integration. Q92 approves temporary saved-link presentation. These changes use that existing boundary, the production detail/editor views, and local fixture datasets. They add no production test parameters, domain commands, saved fields or account operations.

## Required tests and definition of done

- Retry once after a controlled failure. Reject extra lookups, retain Planner in the foreground, reuse the result after leaving and returning to Items, and lose the temporary result after process relaunch while retaining the exact bookmark identity/value.
- Select another saved Maps link while the first is pending. Release the obsolete response and retain the newly selected map, owned notes, Todo state and both exact bookmarks.
- Edit the URL of the same pending bookmark. Retain its identity, reject the old result, and preserve the new URL after relaunch.
- Remove the pending bookmark. Keep the surviving bookmark's identity/URL and map; relaunch retains only that bookmark.
- Qualify the four journeys on iPhone and iPad, inspect their own-app captures, and repeat the affected production capture/address/search rendering checks after the container change. Run strict lint and affected compiler checks. Mac runtime, signing and physical-device gates remain separate.

## Implementation and findings

A native VStack gives loading one stable owner. Native borderless styles keep the fallback Link and Retry button independent within their Form row. The first unchanged Retry run after introducing the VStack reaches the recovered result, then exposes automatic Form action activation. With independent native action styles, the complete Retry/navigation/relaunch journey passes.

The fixture delays a Maps response at the existing provider boundary. `Current` is returned only after releasing a pending `Outdated` result. A fresh process with no pending response returns `Reopened`. This distinction closes an initial proof gap in which a journey could pass without releasing the old response. Candidates still come through the real supplied-coordinate resolver; the fixture changes timing and outcomes rather than saved data.

Initial controller failures concern native element types, offscreen rows and text-selection positioning. Notes can require an unrestricted accessibility query, completion uses the actual switch, and Form rows are recycled. These failures remain distinct from the witnessed extra-lookup defect. A test-variable rename also causes one compiler-only failure; no runtime result is credited to that phase.

The installed XCTest SDK declares modified-key typing on iOS and macOS. A focused Command-A run passes, but an identical-source combined run inserts at the caret instead of replacing the whole URL. That interaction is not qualified for iPhone. Repeated touch-selection failures insert literal keyboard characters. The final controller places the field at least 80 points above the keyboard before using [Apple's documented paragraph-selection gesture](https://support.apple.com/guide/iphone/select-edit-and-move-text-iph1a9cae52c/27/ios/27). Both final combined runs pass, and original captures show the selected URL above the keyboard. Exact field-value checks before Save and bookmark identity/value checks after relaunch remain required. Loading labels require existence checks rather than button-style hittability.

## Results and remaining work

[The evidence packet](evidence/navigation/native-saved-maps-lifecycle/) retains actual commands, compressed logs, frozen source hashes and result exits.

| Controlled native journey | iPhone seconds | iPad seconds |
| --- | --- | --- |
| Edit the same pending bookmark URL, then relaunch | 57.649 | 42.945 |
| Explicit Retry, leave/return, then relaunch | 41.011 | 38.368 |
| Remove the pending link, then relaunch | 47.142 | 39.890 |
| Switch links and release the obsolete response | 23.906 | 20.614 |

The final four-case batches pass with zero failures/skips in 169.708 seconds on iPhone and 141.816 seconds on iPad. Their 230 source inputs and three compiled fixture products are identical. All source hashes still match the worktree. All ten original named captures are inspected, including the selection, edited URL, recovered Retry, removed link and switched link on each device.

The three affected production capture/address/search journeys pass with zero failures/skips on iPhone in 124.581 seconds and iPad in 195.931 seconds. Their six original named captures are inspected: the independently authored Cupertino address takes precedence, the Google coordinate search renders a native map, and the text search retains its useful fallback without inventing a pin. These captures do not establish live-provider availability or whole-app polish.

All fourteen represented native function runs pass. The five affected Swift files pass strict lint, both reports pass Markdown lint, and Standards/Spec reviews find no remaining material findings in this slice. Frozen source records include unfinished creation/selection work; no Q88/Q93 writer completion or Q89 selection completion is credited here.

The focused Mac fixture app and test targets compile without signing. This establishes compilation only. No Mac UI runtime, physical iCloud/account/Share behavior, accessibility, performance or whole-app polish gate is closed. Q93's ordinary creation contract remains pending independently.
