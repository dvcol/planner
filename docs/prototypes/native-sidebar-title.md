# Native iPad sidebar title

The ordinary dark iPad reader capture showed the sidebar's app title as "Pl…"
beside its archive, Add, More and sidebar controls. The regular iPad sidebar now
uses SwiftUI's native `toolbar(removing:)` modifier to omit that default visible
title. Its `navigationTitle("Planner")` metadata remains available to the native
navigation controls and existing test queries. Phone and Mac presentation retain
their existing title behavior.

Three final native executions pass through two existing functions. The dark
iPad reader journey preserves the linked webpage through actual sidebar width
changes, then Back, Forward, Reload and exact saved-bookmark Return. The catalog
journey passes on maximum-text dark iPad and phone with Increase Contrast,
covering Settings, labels, sorting, archive modes, List creation and relaunch.
The phone retains its visible title and passes the native text-clipping audit.
Simulator appearance, contrast and text-size settings are restored afterward.

All 1160 native inputs match the Mac app, Share and UI-test product compilation.
Affected strict Swift and Markdown lint pass. The production correction is one
native modifier; existing test functions and selectors are unchanged.

The [structured result](evidence/native-sidebar-title/final-validation.json)
records the actual executed identifiers. Three original captures were inspected;
their dimensions, hashes and observations are in the
[inspection record](evidence/native-sidebar-title/visual-inspection.json).
Commands, source/product hashes, results, logs and the execution scripts are
preserved in the read-back-verified
[archive](evidence/native-sidebar-title/execution-records-index.json).

Maximum-text sidebar destination words still wrap across lines. Other scene,
search, contrast and full accessibility findings remain open. Actual Mac
resizing/keyboard behavior, installed Share and physical sync/performance retain
their separate acceptance gates. Signing stays deferred and advanced portability
remains post-MVP.

## iPad clipping audit follow-up

The current maximum-text dark iPad catalog still fails the unfiltered native
text-clipping audit after the visible app-title correction. Its first issue
supplies an Inbox row capture. Giving the destination labels their required
vertical size leaves that same warning. A conditional title-only style at
accessibility sizes makes Calendar fit on one line, but still produces a generic
clipping warning without an element screenshot. Neither probe establishes a
passing layout, so both production probes and the diagnostic test change are
discarded. No audit exception is added.

The restored catalog interaction journey passes at maximum text size with
Increase Contrast. All 1160 restored production/test inputs exactly match
`09ef6525` and the rebuilt Mac products. The actual Add, archive, More, Settings,
labels, sorting and List identity through relaunch remain qualified; this is
functional evidence, not an iPad clipping-audit pass.

The [follow-up results](evidence/native-sidebar-audit/final-validation.json)
separate three failed audit executions, the passing restored journey and the
compiler epochs. Four originals are inspected. Source variants, complete issues,
commands, settings restoration and results are retained in the
[verified archive](evidence/native-sidebar-audit/execution-records-index.json).

The [read-only Mac observation](evidence/native-sidebar-audit/mac-runtime-observation.json)
still reports the 14 October boot and 17 October native test-broker start. No
unchanged Mac UI startup attempt is made. Native audit/assistive review and
actual Mac interaction retain their separate limits; signing stays deferred.
Continue the remaining core journey and acceptance audit before adding further
layout machinery or revisiting these unsuccessful probes.
