# Older memberships without removal history

## Current decision

Q154 is pending. [Q153 A](native-unseen-membership-add-decision.md) is accepted: a same-pair Remove defeats an unseen independent Add, while an informed re-add starts Todo. This decision concerns older saved data that never recorded the information required to distinguish those cases. No production code, schema, public interface or new test is changed by this review.

## What the existing data can prove

Current Membership records retain the membership, Item and List identities/lifetimes, order and local completion. They have no record of which removals an Add observed. A deletion marker closes a membership identity/lifetime without retaining its Item/List pair. Context aliases likewise do not retain the losing membership's complete pair binding.

Native Remove receipts can sometimes recover the exact pair. Match the marker's operation ID and membership lifetime to its stored membership/List/Item bindings before accepting that evidence. This proves endpoints, not which removals a historical Add observed. An old portable backup contains no command receipts. Its marker may therefore lack even the deleted pair's identity. Recovery receipts also omit the stored command bindings.

These are concrete limits of the saved bytes. A migration cannot manufacture observation history or infer a removed pair from titles, current placement, timestamps or coincident public IDs. Retain existing original-ID deletion protection under either option. No option makes the old removed membership live again automatically.

Source references:

- [MembershipSnapshot](../Packages/PlannerCore/Sources/PlannerCore/PlannerMembershipValues.swift#L8) and [native Membership](../Packages/PlannerCore/Sources/PlannerCore/PlannerSchemaV18.swift#L117).
- [Portable context aliases](../Packages/PlannerCore/Sources/PlannerCore/PlannerImportValues.swift#L107) and [deletion encoding](../Packages/PlannerCore/Sources/PlannerCore/PlannerDeletionRecovery.swift#L55).
- [Remove's exact native bindings](../Packages/PlannerCore/Sources/PlannerCore/PlannerCore.swift#L5676) and [Add's bindings without a removal basis](../Packages/PlannerCore/Sources/PlannerCore/PlannerCore.swift#L5533).
- [Stored native operation evidence](../Packages/PlannerCore/Sources/PlannerCore/PlannerStore.swift#L60) and [recovery receipts](../Packages/PlannerCore/Sources/PlannerCore/PlannerRecovery.swift#L430).

## Worked case

An old backup says membership M401 was removed. Its marker omits the Item/List pair. Hotel and Tokyo survive, and today's saved data has a different membership M402, locally Done. The file cannot establish whether M402 was an unaware concurrent Add or a deliberate later re-add. Even a native receipt that reconstructs M401's pair does not supply M402's missing causal history.

A later Remove recorded by the new implementation can retain the exact pair and causal provenance. That new removal must defeat an unaware M403, and a deliberate later Add must start Todo. Both options retain this full Q153 requirement for newly recorded removals.

## Options and effects

A. Preserve today's saved memberships, order and completion as the upgrade's accepted starting data. Backfill only proven old bindings and retain original-ID deletion protection. Enforce Q153 for newly recorded removals. Explicitly acknowledge that older missing pair/observation history cannot retroactively guarantee suppression of a different unseen legacy Add. This permits existing datasets and old supported backups to remain usable without invented history. Original command receipts and exact replay remain unchanged. This is an explicit historical compatibility limit, not a weaker rule for new removals.

B. Refuse writable upgrade when required historical pair or causal information is missing. Leave its files untouched while an authoritative migration path is reviewed; existing compatible inspection/export paths remain separate. This avoids accepting an unproven historical starting state, but some old backups cannot supply the missing information at all. Existing data can remain blocked rather than being silently reclassified. New datasets can still use Q153 normally.

A17 still requires one visible duplicate context, initial Done/Todo consolidation and preservation of explicit Reopen history. Preserving older user data does not mean retaining duplicate visible rows or creating a new seed that overrides Reopen.

Recommendation: A. Preserve actual current Planner data and make the historical limit explicit. B adds an upgrade restriction without recovering missing facts. Neither option authorizes deleting current memberships by inference, losing local completion, changing another List, or pretending an old writer observed a removal.

## Concrete contract after this choice

The next review must specify retained membership bindings and removal-observation provenance, duplicate retirement distinct from user Remove, exact context aliases across completion generations, canonical identity/order, native reader/writer compatibility and supported portable-version migration. It must also declare a truthful automatic maintenance/recovery transaction. Existing recovery only tracks command receipts; normalization must not fabricate a user command receipt or silently declare incomplete maintenance complete.

Use the already approved real-native-store and public query/read/execute/export/recovery boundaries. Retain the existing failing diagnostic, then work through literal cases in vertical slices: initial Done/Todo consolidation; explicit Reopen followed by a late seed; same-pair unseen Add suppression; informed re-add; independent other-List additions; exact repeated-itinerary contexts; faithful full export; genuine save/recovery failure; replay and reopen. Schema/compiler or local-store evidence does not qualify live CloudKit or physical convergence. Signing stays deferred.
