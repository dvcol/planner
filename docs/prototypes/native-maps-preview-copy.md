# Maps preview wording

The native UI review found technical provider terminology in ordinary saved Item details. Maps previews now say that place details come from the saved link and have not been verified. A Google search link continues to describe a search location, without claiming a resolved business.

This copy change preserves original URLs, temporary provider data, owned-location precedence, fallback actions and backup semantics. It adds no production interface or schema change. The existing controlled Maps resolver tests have matching wording expectations; this is not a behavior-red claim.

[Recorded validation](evidence/navigation/native-maps-preview-copy/results.json) reports four passing filtered test functions, including the two-case ineligible-URL test, and strict Swift lint. The first sandboxed attempt could not access the compiler cache and executed no tests. The permitted retry passed. [Logs and source hashes](evidence/navigation/native-maps-preview-copy/) preserve both attempts.

This checkpoint does not establish native layout, complete contrast, physical-device or whole-app polish acceptance. The selected-row contrast audit and ticket 23 remain open.
