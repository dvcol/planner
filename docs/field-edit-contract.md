# Field edits and hash guards

Proposed concrete contract for [Shared command contracts](https://github.com/dvcol/planner/issues/13). Q9/Q10 already require changed-field validation and Set/Clear/Unchanged. Q27 delegates the simple hash design to engineering judgment. This packet makes that choice reviewable without changing the approved Planner facade. Final public-contract approval remains pending; no Swift implementation or passing runtime test is claimed.

## Context, starting state and goal

An agent reads Hotel's notes, another local action saves Friday booking, and the agent submits Monday booking from the old read. The accepted result rejects the stale edit and retains Friday booking. An intervening title change must not reject a notes-only edit. Previously the contract named per-field SHA-256 hashes without fixing their format or canonical input.

The expected end is one read/edit vocabulary and deterministic encoding that can be implemented through the approved Core boundary. No stored edit-token registry, revision history or client-side hash implementation is needed. Hashes describe the receiving device's current values; they do not prove CloudKit freshness or authenticate a caller.

## Read and partial-edit forms

A source-detail read returns its existing immutable content plus `fieldHashes`, an object mapping each supported editable content field to its opaque hash. These hashes belong to the returned source and authorized lifetime. Lightweight query rows do not load full notes or produce all content hashes; an editor requests the detail value. Appearance reads identify the source and appearance separately; local completion remains a separate scoped command.

An edit supplies `operationId`, the selected source identity, `changes` and `expectedFieldHashes`. The existing adapter supplies the authorized Core dataset session. Clients cannot choose an account or lifetime by adding JSON fields. Native typed values use the approved `PlannerFieldChange` cases and a mapping from the source's typed editable-field enum to `PlannerFieldHash`. JSON field names are converted to those enum cases at admission; Core does not use arbitrary user strings as fields. `PlannerOperation`, `Planner.execute` and their approved result cases remain unchanged.

For every field in `changes`, a same-named entry in `expectedFieldHashes` is required. No hash is needed for an omitted, unchanged field. Clients may echo the full read's hash map; known hashes for unchanged fields do not participate in comparison or the typed edit payload. Reject missing required hashes, unknown field names or malformed supplied hashes before mutation. Empty `changes` rejects as invalid input instead of creating a meaningless saved operation. A supplied value sets the field; null clears an optional field; omitted fields remain unchanged. Clearing a required title rejects.

Use the wire string `sha256-v1:` followed by exactly 64 lowercase hexadecimal characters. Native `PlannerFieldHash` retains that validated string. It is an opaque read result, not a value an agent calculates. A malformed or unsupported prefix rejects as `invalidInput` with the property path. Schema/version negotiation of the overall tool remains separate.

A notes-only request has this proposed shape. The digest in this example is supplied by the vector below, not a hash of the new notes:

```json
{
  "operationId": "00000000-0000-4000-8000-000000000901",
  "itemId": "00000000-0000-4000-8000-000000000101",
  "changes": { "notes": "Monday booking" },
  "expectedFieldHashes": { "notes": "sha256-v1:514218da3ebca004857b8063cf5c59a50a25b02eb99b293bc9c4bc17fcca90dd" }
}
```

On success, a subsequent read supplies the new field hashes. For `staleEdit`, the rejected attempt identifies the conflicting changed field names and current values/hashes so the agent can reread and decide. It does not automatically overwrite or replay. An already applied operation's recorded result is not rewritten by a later rejected attempt.

## Canonical hash input, version 1

Use native CryptoKit SHA-256 over the following bytes, in sequence. This is a fixed encoding for field fingerprints, not a new backup or transport format. Do not hash a JSON property's spelling or JSON encoder output.

1. ASCII `PlannerFieldHash`, one zero byte, then the version as unsigned 32-bit big-endian `1`.
2. Dataset UUID as its 16 bytes in UUID textual group order.
3. One entity-kind byte: Item `01`, List `02`, Itinerary `03`, Category `04`, Tag `05`, Schedule `06`.
4. Source UUID, then its currently authorized logical lifetime UUID, each as 16 bytes. For a restored source, use the accepted restoration-family binding, not a physical duplicate's candidate ID. Core obtains these bindings from its validated logical read.
5. The declared ASCII field name, encoded as an unsigned 64-bit big-endian byte length followed by those UTF-8 bytes.
6. The typed canonical field value from the table below.

Dataset session IDs, process IDs, operation IDs, timestamps of other fields, transport state and credentials are absent. The hash remains stable across processes given the same context/value. A different source, field, dataset or authorized lifetime changes its input even when the displayed value is identical. Core account/lifetime validation still applies independently.

All length/count conversions are checked. UUID byte order does not depend on host integer endianness. Preserve String UTF-8 bytes without trimming, case folding or Unicode normalization. This keeps an edit of stored text detectable even when native search treats the spellings as equivalent.

| Value | Byte encoding after its tag |
| --- | --- |
| String, tag `10` | Unsigned 64-bit big-endian UTF-8 byte length, then exact UTF-8 bytes. |
| Bool, tag `11` | One byte, `00` for false or `01` for true. |
| Int64, tag `12` | Eight bytes of signed two's-complement representation, big-endian. Wire decimal strings are validated and converted before hashing. |
| Finite Double, tag `13` | IEEE 754 binary64 bits, big-endian. Normalize either zero sign to positive zero; reject NaN/infinity before hashing. |
| UUID, tag `14` | Its 16 bytes in UUID textual group order. |
| Optional, tag `15` | Presence byte `00` alone for nil; `01` followed by the nested tagged value when present. Nil and an empty String differ. |
| Ordered collection, tag `16` | Unsigned 64-bit big-endian element count, followed by each complete tagged value in logical order. |
| Identity set, tag `17` | Validated distinct identities encoded as complete tagged values, sorted lexicographically by their bytes; unsigned 64-bit count followed by those values. Input order cannot change the set's hash. |
| Record, tag `18` | Unsigned 64-bit field count; declared fields sorted by ASCII name, each name length/bytes followed by its complete tagged value. All declared optional fields are included, including nil. |
| Date, tag `19` | Finite `timeIntervalSinceReferenceDate` encoded as eight big-endian binary64 bytes, normalizing zero signs. Native Date and wire round-trip validation still apply. |

A schema field fixes its value type; type tags cannot coerce a string into an integer. Enum cases use their declared stable String values. New canonical layouts require a new hash version; silently changing version 1 is prohibited.

Apply this encoding to content fields only. Notes/subtitle are optional String values, title is a required String, and an estimate is an optional record with `displayUnit` and `minutes`. Label association values include the selected label identities/lifetimes, not their names or display metadata. Owned ordered links include their declared persisted content/identity/order values; transient provider previews are absent. Location/provenance and all nested field names must match their final approved content declarations. This packet does not invent missing content fields or replace the final full schema review.

Changing notes cannot invalidate a title hash. Renaming a referenced label cannot invalidate an owner's association hash. Changing local completion, membership placement or another source's content cannot invalidate an Item's content hashes. Commands for completion, archive, organization and schedule actions retain their separately approved scopes and validations.

## Admission and replay

Core validates authority, dataset/lifetime ownership and the typed patch, then checks only changed-field hashes against the current canonical values under the same writer gate as the complete action. If any differs, reject the whole edit with `staleEdit`; change no field, timestamp, association or completion flag. A successful edit changes only the supplied content fields and the accepted source timestamp.

For a previously applied identical operation/payload, return its recorded result through the approved replay path rather than evaluating old read hashes as a new edit. A different payload under that operation UUID rejects that attempt as `operationPayloadMismatch` and retains the earlier result. Checking field hashes cannot turn replay into a second mutation.

If a value changes and later returns to exactly the same canonical value in the same authorized lifetime, its old hash matches again. This is accepted under Q27's value guard; there is no revision-history promise. A deleted/recreated or restored lifetime cannot reuse that authorization just because its notes match.

## Independent expected vectors

Constructed fixtures use dataset `00000000-0000-4000-8000-000000000801`, Item `00000000-0000-4000-8000-000000000101`, logical lifetime `00000000-0000-4000-8000-000000000811`, kind `01` and field `notes`. Notes use Optional then String encoding. These are independently calculated expected bytes/digests for later Swift tests, not executed Planner tests.

| Notes value | Value bytes after the context | Expected wire hash |
| --- | --- | --- |
| nil | `1500` | `sha256-v1:11eeb5c2a9e789af128e0d79806d091a22745d8f498b5d1134d9eef979940815` |
| empty String | `1501100000000000000000` | `sha256-v1:12a4257657b7085b44053bcd3b81f37bad14784157a194689139d0c109d5cad2` |
| Original notes | `150110000000000000000e4f726967696e616c206e6f746573` | `sha256-v1:514218da3ebca004857b8063cf5c59a50a25b02eb99b293bc9c4bc17fcca90dd` |
| Friday booking | `150110000000000000000e46726964617920626f6f6b696e67` | `sha256-v1:175c9aea4180ace4585ad4fdba4ca1343d5cbc4c8bb118ec1f784cfee90a793c` |
| Monday booking | `150110000000000000000e4d6f6e64617920626f6f6b696e67` | `sha256-v1:9f7394c5b70585a0735cf41734287fb6495f5e134993ffbc2f01e821c3921507` |
| precomposed é | `1501100000000000000002c3a9` | `sha256-v1:7c25761c184da6cb6a9d970e42ed8666028ff0a7d02201a74a94dafb5e3178f0` |
| e plus combining acute | `150110000000000000000365cc81` | `sha256-v1:fbe4813dfda21f8884b7b464c23ac2d0cbb31a9dbdc15c3dd7563fdbb6a7ff2c` |

The original-notes full input hex is:

```text
506c616e6e65724669656c644861736800000000010000000000004000800000000000080101000000000000400080000000000001010000000000004000800000000000081100000000000000056e6f746573150110000000000000000e4f726967696e616c206e6f746573
```

The JSON example above uses the Original notes vector. A Friday booking current value differs and must cause stale rejection of that request; a title-only change leaves its expected notes hash valid.

## Definition of ready

- [x] Q9/Q10/Q27 behavior and A21/A22 Core ownership/result semantics are accepted.
- [ ] Accept this concrete read/edit/hash declaration as part of the final public contract review, including the remaining full content-field catalog.
- [ ] Agree the prototype's real storage configuration and affected native test/build commands before implementation.

## Required /tdd and other evidence

Through approved reads and edits, start with one failing behavior test and its minimum implementation. Expected values must come from these fixtures and accepted product examples, not the production hash function.

- Unit checks independently reproduce each byte input/digest, UUID and endian ordering, nil/empty distinction, Unicode byte preservation, identity/lifetime/field isolation, Int64 limits, finite Date/Double values and zero normalization. Identity-set order does not affect its hash; ordered-link changes do.
- Boundary/real-store checks reject malformed/missing required hashes, unknown fields, required-title clear and an empty patch with zero mutation. Echoing the full read hash map does not guard unchanged fields or enlarge the typed edit payload. A notes-only edit retains title/estimate and every global/local/archive/reference value.
- For Original notes, then Friday booking, the old-read Monday booking attempt returns `staleEdit` and retains Friday booking. The same attempt after only a title change succeeds. A two-field patch with one mismatch changes neither field.
- Make two edits with the same original notes hash contend at the real writer boundary. One succeeds; the other sees the newly stored value and rejects. No check/save gap permits both to overwrite it.
- An unchanged operation replay returns its original stable result even though the prior read hash is now old. Changed-payload replay preserves the original operation evidence and current data. Precommit failure is unapplied; postcommit recovery failure remains applied with incomplete recovery.
- Relaunch/read and separate native processes reproduce hashes from the same validated fixture and values. Restoration-family/alias reconciliation cannot borrow an obsolete lifetime's read authorization. Measure actual native serialization and persistence behavior instead of counting this packet as proof.
- Equivalent authorized native and MCP edits use Core's same guard and return the same domain outcome. Q29 selects the official Swift SDK. Actual MCP client/protocol qualification belongs to its prototype; this document supplies no connection proof.

## Definition of done

- [ ] Final public-contract review confirms these declarations and the complete content-field catalog.
- [ ] Future implementation records red/green evidence, real-store reopen results, affected-target build/type checks and applicable lint.
- [ ] Link implemented evidence from Shared command contracts and its owning prototype. This draft alone neither resolves that decision nor proves runtime behavior.
