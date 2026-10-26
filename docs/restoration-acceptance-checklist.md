# Local restoration acceptance checklist

This checklist records A20 and Q147–Q163 local acceptance and its limits. It does not
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
| Retire proven closed direct/List stop copies while preserving deletion or fresh Undo and exact route state; reject unknown stop lifetimes without mutation | [Closed stop families](prototypes/native-restored-owned-reference-history.md#closed-itinerary-stop-families) |
| Preserve deleted or fresh Category/Tag selections on Item/Itinerary owners after closed-family redelivery; reject unknown selection lifetimes without mutation | [Closed label families](prototypes/native-restored-owned-reference-history.md#closed-label-selection-families) |

These checkpoints include bounded recovery, replay, migration and redelivery
cases. They do not claim that every interaction below has already executed.

## Local acceptance limits

| Check | Qualified result | Limit |
| --- | --- | --- |
| Source-owner and owned-reference families choose different candidates | Four real-store cases preserve both complete versions under rejection, including reopen | [Q163 A](native-crossed-restoration-family-decision.md) explicitly defers reconciliation beyond MVP. Preserve every record; affected datasets remain unavailable for canonical reads/export until explicit recovery or later reconciliation |
| Named import, legacy admission, causal-history and interruption outcomes from older checkpoints | The [history audit](local-restoration-history-audit.md) links later evidence, including [prepared-only Move/Capture](prototypes/native-prepared-move-capture.md), and separates current qualification from historical open lists | Named Q161/Q162 payload faults are qualified locally. Separate native/system/physical gates remain. Historical open lists do not authorize a general reconciliation framework |

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
