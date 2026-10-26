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
