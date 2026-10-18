# Maps preview wording

The native UI review found technical provider terminology in ordinary saved Item details. Maps previews now say that place details come from the saved link and have not been verified. A Google search link continues to describe a search location, without claiming a resolved business.

This copy change preserves original URLs, temporary provider data, owned-location precedence, fallback actions and backup semantics. It adds no production interface or schema change. The existing controlled Maps resolver tests have matching wording expectations; this is not a behavior-red claim.

[Recorded validation](evidence/navigation/native-maps-preview-copy/results.json) reports four passing filtered test functions, including the two-case ineligible-URL test, and strict Swift lint. The first sandboxed attempt could not access the compiler cache and executed no tests. The permitted retry passed. [Logs and source hashes](evidence/navigation/native-maps-preview-copy/) preserve both attempts.

This checkpoint does not establish native layout, complete contrast, physical-device or whole-app polish acceptance. The selected-row contrast audit and ticket 23 remain open.

## Native qualification

Both existing native warning expectations are updated. The first phone run exposed the missed old Google wording after map presence had passed. That failure belongs to this copy change, not the base. Both Apple and Google assertions were corrected without weakening their map, owned-address or original-bookmark checks.

The final [native results](evidence/navigation/native-maps-preview-copy/native-results.json) report two passing phone Dark Mode journeys in 101.329 seconds and two passing tablet light journeys in 145.387 seconds. The Apple journey verifies owned-address precedence; the Google journey verifies the temporary native map and exact bookmark after relaunch. Source/products remain frozen during runtime, and appearance is restored. Final mobile and Mac compilers and three-file strict Swift lint pass. Mac compilation uses local ad hoc signing and provides no runtime credit.

The [inspected originals](evidence/navigation/native-maps-preview-copy/visual-review.json) show the dark phone MapKit card and the light iPad detail pane. On iPad, the revised warning and retained link are readable in the captured pane, without a floating top tab tier. On phone, part of the map caption is behind the native bottom tabs at that scroll position. The journey subsequently reaches the bookmark below; the capture does not establish full caption/scroll readability. That visual review, selected-row contrast, native Mac runtime and physical qualification remain open.
