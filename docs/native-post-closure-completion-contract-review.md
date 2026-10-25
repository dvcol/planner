# Explicit completion after an imported context closure

Status: Q156 A accepted on 25 October 2026. The [local implementation checkpoint](prototypes/native-post-closure-completion.md) passes the affected Mac storage cohort, real HTTP operations, matching native builds, genuine older-Core-writer rejection and phone/dark-iPad checkbox/relaunch/Reopen journeys. The refresh correction retains informed Done/Reopen rows without repeated maintenance and still retires stale rows. The affected mobile cohort also passes all four batches. Smaller canonical-root Done/Reopen and exact replay cases now pass on Mac/iPhone with production unchanged. Actual child SIGKILL after a blocked activation and fresh retry now pass with original recovery bytes/history preserved. Observed-marker/head partial delivery now rejects safely, preserves saved replay and resumes after exact record return on Mac/iPhone. Further lineage/failure qualification and external gates remain open; this is not full contract acceptance. Signing stays deferred. The implementation uses the already approved public Core, native-input, recovery-filesystem, HTTP and native UI boundaries, with no additional direct test seam.

## Observed problem and accepted intent

A reviewed import removes Hotel's saved completion from one itinerary List stop while retaining the Item, membership and stop. Its exact expanded-completion marker remains, and that live appearance becomes implicit Todo. A later deliberate Done action should remain usable without changing the Item globally, replacing the stop or recreating the List membership. Old offline completion data must still lose to the retained removal.

The [actual public-interface probe](prototypes/evidence/native-membership-consolidation/post-closure-completion-readiness-mac/execution.json) compares otherwise identical data with and without the marker. Without it, Done applies with complete recovery at checkpoint 2. With it, Done rejects before saving with `recoveryIntegrityFailure`: “The removed expanded completion is still live or unsupported.” The probe's temporary test source is archived with its executed inputs; the committed test source is restored exactly. This is readiness evidence, not a passing implementation test.

Existing completion changes observe other completion changes, not deletion markers. A fresh UUID cannot distinguish a deliberate action after the removal from a delayed action created before it. Restoration families have no expanded-completion identity kind. Reusing a membership removal declaration, dropping the marker, inferring a timestamp winner or changing a containing relationship would supply different semantics.

## Proposed declaration and causal rule

Add `observedExpandedCompletionDeletionIds: [UUID]` to `PlannerPortableCompletionChange`. It is an immutable UUID set, serialized in stable order. Existing initial alias values, original contexts, change identities and `observedChangeIds` retain their meanings. Newly recorded changes for standalone membership or direct itinerary contexts have an empty set; nonempty claims for those contexts reject.

For an expanded assertion, every observed ID must name a retained `expandedCompletion` marker for its exact context, or the same already proven eligible canonical alias group. The group must preserve the List-entry lifetime, Item/List bindings and membership removal generation. Unknown, duplicate, cross-branch or unproven claims reject. This introduces no new authority for missing alias roots, closed membership generations, competing lifetimes or restoration families.

A deliberate Complete or Reopen records every currently known applicable expanded-completion deletion ID. An assertion missing any applicable closure remains historical and cannot supply the current value. Once a closure exists, initial contributions cannot recreate that removed value. Among eligible explicit assertions, keep A17's observed-change ordering and stable UUID winner for incomparable heads. Global Item Done precedence and every other appearance's state stay unchanged.

Later delivery of another applicable closure can make an earlier assertion ineligible. A new explicit action that has observed all closures can supply the value again. Retain all markers and original history. Never stamp observations onto an old assertion or rewrite its original context when canonical roots change. Already proven alias normalization must preserve the observation set; unresolved root admission keeps its existing failure behavior rather than guessing.

The public appearance retains its existing Item, itinerary entry and membership identities/lifetimes. No new user-facing Restore action, source lifetime, appearance identity, command parameter or completion dialog is added. This is a normal data-layer completion action for native views, Shortcuts and agents.

## Portable and native compatibility

Fresh native exports and recovery snapshots use portable version 4. In that version, every `completionChanges` record has the required new array. Missing fields, unknown fields, malformed UUIDs and invalid observation relationships reject with the corresponding JSON Pointer. New formats remain strict; unsupported future versions reject.

Continue reading versions 1 through 3. Their missing field supplies no attested closure observations. Preserve their original format/absence information for preview and exact historical replay. Previously invalid legacy row/marker contradictions do not become valid through inference. A faithful empty-dataset restore keeps every represented public identity and history record. Default Skip retains matching current owners and proven current metadata. A missing legacy field cannot erase an already proven observation set for the same immutable change identity; explicitly conflicting version-4 claims reject.

