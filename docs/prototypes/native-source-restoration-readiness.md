# Native restored-source candidate readiness

Q157 A is now implemented and locally qualified at the [maintenance checkpoint](native-source-restoration-maintenance.md). The diagnostic below records the earlier failure and remains retained.

## Existing rule and test boundary

A20 already requires one deterministic initial candidate for an authorized restoration family. Candidate lifetime UUID ordering chooses the winner. Authorized references and later family closure have their existing rules. Manual import normalization does not prove that independently delivered native rows receive the same treatment.

The approved public Core/real native-input boundary constructs a disposable actual store, then observes bootstrap, import, query and Item reads. No production hook, target or additional direct test seam is introduced. The diagnostic uses fully declared metadata and no losing-owned or inbound references, avoiding any new admission or field-merge policy.

## Executed result

Import Item X101/814 with its original title Nezu Museum, note Original notes and global Todo. Family F890 declares predecessor X101/811, its retained closure and both candidate lifetimes814/815. The valid imported graph exports one live source and both candidate declarations.

A separate native ModelContext then saves a second well-formed Item X101/815 with different content and global Done. A20's required result is one readable X101/814 retaining its original content/state. Instead, the executed diagnostic fails one function. Query returns readUnavailable, “Query Item identities are duplicated and unresolved.” Item details return missingReference, “The selected Item is missing or unresolved.” The diagnostic verification reconciles all 811 isolated inputs, proves the prior 810 Core inputs unchanged and verifies both actual test binaries. No SQLite unlink warning occurs. The original failed store is retained.

The first attempt fails compilation before any test because the probe used a direct globalDone property instead of the public Item read's optional state.globalDone. That attempt remains separate and is not evidence of the runtime defect. The corrected probe passes strict Swift formatting. At that checkpoint its source was retained compressed and withdrawn from the shipping target pending review. After Q157 A approval, the unchanged probe returned to the storage target, reproduced the failure and passed with the implementation.

## Concrete next step

Before Q157, native maintenance admitted only membershipConsolidation rules1–2. Native source loading retains restoration-family metadata but does not normalize candidate source rows. Reusing the membership kind would misdescribe the durable action. The [accepted Q157 contract](../native-source-restoration-maintenance-contract-review.md) declares the bounded source rule, its distinct evidence kind and explicit writer compatibility21 while preserving physical model19 and portable4.

The bounded rule now has its local checkpoint. Broader referenced/owned candidate handling still needs its concrete declaration before dependent implementation. Losing references/owned data, broader family reconciliation, actual Mac interaction and signed/system/physical gates remain distinct. Signing did not prevent this diagnostic.
