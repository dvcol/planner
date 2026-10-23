# A removed membership and an unseen independent add

## Current decision

Q153 is pending. Q16 already settles removal versus edits or reordering of the existing membership, independent additions to other Lists, and ordinary re-add starting locally Todo. It does not settle a new membership for the same Item/List pair when its writer never saw the removed membership.

This is local concurrency implementation work. Signing is not needed to establish the native storage behavior or prepare the contract. Real CloudKit delivery and physical convergence remain separate gates.

## Worked case

1. Both devices know Hotel X and List A. Device A has membership M401; device B has not received it.
2. A removes M401. Its retained marker closes that membership identity and lifetime.
3. While offline and unaware of M401 or its removal, B independently adds Hotel to A as M402, initially Todo.
4. The devices reconnect. M401 remains removed. The unsettled question is whether M402 makes Hotel visible in A again.
5. After receiving the removal, an explicit ordinary Add must still create a new local Todo membership. An independent addition to another List survives either policy. Shared Item content, global completion and other appearances remain unchanged.

A. Removal wins for the same pair unless a new Add observed that removal. M402 does not put Hotel back. Adding it after synchronization works normally. This needs minimal owner/source identity and causal removal provenance so Planner can distinguish the late offline Add from the deliberate later re-add. No deleted title, notes or other content belongs in that metadata.

B. The unseen independent Add survives. Removing M401 closes the relationships A knew; M402 becomes visible after reconnection. Edits or reordering of the removed M401 still lose. This permits an Item to reappear in the List after Remove, without resurrecting the old membership.

Recommendation: A, for a Remove action that stays effective through reconnection. This is a new policy case, rather than a reinterpretation of Q16. The concrete native/portable and recovery declarations follow the answer before their dependent implementation.

## Existing evidence and constraints

The [accepted conflict rules](offline-conflicts-and-recovery.md) cover removal against an existing association's edits/reorder. The [architecture packet](architecture-review-packet.md#definition-of-ready-and-required-tdd-evidence) already approves native duplicate-context store testing, so that test boundary does not need another approval.

The [first actual native-store case](prototypes/native-membership-consolidation-readiness.md) inserts two real native memberships with the same owner/source bindings, then observes public Planner query/read behavior. It reproduces `readUnavailable`, with the message `List memberships are duplicated and unresolved.` No CloudKit callback, public production hook or signing change is involved.

Current Membership fields retain the association identity/lifetime, owner/source bindings, rank and local Bool. Its removal target retains only the removed membership identity/lifetime. New membership creation has no observed-removal basis. Consequently the existing declarations cannot distinguish step 3 from step 5. Adding that distinction must preserve older backups, migrations, exact appearance targeting, replay and independent recovery; it requires a concrete reviewed contract.