Native completion-change JSON remains in `LineageRecord.recordData`. No SwiftData attribute or model migration is needed. Advance the existing native control compatibility integer to 20 while retaining the actual `PlannerSchemaV19` structural model and V1–V19 migration plan unchanged. Document and test these separate meanings. Existing binaries checking a maximum of 19, including their active sessions, must reject that control state before writing. Merely adding an ignored JSON property is insufficient protection.

The main app owns the compatibility upgrade. Share asks to open Planner until it is ready. Validate the legacy graph, establish a coherent version-4 recovery baseline and durably activate control compatibility 20 under the existing writer coordinator. Preserve namespace, dataset, epoch and ownership. Retain previous acknowledged copies, exact receipts and their original checkpoint generations. An interrupted upgrade must be inspectable and retryable from its actual durable control/recovery state, without fabricating a successful user command or publishing partial data. Native history changes require a fresh coherent snapshot. Physical model migration and account/cloud qualification remain separate.

Recovery inspection accepts the new storage compatibility value and portable version while preserving existing envelope versions and acknowledgement rules. Existing version-3 maintenance preparations and acknowledged receipts remain valid. Newly prepared canonical maintenance uses its next declared rule version with a complete version-4 graph; its evidence still binds the exact durable preparation digest. Do not reinterpret an old preparation under a new rule.

## Commands, replay and import

Existing `setCompletion` and confirmed bulk commands remain the entry points. Resolve the exact appearance and current closure basis under coordination. Reviewed bulk actions keep their full accepted targets, including hidden/archived children; stale reviews reject rather than refreshing targets silently.

New expanded-assertion operations use a versioned payload/evidence path. Declare payload fingerprint version 4 and prepared/stored operation evidence version 3, adding `resolvedExpandedCompletionEvidence`. Each entry contains the four-UUID `context` and `observedExpandedCompletionDeletionIds`, frozen in deterministic context order. Preserve existing resolved bindings and membership evidence. The command's new explicit assertions use that exact frozen basis.

All existing v1/v2/v3 fingerprint algorithms, legacy/result-only receipts, version-2 evidence, original results and original checkpoint generations remain supported unchanged. Replay dispatches from saved evidence before resolving current targets or observations. A later closure, removal or re-add must not turn replay of an old action into a newly authorized completion. An unverified preparation remains unverified; no automatic execution is introduced.

Portable validation, import review/apply, shared queries, native maintenance and recovery use the same eligibility rule. A version-4 saved flag must agree with eligible current history. Absence still means Todo. Historical assertions without the required basis remain portable history, not active flag authority. Native partial delivery stays unresolved until its required marker/change references arrive; it never invents a binding.

An authorized new completion does not adopt a restoration candidate or replace an owner. Skip/Overwrite retain their existing whole-owner and deletion-review promises. Grouped association Undo and fresh-lifetime restoration remain independent; the new observation field does not authorize restoring a deleted source, entry or membership.

## Literal outcomes and required evidence

Use a fixed live context C, expanded closure D1, and distinct assertions E0/E1/E2:

| Current data and arriving action | Required result |
| --- | --- |
| C is Todo after D1; local Complete E1 observes D1. | C becomes Done; E1 retains `[D1]`; Item/entry/membership identities and D1 survive. |
| A delayed pre-D1 assertion E0 has a larger change UUID but observes no closure. | E0 remains historical and cannot override E1 or a later eligible Reopen. |
| E1 observes D1, then another valid applicable closure D2 arrives. | E1 cannot supply the current value; no initial or stale scalar resurrects it. |
| New Complete E2 observes both D1 and D2. | C becomes Done under E2 with `[D1, D2]`; both closures remain. |
| An assertion names another itinerary branch's closure or an unknown ID. | Reject without changing native data or recovery files. |
| The same membership appears in another List stop or directly in the itinerary. | Its independent local state remains unchanged; global Item Done still takes precedence. |
| An original applied E1 is replayed after D2 or a relationship replacement. | Return E1's original result and checkpoint; never record a new basis or change the replacement. |
| A retained eligible alias group receives a smaller canonical root. | Preserve original assertion contexts and observations, causal winners and independent branch scope. Unproven root authority still rejects. |

Qualify these through existing public real-store/native-input tests, strict portable literals and real HTTP operations. Include faithful version-4 round-trip, versions 1–3, malformed claims, same-ID metadata preservation/conflict, stale bulk review, current recovery projection and exact old receipt/preparation replay.

Also qualify genuine main-app compatibility upgrade, old-session rejection, Share setup presentation, control/recovery write failures, native save rollback, committed-publication failure/Retry and actual interruption at the relevant existing filesystem/native boundaries. Native checkbox journeys must use the same source/appearance scope. No test-only production parameter, new package or new target is proposed. Actual CloudKit/physical delivery, system invocation, Mac UI availability, signing and final whole-app polish keep their separate gates.
