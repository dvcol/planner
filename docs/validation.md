# MVP validation status

## Artifact policy

Keep application source, required test fixtures and concise validation results
in Git. Generate logs, screenshots, videos, result bundles and source snapshots
in temporary storage. Inspect them while diagnosing or reviewing a run, then
discard them. Raw run output is not a repository or publication deliverable.

Older prototype notes describe the results of their original runs. Their raw
artifacts and tracker snapshots have now been discarded. Required fixtures in
`Packages`, `PlannerFixtures` and `docs/fixtures` remain part of the source.
Published Git history still contains earlier artifacts; removing those objects
requires a separately reviewed history rewrite.

## Latest focused checks, 31 October 2026

- Mac Map: `testItineraryMapFitsDistinctPlacesAndUsesAvailableWidth` passes in
  159.645 seconds on the signed build from application checkpoint `278da3da`.
  Three distinct pins remain tappable, repeated Hotel stops share a counted
  marker, walking and driving calculate all three legs, and transit offers its
  explicit Maps fallback. Resizing to 1200 and 1600 points preserves the
  selected bookmark identity and bounds details while expanding the Map. The
  test does not open the external transit route. Three original captures were
  inspected, then the raw output was discarded. Manual automation authentication
  is unchanged.
- Phone Simulator: the Dark maximum-text navigation/save/relaunch journey passes
  in 121.079 seconds with Increase Contrast. The normal-size Light draft-guard
  journey passes in 79.297 seconds. New Item hides the tab bar while editing and
  restores it after Save. Original captures match the represented appearances.
  The older Simulator theme mismatch has no proven cause.
- Affected Simulator, Mac and signed mobile builds pass. The signed mobile build
  has not been newly installed for this editor change.
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
in the [canonical map](https://github.com/dvcol/planner/issues/1). Unlisted
release preparation separately awaits the final name and Production schema
approval. Public source must pass a secrets/privacy review; generated artifacts
are excluded from that handoff.

## Repository cleanup

Generated validation artifacts and obsolete design previews are removed from
the current tree and ignored for future runs. Application code, configuration,
test fixtures and shipping icon assets are unchanged. Completed local Map
outputs and obsolete release archives are discarded after review; the current
build cache and installed app are preserved.

Gitleaks 8.30.1 finds no secrets in the cleaned tracked tree. This automated
check complements the device/account metadata review; it is not a guarantee
that arbitrary future changes contain no sensitive data. Published history
still requires the separately reviewed purge before source publication.
