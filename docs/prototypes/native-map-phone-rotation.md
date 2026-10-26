# Collection Map through phone rotation

The existing List Map journey now rotates iPhone to landscape and back before
opening its pin. With unchanged shipping code, the landscape summary leaves no
usable pin viewport. Bounding the summary alone fixes landscape but recreates
the Map during the return to portrait, leaving the pin behind the summary.
Both failed diagnostics are retained.

The correction keeps one Map host and adapts only its native top inset. A
scrolling summary takes at most one third of the collection height in compact
vertical layouts, reusing the existing accessibility-size treatment. Its native
background follows light and dark appearance. No camera, Core, provider or
saved-data rules change.

Two final native executions pass: light iPhone rotation and dark iPad's existing
portrait/landscape viewport checks. Each opens the exact locally completed List
membership, preserves its bookmark identity and original Google Maps URL, and
verifies that the shared Item remains Todo. All 1164 production/test inputs match
the Mac app, Share and UI-test compilation. Strict affected Swift lint and
Markdown lint pass. Simulator settings are restored after each execution.

The [structured results](evidence/native-map-phone-rotation/final-validation.json)
retain the actual executed identifier, diagnostics and comparison to unchanged
production at `0dbd3c63`. Nine original captures are inspected: three diagnostic
and six final images. Their hashes and observations are in the
[inspection record](evidence/native-map-phone-rotation/visual-inspection.json).
Detailed commands, logs and source/product inventories are compressed in the
[execution archive](evidence/native-map-phone-rotation/execution-records-index.json).

The landscape phone Map is still shallow because native navigation, search and
tabs share the limited height; this check proves a reachable pin, not generous
map space or whole-app visual acceptance. Actual Mac resizing, broader
accessibility, physical devices and provisioned shared/CloudKit storage remain
open. Identifier registration awaits Apple Developer sign-in; actual signing
still needs private-key access. Advanced portability remains post-MVP.
