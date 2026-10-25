# Local restoration acceptance checklist

This checklist makes the remaining A20 and Q147–Q162 work concrete. It does not
add restoration policies or authorize merging collections. A pending check is
not an assumed production defect. Reproduce it through the existing real-store
boundary before changing code. Prefer the existing closure and maintenance paths.

## Qualified local behavior

| Accepted behavior | Local evidence |
| --- | --- |
| Choose the declared source-family winner across all five source kinds | [Q157](prototypes/native-source-restoration-maintenance.md) |
| Preserve independent reference identities, order, completion and original Add observations while following an open-family winner | [Q158](prototypes/native-source-restoration-entry-rebinding.md), [Q160](prototypes/native-restored-target-reference.md) |
| Keep the winner's complete ordinary owned collections without merging losing contents | [Links](prototypes/native-restored-owned-links.md), [bookings](prototypes/native-restored-owned-bookings.md), [labels](prototypes/native-restored-owned-labels.md), [memberships](prototypes/native-restored-owned-memberships.md), [stops](prototypes/native-restored-owned-itinerary-stops.md) |
| Keep the smallest public label-selection identity after target collisions | [Q162](prototypes/native-restored-label-collisions.md) |
| Reconcile related Item/List source families and mixed losing Itinerary contents | [Combined and related families](prototypes/native-restored-owned-reference-history.md) |
| Retire known closed bookmark/Schedule candidates while preserving fresh authorized restorations | [Closed owned families](prototypes/native-restored-owned-reference-history.md#closed-owned-families-and-late-delivery) |
| Retire known closed unreferenced source candidates, with or without a fresh restoration, across all five source kinds | [Closed source families](prototypes/native-restored-owned-reference-history.md#closed-source-families) |
| Reject an unknown source lifetime after family closure without changing native data, recovery or writer control, across all five source kinds | [Unknown source lifetimes](prototypes/native-restored-owned-reference-history.md#unknown-source-lifetimes-after-deletion) |
| Preserve the fresh Undo membership and repeated-branch completion when a closed-family membership and expanded copies arrive | [Closed membership families](prototypes/native-restored-owned-reference-history.md#closed-membership-family-after-undo) |

These checkpoints include bounded recovery, replay, migration and redelivery
cases. They do not claim that every interaction below has already executed.

## Remaining local checks

| Check | Required result | Gate |
| --- | --- | --- |
| Late closed Itinerary-entry restoration copies, including a fresh current entry | Preserve the fresh entry, route order and direct/expanded completion; reject stale identities | Real-store fixture and existing public read/export/replay boundary |
| Late closed Category/Tag selection restoration copies on Item/Itinerary owners | Preserve the current selection and owner fields/timestamps; close no unproven identity | Real-store fixture and existing public read/export/replay boundary |
| Source-owner and owned-reference families choose different candidates | Apply the accepted complete-winner policy where authority is proven; retain atomic rejection where existing declarations cannot prove it | Worked fixture first; request a decision only if the accepted contracts leave a concrete policy gap |
| Remaining import, legacy admission, causal-history and interruption outcomes named in older checkpoints | Match their existing literal contracts; establish which are covered by current tests before adding tests or code | Reconcile the retained diagnostics with the existing Core/HTTP suite coverage |

A20 closes the whole declared family after Delete. It does not authorize
redirecting independent references across closed families or predecessors.
Unknown candidates, contradictory bindings and unresolved authority keep their
existing atomic rejection. Ordinary Add creates a new association; explicit Undo
restores its original public identity under its approved fresh lifetime.

## Separate acceptance gates

Actual Mac window interaction, native Map/browser/change-stream lifecycles,
installed Share, protected signed storage, CloudKit/account convergence, system
Shortcuts/Siri and physical-device performance retain their own gates in the
[implementation map](implementation-map.md#remaining-implementation-and-acceptance).
Signing is deferred. Core/HTTP results do not qualify those boundaries.
