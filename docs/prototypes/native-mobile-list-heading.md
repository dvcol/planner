# Full List names in mobile content

Q113 A keeps the full List name in the content when the compact native bar
cannot fit it. The Mac toolbar consolidation had also removed that mobile
heading. A real phone journey reproduced an empty List showing only the
truncated bar title, with no full name in its content.

The correction adds a wrapping native heading to the existing iPhone/iPad
summary in empty, populated and Map representations. It scales with Dynamic
Type and exposes the heading accessibility trait. Mac keeps its single unified
toolbar title. Itinerary presentation and saved data are unchanged.

## Local qualification

Five final native executions across two functions pass:

- Empty-to-populated List creation on ordinary light iPhone and maximum-text
  dark iPhone/iPad with Increase Contrast. The full name stays within the pane;
  progress remains `0 of 1 item done`, and scrolling reaches the new Item.
- The existing List Map journey on light iPhone and dark iPad. Pin selection
  retains local Done, global Todo and the original bookmark. Tablet viewport
  transitions retain the selected context.

All 1160 native inputs match the workspace and Mac app/Share/UI-test compilation.
Strict affected Swift and Markdown lint pass. Eleven final original title,
scroll and Map captures are inspected. These are scoped interaction and visual
checks, not a whole-app accessibility audit.

The original failing reproduction remains recorded. Two intermediate driver
failures are also retained: a container queried as a Button, and a lazy row
queried before scrolling at maximum text. Neither is reported as a passing run.
[Final verification](evidence/native-mobile-list-heading/final-validation.json)
lists the matching final cohorts. Execution records are compacted with read-back
hash verification; original captures remain directly viewable.

## Single heading and matching insets, 28 October 2026

Mobile now explicitly clears the secondary native navigation title and keeps
one full wrapping content heading. Removing the default toolbar title alone
failed after relaunch: the native bar restored a second title. Inline-only and
large-title trials also failed to retain a visible name in the narrow iPad pane
at maximum text size. Those attempts retain their actual outcomes.

Empty and populated mobile contents now share the same native List and summary
row, giving the heading and estimates the same insets. The native search drawer
stays available in portrait and uses automatic behavior in compact height.
Mac retains its merged title/toolbar. Filters, saved content and identities are
unchanged; Itinerary headings are outside this correction.

Six primary mobile executions pass: the title/Map/relaunch journey on ordinary
phone/iPad and maximum-text dark phone/iPad with Increase Contrast, plus two
landscape loading checks. The journey requires one content heading and no
duplicate native-bar title, compares heading position/height and estimate
spacing, and preserves exact List/appearance identities through Map switching
and relaunch.

Two later landscape executions use ordinary native List swipes and retain the
actual hierarchy. Their inspected originals show the full No items label above
native chrome. The earlier custom edge-drag and whole-placeholder frame checks
did not establish that visual result: ContentUnavailableView exposes its padded
graphic/text group as one static-text element. No extra production inset or row
sizing workaround is needed.

The [checkpoint](evidence/native-mobile-list-heading/single-heading-2026-10-28/result.json)
retains eight inspected originals, passing executions and rejected attempts.
Final Mac and Simulator builds match 1,169 current inputs. The six primary
passes have their own source/product snapshot; subsequent changes are a
production comment and the landscape test driver. The primary title journey
and its helpers are byte-identical. Maximum-text Map summaries remain
scrollable; this does not promise every summary field fits simultaneously.

The [temporary-artifact cleanup](evidence/native-mobile-list-heading/single-heading-2026-10-28/cleanup.json)
removes 592,205,153 nominal bytes of superseded trial files after archive and
capture read-back verification. Final results, build caches and app data remain.

## Mac manual-authentication retry, 28 October 2026

The user-ready retry passes the existing long-title journey in 65.171 seconds,
with no failures or skips. All 1,169 source inputs match the workspace and private
snapshot; nine product hashes remain unchanged after execution. Main app,
embedded Share and UI-runner signatures verify. Manual UI Automation
authentication remains required before and after the run.

The test creates an empty List, resizes between 860 and 1200 points, creates its
first Item and repeats the resizing. The title stays in the top native toolbar,
starts at the collection edge and remains clear of Filters. Widening releases
title space in both states, and the populated narrow toolbar controls remain
hittable. Four inspected original captures retain one left-aligned title and
the compact estimate summary. Item-specific actions take toolbar space, so
empty and populated titles can truncate at different points.

The [verified result](evidence/native-mobile-list-heading/mac-manual-retry-2026-10-28/result.json)
retains the originals and compact execution records. No production or test code
changes were needed for this retry. The earlier final-source authentication
timeout remains recorded separately and receives no test-execution credit.

## Itinerary heading and compact navigation, 28 October 2026

The native iPad reproduction also exposes an Itinerary name twice: a truncated
bar title and its full content heading. iPad now keeps the full content heading
and clears the repeated bar title. iPhone retains its native title; the Mac
title branch is unchanged.

The same journey finds a separate phone defect: creating a second Itinerary can
leave Opening Itinerary indefinitely. The exact committed production view also
reproduces it before the title assertions. A narrow trace shows the new read
being cancelled during compact navigation. Resetting that compact split-view
stack when the selected plan changes fixes the represented case. Per-plan
filters, saved identities and ordinary loader cancellation remain intact.
Stable-container and sheet-dismissal experiments did not fix it and are removed.

Five final executions across three existing native functions pass: second-plan
creation, exact selection and relaunch twice on ordinary phone and once on
maximum-text dark iPad with Increase Contrast; repeated List-branch Map selection
and rotation on that iPad; and exact Itinerary-guide Return on phone. The existing
test driver now opens collapsed navigation through the shared helper and prefers
the actual back button before a sidebar fallback. No new test boundary is added.

The [result](evidence/native-itinerary-heading/2026-10-28/result.json) retains the
six failed production/diagnostic attempts separately from final passes. Eight
original captures are inspected and four retained. All 1,169 native inputs match
both final builds; strict Swift formatting and signed Mac app/Share/UI-runner
signature verification pass. Simulator appearance settings are restored. The
prepared final Mac reader batch still awaits the existing manual-authentication
readiness response. These checks do not close whole-app or physical acceptance.

## Remaining gates

Broader scene/assistive review, installed Share and physical/synchronized use
remain open. Production CloudKit is still disabled and account-transition
testing remains deferred. Advanced export/import and manual restoration remain
post-MVP under the amended release scope.
