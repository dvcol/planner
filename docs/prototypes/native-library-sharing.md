# Optional library sharing

The accepted 1 November plan adds Off, Whole library and Selected Lists in
Settings → Sharing. One library has one invitation group and one active mode.
Changing the mode or selected Lists revokes the previous invitation before
exposing the replacement scope. Deleting a selected List also ends that invitation
before its deletion is uploaded. Stopping sharing preserves saved plans.

Both modes use one private CloudKit record hierarchy. Whole library includes all
plan records. Selected Lists include the original Lists, memberships, live Items
and their owned links, bookings and label selections; other List memberships and
private Itineraries stay outside that selected hierarchy. Global Item edits and completion remain
live wherever the owner also uses that Item. There are no copied Items or
automatic collection merges. Scoped editors cannot delete shared sources
globally; read-only participants cannot write. The owner's private control zone
retains sharing authority separately from the shared records.

Whole-library hierarchy invitations use sharing configuration version 2. Earlier
zone-wide version 1 invitations remain readable. Selected-List and Off configurations
remain version 1. Older clients reject the new whole-library configuration and
need an update before syncing it. This avoids converting an existing record zone
between incompatible sharing capabilities; it adds no data-zone migration or
public database fallback.

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

Six focused Core sharing tests pass. They cover live scoped contents, private
relationship exclusion, permissions, exact record identity/parents, and version 1
compatibility with the version 2 whole-library hierarchy. The previously qualified
native contextual-identity and picker checks remain applicable; their expensive
fixture setup is not repeated as routine smoke coverage.

Signed Development builds have exchanged fresh edits between an actual iPhone
and Mac using different iCloud accounts. Selected Lists exposes the selected
List and its Item while excluding the private List. Whole library exposes both
Lists. Each mode has passed a Mac edit received on iPhone and an iPhone reply
received on Mac, with unique markers preventing old values from counting as a
new exchange. The native owner controls prepare invitations, add the explicitly
verified account through Apple's Add Access action, and copy the private link.
Mac acceptance and received-data assertions use the production sharing and Core
interfaces. No messaging service or iCloud account sign-out is required.

The checks exposed three corrections: durable local saves now wake the sync
worker directly; both modes use the same record hierarchy because the existing
zone rejected a switch to zone-wide sharing; and acceptance reads the saved share
before constructing its library descriptor. Existing plan identities and content
are preserved. The original selected-List boundary is restored after the whole
library check. The iPad is not controlled by these tests.

The Production root metadata field `PlannerNode_v1.f_scopeData` is already
deployed. The legacy `cloudkit.share.f_scopeData` field remains for older
zone-wide invitations. No additional schema deployment or data-zone migration is
needed for the hierarchy correction. Build 7 is already available in the Personal
internal TestFlight group; the corrections are prepared for build 8. Neither App
Store submission nor external distribution is enabled.

Actual native permission changes, read-only invitation behavior, revocation,
and cross-account TestFlight Production qualification remain separate beta
checks. Core permission and stale-access protections remain covered by existing
tests. No repeated iCloud off/on session is a prerequisite for this work.

A later restored-scope repeat exceeded its two-minute receiver wait. A separate
read of the authoritative private server record confirmed the exact reply had
arrived. The attended harness now spaces explicit refresh requests ten seconds
apart and allows three minutes for the reply; it does not promise a sync latency
guarantee. This timing limit does not erase the earlier successful device exchanges.

Raw test outputs, contact details, invitation links and screenshots stay temporary
and outside Git.
