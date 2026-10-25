# Local restoration and history audit, 26 October 2026

## Scope

Older checkpoints preserve their historical "remaining" lists. Later checkpoints
resolve several of those items. This audit separates that recorded behavior from
the still-unqualified cases. It adds no policy, schema, format, gate, module or
test boundary and does not qualify physical/cloud behavior.

The [restoration checklist](restoration-acceptance-checklist.md) remains the
current index. Its crossed source/owned-family case is a real policy question,
[Q163](native-crossed-restoration-family-decision.md), rather than a generic
instruction to build more reconciliation machinery.

## Existing evidence by named obligation

| Earlier open item | Later qualification | Current limit |
| --- | --- | --- |
| Move must observe strict removals and retain original action evidence | [Strict Move](prototypes/native-membership-strict-move.md) covers new/preexisting destination, exact source/destination bases and replay after replacement; [prepared-only replay](prototypes/native-prepared-move-capture.md) now covers a surviving proposal without its receipt | A copied valid preparation does not prove actual Move process death |
| Capture reuse must observe destination removals without changing other contexts | [Strict Capture](prototypes/native-membership-strict-capture.md) covers informed additions, no-op reuse, original content and later replacement/replay; [prepared-only replay](prototypes/native-prepared-move-capture.md) preserves an unrelated edited draft | Preparation input, applied replay and recovery-incomplete saves keep their distinct evidence |
| Reviewed Overwrite must establish a truthful removal barrier and preserve frozen replay | [Strict Overwrite](prototypes/native-membership-strict-overwrite.md) covers old/new evidence, competing-value regression and preparation-only admission | Preparation input is not evidence of an actual interrupted import process |
| Legacy closed alias delivery, eligible aliases and later smaller roots | [Legacy delivery](prototypes/native-legacy-closed-alias-delivery.md), [alias actions](prototypes/native-membership-eligible-alias-actions.md) and [delayed roots](prototypes/native-delayed-canonical-roots.md) cover their worked cases | Unknown or contradictory authority retains rejection; unrelated generations do not gain a redirect |
| Native flags disagree with retained history, or causal records are missing | [History-backed flags](prototypes/native-membership-history-backed-flags.md), [partial history](prototypes/native-partial-completion-history.md) and [Q156](prototypes/native-post-closure-completion.md) retain proven completion and reject incomplete history until exact records return | Broader physical delivery and repair-specific faults remain separate |
| Prepared contextual commands must not resolve against replacement targets | [Context preparations](prototypes/native-membership-prepared-context-replay.md), [pending maintenance](prototypes/native-membership-pending-maintenance-replay.md) and [Move/Capture](prototypes/native-prepared-move-capture.md) cover represented missing/newer targets and blocked maintenance | Actual command-specific process death is not inferred from a copied preparation |
| Automatic maintenance interrupted before or after native commit | [Pre-save SIGKILL](prototypes/native-maintenance-pre-save-interruption.md), [post-save/relaunch](prototypes/native-maintenance-post-save-interruption.md) and native save-failure evidence qualify the shared transaction | A generic transaction test does not claim each owned-content payload has executed at every fault stage |
| Q156 compatibility publication or activation interrupted | [Both retained termination checkpoints](prototypes/native-post-closure-completion.md#compatibility-activation-after-termination) preserve the old or already published baseline and retry through the public interface | Controlled local SIGKILL does not qualify power loss or cloud/account interruption |
| Native recovery selection and committed Retry | [Prepared-copy inspection](prototypes/native-prepared-maintenance-inspection.md), [committed Retry](prototypes/native-committed-maintenance-retry-ui.md) and [late-input reload](prototypes/native-maintenance-post-save-interruption.md#native-late-input-recovery-follow-up) cover represented phone/iPad workflows | Actual Mac interaction and whole-app accessibility remain open |
| Old/deleted/competing restored import values | [Live overwrite](prototypes/core-native-import-live-overwrite.md), [fresh local restoration](prototypes/core-native-import-fresh-local-values.md) and [owned-history imports](prototypes/native-restored-owned-reference-history.md) qualify their literal contracts | This does not settle Q163's simultaneous native union |

## Current-source regression

Eight existing functions are selected without changing their assertions or
production code. They cover Move, Capture reuse, two Overwrite/evidence paths,
contextual prepared replay, legacy alias roots, sole legacy late delivery and
missing causal history. Their commands and actual result packets are retained
under `native-history-audit-current-mac` and `native-history-audit-current-phone`
in the existing membership evidence directory. No full-repository run is added.

Both current cohorts pass all eight functions and 119 invocations in four suites,
with no skips, failures, timeouts or SQLite-unlink diagnostics. The
[validation record](prototypes/evidence/native-membership-consolidation/native-history-audit-validation.json)
verifies actual products, 813 matching Core inputs and 1160 unchanged native
inputs against the preceding preservation checkpoint. That includes the 514
frozen store fixtures and every production/schema input. Historical evidence
files are hashed separately, preserving their own execution epochs and limits.
Verified cleanup removes 238 marked disposable stores after host exit and closed
database handles. Results, manifests and runner sources remain compressed.

These current results supplement the earlier fault/termination/UI evidence.
They do not rerun every historical test, qualify another platform boundary or
turn historical product hashes into current execution credit.

## Concrete local work still open

1. Reconcile payload-specific save/publication/interruption promises in the Q161
   owned-content reports with the existing shared transaction tests. The
   [mixed Itinerary publication check](prototypes/native-restored-owned-reference-history.md#mixed-itinerary-publication-failure)
   now preserves its complete graph through real publication failure and Retry.
   Its native-save/actual interruption cases and distinct Item/List owned-data
   and label-collision faults remain separate. Do not claim a Cartesian fault
   matrix or add a new recovery framework by inference.
2. Await Q163 for the conflicting source/owned-family authority. Preserve the
   current atomic rejection while that decision is pending.

Mac interaction, Map/browser/change-stream lifecycle and accessibility, signed
shared storage, installed Share, CloudKit/account convergence, actual system
Shortcuts/Siri and physical performance retain their distinct map gates.
Signing stays deferred. The feature-complete whole-app UI pass and the user's
final coherence/layout review remain required.
