# Confirmed bulk completion in Shortcuts

Status: Q120 A accepted on 21 October 2026. The three actions and production store preparation/submission test boundary below are approved; [The three actions and reviewed writer are implemented locally](prototypes/native-bulk-completion-intents.md); actual system confirmation remains a separate gate.

## Context, starting state and goal

At `85224b9b`, native UI and MCP use Core's exact-target bulk review, but the 69 native actions have no full-context bulk completion. Individual List and Itinerary appearance completion is implemented. SavedPlannerStore.executeAppIntent currently accepts no review token; its raw result preserves applied/incomplete recovery. The UI's applyReviewedChange handles refreshed review but returns a different UI-oriented result.

Add the ordinary bulk actions without bypassing system confirmation or duplicating Core target resolution. Retain Q8 completion precedence: each local appearance is set independently; globally Done Items remain displayed Done after clearing local completion. Hidden and archived appearances remain targets. No action changes Done everywhere or exposes Delete, backup or recovery administration.

## Concrete native actions

Use three focused actions, following the existing typed scope pattern:

- Set List child completion: required List and Completed Boolean.
- Set Itinerary child completion: required Itinerary and Completed Boolean.
- Set Itinerary List-entry child completion: required Itinerary, exact existing route-entry entity and Completed Boolean. Validate that the entry belongs to that Itinerary and still references a List. A removed, mismatched or Item entry rejects without redirecting to another scope.

The route-entry action reuses the current dependent entry-query pattern and saved entry identity. Repeated references to the same List remain distinct; route positions are labels, never identifiers. Actual system dependency/picker injection retains its own qualification gate. No new dynamic-provider boundary is implied by this proposal.

Read current labels and ask Core for the exact scope review. The confirmation names the container or branch, counts every targeted item appearance from review.targetCount, includes hidden/archived entries and explains that Done everywhere is unchanged. Count repeated appearances separately. No display filter changes the target set.

Use Apple's current requestConfirmation dialog API. Apply only after it returns normally. Propagate any SDK throw without applying; Apple does not guarantee a particular cancellation error type. Check task cancellation before submission, preserving the current rule that an applied result is not discarded by a later cancellation check.

A staleReview rejection applies nothing. Obtain a fresh review and require system confirmation again before another attempt; do not silently apply refreshed targets. Cancellation ends that flow. Preserve Core's zero-target semantics and No items completion state; never describe an empty container as completed. Complete, rejected, unverified and applied/incomplete outcomes retain truthful native dialogs and store recovery blockage.

## Required production store support

Add prepareAppIntentBulkCompletion(scope:done:) returning Core's existing PlannerReview, with normal context opening, cancellation, write admission and useful failures. Extend executeAppIntent with an optional reviewToken defaulting to nil, forwarding it through the existing admitted-change path to PlannerOperation. Existing ordinary callers retain their current behavior and raw result shape. Reuse existing recovery handling; do not introduce a separate writer, review registry or aggregation algorithm.

The native action owns the system confirmation checkpoint. The store supports the post-confirmation Core submission. It takes no test-only confirmation callback, injected SDK service, fabricated user-response Boolean or alternate test factory. Tests of the store do not prove that a user confirmed in Shortcuts.

## Verified SDK facts and local limit

The installed SDK has a modern asynchronous throwing requestConfirmation dialog overload with custom accept/deny labels. Apple's [confirmation documentation](https://developer.apple.com/documentation/appintents/appintent/requestconfirmation%28conditions%3Aactionname%3Adialog%3A%29) describes normal return on confirmation and throwing on cancellation. It provides no rollback for writes made before the checkpoint.

The public callAsFunction interface accepts only donate. AppIntentsTesting's AnyAppIntent.run has no confirmation-response argument; no public response-control API was found in the installed interface. Its [system testing setup](https://developer.apple.com/documentation/appintentstesting/testing-your-app-intents-code) uses the live system infrastructure. The existing Customer-build rejection remains unresolved and signing stays deferred. That does not prove a paid account fixes it.

The SDK packet retains the actual source, typecheck command/exit and inspected interface hashes. Its generic syntax example is not a proposed All Items bulk scope. No confirmation, GUI or Planner mutation was invoked. These are declaration facts, not runtime approval/cancellation evidence.

## Q120 alternatives and impacts

A. Approve the concrete adapter contract and direct tests at the required production SavedPlannerStore prepare/submission interfaces. Use actual dependency/storage and existing filesystem obstructions in PlannerMCPTests. This makes exact-review submission, stale rejection and truthful recovery repeatable locally, while retaining separate real-system confirmation tests. It adds a test boundary, not a production testing hook or new module.

B. Keep only Q112's Intent/EntityQuery test boundaries. Implement the same thin adapters and locally qualify metadata, compilation and failures reached before confirmation. Leave positive confirmed submission and its store/recovery qualification open until real system invocation is available. This avoids the additional direct boundary but provides less local evidence.

C. Revise the concrete contract or supported action layout before implementation. Q7's required system confirmation, Core's exact-target/atomic semantics and independent local completion remain settled.

Recommendation: A for the accepted quality priority. This does not replace actual confirmation tests with a mocked approval.

## Definition of ready

Q7 already authorizes native confirmation with full scope/count. Q112 already authorizes production Intent invocation and EntityQuery tests. Q120 A approves the additional direct store boundary. The TDD skill says, "No test is written at an unconfirmed seam." No new package, target, schema, Core/MCP wire contract, signed identity or device installation is proposed.

## Required tests and definition of done

Under A, first test the production store preparation and reviewed submission using literal fixtures. Tokyo Food contains active Hotel and archived Museum, both globally/local Todo. The review targets two appearances. Submission sets both local flags together and keeps both global flags Todo. Explicitly set Hotel Done everywhere, then globally reopen it: its local Done state remains. Local Undone leaves any globally Done Item displayed Done.

For an Itinerary containing Hotel, a Food List containing Museum, then Hotel again, review three independent appearances. Full completion changes all three; the List-entry action changes only its one expanded Museum appearance. The standalone Food List and another itinerary retain their local state. Saved identities, order, labels, notes, archive and bookings survive. Empty targets remain No items, not completed.

Add a child after preparation: old-token submission rejects staleReview with no partial local updates. A new review names the new full count. Only a separately authorized submission can apply it. Removed/recreated owners or branches, wrong parent/kind, missing tokens, precancellation, unavailable storage and recovery-blocked admission reject without redirection or partial changes. Independent source-content edits follow existing Core rules.

Exercise actual precommit filesystem failure and post-save recovery obstruction. A precommit failure leaves all flags unapplied; applied/incomplete retains the whole bulk result, blocks later mutations and repairs only that checkpoint through native administration. Preserve original operation evidence and truthful raw results. Keep all ordinary executeAppIntent callers compatible.

Use Q112 for reachable pre-confirmation Intent failures. Confirmed execution, pressing native Cancel, changed-target reconfirmation, invocation continuation/retry, count/scope labels, locked/background restrictions and dependent picker injection still require real system journeys. An unavailable-runtime error is not evidence of user cancellation; Task.cancel is not a fabricated confirmation response. Under B, these outcomes remain explicitly unqualified rather than being represented by direct-store tests.

Compare native metadata and existing contracts, run affected strict lint/type checks, compile matching Mac/Simulator/unsigned device sources and record fixture closure. Retain separate scope for actual Shortcuts, physical-device, CloudKit/shared-storage and signed Agent Control gates. Keep the map open until every required gate is proved.
