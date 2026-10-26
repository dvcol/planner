# Native Item title wrapping

At the largest accessibility text size, the single-line Item title field
truncated "Museum morning" even after focus moved to Notes. New Item and
Edit Item now use Apple's [vertical TextField](https://developer.apple.com/documentation/swiftui/textfield/init(_:text:axis:))
with native Done submission and a FocusState submit handler. Titles can grow
vertically without a font cap, custom measurement or changes to saved content.

The focused native journey first fails the phone clipping audit. Its final
fixture uses "Tokyo museum morning", checks that the title occupies more height
than the single-line Subtitle field, and verifies actual Return key events,
creation, reopening the editor, Cancel and relaunch. Exact source identity,
notes and unfinished global completion remain intact. Four original phone/iPad
creation and editing captures are inspected and retained.

Phone additionally runs native text-clipping audits in the two editors. iPad
uses the field layout/value assertions and inspected captures. Its full-window
audit also sees the adjacent native search field and retains that separate
failure. No issue-suppression handler is added to the permanent journeys.

The first Return probes inserted newline text with XCTest rather than sending
a key event. The two existing estimate/label helpers now send a real Return key.
Four final-source UI executions pass with no failures, skips or SQLite-unlink
diagnostics: the phone/iPad title journeys and the existing estimate/label
regressions. Their 1160 native inputs match the workspace and both Mac compiler
phases. Nine Mac app/Share/test products and four fixture/test products are
verified. All temporary Simulator settings are restored.

[The final validation](evidence/native-ui-accessibility-frontier/final-validation.json)
records those outcomes and the explicit audit limits. The compact execution
archive is read back and hash-compared before its duplicate packet directories
are removed.
The retained diagnostic source epochs keep their actual outcomes, including the
initial diagnostic-helper compiler failure that executed no tests.

The unfiltered largest-text audit identifies the crowded compact Planner title,
native search clipping, and contrast findings for Save, Calendar's empty agenda
and the landscape completion footer. A shorter search prompt did not remove its
diagnostic, so that probe and its caller changes are reverted. Those wider
findings remain open; this title correction does not close whole-app acceptance.

The Mac boot and test-broker timestamps remain unchanged from the retained
runtime failure. No unchanged Mac UI startup retry is made. Mac interaction,
physical/cloud behavior and human final review retain their existing gates.
Signing stays deferred; export/import and advanced manual recovery stay post-MVP.
