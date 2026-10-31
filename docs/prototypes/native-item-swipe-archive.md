# Native Item archive swipes

The brief requires ordinary mobile swipe gestures. Item catalogs previously
required opening details to archive. Their shared Items/Inbox row now uses native
SwiftUI swipeActions to reveal Archive or Unarchive. Tapping calls the existing
SavedPlannerStore command. Full-swipe submission is disabled, the native action
uses the app accent and the existing write-availability guard remains effective.
No new command, state flag, dependency, provider or recovery path is introduced.

The existing native UI boundary first reproduces the missing Archive action.
The initial implementation reaches Archive, Unarchive and exact row readback
after relaunch, then fails because the new test queries the detail Toggle as a
Button. The retained query chain proves that wrong element type. The final test
uses the established typed-independent Toggle lookup. Original failure results
remain failures. The existing direct row-completion regression passes in that
diagnostic cohort; it is not counted as a final-source result.

The final validation
records two passing functions on iPhone and dark iPad, four final executions with
zero failures, skips or SQLite-unlink warnings. Active/Archived filtering follows
both actions. The original Item identity, notes and global Done survive the
round trip and actual relaunch. Direct completion still works independently.
The iPad's original appearance is restored. Six original final captures are
inspected, showing readable native actions and reopened details.

All 1160 final source inputs match both mobile runs and final Mac compilation.
Products are verified before reuse. Mac app, Share and native tests compile
through the established account-free local recipe; this gives no Mac runtime
or protected-storage credit. Strict affected Swift/Markdown lint and whitespace
checks pass. Only SavedItemViews and the existing native journey class change.

The shared row supplies Inbox's action too, but these executions exercise Items.
They do not qualify every Inbox state, full accessibility, actual Mac UI,
physical behavior or CloudKit. Contextual completion remains unchanged.
Signing stays deferred; export/import remains outside MVP.
