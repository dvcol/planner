# Store listing draft

Prepared locally on 31 October 2026. These are editable submission materials,
not a submitted listing or a claim of final MVP acceptance. App Store Connect
accepted Plan 2Do and created app `6829213508` for iOS and macOS. MapCheck,
CheckPoint and Plan & Do were unavailable.

## Distribution constraint

This app is for the owner's personal use and unlisted distribution only. These
materials satisfy submission requirements; they are not a public launch or
marketing plan. Keep release manual and wait for unlisted approval before
releasing. Follow the
[standing release constraint](release-goals.md#personal-unlisted-distribution-reaffirmed-31-october-2026).

## English listing

**Name:** Plan 2Do

**Subtitle:** Places, lists and itineraries

**Description:**

Keep your places, tasks and trips together.

Save a website or Maps link, add your own notes and location, and organize it
into reusable lists. Build an itinerary from saved items and lists without
copying their content.

- Organize items with categories, tags, search and filters.
- Track completion, full estimates and remaining time.
- Arrange itinerary stops and view saved places on a map.
- Schedule items and itineraries in day, week and month views.
- Open saved guides inside Plan 2Do and return to your plan.
- Keep plans on your device, with optional synchronization through your private
  iCloud storage across devices using the same Apple Account.

Plan 2Do has native layouts for iPhone, iPad and Mac, with light and dark
appearances. Location lookups, route information and websites require their
providers to be available; your saved planning content remains usable offline.

**Draft keywords:**

`itinerary,travel,places,lists,tasks,calendar,trip,organize`

## App Review notes draft

The app works locally without a Plan 2Do account or iCloud sign-in. To review its
main workflow, create an Item, add it to a List, then create an Itinerary using
that Item or List. Map mode shows saved or resolved locations. Calendar
schedules can be added independently of activity estimates. External maps,
previews and websites depend on their providers and network access.

Optional sync uses only the signed-in user's private iCloud database. It does
not provide a public/shared database fallback. The app is intended for the
owner's personal planning across iPhone, iPad and Mac. We are requesting
unlisted distribution and will keep release manual while Apple reviews that
request. No paid content, subscription or developer-hosted account is required.

## Unlisted request draft

This application is intended for the developer's personal use across their Apple
devices, rather than discovery by a general App Store audience. Direct
installation from an unlisted link is the intended distribution workflow.
Planning data stays local with optional private iCloud synchronization. We
understand that an unlisted link does not restrict who can install the app, and
that App Review and unlisted-distribution approval are separate decisions.

These statements need owner review before either submission. No request has been
sent to Apple.

## Submission fields still to prepare

- Plan 2Do is registered for iOS and macOS as app `6829213508`. Release
  metadata is prepared as version `1.0.0`, build `1`.
- Select final screenshots from the accepted release build. Existing QA
  screenshots are evidence, not automatically finished store assets.
- Public support and privacy pages use the existing GitHub repository:
  `https://github.com/dvcol/planner/blob/main/docs/support.md` and
  `https://github.com/dvcol/planner/blob/main/docs/privacy-policy.md`.
  Apple-only review contact fields still need the owner's details.
- Complete remaining review contact and content-rights/distribution fields.
  Privacy responses and the age rating are saved as recorded below; inspect any
  further encryption/export-compliance question Apple presents.
- Request unlisted distribution through Apple's process after submission for
  review. Use manual release while the intended distribution is being arranged.

## Privacy-policy drafting facts to verify

The implemented data paths provide the starting point for the policy:

- Planner content is local; optional synchronization uses the user's private
  CloudKit database. There is no public/shared developer-funded fallback.
- Apple Maps/address previews, route lookups and link previews can contact
  providers. Provider results remain distinct from owned saved content.
- Opening a saved website uses WebKit's persistent website store, including
  website cookies and login state on the device.
- Exported backups contain the user's planning data and go to a destination
  selected by the user. Further portability qualification is outside MVP.

The [privacy audit](release-privacy-audit.md),
[privacy policy](privacy-policy.md) and [support page](support.md) now capture
the reviewed data paths and unfinished release checks. Do not infer a complete
“Data Not Collected” answer solely from the use of private iCloud. The public
support channel is the existing issue tracker. No private developer-account
contact details are copied into these pages.

## Saved Apple state, 31 October 2026

- Both platform drafts have the description, keywords, support URL and review
  notes saved, with manual release selected. No review submission or release
  has occurred.
- Signed iOS and arm64 Mac `1.0.0` (build `1`) uploads succeeded. Apple reports
  both builds “Ready to Submit”; both are selected in their saved drafts.
- The owner approved the reviewed “Data Not Collected” declaration and Apple's
  final compliance confirmation. The privacy responses are published, with the
  policy URL above. The open-web reader produces a saved age rating of 16+.
- Reviewed native iPhone and 13-inch iPad screenshots are uploaded, with Apple's
  reuse confirmation for smaller display sizes. The existing Item creation and
  relaunch journey passes on the disposable iPad Simulator as well. Mac store
  screenshots, Apple-only review contact details, the review sign-in
  checkbox and remaining content-rights/distribution declarations are unfinished.
  Unlisted distribution is not yet requested or approved.

## Apple submission references

- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- [App privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Unlisted app distribution](https://developer.apple.com/support/unlisted-app-distribution/)
