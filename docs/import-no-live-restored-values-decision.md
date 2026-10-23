# Incoming restored values when the current source is deleted

Status: Q151 A accepted on 23 October 2026. The concrete lineage/reference contract requires review before implementation. Q149 A and its known-candidate follow-up require a current live owner. Their implementation does not admit an incoming restored lifetime over a currently deleted source. Independent local qualification continues; signing is separate.

## Concrete case and current gate

Current Planner retains deleted Museum X101/A811 and its closure, with no live Museum. A valid backup represents Museum X101/D813 under a restoration family rooted in A811, plus a new Tour bound to X/D. The user explicitly selects Overwrite and authorizes restoration. The file is independently valid and its shared retained provenance agrees.

The current public review can describe the restoration, but execution rejects it without partial import or receipt. `PlannerImportRestoration` requires a restored incoming source itself to be a closed current identity; D is a restoration candidate, not the closed A. The permanent `reviewedRestoreKeepsPublicIdentityAndClosesThePreviousLifetime` regression preserves this admission gate. Q149's value-copy authority applies only while a matching live owner exists and therefore does not decide this case.

## Decision and impact

A. Restore the incoming values as a fresh local restoration under the current retained deletion lineage. Keep X's public identity, generate a fresh live lifetime, preserve current deletion/history metadata and bind the explicitly imported Tour to that fresh Museum. Do not adopt the backup's D/family as canonical history. Previously removed references stay removed unless they are represented and separately included in the explicit restoration review. The concrete authority, lineage, owned-reference and failure contract must be reviewed before implementation.

B. Admit the incoming D and its restoration family. This preserves the backup's restored lifetime instead of generating a local one, but requires rules for canonical family admission, current closures, related histories and later convergence. It cannot be inferred from faithful import into an empty planner.

C. Keep rejecting this import. Current data stays unchanged; use a backup of the pre-deletion source for the existing explicit restoration workflow, or restore the file into a separate empty dataset. This retains the present restriction and leaves this incoming-candidate restoration outside the implemented capability.

Recommend A, consistent with deliberate manual restoration and retaining authoritative current history. No choice silently restores a source, changes Skip, introduces Trash, exposes backup administration to agents, or removes the need for physical convergence tests.

## Existing boundaries and prerequisite policy

Use the already accepted public import review/execute, canonical export/read, recovery, receipt and reopen seams. No additional direct test boundary is proposed by the policy question. A later concrete review must settle exact declarations and literal expected graphs for the selected behavior. Q150 A's browser Return policy is accepted independently; its native qualification remains separate.

## Concrete review

The [Q152 contract](import-no-live-restored-values-contract-review.md) specifies current-lineage construction, represented dependencies, owned/contextual guards, truthful preview/results and real-storage qualification. Its approval is the remaining prerequisite for this transformation. Q150 A is accepted separately.
