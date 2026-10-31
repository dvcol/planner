# Store listing draft

Prepared locally on 31 October 2026. These are editable submission materials,
not a submitted listing or a claim of final MVP acceptance. App Store name
availability and the account's existing app record have not been checked.

## Distribution constraint

This app is for the owner's personal use and unlisted distribution only.
These materials satisfy submission requirements; they are not a public launch
or marketing plan. Keep release manual and wait for unlisted approval before
releasing. Follow the [standing release constraint](release-goals.md#personal-unlisted-distribution-reaffirmed-31-october-2026).

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

## Submission fields still to prepare

- Confirm the available App Store name; the working name is not registered by
  this draft. Choose the release version/build number.
- Select final screenshots from the accepted release build. Existing QA
  screenshots are evidence, not automatically finished store assets.
- Provide a support page with the owner's approved contact details and a public
  privacy-policy URL. Do not substitute developer-account contact details
  without approval.
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

Audit the final bundled code/SDKs and required-reason API manifest before
finalizing privacy declarations. Do not infer a complete “Data Not Collected”
answer solely from the use of private iCloud. The owner still needs to approve
the final policy and public contact information.

## Apple submission references

- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- [App privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Unlisted app distribution](https://developer.apple.com/support/unlisted-app-distribution/)
