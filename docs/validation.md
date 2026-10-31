# MVP validation status

## Artifact policy

Keep application source, required test fixtures and concise validation results
in Git. Generate logs, screenshots, videos, result bundles and source snapshots
in temporary storage. Inspect them while diagnosing or reviewing a run, then
discard them. Raw run output is not a repository or publication deliverable.

Older prototype notes describe the results of their original runs. Their raw
artifacts and tracker snapshots have now been discarded. Required fixtures in
`Packages`, `PlannerFixtures` and `docs/fixtures` remain part of the source. The
owner approved purging the earlier artifacts from published branch history. Main
and both prototype branches now use the cleaned history. Existing clones and
GitHub caches cannot be recalled by rewriting branch references.

## Latest focused checks, 31 October 2026

- Mac Map: `testItineraryMapFitsDistinctPlacesAndUsesAvailableWidth` passes in
  159.645 seconds on the signed build from application checkpoint `a15d57877908`
  (formerly `278da3da`). Three distinct pins remain tappable, repeated Hotel
  stops share a counted marker, walking and driving calculate all three legs,
  and transit offers its explicit Maps fallback. Resizing to 1200 and 1600
  points preserves the selected bookmark identity and bounds details while
  expanding the Map. The test does not open the external transit route. Three
  original captures were inspected, then the raw output was discarded. Manual
  automation authentication is unchanged.
- Phone Simulator: the Dark maximum-text navigation/save/relaunch journey passes
  in 121.079 seconds with Increase Contrast. The normal-size Light draft-guard
  journey passes in 79.297 seconds. New Item hides the tab bar while editing and
  restores it after Save. Original captures match the represented appearances.
  The older Simulator theme mismatch has no proven cause.
- Affected Simulator, Mac and signed mobile builds pass. The signed mobile build
  has not been newly installed for this editor change.
- The final Plan 2Do packaging change passes the existing phone Simulator
  creation/cancel/completion/relaunch journey in 61.841 seconds. Affected Swift
  formatting, shell syntax, project/scheme and Info-plist checks pass. Signed
  iOS and arm64 Mac Release archives and App Store exports pass signature and
  bundle inspection with version `1.0.0` (build `1`), the intended app/group
  identifiers and Production private CloudKit. Xcode reports successful upload
  for both packages. App Store Connect subsequently reports both builds
  “Ready to Submit.” This does not prove review, final acceptance or release;
  the installed development app remains untouched.
- A single existing Item creation/cancel/completion/relaunch journey also passes
  in 76.007 seconds on a disposable 13-inch iPad Simulator for the required store
  capture. Reviewed native iPhone and iPad images are uploaded to App Store Connect;
  their raw run artifacts are discarded after use. No physical device or
  additional sync scenario is involved.
- Recorded same-account physical iPhone/iPad create, bidirectional edits, delete
  and relaunch pass with private CKSyncEngine synchronization. Further
  account-transition and stress scenarios remain deferred.
- The user reports physical iPad Apple Maps Cancel/Save/relaunch and retained
  original link/map. The user also confirms named-place title prefill on iPhone.
  Exact UUID/cleanup readback was not independently observed in the manual iPad
  check. Native Google Maps sender coverage remains open; the app is not
  installed on the available devices.

## Open acceptance and release gates

Native Save still triggers the separate unfiltered editor contrast audit. Its
detailed message is `Contrast failed for SwiftUI.AccessibilityNode`. Palette
probes did not establish a fix and were reverted; no audit exclusion is added.
Functional passes do not constitute a passing Save contrast audit.

Hands-on keyboard, assistive/layout and final daily-use acceptance remain open
in the [canonical map](https://github.com/dvcol/planner/issues/1). Apple accepted
Plan 2Do; the approved Production schema is deployed and both release packages
uploaded. Store assets, review metadata and remaining declarations still precede
submission and unlisted approval. Reviewed application source is published on
`main`; generated artifacts are excluded from the handoff.

## Repository cleanup

Generated validation artifacts and obsolete design previews are removed from the
current tree and ignored for future runs. The cleanup preserves application
code, configuration, test fixtures and shipping icon assets. Completed local Map
outputs and obsolete release archives are discarded after review; the current
build cache and installed app are preserved.

Gitleaks 8.30.1 finds no secrets in the cleaned tracked tree. This automated
check complements the device/account metadata review; it is not a guarantee that
arbitrary future changes contain no sensitive data. The filtered-history scan
has one reviewed false positive: ordinary prose about search tokens. All nine
branch-tip comparisons preserve source and required fixtures, and the cleaned
history passes Git integrity checks.

The owner explicitly approved discarding abandoned local source variants and
orphan objects. Local garbage collection is complete; the retained Git pack is
7.61 MiB and the post-cleanup integrity check passes. Main contains the reviewed
MVP, and the current checkout follows main.
