# Membership removal across restored candidates

Status: proposed Q159. Q158's direct-entry rule is committed and locally qualified. This decision concerns the next aggregate target-reference rule, before its serialized declaration or tests.

## Why existing decisions do not settle this case

A20 authorizes references to either declared restoration candidate to follow the deterministic winner. Q155 defines strict membership Remove and observed-Add generations for an exact Item/List lifetime pair. It does not explicitly say whether the two authorized candidates of one open Item restoration family share that removal authority.

Current portable validation requires retained provenance and removal observations to match exact endpoint lifetimes. Rewriting old records to the winner would falsely describe what the original Add observed. Expanding that comparison is a serialized semantic change, even if its fields look unchanged. The next concrete contract must declare the representation/version and preserve original receipt replay.

## Literal input

Item X101 has a proven open restoration family declaring winner814 and candidate815, both descended from closed predecessor811. Independent List L201/821 survives unchanged. You explicitly Remove X101/814 from L201/821. Strict removal M is retained. An offline Add made against X101/815 arrives afterward, with no observation of M. Both candidate references are authorized to resolve to winner814.

### A. One removal authority within the proven open family

M suppresses the unaware Add against815 when it resolves to814. A deliberate new Add can work after observing the applicable removal. Preserve original attested bindings and observation records, and compare their authority through the proven family without fabricating observations.

This keeps one visible Item/List relationship from returning through another candidate of the same restoration. It extends the exact-pair rule and requires a concrete compatibility/portable-history declaration before implementation. Closed predecessor families, unknown candidates, new unrelated source lifetimes and unresolved authority do not become equivalent.

### B. Keep exact candidate pairs independent

M applies only to814/821. The Add attested against815/821 can survive and then bind to814/821. This preserves exact-pair removal authority, but the Item can reappear in the List after your Remove through another authorized candidate.

The concrete normalization contract must still make retained provenance truthful after binding. Existing pair/duplicate handling cannot simply rewrite its endpoints.

### C. Leave these cases unresolved

Reject cross-candidate membership maintenance when removal authority could differ. Preserve native data and recovery for later work. Independent target-reference cases without this conflict can continue, but this required membership case remains on the map.

## Recommendation and next declaration

Recommend A, matching the accepted expectation that an unaware offline Add cannot undo a deliberate Remove. This is a new cross-candidate policy choice, not a claim that Q155 already approved it.

After this answer, review one aggregate target-reference contract for independent List memberships, referenced List entries and Category/Tag targets. It must separate target rebinding from candidate-owned collection transfer, preserve contextual identities/history and original replay, and explicitly reject unresolved label-identity collisions. Existing Q155 duplicate-membership rules apply only after pair/generation authority is proved. No dependent implementation or test is authorized by this draft alone. Signing stays deferred.
