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

Actual invitation, acceptance, two-account edits, permission
changes, revocation and relaunch still need one signed integration session using
the iPhone owner account and different Mac account. Development schema creation
and Production deployment of the new scope field follow that session. No real
invitation has been issued by these local tests. No repeated iCloud off/on test
or new MCP listener is required for this work.

Calendar build 1.0.0(6), committed separately, uploaded successfully on
1 November. It excludes this unfinished sharing slice. App Store Connect confirms
Testing in the existing Personal internal group. No App Store submission or
external tester invitation was made.

Raw test outputs and screenshots stay temporary and outside Git.
