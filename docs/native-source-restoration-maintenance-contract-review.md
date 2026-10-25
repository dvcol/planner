# Native restoration-family maintenance

Status: Q157 A approved on 25 October 2026; the first bounded implementation has a [local checkpoint](prototypes/native-source-restoration-maintenance.md), with further qualification in progress. A20 already settles deterministic restoration-family winners. This proposal makes the first native normalization rule and its recovery/compatibility behavior concrete. It does not change manual Skip, Overwrite or explicit restoration.

## Reproduced local gap

The [real native-input diagnostic](prototypes/native-source-restoration-readiness.md) imports one valid open Item family with winner X101/814 and candidate X101/815. Only the winner initially has a native row. Delivering the fully declared losing row makes ordinary query and Item reads unavailable. Both candidate bindings and the predecessor closure are known; this is not an ambiguous metadata merge or a signing limitation.

A20 requires the smallest declared candidate lifetime UUID to win initially. Its current content remains authoritative. Closing that whole family is a separate user Delete; normalization must not issue such a Delete.

## First rule and preserved scope

Declare `sourceRestorationConsolidation`, rule version 1, for all five source kinds: Item, List, Itinerary, Category and Tag. The first implementation tracer is the reproduced Item case.

The rule applies only when the complete retained history proves one open family, its actual smallest candidate is present, and every row to retire is another declared candidate for the same public source identity. Require valid exact source/lifetime bindings and uniquely resolved family history. The losing rows must have no live owned associations or inbound Planner references. Retained family, deletion, alias and receipt history is not a live Planner relationship and remains unchanged; unresolved relationship liveness rejects. Check persisted scalar bindings as well as SwiftData relationship arrays; a missing relationship object is not proof that the binding is absent.

Preserve the winning row's exact lifetime, content, global/archive flags and timestamps. Preserve its owned data, every candidate declaration, predecessor closures, unrelated sources and references, existing command receipts and completion history. Remove only the admitted losing physical rows. Do not allocate a source lifetime, redirect predecessor references, merge candidate content, create a source Delete marker or close the family. An unchanged normalized graph causes no maintenance; redelivery of a retired candidate can require another truthful maintenance attempt.

Unknown candidates, missing winners, conflicting or partial authority, referenced losing rows and other unresolved graph conditions remain unavailable without a native mutation or published partial graph. Broader candidate-reference/owned-data rebinding, closed-family arrivals and source-family history reconciliation remain required follow-ups on the map. This first rule does not defer them outside the map or claim that every possible native restoration input is solved.

## Durable preparation and evidence

Reuse the existing maintenance preparation, commit, inspection and Retry interfaces. Add the distinct kind above rather than labeling source retirement as membership consolidation.

A new preparation retains the existing exact fields: `format`, `formatVersion`, `maintenanceId`, `namespaceId`, `datasetId`, `epochId`, `ownershipBinding`, `kind`, `ruleVersion`, `proposedBackup` and `evidence`. For this rule, values are `planner-maintenance-preparation`, format version 1, kind `sourceRestorationConsolidation`, rule version 1, a complete validated portable-v4 proposed graph and `preparedUnverified`. Generate a fresh maintenance ID and bind the commit to the SHA-256 digest of the exact durable preparation bytes, as for existing maintenance.

Persist preparation before the native transaction. Retire admitted rows and save the matching maintenance evidence atomically. A preparation without committed evidence remains unverified and does not authorize automatic execution. Native save failure leaves the original graph and truthful preparation state. After a committed native save, recovery publication failure leaves maintenance incomplete, blocks new mutations and permits explicit Retry to publish current canonical data without repeating the retirement. Never fabricate a successful user command or rewrite its result/checkpoint. Reopening and exact saved-command replay retain their established meaning.

Recovery envelope version 2 already carries maintenance evidence and stays version 2. Its validation must explicitly accept this new kind/rule with portable v4. Keep membership consolidation rules 1/v3 and 2/v4 unchanged, including their exact historical preparations, receipts and replay. Native recovery UI and change notifications use the existing maintenance IDs and outcomes; there is no new user-facing maintenance action, agent restore command, package or target.

## Compatibility activation

Advance the native writer compatibility gate from 20 to 21 before writing new-kind evidence. Physical `PlannerSchemaV19`, its V1–V19 migration plan, portable format 4 and old portable readers remain unchanged. This is a logical writer/recovery declaration change, not a new SwiftData model migration or portable field.

The main app owns activation. When raw duplicate source rows already exist under control20, first derive and validate a nonmutating canonical projection using only this bounded admission rule. Do not pass unresolved duplicates to uniqueness-assuming import projections. If admission or projection fails, retain native data and prior recovery unchanged. The projected coherent portable-v4 graph may establish the compatibility21 recovery baseline and matching metadata before control21 activation under coordination; it does not retire native rows, record a maintenance commit or fabricate a user command. Actual physical retirement occurs only after activation, through its own durable new-kind preparation/transaction, with current input revalidated. Preserve dataset, namespace, epoch, ownership and all historical copies/results. Share requests the main app until activation completes. Interrupted publication/activation stays inspectable and retryable. Membership-only projection and Q156 ordering evidence do not qualify this new source projection; its actual failure/interruption states require tests. A genuine compatibility-20 executable with an active session must reject subsequent writes/reads under the current version/session guards; cold older main/Share Core roles must refuse unsupported control 21. A late unknown-kind integrity error alone does not establish that guarantee.

## Literal outcomes

| Native input or failure | Required outcome |
| --- | --- |
| X101 family F890 declares closed predecessor811 and declares candidates814/815; both rows arrive, neither loser-owned nor inbound data exists | Retain X101/814 exactly; retire only row815; preserve F890, its two candidates and predecessor closure. |
| Row815 has different notes or global Done | Winner814's original notes/global flag survive; no field merge or completion OR. |
| The losing row has an owned link or an inbound reference, even with a nil relationship object | Do not apply this first rule. Keep all input and recovery unchanged pending a supported complete reconciliation. |
| Winner814 is absent or candidate815 is not declared | Do not invent a winner or admission. Keep input/recovery unchanged. |
| Preparation succeeds but native save fails | No partial retirement or user receipt; preserve truthful unverified evidence. |
| Native save commits but recovery publication fails | Expose incomplete maintenance; block new changes; explicit Retry copies current canonical data and acknowledges the exact maintenance. |
| Both candidate rows already exist during a compatibility20 upgrade | Validate a nonmutating bounded projection, establish its coherent baseline and activate21 before any new-kind native retirement. Revalidate input before that separately prepared save. |
| An already applied command replays or the app reopens | Preserve its exact result/checkpoint; do not allocate another source lifetime or duplicate retirement. |

## Ready and done

DoR is approval of this concrete rule, evidence kind and compatibility behavior. Retain the existing failed native diagnostic. No new test seam is requested: use the approved real native-input/public Core, recovery-filesystem, actual process interruption, native UI and real HTTP boundaries.

Qualify the first tracer before broader cases. The local DoD includes all five source kinds for this bounded rule, exact winner/unrelated-data preservation, scalar-reference rejection, redelivery/idempotence, genuine gate20 old-writer rejection, main/Share activation, preparation/native-save/publication failures, Retry, interruption, exact old command/maintenance replay, coherent queries/exports/recovery and independent-writer refresh. Run affected compiler/format checks and native/HTTP regressions. Keep every unresolved reference/family case explicit on the map. Actual installed Share, signed storage, CloudKit delivery, physical interruptions/performance, Mac UI availability and whole-app acceptance remain separate gates.
