# Content and credential-reader review

Concrete declarations for [Shared command contracts](https://github.com/dvcol/planner/issues/13). Q1-Q30 behavior is settled, including the official Swift MCP SDK under Q29. On 2026-10-09 the human clarified that Q31 repeats the already delegated Q27 edit-guard decision, and accepted Q32 A, authenticated SDK ping. The approved [architecture packet](architecture-review-packet.md) and [field-edit draft](field-edit-contract.md) supply the existing facade, identity, partial-edit, hash and outcome rules. This packet makes the content fields concrete under those rules. It is not compiled Swift or passing runtime evidence.

## Context, starting state and expected end

The approved architecture names content families but leaves some nested field types unspecified. An implementation cannot independently test a location, an ordered link edit or a label association hash until those types are fixed. This packet declares the editable content catalog and the compound values used by reads, creation and edits. Completion, archive, organization, scheduling and recovery retain their own commands.

The expected end is a complete public contract using these concrete values and the accepted reader observations. Q31 is withdrawn as a repeated policy question; its catalog is an engineering declaration under Q10/Q27, not a new conflict policy or an invented human approval. Q32 selects the ping candidate for qualification. The [complete adapter packet](adapter-contract.md) and [portable/native recovery declaration](portable-data-contract.md) now supply command/query/review/result encodings and native backup administration forms accepted under Q33 A on 2026-10-09. This resolves the declarations for the contract decision; it does not prove an extension, client or device workflow.

## Content catalog under accepted Q10/Q27

Use one typed content value per source kind. The public Core representation is Sendable value types, not mutable SwiftData models or arbitrary dictionaries. Each row below declares every content field for that kind. Creation accepts those fields and generates the source ID, lifetime and timestamps once per operation. An edit uses a typed `PlannerFieldChange` for each declared field and the existing changed-field hash map. The adapter never chooses a dataset or logical lifetime.

| Source value | Required fields | Optional fields | Separate read-only state |
| --- | --- | --- | --- |
| `PlannerItemContent` | `title: String`, `links: [PlannerOwnedLinkRead]`, `categoryIds: Set<UUID>`, `tagIds: Set<UUID>` | `subtitle: String?`, `notes: String?`, `location: PlannerOwnedLocation?`, `estimate: PlannerEstimate?` | Source ID, authorized lifetime, creation/Item Last updated, global Done, archive, memberships, appearances and schedules. |
| `PlannerListContent` | `name: String` | `notes: String?`, `color: PlannerColor?`, `iconName: String?` | Source ID/lifetime, timestamps, archive, memberships/order and derived completion. Lists have no copied Item fields or stored parent Done override. |
| `PlannerItineraryContent` | `title: String`, `links: [PlannerOwnedLinkRead]`, `categoryIds: Set<UUID>`, `tagIds: Set<UUID>` | `notes: String?`, `color: PlannerColor?`, `iconName: String?`, `location: PlannerOwnedLocation?` | Source ID/lifetime, timestamps, archive, entries/order, independent appearance completion, schedules and derived progress. |
| `PlannerCategoryContent` | `name: String` | `color: PlannerColor?`, `iconName: String?` | Label ID/lifetime, timestamps and referring owners. |
| `PlannerTagContent` | `name: String` | `color: PlannerColor?`, `iconName: String?` | Label ID/lifetime, timestamps and referring owners. Duplicate names remain allowed. |

Required text contains at least one non-whitespace character. Validation does not trim or normalize the stored text. There is no added character or planner-count cap. Optional text distinguishes nil from an empty String. Links and label selections default to empty on creation; clearing a required collection means supplying `[]`, not null. Optional fields default nil. Ordinary creation initializes global Todo, Active and new local Todo contexts under the accepted domain rules.

Creation uses the corresponding `PlannerItemContentInput`, `PlannerListContentInput`, `PlannerItineraryContentInput`, `PlannerCategoryContentInput` or `PlannerTagContentInput` with the same declared fields. For Item/Itinerary links, creation and edits accept `[PlannerLinkInput]`; reads return `[PlannerOwnedLinkRead]` after Core assigns identities and validates retained references. No read-only classification or provenance field becomes writable through that conversion. Label selections are sets; repeating one selected ID creates no extra association, while two distinct same-name labels remain distinct.

Item and Itinerary category/tag fields are live selections of shared label identities. Lists retain their approved own presentation metadata; this packet does not add label associations to Lists. Native label editors and authorized ordinary adapters use the same label commands. Names are display data, never identity or uniqueness keys.

Source detail reads return immutable content, current source state and `fieldHashes` for exactly the catalog fields. They also return current referenced label display values for rendering, separately from the editable ID selections. A shared label rename changes that display projection, not the owner's association hash or Item timestamp. A lightweight query row does not carry full notes, all links or this complete hash map.

The later accepted [Q43-Q46 row amendment](navigation-row-contract-review.md) adds owned location, one selected owned link and a typed Schedule summary to that lightweight read. It retains this content catalog and the no-full-detail-per-row boundary. Temporary thumbnails/geocoding, resolved query time/zone and native completion affordances introduce no editable fields, hashes or backup state.

## Compound content values

The following declarations fix nested values for both native callers and their eventual JSON encodings. Swift integer values remain native types; Int64 values use accepted canonical decimal strings on the wire. JSON optional properties use null in full reads and missing/null/value in patches according to Q10.

| Value | Exact declared fields and validation |
| --- | --- |
| `PlannerEstimate` | `minutes: Int64`, `displayUnit: PlannerEstimateUnit`. Positive whole minutes, checked conversion, units `minute`, `hour`, `day`, `week`, `month`, `year`. Fixed conversions from the accepted duration record; no calendar arithmetic or new picker cap. |
| `PlannerCoordinate` | `latitude: Double`, `longitude: Double`. Finite values in inclusive -90...90 and -180...180. Both required together; never clamp or infer a point from a map viewport. |
| `PlannerOwnedLocation` | `displayName: String?`, `formattedAddress: String?`, `coordinate: PlannerCoordinate?`. These are independently supplied planner fields. Provider-generated candidate names/addresses/coordinates belong in the temporary capture preview, not this saved value. Clearing location removes only this owned location. |
| `PlannerColor` | `red: Double`, `green: Double`, `blue: Double`, `alpha: Double`. Finite sRGB components in inclusive 0...1; preserve native Double values. Native UI converts this value to its platform color. Invalid components reject, rather than silently clamp. No platform color object is persisted or transported. |
| `PlannerLinkInput` | `linkId: UUID?`, `originalUrl: String`, `label: String?`. Omit `linkId` for a new owned link; an existing ID must belong to this source and authorized lifetime. Retain original spelling, including query parameters. Supported web-link validation follows accepted capture classification; parsed request URL is separate. |
| `PlannerOwnedLinkRead` | `linkId: UUID`, `originalUrl: String`, `label: String?`, `kind: PlannerLinkKind`, `providerReference: PlannerProviderReference?`. Array position supplies logical order. Core assigns/validates classification and retained references; callers do not write these by adding fields to `PlannerLinkInput`. |
| `PlannerLinkKind` | Stable strings `appleMaps`, `googleMaps`, `tabelog`, `website`, `booking`, `generic`. Detection does not require fetching a page. Unknown or ambiguous provider recognition retains an ordinary supported bookmark. |
| `PlannerProviderReference` | `kind: applePlaceId`, `value: String`. Only a permitted stable Apple reference established by the accepted parser/provenance rules. Contextual values such as my-location and parked-car are not place identities. No Google provider metadata snapshot or opaque path decoder is introduced. |

Replacing a links array edits that source's owned links and their order. Retained IDs preserve their ownership; new links receive stable IDs through the operation; omitted owned links are removed without deleting their source or other sources. A repeated existing link ID within one replacement is invalid; distinct new link records do not share an identity. A replay retains the same generated IDs. Capture's accepted exact-original-URL deduplication remains its separate rule. Removing an owned link is ordinary reference/content editing, distinct from permanent source Delete. Storage scalar ranks are internal; rebalance without a visible order change must not invalidate a content hash.

Content origin is Core-owned evidence from accepted input classification, user edits and app-generated fallback values. There is no caller-writable flag that promotes a provider preview into independent content. Merely accepting an unchanged preview does not change its origin. Actual independently supplied content and legitimate agent edits remain permitted. Capture retains its separate editable draft and temporary preview; it cannot create a source merely by parsing or receiving a callback.

## Complete content-hash catalog

The [version-1 byte encoding](field-edit-contract.md#canonical-hash-input-version-1) remains unchanged. The catalog above defines the typed editable-field enums for Item, List, Itinerary, Category and Tag. Required strings use the String encoding, optional values include the Optional tag, and nested record fields sort by their declared ASCII names.

| Field value | Exact canonical value under the existing encoding |
| --- | --- |
| `title`, `name` | Required String. |
| `subtitle`, `notes`, `iconName` | Optional String, preserving nil/empty and exact UTF-8 bytes. |
| `estimate` | Optional record containing `displayUnit` as its stable String and `minutes` as Int64. |
| `coordinate` within location | Optional record containing finite Double `latitude` and `longitude`. |
| `location` | Optional record containing optional `coordinate`, `displayName`, `formattedAddress`. Held preview values are absent. |
| `color` | Optional record containing finite Double `alpha`, `blue`, `green`, `red`. |
| `categoryIds`, `tagIds` | Identity set of resolved label records containing `id` and `lifetimeId` UUIDs. Core obtains the lifetime binding from the validated association; wire edits submit only IDs. Names/color/icon are absent from this hash. Input ordering does not change it. |
| `links` | Ordered collection of records containing `kind`, `label`, `linkId`, `originalUrl`, `providerReference`. The optional provider-reference record contains stable String `kind` and `value`. Core binds owned link identity to its source lifetime. Array order is significant; internal scalar rank is absent. |

Compound values are one edited field. A location edit validates and guards the complete location; a links replacement guards the complete ordered links value. This avoids independently applying half a coordinate pair or a partial reorder. Title and notes remain independent fields. Label metadata changes stay independent of owner association edits. This implements Q27's delegated simple changed-field guard and does not add an entity revision or another conflict-policy approval gate.

A supplied compound field is a complete replacement value, not a recursive patch. Its declared nested properties must be present, using null for nullable members; a location object containing only formattedAddress is rejected rather than silently clearing the other members. Link input alone may omit `linkId` to request a new owned identity. Top-level optional fields may be omitted on creation for their nil defaults; omitted top-level edit fields remain unchanged. This distinction must appear in the final input schemas and error paths.

Schedule commands are separate from source-content edits. A source patch cannot reschedule its Item by putting a schedule property in `changes`. The [adapter packet](adapter-contract.md#schedule-form-and-guard) uses the approved typed timed/all-day form, fixed instants, inclusive civil dates and explicit zone-only edit. The Schedule kind byte reserved by the hash draft does not grant an extra source-content field or authorize a blind Schedule edit.

## Representative independent fixture

Read Hotel after assigning independent content, using the existing Hotel identity and an empty link/label selection. The content projection is:

```json
{
  "title": "Hotel",
  "subtitle": null,
  "notes": "Original notes",
  "links": [],
  "location": {
    "displayName": "Meeting point",
    "formattedAddress": "Meeting point A",
    "coordinate": { "latitude": 35.0, "longitude": 139.0 }
  },
  "estimate": { "minutes": "120", "displayUnit": "hour" },
  "categoryIds": [],
  "tagIds": []
}
```

The actual detail read additionally supplies source/state and Core-issued field hashes. It must not fabricate a hash from the JSON object above. The independently calculated Original notes digest remains the [existing fixed vector](field-edit-contract.md#independent-expected-vectors).

[Six compound hash expectations](fixtures/content-field-hashes-v1.json) supply exact resolved values, complete canonical input bytes and expected SHA-256 digests for the estimate, owned location, Category identity set, both two-link orders and a blue List color. They were calculated independently from the documented encoding, checked against the existing Original notes vector and verified against their recorded bytes. They are future Swift-test expectations, not production-hash execution. Resolved label lifetimes in this fixture file are internal canonical inputs, not caller-writable MCP fields.

Apply the existing notes-only request while its notes hash is current. Expected end is notes Monday booking, with the exact location, estimate, labels, links, identity, timestamps of other owners and every completion/archive/reference value retained. Core updates this Item's own Last updated under A6. Intervening title-only change still permits it; an intervening notes change to Friday booking rejects it as staleEdit and leaves Friday booking. Null notes clears notes; omitted location preserves it. An invalid coordinate pair rejects the entire location change without affecting notes or any other field.

For label independence, associate Hotel and Tokyo itinerary with the same Category identity. Rename Food to Dining through the label command. Both reads show Dining; their `categoryIds` selections and association hashes are unchanged. Deleting that Category is a separate reviewed native action; it removes associations rather than copying or deleting owners.

## Credential-reader declaration, accepted Contract Q32 A

Q28 already accepts the signed Mac app executable's non-UI reader mode. Q29 selects the official SDK, while Q30 adds no client-profile arguments or extra request counter. On 2026-10-09 the human accepted Q32 A, live confirmation through authenticated SDK ping. The declarations below specify that selected candidate; actual signing, Keychain, lifecycle and client behavior remain prototype gates.

Use one non-UI mode, `--mcp-headers`, with no profile, token or enablement argument. Select that branch before SwiftUI `App.main()` executes. Calling it must not open a window, activate the GUI, initialize/migrate Planner data, start a listener or enable Agent Control. Success writes one JSON header object to stdout and exits zero. Failure writes no header object, exits nonzero and uses a controlled credential-free stderr reason such as `agentControlUnavailable`, `credentialUnavailable` or `unsupportedStoredState`. The header object has this shape, with the real credential substituted only at runtime:

```json
{ "Authorization": "Bearer <runtime credential>" }
```

On Enable, generate 32 cryptographically random bytes with native SecRandomCopyBytes and check success, then encode unpadded base64url. Store one active generic-password item in the data-protection Keychain. Use the actual configured bundle identifier plus `.AgentControl` as service, the new `accessWindowId` as account, `AfterFirstUnlockThisDeviceOnly`, no synchronization and no added biometric/user-presence requirement. Noninteractive lookup uses `kSecUseAuthenticationContext` with `LAContext.interactionNotAllowed = true`; the deprecated `kSecUseAuthenticationUIFail` is not selected. App and reader have the same signed executable identity; actual installed signing/Keychain access remains a prototype gate.

An atomic ephemeral App Group control record, `AgentControlState.plist`, contains exactly `formatVersion: 1`, `mainInstanceId: UUID`, `accessWindowId: UUID`, `endpoint: URL`, `protocolVersion: String`, `state: on`. The main instance ID is fresh per launch; the access-window ID and credential are fresh per Enable. This control record is neither Planner data nor a credential container. Credentials and control metadata are excluded from data sync and portable backups. The main app publishes On only after credential creation, listener binding and metadata publication succeed. Partial setup returns unavailable and removes its listener rather than reporting On. Relaunch begins Off and never interprets stale On metadata as permission to restart a listener.

The selected candidate additionally verifies the already-running listener through a standard authenticated MCP ping before emitting headers. Validate the stored endpoint against the accepted loopback scheme/host/port/path before accessing its credential. After reading metadata and its matching Keychain item, the reader POSTs only to that exact loopback `/mcp` endpoint, with a fresh string request ID, the current Authorization, Content-Type application/json, Accept application/json and text/event-stream, and the explicitly supported MCP-Protocol-Version. It does not follow redirects, initialize the server, register a client profile or execute a Planner command. The embedding main app validates current authorization and the existing Origin/Host/content/version rules before dispatch. A successful authorized response retains the official SDK's result and adds `X-Planner-Access-Window` bound to the window authorized for that request. It cannot attach a newer window to an old admitted credential.

Require the matching JSON-RPC request ID, a ping result `{}`, no error and the exact current window header. HTTP 200 alone is insufficient. Reread the control metadata after the response; emit only if its main/window/endpoint binding is unchanged and On. Missing metadata, denied Keychain access, an unreachable listener, wrong/missing window header, error result or a changed binding returns unavailable without startup or plaintext fallback. SDK/OS transport failure and cancellation are individual I/O outcomes; they do not introduce automatic Agent Control expiry.

Stop first revokes the active credential/window at the listener admission boundary, then removes the listener and attempts metadata/Keychain cleanup. A cleanup failure cannot authorize the old credential. Quit/forced exit ends the listener; stale metadata or a leftover Keychain item cannot pass the live ping. A response can race with a later Stop/exit, so this is evidence of an authorized endpoint at the check, not an atomic promise of future availability. Every actual request must still enforce the current credential/window. Known committed domain actions retain the approved applied/recovery result; ping creates no domain action or receipt.

The unselected alternative was live main/window confirmation through an app-owned native anonymous XPC listener. It would add a private IPC listener and its endpoint handoff, signing, sandbox and interruption work. No XPC bootstrap, permanent launchd service or daemon is required by selected Q32 A. Apple documents endpoint transfer over an existing XPC connection; an App Group archive bootstrap remains unproved. Process/metadata checks alone do not establish current listener authority. Acceptance of A is a qualification direction, not a claim that the reader already works.

## Native reader facts and limits

Checked 2026-10-08/09 through primary sources and installed macOS 27 declarations. No app was launched, credential accessed or probe executed for this packet.

| Evidence | Consequence |
| --- | --- |
| [Process lookup](https://developer.apple.com/documentation/appkit/nsrunningapplication/init(processidentifier:)), [PID identity](https://developer.apple.com/documentation/appkit/nsrunningapplication/processidentifier), [launch date](https://developer.apple.com/documentation/appkit/nsrunningapplication/launchdate), [running application](https://developer.apple.com/documentation/appkit/nsrunningapplication) | PID alone is insufficient; Apple directs comparisons to isEqual. Launch date exists only for LaunchServices launches and has no documented uniqueness/precision guarantee. Time-varying properties require main-run-loop progress and can race. A nonnil retained object can outlive exit. These facts motivate live endpoint verification instead of treating stored PID/On as proof. |
| [Data-protection Keychain](https://developer.apple.com/documentation/security/ksecusedataprotectionkeychain), [after-first-unlock accessibility](https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly), [noninteractive context](https://developer.apple.com/documentation/localauthentication/lacontext/interactionnotallowed) | Documents the selected storage/access candidate. Actual signed main/reader access while locked, after restart and during updates must be demonstrated. No UI prompt or fallback is assumed safe. |
| [Random bytes](https://developer.apple.com/documentation/security/secrandomcopybytes(_:_:_:)), [SwiftUI app entry](https://developer.apple.com/documentation/swiftui/app/main()), [subprocess execution](https://developer.apple.com/documentation/foundation/process) | Check RNG status before Enable; choose the reader branch before the GUI entry point. Executing the app binary as a subprocess is distinct from opening an app through LaunchServices. No-window/no-listener behavior still needs real execution. |
| [Official SDK ping exemption](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Server/Server.swift#L704-L712), [built-in ping](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Server/Server.swift#L888-L899), [HTTP response](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Base/Transports/HTTPServer/HTTPServerTypes.swift#L74-L107) | SDK 0.12.1 permits ping before initialization, returns Empty and allows additional response headers. Its headers accessor is get-only; the embedding adapter constructs the final response while preserving SDK headers/body/status. This limited SDK-supported probe is not a fully initialized client or a replacement protocol stack. |
| [HTTP validation](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Base/Transports/HTTPServer/HTTPRequestValidation.swift#L145-L216), [legacy lifecycle](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle), [ping utility](https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/ping) | The SDK does not supply Planner authorization by itself. Retain supported version/media/Origin/Host validation and current authorization on the probe. Ping is exempt from the initialization gate in this implementation; do not describe it as negotiation or an initialized client connection. |
| [Anonymous XPC listener](https://developer.apple.com/documentation/foundation/nsxpclistener/anonymous()), [endpoint transfer](https://developer.apple.com/documentation/foundation/nsxpclistener/endpoint), [secure coding conformance](https://developer.apple.com/documentation/foundation/nsxpclistenerendpoint), [connection signing requirement](https://developer.apple.com/documentation/foundation/nsxpclistener/setconnectioncodesigningrequirement(_:)) | Supports investigating a live app-owned IPC alternative without a permanent service. Secure coding conformance is not proof that archiving an endpoint into a shared file transfers a usable endpoint. An existing XPC connection is the documented transfer path. Signing/admission and actual endpoint bootstrap require real-process proof. |

Neither process properties nor a successful bearer-authenticated ping proves vendor identity or excludes another process running as the authorized local user. Q28 already accepts that reader trust boundary. Do not add vendor pairing or a client registry. The prototype must prove the selected candidate's actual behavior and return to the contract ticket if these observations cannot be met.

## Definition of ready

- [x] Q1-Q30 behavior and A21/A22 public architecture carry forward without reopening them.
- [x] Every source-content field and nested value is explicitly cataloged, with a complete hash layout and independent before/after fixtures.
- [x] Finish the native reader fact check and specify its observable input/output/storage/lifecycle candidate with unproved runtime limits.
- [x] Q31's repeated conflict-policy question is removed; Q10/Q27 govern the engineering content catalog and changed-field guards.
- [x] Human accepts Q32 A, authenticated SDK ping, for the same-app reader.
- [x] The adapter and native administration request/result declarations are linked using these accepted types; complete human review is accepted under Q33 A.

## Required /tdd and other evidence

These are future obligations. Agree the public declarations first, then write one independently specified failing behavior and its minimum implementation at a time. Test through the existing Planner read/execute boundary, temporary real stores and real reader process. Mock only actual I/O; add no test-only production callback.

- Unit/real-store creation and reread reproduce the representative Hotel content exactly. New IDs/lifetimes/timestamps are Core-issued; ordinary creation is Todo/Active and selected memberships start local Todo. Required empty/whitespace-only title/name reject with no mutation, while nonempty submitted text retains its whitespace/Unicode bytes.
- Each source kind exposes exactly its declared content fields. An Item patch cannot modify timestamps, global/local completion, archive, memberships, schedules, provenance or dataset ownership. Optional null clears only the named field; an empty required collection supplies `[]`. Unsupported field/required null, malformed hash or missing changed-field hash rejects the whole attempt.
- The six recorded compound expectations and existing seven notes vectors verify exact bytes/digests through the public read/edit behavior. Additional independent boundary values cover nil/empty text, finite coordinate/color boundaries, invalid/non-finite inputs, estimate checked Int64 conversion, identity-set order independence and link-array order sensitivity. They do not call the production canonicalizer to generate their own expected answer.
- Replace two Hotel links in reverse order, preserving their link IDs. Reopen/read preserves reversed order and each label/original URL. Same-order storage rebalance retains the links hash. A link ID owned by Museum rejects the whole Hotel edit; Museum remains unchanged. Replay adds no extra owned link.
- Rename a referenced Category and Tag. Owner reads refresh display names without changing ID selections, their association hashes, local flags, Item Last updated or source counts. Removing a label association changes only that owner's selection; confirmed native label Delete preserves the owners.
- Location/capture provenance checks retain independent Meeting point A and 35.0/139.0, while provider-shared U retains its bookmark/permitted reference and no held saved name/address/coordinate. Provider preview, capture callback and unchanged confirmation cannot supply an owned-location field by bypassing Core classification.
- Existing hash fixtures and writer-boundary contention still apply: unrelated title change permits a notes edit, a notes conflict rejects together, one of two competing edits wins locally, unchanged replay retains its result, and postcommit recovery failure remains applied with incomplete recovery.
- Native UI controls display these values on each platform; native pickers and validation presentation belong to Navigation prototype. Store reopen, separate processes, data-only backup round-trip and physical-device sync retain the accepted exact values and shared identities. These require their owning prototypes; this document supplies no device result.
- Real signed reader/process/listener checks reproduce one valid stdout header object only while the authorized main/window can be verified. Test main closed, Off, partial Enable failure, missing/unsupported control metadata, denied Keychain access, stale window, wrong/missing response header, HTTP-200 JSON-RPC error, no matching result, redirect refusal and changed metadata during read. No case opens a GUI, initializes data, starts a listener or auto-enables access.
- Forced exit without cleanup leaves the reader unavailable despite stale metadata/credential. Enable again rejects the old credential; old main/window metadata cannot retarget to the new instance. Stop during probe cannot authorize a subsequent request. Locked after-first-unlock use, actual sleep/wake, first restart before unlock, installed update/signing and last-window closure need native evidence. Use process identity checks only as selected, with explicit PID reuse/nil launch-date/run-loop cases; do not fake OS liveness through a test-only production callback.
- With the live-ping candidate, two reader invocations use distinct request IDs and each gets its own empty result/current window. The existing SDK collision fixtures remain required for actual agent callers. Probe reads change no source, association, completion, receipt or checkpoint; no initializing client roster or custom admission cap appears. Demonstrate configured header handoff separately in all four selected actual client surfaces, with credentials absent from ordinary logs/configuration.

## Definition of done for this review packet

- [x] Human clarification preserves Q27's delegated hash decision and accepts Q32 A without another conflict-policy round.
- [x] Reconcile amendments into the field-edit draft and linked adapter/portable declarations; original domain and authority invariants remain intact.
- [x] Link the source, exact independently specified fixtures and applicable validation from Shared command contracts.
- [x] Q33 A accepts complete request/result/admin forms; the linked packet assigns runtime obligations to their prototypes. Contract resolution does not complete the map or imply executed runtime proof.
