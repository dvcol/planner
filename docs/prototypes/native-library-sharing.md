# Optional library sharing

The accepted 1 November plan adds Off, Whole library and Selected Lists in
Settings → Sharing. One library has one invitation group and one active mode.
Changing the mode or selected Lists revokes the previous invitation before
exposing the replacement scope. Deleting a selected List also ends that invitation
before its deletion is uploaded. Stopping sharing preserves saved plans.

Whole library uses a private CloudKit zone share. Selected Lists use one record
hierarchy containing the original Lists, memberships, live Items and their owned
links, bookings and label selections. Other List memberships and private
Itineraries stay outside that hierarchy. Global Item edits and completion remain
live wherever the owner also uses that Item. There are no copied Items or
automatic collection merges. Scoped editors cannot delete shared sources
globally; read-only participants cannot write. The owner's private control zone
retains sharing authority separately from the shared records.

Received libraries have separate local stores, sessions, cache/preference
namespaces and saved Shortcut identities. A fresh invitation generation has a
fresh library identity, including when CloudKit reuses a zone-share record name.
Selecting a library that is unavailable
shows an error; it never silently opens the personal library. Open editors and
running external actions prevent switching. Share capture uses the remembered
library and requires an authorized destination. A known revocation closes its
sessions and prevents later offline writes; unsent local data is retained.
Temporary network loss preserves cached plans, with access verified again before
upload. Account changes retain the existing account isolation.

Only the private and shared CloudKit databases are used. Shared data consumes
the owner's private storage, with no public/developer-funded fallback. Physical
model20 and portable5 are unchanged; native writer gate25 prevents older local
writers from opening the new configuration. Update participating devices before
enabling sharing.

## Qualification

Four focused real-storage/CloudKit-value tests pass: live scoped projection and
private exclusions, scoped/read-only command policy, original zone/parent
preservation, and exact invitation hierarchy filtering. Removing an unused label
from the projection preserves the owner's saved label. Projection validation
uses the ordinary graph validator before any invitation is created.

Nine app-hosted production-interface checks pass: source/library identity,
explicitly bound query results, draft-switch pinning, Item creation in a List,
Category/List reads, repeated itinerary appearances, links, Schedule owners,
deferred content and directed opening. The first run reproduced a dependency
lookup crash in two constructors; identities now receive explicit library context
instead. No constructor depends on running inside an Intent. Strict Swift lint
passes. Mobile app/Share compilation and two production iPhone Simulator journeys
pass: creation-menu cancellation and Calendar modes with the landscape list on
the left. Native invitation controls still require the signed session below.

The expanded contextual regression slice establishes 41 unique passing
app-hosted methods, including stale/malformed choices, repeated stops, ordered
bookmarks, cancellation, recovery and paging. Legacy literal paths in fixtures
now assert the library envelope too; embedded source UUIDs use the underlying
record identity. The existing 130-entry fixture exceeded short runner budgets
and then passed once with a ten-minute allowance. Reuse that result rather than
repeating the expensive setup as routine smoke coverage.

The signed iPhone owner flow now creates a private scoped invitation and opens
Apple's native management sheet. Automated setup preserves existing plans, uses
two uniquely named Lists and one Item, selects only the shared List, verifies the
private List remains unchecked, and confirms the one-Item preview before Apply.
The inspected native sheet shows only the owner and invited-person edit access.
No participant has been added yet. Two-account acceptance, edits, permission
changes, revocation and relaunch remain open, followed by Production deployment
of the scope field. No repeated iCloud off/on test or new MCP listener is needed.

The first signed build 7 attempt stopped during startup with
`recoveryIntegrityFailure`: private storage writes version 25, but the recovery
reader's version list ended at 24. A focused real-store regression reproduced
the exact rejection only for 25. The reader now accepts 25 without weakening
ownership, payload digest or receipt validation. Five affected test methods pass,
including versions 23–25 and seven existing invalid/scoped-status cases. Signed
Mac/iPhone rebuilds resume the same session with retained data; no reset is needed.

After that correction, physical startup exposed a SwiftUI metadata stack overflow
in the List collection column, also reproducible with an empty local dataset.
Explicit `AnyView` boundaries around its content branches limit type expansion.
Two existing physical iPhone journeys now pass: creation-menu cancellation and
normal-library Settings/status/Sync now. The latter reports Up to date before
and after synchronization. A cached runner first failed against obsolete sidebar
selectors; rebuilding it for current navigation resolved that separate test
failure. Signed iPhone and Mac builds and strict Swift lint pass.

Opening Sharing then exposed a separate signed-device preview crash: its
temporary SwiftData configuration left CloudKit automatic. The preview now
explicitly uses no CloudKit database. A physical regression reproduces the
original crash, then passes opening Sharing, previewing Whole library, opening
the Selected Lists picker and cancelling without changing the saved Off scope.
Controls wait for loading and prevent concurrent changes during preparation.

Real invitation creation also exposed stale CloudKit versions in parent-link
updates. Preparation now fetches current records and the current root before
optimistic saves, preserving server content while changing sharing parents.
Atomic failures report the causal record error instead of a cancelled peer.
The same disposable fixtures survive the failed-preparation reset and successful
retry. The native owner flow passes in 86.5 seconds; five focused Core sharing
tests, signed platform builds and strict affected Swift lint pass. Recipient
entry in Apple's controls is the current attended step; raw diagnostics stay local.

Calendar build 1.0.0(6), committed separately, uploaded successfully on
1 November. It excludes this unfinished sharing slice. App Store Connect confirms
Testing in the existing Personal internal group. No App Store submission or
external tester invitation was made.

Raw test outputs and screenshots stay temporary and outside Git.
