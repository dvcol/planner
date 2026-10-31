# Native List pane header

## Context, starting state and goal

The user's Mac captures show a repeated List title, different empty/populated
estimate alignment, cramped button labels and controls crossing the middle
pane's divider. A long-title reproduction confirms that the global toolbar title
ends at x=534 while the List pane ends at x=440. Hiding that title alone leaves
Add extending to x=474.

The Mac List now uses one shared native top toolbar. Its system navigation title
stays leading aligned and uses available window space. Filters, Sort, List
actions, Add and the selected Item's actions share that toolbar owner. The main
window supplies a continuous system-material background. Estimates/progress
remain directly below it, using the same summary for empty and populated Lists.

The first correction pinned a separate title/control block beneath the native
toolbar. Although it contained the title and controls, the user's follow-up
correctly identified the remaining empty strip and duplicate header structure.
The unified-toolbar follow-up below supersedes that intermediate layout.
iPhone/iPad keep their accepted native navigation and action placement. Saved
identities, completion, estimates, filters, ordering, creation destinations and
draft decisions retain their existing meaning.

## Definition of ready and done

The existing public native UI boundary is approved. Reproduce containment using
an actual long List name and an 860-point window. Compare the visible title and
controls with the actual List pane bounds; do not assert padding constants or
SwiftUI structure. Use the existing rich-editor resize/save/relaunch, guarded
navigation, sorting and mobile first-List journeys for affected behavior.

This slice is done when the shared-toolbar, available-space and
empty/selected-title regressions pass, their original captures are inspected,
affected interaction journeys and platform compilation pass, and strict
Swift/Markdown checks pass. Physical devices, system Intents, signed storage and
the final feature-complete whole-app review remain separate map gates.

## Executed qualification

These first six runs record the intermediate pane-containment correction. The
later shared-toolbar results below supersede its layout acceptance.

The original title regression fails at the measured 534 > 440 containment check.
The subsequent control regression fails at 474 > 440. The initial
screenshot-only locator proved reachability rather than pane containment; its
passing result does not qualify the overflow.

The intermediate Mac invocation passes three cases with zero failures/skips:
long-title/control containment in 34.661 seconds, actual rich-editor
860/1200-point resizing and relaunch in 157.986 seconds, and guarded draft
navigation in 62.097 seconds. Original narrow/expanded captures were inspected.
Title and controls remain inside the pane, and the editor retains its fields and
original List destination.

Earlier iterations and failures remain recorded. Increasing native control size
did not visibly improve toolbar insets, so the final change adjusts label
insets. One rich-editor run timed out synthesizing location input; two later
retries failed at restored-window overflow before editing. The existing native
Fill helper now establishes the rich journey's initial Mac geometry while
preserving every later narrow/wide check. The title-only layout's first query
looked for an AX value, while its content heading already exposed the full
accessible label. The corrected locator accepts either public native
representation; no accessibility-name production change was needed.

The native Mac sorting journey passes in 257.856 seconds. It exercises the
relocated control, Title/Created/Manual ordering, ascending/descending choices,
two Lists' independent preferences, contextual completion, stable appearance
identities and relaunch. Two preceding invocations fail on locator assumptions:
the Menu button exposes its selected sort through its native title, and
ProgressView owns its accessible progress label. Their original captures
establish those representations. The corrected assertions read those public
native properties; production sorting and progress behavior are unchanged.

The first-List landscape journey passes on iPhone in 19.692 seconds and iPad in
21.156 seconds. Their original light-mode captures were inspected. Both show the
ready empty List and its Estimate/Remaining metrics, with the established mobile
navigation retained. Mac captures supply dark-mode evidence for this slice, not
complete appearance/accessibility acceptance on every platform.

Final validation checks matching production/configuration inputs across the Mac
and mobile epochs, all six passing native cases and affected strict
Swift/Markdown lint. No padding/color constant or internal layout test was
added. No broader map issue closes with this slice. The separate
[storage cleanup](native-local-storage-cleanup.md) reclaims completed temporary
results while retaining their evidence.

## Unified top-toolbar follow-up

