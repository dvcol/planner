# Native Release configuration checkpoint

31 October 2026. The navigation comparison is development tooling, not part of
the daily-use app. Its Mac menu/window and command-line entry are now available
only in Debug. Native Sidebar/Inspector commands, Settings and saved-data
navigation remain in Release. This adds no target, dependency or test seam.

## Executed checks

- The existing Planner scheme produces an unsigned universal Mac Release
  archive. The Debug Mac app also compiles successfully.
- The actual Release binary omits both comparison commands and the comparison
  launch flag. The Debug binary retains all three. This is compiled-artifact
  evidence, not an attended Mac menu interaction.
- The existing navigation target builds in Release for iPhone Simulator. Its
  runfile explicitly targets the Release app and UI runner.
- One existing normal-first-launch journey passes in 55.732 seconds on a fresh
  iPhone 18 Pro Simulator with no Apple Account. It verifies unavailable private
  iCloud feedback, local Item/notes Save and exact source identity/notes after
  relaunch. Its existing hit-region/description audits pass in Settings.
- All 254 native inputs stay unchanged during execution and match collection.
  Strict affected Swift formatting, whitespace and the new Markdown checks pass.

The [saved Item after relaunch](evidence/native-release-configuration-2026-10-31/saved-item-after-relaunch.png)
and [unavailable-iCloud explanation](evidence/native-release-configuration-2026-10-31/private-icloud-unavailable.png)
are inspected original native captures. The
[review record](evidence/native-release-configuration-2026-10-31/review.json)
retains source/product hashes, commands, compressed logs and exact scope.

## Release and publication limits

The Mac archive declares bundle `dvcol.planner`, container
`iCloud.dvcol.planner`, Production environment and version `0.0.1`. These are
configuration values; they do not prove a deployed production CloudKit schema,
distribution provisioning, production private sync or App Store upload validity.
The archive is intentionally unsigned and is not installed over the user's app.

No physical-device, Mac UI, live iCloud or account-transition test is run. No
production/cloud setting, signing resource, App Store metadata or source branch
is published. Final native/physical/assistive acceptance remains in its existing
tickets, including the separate Save contrast finding. Full bundled-SDK and
required-reason API privacy audit also remains release preparation.

The [store listing draft](../store-listing-draft.md) supplies English copy and
explicit unfinished fields. It is neither a final privacy declaration nor a
submitted listing. Draft name/subtitle/keyword lengths fit their field limits.

The owned Simulator and disposable data are removed after evidence export.
Temporary Mac build registrations are removed and the installed development app
is re-registered; its three baseline hashes remain unchanged. The small result
bundle is removed after retained evidence is verified. Useful compiled caches
and the unsigned archive remain available for the next release-preparation step.
