# Source and owned restoration families choosing different versions

Status: Q163 A accepted on 26 October 2026. Crossed source/owned-family
reconciliation is explicitly deferred beyond MVP. Preserve every record and the
existing atomic rejection. An affected dataset remains unavailable for canonical
reads/export until explicit recovery or later reconciliation. Ordinary Q161/Q162
cases remain implemented. No new ownership/lifetime policy, production change or
signing setup is authorized by this deferral.

## Reproduced conflict

Two independently valid snapshots restore the same Museum. The declared source
family chooses Museum814 over Museum815. A separate family restores the same
public guide identity and chooses guide872 over guide889.

| Source version | Owned guide | Result of that family's winner rule |
| --- | --- | --- |
| Museum814 | guide889, "Late guide" | Winning source, losing guide candidate |
| Museum815 | guide872, "Losing guide" | Losing source, winning guide candidate |

The same conflict occurs for a booking instead of a guide and for an Itinerary
instead of an Item. Each pre-union snapshot passes the actual import decoder.
After both arrive in one native store, canonical reads/export reject at
`/restorationFamilies/0/candidates` with "The restored live record must use the
stable candidate lifetime." Reopening also remains unavailable. Both source
versions, complete owned values, recovery files and writer control stay intact.

This is not the ordinary Q161 case where the two owners have unrelated guide or
booking identities. It involves one public owned identity with its own proven
restoration family. Prior owned-history tests declared its other candidate in
history without a live copy on the winning source.

## Why the accepted rules do not choose an outcome

[A20](architecture-review-packet.md#versioned-schema-and-reference-ownership) chooses the stable
candidate in each declared family. The [portable contract](portable-data-contract.md)
uses that mechanism for owned records too. [Q161 A](native-restored-owned-data-decision.md)
keeps the winning source's complete contents and closes losing-owner contents.

Keeping guide889 unchanged violates its family's winner rule. Closing that whole
family closes guide889 too, removing part of Museum814's contents. Keeping and
transferring guide872 changes which contents survive on Museum814. Existing
declarations do not prioritize these competing rules.

Q151/Q152's rejection of foreign owned candidates concerns a reviewed import
transformation. It does not settle the union of these two independently valid
native snapshots. Q160 excluded candidate-owned collections; Q161 did not
explicitly settle competing source and owned-family authority.

## Q163 choices

- **A, recommended for MVP:** explicitly defer this crossed-family case. Preserve
  every native record and the current atomic rejection. A dataset containing it
  remains unavailable for canonical reads/export until explicit recovery or a
  later reconciliation change. Ordinary Q161 cases remain implemented. This
  avoids another automatic lifetime policy, at the cost of this recovery limit.
- **B:** prioritize the winning source's values. Keep Museum814's guide/booking
  values under newly authorized owned lifetimes, preserving public identities
  and truthfully closing the old owned family. This requires a concrete automatic
  restoration/identity contract before implementation; it is not permission to
  merge collections or alter unrelated sources.
- **C:** prioritize the owned-family winner. Retain guide872's values, bind that
  guide to Museum814 and discard guide889's values. This revises Q161 for a shared
  contested owned identity and requires a concrete ownership/history contract.

The user selected A. The existing green preservation diagnostic proves safe
rejection; the user's decision explicitly accepts that recovery limitation for
MVP. It does not implement reconciliation or authorize automatic data loss.

## Local qualification

The diagnostic uses the existing real native-storage and public read/export
boundaries. Four cases cover Item/Itinerary owners and guide/booking contents.
Complete source/owned values are compared before rejection and after reopen.
The existing eight-case discarded-owned import regression also runs after the
test fixture gains explicit owner selection. No production code, schema,
portable format, writer gate, public interface or test boundary changes.

Executed packets and source/product reconciliation are recorded in the
[qualification report](prototypes/native-crossed-restoration-family.md).