The user's running-app captures confirm that containment alone left a second
header beneath an empty toolbar strip. The List title and its actions now share
the native macOS window toolbar. The main window requests the system
[unified toolbar style](https://developer.apple.com/documentation/swiftui/windowtoolbarstyle),
with a visible regular-material background applied at the window root. This
makes the top band continuous across the pane dividers. The old lower
title/control block is removed; the same estimates/progress summary remains
beneath it in both List states.

The existing system navigation title owns its leading placement and available
width. A manual cap initially left its accessible frame at 158.5 points even
after widening from 860 to 1200 points. A principal-placement probe centered the
title and hid it with its actions at narrow width. Both are removed. No custom
title view, width measurement or new dependency remains.

A separate fixed-window reproduction exposes the selected-Item issue: the title
region collapses from 1698 to 160 points when a detail-column toolbar appears.
Removing only the detail navigation title does not fix it. The Mac Item actions
now live with the List's actions in the content toolbar. The existing view
supplies the same menu and command closures; phone/tablet retain their detail
navigation title and toolbar. This changes presentation ownership without
changing the selected source, appearance or action scope.

The existing native UI seam checks actual title/control frames against the
native toolbar, leading alignment, growth on widening, nonoverlap and the
summary's distance below the bar. It creates an Item in the same List and
repeats the narrow/wide checks with selection. A second case compares
empty/selected title space without resizing, allowing the added Item action's
native width and spacing instead of forcing equal frame widths.

The qualified header baseline fails at the misplaced-title assertion against the
prior production layout. The title-space baseline fails at unchanged width. The
selection baseline fails at the 160-point title region despite room for at least
1603.5 points. Earlier locator, menu, resize and startup failures retain their
actual outcomes. Native resize gestures now activate Planner first; the existing
Fill setup closes its menu when Fill is disabled rather than clicking an
unavailable action. Every reported narrow/wide journey still asserts the
window's actual width.

Moving creation into the native bar also exposes a real narrow-editor
regression: Save becomes unavailable behind overflow while the List controls
consume the toolbar. Merely assigning secondary-action placement does not fix
it; the failed native probe retains that outcome. During a New Item draft, the
Mac bar now shows Filters as an icon and groups Sort, List actions and Add in
one native List options menu. Save and Cancel remain directly available.
Browsing retains the direct controls, and the existing accessible filter summary
remains complete.

The final source passes six actual Mac cases, with zero failures/skips:

| Invocation              | Executed checks                                                                                                                                              | Result                                     |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------ |
| Rich editor             | Real 860/1200-point resizing, sidebar collapse/show, retained rich fields and original List destination, Save and relaunch                                   | 1 pass, 154.214 seconds                    |
| Header and draft guards | Long-title narrow/wide empty and populated states; Save/Discard/Keep editing and invalid draft protection; unchanged-window title space after Item selection | 3 passes, 55.987 / 61.117 / 31.668 seconds |
| Affected native actions | Contextual details and explicit View item; Title/Created/Manual sorts, direction, per-List preferences, order, local completion and relaunch                 | 2 passes, 52.493 / 260.182 seconds         |

The final wide empty/populated, narrow populated, fixed-window
before/after-selection and narrow/expanded rich-editor captures were inspected.
They show the continuous top band, leading title and usable native controls. The
selected Item retains its contextual detail and menu; its global navigation
remains explicit. These captures establish the represented dark Mac states
rather than a whole-app appearance audit.

The same contextual-detail/View item/relaunch case passes on iPhone in 63.419
seconds and iPad in 67.691 seconds. Both original light-mode captures were
inspected. This gives eight passing executions of six distinct cases across the
three platforms, with no failed or skipped tests in these final invocations. All
1,061 source/configuration inputs match the current workspace across the final
Mac build/runtime and mobile epochs. Affected strict Swift formatting, Markdown
lint and whitespace checks pass.

Superseded compiler/locator/resize probes retain their actual outcomes in a
compact iteration record. Their raw unpublished diagnostics remain local; this
relocation makes no disk-reclamation claim. No production domain contract,
package, target or test-only control was added. Physical-device, system Intent,
signed storage and final whole-app review gates stay open.

## Empty versus selected title recheck, 22 October 2026

The follow-up screenshots show the original selection-dependent title
compression: the empty List uses the available toolbar width, while selecting an
Item introduces a separate detail toolbar and squeezes the List title. The
shared-toolbar correction above already addresses that ownership change. The
current app, root window, List view, appearance details and both title tests are
byte-identical to their earlier passing Mac epoch; the earlier before/after
captures were inspected again.

A fresh Mac build succeeds with all 1,061 frozen inputs matching the workspace.
The focused runtime retry requests the existing fixed-window selection and
narrow/wide long-title cases, but XCTest times out enabling automation before
either case starts. Its result contains one runner-initialization failure and no
executed title case. This is not a new runtime pass or a reproduced layout
failure. The retained comparison identifies the five unchanged header/test
files; no further production layout change was made from these screenshots
alone.

Strict formatting of the affected views/tests and Git whitespace checks pass. A
new awake/unlocked Mac confirmation is requested for another focused retry.
Earlier runtime evidence keeps its original scope; current physical and
whole-app visual acceptance remain open.

The next current Mac build also succeeds. Its focused retry again executes zero
requested cases because automation initialization times out. The four header
production files and both requested title methods still match the earlier
passing revision. The whole test file now differs because the saved-preview
follow-up changes unrelated input interactions; its selected-method comparison
records that distinction. This retry establishes neither a new layout failure
nor a new visual pass, and does not justify another speculative header change.

A further bounded current-build retry reaches the runner but executes neither
requested title case before the 600-second wrapper limit. It is stopped and
retains zero passing credit. All four header production files still match the
earlier verified correction. The current-build check is pending with the user;
no further layout patch is inferred from this startup outcome.

The latest build succeeds with the current header sources. Its 240-second
runtime retry starts neither requested test case and receives no visual passing
credit. Strict formatting and whitespace checks pass. After the runner exits,
the freshly built app is opened from its exact build path for the user's
empty/selected comparison. The observed running process uses that path; the
user's current-build observation remains pending. No additional production
layout change is made without reproducing the discrepancy.

The scope-follow-up build also succeeds after the independent bulk-save
correction. Its two-case current-build retry is bounded at 240 seconds and
starts zero cases. The log records unfinished test-runner/LaunchServices work;
the interrupted result bundle has no `Info.plist`, so summary extraction fails
rather than supplying fabricated test results. All four header production files
still match the earlier qualified `9de04bdf` source. This establishes no new
layout verdict or signing cause. The actual current-build empty/selected
comparison remains open, and no speculative title patch is added.

## Isolated current-build comparison retry

The user's two captures still show selection-dependent truncation. A fresh
isolated Mac build passes with the current workspace inputs. Its four header
production files remain byte-identical to the previously qualified correction.
The normal running app's products are left untouched by this compilation.

The two-case native attempt requests
`testSelectingAListItemKeepsItsWindowTitleSpace` and
`testLongListTitleSharesTopToolbarAndUsesAvailableSpace`. It reaches the runner
after the test service's 120-second control-session timeout, then ends at the
360-second controller limit. The retained result has no final Info.plist, usable
case results or fresh title captures. This is no passing visual credit. Absence
of case-start lines in buffered output is not proof that a case never executed.

Strict Swift formatting passes for the app, root window, List view, appearance
details and existing title test. The current discrepancy remains open. Do not
repeat this unchanged startup attempt or infer another production layout patch
from its timeout; obtain a current-build observation or a working native runner
first. The preserved app is
`/private/tmp/PlannerTitleConsistencyDerivedData/Build/Products/Debug/Planner.app`.
No signing setup is requested by this slice.

A subsequent live image comparison finds that the already-running Planner
process has loaded debug-library UUID `FA29A83E-B4D7-3006-9927-4FD0D1E622EC`,
while its bundle now contains `B8FF861C-DF73-3A2E-9EEC-4D689D46C009`. Its
executable path alone therefore did not establish that an earlier Open action
relaunched the rebuilt code. The user is asked to save any draft, fully quit
Planner and open the isolated build before comparing the same long title. This
is a concrete version mismatch, not proof of the new build's layout or of the
exact library used for an earlier screenshot. No running app or draft is
forcibly terminated.

The user subsequently confirms the requested isolated-build relaunch and
comparison: “Reopened; title stays consistent.” The current-build feedback
request is therefore settled. The earlier automated startup failures retain zero
passing credit, and final whole-app visual/accessibility review remains open. No
further header patch or unchanged title-test retry is inferred from this
confirmation.

## Mobile single-title follow-up

The later
[native membership captures](native-legacy-closed-alias-delivery.md#native-list-follow-up)
retain the remaining phone/tablet duplication: the progress summary draws its
own List name below the native navigation title. This follow-up uses the already
approved public native UI boundary. A long-name journey creates a real List,
checks its visible title and accessible name, adds an existing Item, compares
Estimate/Remaining leading edges, and switches List/Map representations. Filters
and Add must remain hittable throughout.

The original regression fails at two visible titles rather than the required
one. Its unedited baseline capture shows both copies. The ranked diagnosis
distinguishes the explicit summary heading from duplicate native navigation
owners and hidden sidebar exposure.

Remove the title and unused title-control parameters from `SavedListProgress`;
its four callers now supply estimates/progress only. The existing native
navigation title owns the List name across empty/populated Lists and Map mode.
The Mac caller already suppressed the summary heading, so it keeps its shared
native toolbar. No toolbar-width cap, new component, data declaration, saved
state or workflow is added.

The unchanged phone tracer passes. Its original test bytes are identical to the
failing run; only the two production view files differ. The affected phone
completion/relaunch journey also passes. The dark-iPad cohort passes both
functions, giving four native executions across two functions. Actual UI reads
verify one visible title, the complete accessible name, live filter/Add controls
and matching horizontal summary alignment in empty, populated and Map states.
The existing membership's identity, local completion, global Todo and note
survive relaunch/redelivery.

All fourteen current native captures and the original duplicate-title capture
are retained and inspected. The phone title captures and tablet captures show
the single native title and bounded controls. The matching Mac build/HTTP
checkpoint passes app/Share/fixture compilation and all nine HTTP regressions.
The reconciliation verifies 1,154 identical final inputs and actual products;
Core, schemas and fixture data remain unchanged. Strict Swift/Markdown lint and
whitespace checks pass.

Verified cleanup removes four closed Mac stores and four duplicate attachment
exports. Original result bundles, fifteen PNGs and Simulator datasets remain
available. Native bars still ellipsize long names to their available width while
preserving the complete accessible label. Search-drawer visibility can change
the summary's vertical position; this test qualifies horizontal alignment.
Larger text sizes, contrast/VoiceOver, actual Mac runtime and physical
acceptance retain separate gates. Item-detail title duplication and the Map
footer's singular/plural wording remain whole-app polish findings. Q156 remains
pending and signing stays deferred.
