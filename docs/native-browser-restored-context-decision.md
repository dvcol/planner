# Browser Return after association restoration

Status: Q150 A accepted on 23 October 2026. Source-lifetime rejection is already accepted and implemented; its native restoration journey can proceed independently. Signing is separate.

## Settled behavior and current distinction

Q141 keeps a webpage readable after its source context disappears, then returns to a valid containing collection with an explanation. `SavedWebsiteRequest` captures the Item's source lifetime and exact `PlannerAppearance` public-ID tuple. `SavedPlannerStore.websiteReturnValidation` rejects a fresh Item lifetime, even when the public Item ID is restored. The existing source-return report explicitly records namespace, source-lifetime and exact-appearance validation.

An appearance currently has no captured membership/entry lifetime in that request. `PlannerAppearanceRead` exposes the source lifetime, while its appearance describes public IDs. Removing Hotel's membership from a List and then using native Undo restores the original public membership ID, order and local Done under a fresh technical lifetime. If Hotel's own lifetime stays unchanged, current Return validation accepts that restored appearance. A restored containing List/Itinerary is also located by public ID. No native browser test currently qualifies this restoration sequence.

## Decision

A. Treat the explicitly restored public context as available. Return may open its current saved state when the same Item lifetime and exact public appearance/path IDs resolve. A restored containing container remains a valid fallback by public ID. Ordinary re-adds create different association IDs and remain unavailable to the old reader; a fresh Item lifetime remains unavailable. This states and qualifies current navigation behavior without adding lifetime fields to the appearance read.

B. Require original association and container lifetimes too. Return treats Undo or backup restoration under a fresh relationship/parent lifetime as unavailable, even when public IDs return. It falls back to an older valid containing context or its catalog. This requires a concrete additional lifetime-read/capture contract before implementation and qualification; it must not use backup export as a client read workaround.

Recommend A for original-association Undo semantics and the smaller native read workflow. Neither choice creates data, restores a deleted source automatically, changes completion, or permits switching a contextual action to global scope. The webpage keeps reading under either choice.

## Evidence references

- [Accepted reader workflow](native-map-browser-workflow-review.md#next-frontier-q134-q141).
- [Implemented source-return checks and remaining lifetime gate](prototypes/native-webpage-source-return.md).
- [Association restoration identity/lifetime contract](native-compound-association-undo-contract-review.md).
- Production request in `Planner/Scenes/SavedWebsiteView.swift`; Return validation in `Planner/Scenes/SavedPlannerStore.swift`; public appearance read in `Packages/PlannerCore/Sources/PlannerCore/PlannerMembershipValues.swift`.
