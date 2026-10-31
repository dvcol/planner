# Store listing draft

Prepared locally on 31 October 2026. These are editable submission materials,
not a submitted listing or a claim of final MVP acceptance. App Store name
availability and the account's existing app record have not been checked.

## Distribution constraint

This app is for the owner's personal use and unlisted distribution only. These
materials satisfy submission requirements; they are not a public launch or
marketing plan. Keep release manual and wait for unlisted approval before
releasing. Follow the
[standing release constraint](release-goals.md#personal-unlisted-distribution-reaffirmed-31-october-2026).

## English listing

**Working name:** Planner

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
- Open saved guides inside Planner and return to your plan.
- Keep plans on your device, with optional synchronization through your private
  iCloud storage across devices using the same Apple Account.

Planner has native layouts for iPhone, iPad and Mac, with light and dark
appearances. Location lookups, route information and websites require their
providers to be available; your saved planning content remains usable offline.

**Draft keywords:**

`itinerary,travel,places,lists,tasks,calendar,trip,organize`

## App Review notes draft

The app works locally without a Planner account or iCloud sign-in. To review its
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

- Confirm the available App Store name; the working name is not registered by
  this draft. Release metadata is prepared as version `1.0.0`, build `1`.
- Select final screenshots from the accepted release build. Existing QA
  screenshots are evidence, not automatically finished store assets.
- Public support and privacy pages use the existing GitHub repository:
  `https://github.com/dvcol/planner/blob/main/docs/support.md` and
  `https://github.com/dvcol/planner/blob/main/docs/privacy-policy.md`.
  Apple-only review contact fields still need the owner's details.
- Complete app privacy, age rating, encryption/export-compliance and review
  contact fields from the actual release configuration.
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

## Apple submission references

- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- [App privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Unlisted app distribution](https://developer.apple.com/support/unlisted-app-distribution/)
