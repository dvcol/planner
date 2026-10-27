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

## Remaining gates

An earlier Mac long-title resize journey passes in 64.911 seconds, with its
separate 1,168-input snapshot retained. The final-source Mac attempt times out
while enabling automation before any test starts. Signing is available; a
manual-authentication readiness retry is requested. This supplies no fresh Mac
runtime credit.

Broader scene/assistive review, installed Share and physical/synchronized use
remain open. Production CloudKit is still disabled and account-transition
testing remains deferred. Advanced export/import and manual restoration remain
post-MVP under the amended release scope.
