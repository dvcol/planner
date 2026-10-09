# Shared command contracts

In-progress review for [Shared command contracts](https://github.com/dvcol/planner/issues/13), claimed on 2026-10-08. The [approved Core architecture](core-architecture.md) and [A21/A22 packet](architecture-review-packet.md) are the baseline. The human answered revised Contract Q1-Q26 on 2026-10-08; the accepted choices below govern the earlier proposals. Q27 delegates the simple edit guard to engineering judgment; per-field hashes are selected. Q28 accepts the same-app credential reader. Q30 C removes an additional app-imposed client/request cap while retaining two-client proof and measured capacity. Q29 accepts the official Swift SDK and its supported sessionless HTTP baseline. The current inspected release is 0.12.1; actual client compatibility and SDK stability remain prototype evidence gates. No Swift declarations have been compiled and no unit, store, UI, device or client test has been executed here.

## Context

The native app, Share extensions, App Intents and temporary macOS MCP adapter must call one PlannerCore implementation. Release stages V0-V2 establish ordinary planning, capture and portable backups. V3 adds the system and agent integrations. Different integrations may have different authority; they must retain the same domain meanings for the operations they can invoke.

An MCP tool annotation or a Core review token does not grant permission. Validation of the decoded command, resulting impact and authorized dataset happens before mutation. An import can apply deletion metadata even when its target is absent locally, so hiding a Delete tool is insufficient.

## Starting state

[Core architecture is resolved](https://github.com/dvcol/planner/issues/12#issuecomment-6057782494). The approved facade, typed source/appearance identities, field changes, review/result/status shapes, native validation and save/recovery sequence carry forward. Their approval must not be requested again for unchanged behavior.

[Local MCP compatibility](https://github.com/dvcol/planner/issues/6) establishes documented candidates and limits, with [committed research](https://github.com/dvcol/planner/blob/research/local-mcp-compatibility/docs/research/local-mcp-compatibility.md). No successful client connection or minimum supported client version is proved. The selected clients, access-window lifecycle and same-app credential-reader candidate are accepted below. The released 2026-07-28 specification removes protocol sessions. Q30 C settles the former client cap; actual client/Swift SDK version compatibility remains a follow-up.

The original ticket mentions earlier keep-current imports and wholly unapplied failures. The accepted architecture amendments govern the final contract: default whole-record Skip, reviewed Overwrite, data-only backups including minimal deletion lineage, and the A15 distinction between true precommit failure and a fully applied action with incomplete recovery. Q12/Q14 require independent itinerary appearances and appearance-count progress. These are carried-forward resolutions, not new questions.

## Goal and expected end

Agree exact command/query transport forms, integration authority, stale-edit handling, JSON grammar and capture resource limits. Produce representative MCP JSON and corresponding typed Swift requests using the approved facade. Record independently specified state/error observations and the unit, real-store, native UI, physical-device and client evidence each prototype must supply.

Contract Q1-Q30 settle authority, encoding, capture and Agent Control policy, with the later human amendment removing automatic access expiry. On 2026-10-09 the human clarified that Q31 repeats the already delegated Q27 conflict decision and accepted Q32 A, authenticated SDK ping. The [content and credential-reader declarations](content-and-reader-review.md) carry those outcomes into concrete types without another conflict-policy gate. Remaining work is the complete adapter request/result/admin schemas and their final review. Q29 selects the official Swift SDK; actual protocol/client compatibility belongs to the MCP prototype. Native JSON handling is accepted; guaranteed duplicate-property rejection and its additional parser branch are no longer required. No executable prototype is claimed.

## Definition of ready

- [x] Read the approved architecture and domain resolutions, release journeys and local MCP compatibility research.
- [x] Inventory the release journeys and required command/query families below.
- [x] Prepare valid UUID fixtures, retained reference graphs and explicit competing stale-edit results.
- [x] Accept revised Contract Q1-Q26 behavior, authority and wire choices, including the human amendments.
- [ ] Specify and accept changed or newly concrete request fields after their prerequisite answers. Unchanged A21/A22 public approval carries forward before /tdd.

## Release journeys and shared operations

| Journey and before state | Commands/queries and required end | Integration/evidence owner |
| --- | --- | --- |
| V0, empty offline planner | Create Book train tickets, read/search, edit its notes, relaunch with the same identity and content. No cloud account is needed to save. | Native app; Navigation and Sync and share prototypes prove their applicable paths. |
| V0, Hotel in two Lists | Add/remove/move memberships, explicit global/contextual completion, archive/unarchive. Removing one membership preserves Hotel and the other membership. | Core semantics approved. Exact authorized adapter operations are finalized here. |
| V1, generic Item without location | Read/search/filter/sort works without map coordinates; completion and archive remain independent. | Approved search fixtures plus public-query/store/UI checks. |
| V1, shared labels | Create/edit references by UUID; rename updates all uses; duplicate names remain distinct. Referenced label Delete is native-confirmed and preserves its owners. | Native UI and authorized label-edit adapters share Core. |
| V2, mixed URL/text capture | Decode supported inputs into one review, optionally look up the selected Maps link, then reviewed create/reuse. Cancel-before-Add creates nothing; saving includes selected memberships together. | Native app/Share; authorized MCP capture uses exact agent-reviewed apply under Q2. |
| V2, Hotel, Museum, Hotel itinerary | Add distinct live entries, reorder without resetting local flags, read appearance progress and schedule source references. Editing Hotel's source content updates both appearances. | Native app; Core, UI and device evidence. |
| V2, timed/all-day schedules | Create/edit/remove only the selected Schedule. All-day civil dates survive travel; zone-only edits preserve instants; no estimate fills an end. | Scheduling fixtures; no Calendar export/EventKit operations. |
| V2, portable data | Export full data-only backup; decode/review/apply Skip or Overwrite. Invalid backup rejects together; absent-file sources survive. | Native UI only; backup administration is not exposed through MCP or Intents. |
| V2, known recovery incomplete | Read/search/export remain available. Retry only the known-applied checkpoint, then unblock domain changes. | Core result/status is approved; native and Share interruption proof. |
| V2, account changed | Inspect/export the old independent recovery namespace without changing the active dataset; explicit restore/merge is separately reviewed. | Native recovery only under Q4; coherent account cutoff is a hard device gate. |
| V3, Shortcuts action | Resolve stable IDs, invoke explicit scoped ordinary action, return the Core outcome. Confirm required bulk targets and route capture to Add/Cancel. | Ordinary Intents may run while locked where Apple permits; bulk uses system confirmation. Native behavior must be demonstrated. |
| V3, Agent Control Off/On | No listener while Off. Enabled authorized client performs permitted operations until Stop or app quit; operation status remains truthful. Lock, sleep and last-window closure retain enablement. | Four selected clients, two-client qualification and the manually controlled lifecycle are accepted; the MCP prototype proves them. No maximum duration, idle expiry or countdown. Q30 C requires measured capacity without an extra app-imposed client/request cap. |

## Command and authority inventory

Command names below identify proposed adapter operations within the approved Core families. They do not replace the approved facade with another domain service. Final JSON/Swift constructor declarations depend on the accepted wire/authority answers.

| Family | Identity and action | Carried-forward invariant or pending boundary |
| --- | --- | --- |
| Create/edit Item, List, Itinerary | Planner-generated source identity on create; explicit source UUID and changed fields on edit. | Item content/label associations are separate from completion/archive. A6 own-Item timestamps have no contextual or label-rename fan-out. Q10 fixes partial missing/null/value rules; Q27 chooses a hash guard for changed fields. Complete read/edit declarations remain final-review work. |
| Set Item completion | Item UUID plus Done/Todo. | Global Done overrides every appearance's display, retaining local flags; global Reopen reveals those flags. Both explicitly described global and appearance scopes are accepted under revised Contract Q1. |
| Set appearance completion | Exact typed List membership, direct itinerary entry or expanded List-child appearance plus Done/Todo. | A source UUID cannot substitute for an appearance; missing/removed appearances do not retarget globally. |
| Set full-context completion | List, Itinerary or itinerary List-entry scope plus Done/Todo and Core-issued exact-target review. | Hidden/archived appearances included once each; global flags untouched. Empty remains No items. MCP capture and bulk may be applied by the authorized agent after exact review under revised Contract Q2/Q3. |
| Archive/unarchive | Item/List/Itinerary source UUID plus independent archive state. | Container-only effects; shared source content and global/local completion retained. |
| Organize | Source/destination and association/entry identity, placement and operation identity. | Brief already includes remove-from-list and unschedule. Planning-reference removal retains shared source Items/Lists. Standalone membership uniqueness and intentional itinerary repeats differ. |
| Schedule | Item/Itinerary source and selected Schedule identity with typed timed/all-day values. | Removing one Schedule preserves source/other Schedules. These ordinary planning edits must not authorize source/label Delete. |
| Create/edit labels | Category/Tag UUID and own name/metadata; owner association edits retain label identity. | Same-name labels allowed; shared edits live everywhere. Permanent label Delete remains a separate authority/confirmation path. |
| Permanent Delete | Source/label identity plus bound impact review. | Default MCP cannot invoke it directly or indirectly. Native confirmation lists affected references; container sources remain. |
| Capture create/reuse | Reviewed draft/origins, original links, selected List IDs, chosen create/reuse and operation identity. | Provider preview stays unsaved. Reuse retains existing fields/state and adds reviewed missing links/memberships. Native Add/Cancel and C16 in-flight rules retained. |
| Backup apply/recovery restore | Validated immutable backup, Skip/Overwrite and exact impact review. | Incoming deletion/lifetime effects require authority even for absent local targets. MCP and Intents expose no backup apply or account-recovery administration under revised Contract Q4. |
| Read/export/recovery status | Current authorized dataset or separately authorized recovery namespace. | Read failure is not empty data. Portable backup excludes credentials, internal receipts and presentation state. Q4/Q5 keep full export/import/recovery manual and unavailable to MCP/Intents; ordinary authorized reads and operation-status queries remain available. |

For permitted reference editing, deleting Item X, a List, an Itinerary, Category or Tag is distinct from removing an association or one Schedule. The original brief explicitly proposes remove-from-list and unschedule as ordinary MCP planning operations. This contract carries those actions forward and requires source-Delete authorization checks for indirect effects; it does not silently introduce a destructive default capability.

## Concrete identity and state fixtures

These valid UUIDs are constructed test fixtures, not records in a running app. Production UUIDs are generated once per logical operation. The hexadecimal suffix is only a readable fixture aid.

| Identity | UUID | Initial state |
| --- | --- | --- |
| Hotel Item | 00000000-0000-4000-8000-000000000101 | Global Todo, Active, notes Original notes, estimate 120 minutes with hour display unit. |
| Museum Item | 00000000-0000-4000-8000-000000000102 | Global Todo, Archived, no estimate. |
| Tokyo Food List | 00000000-0000-4000-8000-000000000201 | Hotel membership locally Done; Museum membership locally Todo. Progress 1 of 2. |
| Trip Prep List | 00000000-0000-4000-8000-000000000202 | Hotel membership locally Todo. Progress 0 of 1. |
| Tokyo itinerary | 00000000-0000-4000-8000-000000000301 | Hotel, Museum, Hotel direct entries in that order; each locally Todo. Progress 0 of 3. |
| Tokyo Food Hotel membership | 00000000-0000-4000-8000-000000000401 | Same shared Hotel, distinct List-local state. |
| Tokyo Food Museum membership | 00000000-0000-4000-8000-000000000402 | Included in progress/bulk despite archive. |
| Trip Prep Hotel membership | 00000000-0000-4000-8000-000000000403 | Removing Tokyo Food's Hotel membership leaves this identity. |
| Itinerary Hotel first entry | 00000000-0000-4000-8000-000000000501 | First independent Hotel appearance. |
| Itinerary Museum entry | 00000000-0000-4000-8000-000000000502 | Independent Museum appearance. |
| Itinerary Hotel second entry | 00000000-0000-4000-8000-000000000503 | Second independent Hotel appearance. |
| Direct Hotel Schedule | 00000000-0000-4000-8000-000000000601 | Retained past all-day date 2026-10-01. Scheduled anywhere remains true until all effective schedules are removed. |
| Create/edit operation | 00000000-0000-4000-8000-000000000901 | Identical authorized replay retains one result. Changed payload does not rewrite the old accepted operation outcome. |

From the initial itinerary, locally complete entry 501: progress is 1 of 3. Globally complete Hotel: progress is 2 of 3 and both Hotel rows display Done. Globally reopen Hotel: progress returns to 1 of 3, retaining entry 501's local Done and entry 503's local Todo. Museum remains Archived/Todo throughout. Tokyo Food's local Hotel flag is independent of the itinerary.

Accepted stale-edit fixture: read Original notes, then locally save Friday booking, then submit Monday booking based on the old read. Reject this attempt as staleEdit and retain Friday booking with no other mutation. A title-only intervening change does not block a notes-only edit. Q27 chooses Core-issued per-field hashes under delegated engineering judgment: compare only hashes for edited fields under the writer gate, rejecting the entire edit when a hash differs. No test has run.

## Wire and outcome proposals

Core-issued dataset ownership and epoch values remain opaque. A MCP client cannot choose an account by supplying JSON ownership fields. The adapter binds the request to its authorized active session and calls the same Planner facade. Read/review/operation values remain immutable and dataset-bound.

Accepted partial-edit JSON has an operationId, selected Item UUID and a changes object containing only edited fields. A notes-only value sets notes, null clears it and absent fields stay unchanged under Q10. The corresponding typed request uses the approved PlannerFieldChange set/clear/unchanged cases and PlannerOperation passed to Planner.execute. Q9/Q27 require expectedFieldHashes for changed content fields, produced by a read and compared against current values under the writer gate. A missing required hash rejects instead of silently authorizing blind overwrite. This is an optimistic edit guard, not an authentication credential or a replacement for review tokens.

Proposed completion wire distinguishes set_item_completion with itemId from set_appearance_completion with a typed appearance object. For the first Hotel itinerary appearance, its object contains kind directItineraryItem, itineraryId 301 and entryId 501 using their full UUID strings. Expanded List children additionally require listEntryId and membershipId. Their typed equivalents are PlannerCompletionScope.globalItem or .appearance with the corresponding approved PlannerAppearanceID case. A request missing its required scope/identity is rejected without guessing.

Proposed stable attempt failure categories include invalidInput, unsupportedVersion, invalidBackup, notFound, staleEdit, staleReview, staleDatasetSession, permissionDenied, recoveryBlocked, operationPayloadMismatch and unavailable. These map to the approved rejected/applied/unverified results. They are not a replacement for structured result evidence. Final category fields and wire spelling require the accepted schema follow-up.

An applied result with recovery incomplete is a complete applied domain action and cannot be represented as an ordinary failed/unapplied tool call. A later rejected replay is an attempt failure and cannot replace the recorded successful original status. Missing evidence means noReliableEvidence or preparedUnverified, never automatic rollback. Cancellation after commit retains applied state; status/readback resolves response loss. These meanings are already approved in A21/A22.

## Verified platform facts

Read-only facts checked against installed OS 27 declarations and primary sources. These do not establish the shipped implementation's runtime results.

| Fact | Contract implication |
| --- | --- |
| Native [Int64 JSON decoding](https://github.com/swiftlang/swift-foundation/blob/2df17f28d6cd4aa0cf27cc66598fcabbcde8292c/Sources/FoundationEssentials/JSON/JSONDecoder.swift#L1112) can accept integral decimal/exponent forms and a rounded tiny fractional value; [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259#section-6) describes binary64 interoperability limits. | Canonical decimal strings plus native checked conversion avoid a JavaScript precision cap and strict-lexeme ambiguity. Q11 accepts canonical Int64 strings; Q12 accepts exact finite native Date numbers. |
| Native [Date Codable](https://github.com/swiftlang/swift-foundation/blob/2df17f28d6cd4aa0cf27cc66598fcabbcde8292c/Sources/FoundationEssentials/Date.swift#L346) uses Double seconds since 2001-01-01 UTC; inspected [ISO8601 fractional formatting](https://github.com/swiftlang/swift-foundation/blob/2df17f28d6cd4aa0cf27cc66598fcabbcde8292c/Sources/FoundationEssentials/Formatting/Date%2BISO8601FormatStyle.swift#L354) rounds to milliseconds. | Full backup cannot claim arbitrary Date fidelity from ordinary ISO formatting. Lossless finite native round-trip remains a focused runtime gate. |
| [decodeIfPresent](https://developer.apple.com/documentation/swift/keyeddecodingcontainer/decodeifpresent(_:forkey:)-w7f) conflates missing/null; contains plus decodeNil can distinguish them. Native UUID Codable uses UUID string conversion. | Patch semantics can use native Codable. Producers use canonical hyphenated UUID output; accepted case variants do not create new identities. |
| Ordinary Foundation keyed decoding collapses repeated property names before allKeys; [RFC 8259 object names](https://www.rfc-editor.org/rfc/rfc8259#section-4) should be unique. | Repeated JSON properties differ from duplicate entity UUIDs. Q14 accepts native handling without a guaranteed duplicate-property rejection or portable winner. |
| [NSItemProvider](https://developer.apple.com/documentation/foundation/nsitemprovider) typed loadObject supports NSURL, NSString and MKMapItem in installed SDK 27; callbacks are asynchronous and return Progress. | Collect supported typed lanes with fixed positions. Do not infer content authorship from loader class or callback order. File URLs are excluded; unsupported formats reported. No arbitrary binary-data fallback is proposed. |
| [Plain text](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/plaintext) has unspecified encoding; native object loading materializes a result before a size check. | NSString avoids an assumed UTF-8 byte decode. A post-load acceptance bound is not proof of bounded peak memory. |
| [Unified Maps URLs](https://developer.apple.com/documentation/mapkit/unified-map-urls) documents Apple place/viewport distinctions and shortened maps.apple-host URLs resolved from redirects. [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started) defines no-key map URLs. | Retain original bookmarks. Preview interpretation follows documented parameters; no opaque path decoding or promotion of provider descriptions to own content. |
| The [Google resolution API](https://developers.google.com/maps/ai/grounding-lite/resolution-api) needs billing-enabled setup and credentials. | It cannot be the approved no-key baseline. Unknown/legacy links can remain bookmarks without promised lookup. |
| [URLSession request timeout](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/timeoutintervalforrequest) resets when data arrives; a non-background [redirect delegate](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/urlsession(_:task:willperformhttpredirection:newrequest:completionhandler:)) can inspect/refuse each redirect. | A whole-preview deadline is separate. Use headers/redirect inspection and cancellation rather than body-fetch convenience methods; HEAD success is not assumed. |
| [MCP tool annotations](https://modelcontextprotocol.io/specification/2025-11-25/schema#toolannotations) are hints; [structured tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools) may return domain evidence. | Enforce authority in command admission/impact, with unambiguous applied/recovery status. |
| [Intent authentication policy](https://developer.apple.com/documentation/AppIntents/IntentAuthenticationPolicy) and confirmation are separate mechanisms; custom intents can default to alwaysAllowed. | Choose authentication explicitly rather than treating invocation or confirmed true as independent human approval. |
| [System sleep](https://developer.apple.com/documentation/appkit/nsworkspace/willsleepnotification), [last-window closure](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationshouldterminateafterlastwindowclosed(_:)) and [ContinuousClock](https://developer.apple.com/documentation/swift/continuousclock) have documented public meanings. [Session deactivation](https://developer.apple.com/documentation/appkit/nsworkspace/sessiondidresignactivenotification) documents switching sessions, not every lock. [Closed-lid operation](https://support.apple.com/en-gb/102282) can leave a Mac awake. | Actual system sleep differs from display sleep/lid closure. Q25 retains enabled access through lock/sleep and does not require universal lock detection. An asleep Mac cannot serve requests; wake resumes access while Planner remains running, without an elapsed-time cutoff. Q26 requires continued process life and menu-bar controls after last-window closure. |

Guaranteed duplicate-property rejection is feasible through the established C library [Jansson's JSON_REJECT_DUPLICATES](https://jansson.readthedocs.io/en/latest/apiref.html#decoding). Its [current releases](https://github.com/akheron/jansson/releases) and [source/tests](https://github.com/akheron/jansson) show maintenance. It is not a verified drop-in Swift package; native platform integration and grammar compatibility would need proof if selected. No dependency has been added. Q14 accepts native handling, so no additional duplicate-rejecting parser is selected or required. Q13 separately requires unknown supported-version backup fields to reject together.

## Credential-handoff facts for the next frontier

These are documented candidates, not successful Planner connections. Fact work inspected public documentation and installed CLI help/schema, without reading private client configuration or credentials and without installing or changing clients.

| Client or native capability | Verified fact and remaining proof |
| --- | --- |
| Codex CLI, observed 0.160.1 | Supports environment-backed bearer/header values and a string http_headers_helper. The [pinned schema](https://github.com/openai/codex/blob/rust-v0.160.1/codex-rs/core/config.schema.json) and [helper implementation](https://github.com/openai/codex/blob/rust-v0.160.1/codex-rs/rmcp-client/src/http_headers.rs#L431) use a shell command, cache per connection and refresh/retry once on same-origin 401/403 when headers changed. Other bearer/OAuth configuration may override helper Authorization. |
| Local Codex desktop | [MCP documentation](https://developers.openai.com/codex/mcp) establishes shared host configuration and local Streamable HTTP. Configuration changes may require Save/Restart. Embedded helper behavior and renewal/reconnect need an independent demonstration. |
| Claude Code CLI, observed 2.1.291 | [Dynamic authentication](https://code.claude.com/docs/en/mcp#use-dynamic-headers-for-custom-authentication) supports a shell headersHelper, evaluated on connection/reconnection with one refresh/retry after 401/403. A running client's environment is not automatically changed by editing shell variables. |
| Claude Desktop local Code tab | [Shared configuration](https://code.claude.com/docs/en/desktop#shared-configuration) uses the CLI configuration. Desktop does not inherit arbitrary shell variables; its local environment editor applies values to new sessions. Actual helper execution and reconnect require separate proof. |
| Existing signed app executable | Apple's [app-like executable/profile example](https://developer.apple.com/documentation/xcode/signing-a-daemon-with-a-restricted-entitlement) and [Keychain process rules](https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains) support using an executable inside its signed app wrapper. A non-UI mode of Planner's main executable is a smaller candidate than another restricted-entitlement tool, not yet implemented or proved. |
| Credential storage and access | [App Group containers](https://developer.apple.com/documentation/xcode/accessing-app-group-containers) and [Keychain sharing](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps) have process/signing requirements. Storage and reader caller trust are separate; neither storage mechanism alone identifies a client invoking a credential reader. If a reader is chosen, its exact storage and access contract is the dependent follow-up. No unauthenticated credential-serving HTTP endpoint is proposed. |
| Port 44444 | [IANA](https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?search=44444) assigns TCP 44444 to cognex-dataman. This does not establish local occupancy or invalidate a configurable loopback default. Preserve the human's requested 44444 and prove clear occupied-bind failure. |

## Accepted Contract Q1-Q26

These choices are the human's answers, not inferred acceptance of recommendations. Earlier recommendations in the historical question round are superseded wherever the chosen option differs.

| Question | Accepted option and resulting behavior |
| --- | --- |
| Q1 | A. Separate global Item and contextual appearance completion, with descriptions explaining the effect of each. No missing-scope fallback. |
| Q2 | A. Agent capture is a legitimate flow; the enabled agent reviews and applies the exact create/reuse proposal without an additional native click. |
| Q3 | A. Agent applies the exact full-context local bulk preview, including hidden/archived targets, without modifying global Item flags. |
| Q4 | A. Backup import/restore and old-account recovery are rare manual native actions, unavailable to both MCP and Intents. |
| Q5 | C. Full export is also manual native administration. Integrations interact with ordinary Planner data, not backup administration. |
| Q6 | C. Ordinary data Intents may run while locked where Apple permits. No added Planner authentication requirement; Apple's system restrictions still apply. |
| Q7 | A. Bulk Intent uses system confirmation describing the full scope and count; cancellation changes nothing. |
| Q8 | A. Stop attempts safe precommit cancellation. Applied actions remain applied, with truthful status/recovery reporting. |
| Q9 | A. Reject a locally known stale edit only when an edited field changed; unrelated field edits do not block it. |
| Q10 | A. Omitted fields unchanged, null clears optional fields, a supplied value sets; required-field clear rejects. |
| Q11 | A. Int64 wire values are canonical decimal strings with checked native conversion. |
| Q12 | A. Finite Date values use numeric Double seconds since 2001-01-01 UTC with exact native round-trip proof. |
| Q13 | A. Unknown fields in supported-version backups reject the whole import with a property path. |
| Q14 | A. Native duplicate-property handling, with no guaranteed rejection or portable first/last winner. Review/apply use one immutable decode. |
| Q15 | A. Input/attachment order, then typed URL before text-detected links; callback timing cannot change order. |
| Q16 | A. 32 providers, 1 MiB decoded URL/text total, 128 distinct links, four concurrent loads, ten seconds overall; physical allocation/lifecycle proof required. |
| Q17 | A. Failed/oversized supported inputs block Add until retry or explicit removal. Optional enrichment failure remains separately saveable. |
| Q18 | A. Network lookup only for HTTPS originals on documented Maps hosts; retained HTTP bookmarks receive no lookup. Every redirect is checked. |
| Q19 | A with amendment. Eight seconds overall, four per request, five redirects/six requests maximum; show an appropriate loading indicator. Add never waits. |
| Q20 | A. Qualify Codex CLI, local Codex desktop, Claude Code CLI and Claude Desktop local Code tab separately. |
| Q21 | Original A is superseded by accepted Q30 C: prove two clients together without a hard client-registration limit or an extra app-imposed tool-call cap. |
| Q22 | A with amendment. Stable configurable loopback endpoint, default 127.0.0.1:44444/mcp; occupied port fails clearly and offers an explicit change. |
| Q23 | Superseded by the human amendment: no maximum duration, duration picker or countdown. Original C is historical. |
| Q24 | Superseded by the human amendment: no idle expiry or activity-reset timer. Original A is historical. |
| Q25 | C, amended to remove expiry qualifiers. Lock/sleep do not revoke enabled access; wake resumes it while Planner remains running. |
| Q26 | B, amended to remove expiry qualifiers. Last-window closure retains enabled access with a native menu-bar status and Stop control. App quit always stops access. |

Completion command descriptions must say what changes and what is retained. Global Complete sets the Item Done so every appearance displays Done; Global Reopen reveals retained local flags and can leave some appearances Done. Contextual Complete/Reopen changes only the selected local flag; a globally Done Item still displays Done. Container bulk affects all contextual children, including hidden/archived ones, without changing global completion. Read results identify global, local and effective completion so an agent can explain the outcome.

The manual-administration boundary excludes backup export/decode/apply, recovery-namespace inspection/restore and recovery administration from public MCP tools and App Intents. It does not prevent ordinary reads, scoped operation-status checks or Core's internal recovery work after an allowed save. Native app/Share internal calls retain their approved ownership; no adapter reimplements recovery or domain rules.

Loading feedback belongs beside the pending Maps preview, not in a blocking save screen. Show that lookup is in progress, then its result or truthful unavailable/partial state. Obsolete callbacks after input changes/Add/Cancel cannot update a saved Item or the current review.

The Mac menu-bar control shows On/Off and Stop, with no countdown or duration selector. The running app retains manually enabled access through long idle periods, lock, sleep and last-window closure. Manual Stop or app quit removes the listener and revokes its credential. App restart starts Off; the reader cannot enable access. No separate daemon is introduced. Actual system sleep prevents serving requests until wake, without changing the enablement policy.

## Accepted amendment: no automatic agent access expiry

On 2026-10-08 the human explicitly removed all session timeouts from the preceding questions. Previously accepted Q23 C and Q24 A imposed a 60-minute maximum and ten-minute idle expiry, and Q25/Q26 retained access only while unexpired. Those limits are superseded: Agent Control stays enabled until manual Stop or app quit, including long idle periods, lock, sleep and last-window closure while the main app remains running.

Remove duration choices, countdown, maximum-duration and idle-reset timers, elapsed-expiry checks after wake, and time-based credential rotation. Enablement still creates a fresh credential. Stop revokes access and removes the listener; quit or process termination ends access; relaunch starts Off. Menu-bar On/Off and Stop remain visible after last-window closure. Authorization, Core dataset ownership, reviewed-action validation and truthful precommit/postcommit cancellation outcomes still apply. The reader cannot start or re-enable Agent Control.

This amendment overrides the original brief and historical Q23-Q26 wording below. Capture loading and Maps-request budgets govern individual operations and are unchanged. Q30 C settles capacity independently; accepted Q29 selects the official Swift SDK and its supported protocol baseline. The required evidence table below states the updated unit, real-listener and native lifecycle observations; no runtime evidence is claimed.

## Accepted Q27/Q28 and clarified session meanings

The human offered a hash-based edit guard or last-write-wins for Q27 and delegated the choice to whichever is sensible without excessive complexity. Choose Core-issued per-field SHA-256 hashes: reads return an opaque digest for each editable content field; changes return the original digest for every changed field. Core computes the current corresponding hashes and compares them under the same writer gate as save. A mismatch rejects the complete attempt as staleEdit, retaining the current values. Title-only changes do not invalidate a notes hash.

This preserves accepted Q9 without resending large notes, a stored version history, a separate edit-token registry or timestamp-based conflict decisions. Clients echo hashes rather than implementing canonical hashing themselves. Stable type/field framing and value encoding must be fixed in the final schema and tested across processes, including absent optional values, Unicode, collections, native integers/dates and identity/lifetime changes. Hashes do not authenticate clients or prove sync freshness. A value changed and then restored to its original canonical value has the original hash and is eligible; no revision-history claim is made. Apple provides native [CryptoKit SHA256](https://developer.apple.com/documentation/cryptokit/sha256). No dependency or code has been added. The [field-edit packet](field-edit-contract.md) specifies opaque hash grammar, canonical bytes, read/edit/replay behavior and independent vectors. The [content catalog](content-and-reader-review.md#complete-content-hash-catalog) completes its concrete fields under this delegated engineering choice. Final complete-contract review remains; it must not reopen unchanged Q9/Q10/Q27 behavior.

Q28 A is accepted: use the existing signed Mac Planner executable's non-UI header-reader mode, with actual signing/access and all-four-client proof. The human's question about protocol sessions triggered the verified correction below, not an assumption that initialization is still required by every client.

| Meaning | Current contract |
| --- | --- |
| MCP protocol session | The published 2026-07-28 revision removes initialize/initialized and Mcp-Session-Id. Modern requests carry their own version/capabilities; server/discover is available without a mandatory client handshake. No modern protocol session is required. |
| Agent access window | Manual enablement with a fresh credential, retained until Stop or app quit. The human removed all automatic maximum/idle expiry and countdown. Lock, sleep and last-window closure retain enablement. No MCP handshake creates or extends this authority. |
| PlannerDatasetSession | The already approved Core ownership/lifetime binding. It prevents stale account/store operations and is not an MCP transport session. It carries forward unchanged. |
| Operation/review identity | Explicit UUID/review handle with accepted payload/target/ownership and replay meanings. Stateless transport does not eliminate durable operation evidence or make an uncertain write automatically safe to repeat. |

## Q31 clarification and accepted Q32 A

On 2026-10-09 the human asked whether Q31 had already been settled through the agentic-change conflict choice, and answered "Q32 a". Q31 is withdrawn as a repeated policy question. Q27 already delegated hash versus last-write-wins and selected the simple changed-field hash guard; Q9 requires rejection of a changed edited field. The engineering catalog uses complete compound fields, not recursive nested patches or a new entity-wide revision policy. This records the clarification, not a fabricated answer accepting every previously proposed declaration. The complete contract remains available for final review.

Accept Q32 A: the signed executable's non-UI credential reader verifies the existing listener with an authenticated standard SDK ping and the matching access-window response header before emitting its header JSON. Reread unchanged On metadata; otherwise return unavailable without enabling/launching the app. The [exact reader declaration](content-and-reader-review.md#credential-reader-declaration-accepted-contract-q32-a) fixes Keychain storage, metadata, output, validation and Stop/quit races. No separate XPC service or bootstrap is introduced. Ping is neither an agent initialization nor a Planner mutation; it creates no receipt or recovery checkpoint. Native signing, Keychain, lifecycle and all-four-client proof remain required.

## Verified current MCP facts

| Primary source | Verified implication and limitation |
| --- | --- |
| [Published 2026-07-28 changelog](https://modelcontextprotocol.io/specification/2026-07-28/changelog) and [versioning](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning) | Stateless protocol is a released revision, not only a draft. Modern and legacy clients have different request/handshake behavior; compatibility must be proved. |
| [Current Streamable HTTP](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http) | Modern requests use per-request metadata/headers. Servers do not mint or echo Mcp-Session-Id. Closing a request SSE response signals cancellation; resumable Last-Event-ID delivery is removed. Cancellation still cannot undo Planner's committed domain action. |
| [Legacy HTTP](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports) | 2025-11-25 still initializes, but assigning an HTTP session ID is optional. Legacy stateless transport and modern handshake-free protocol are different. |
| [Official Swift SDK 0.12.1](https://github.com/modelcontextprotocol/swift-sdk/releases/tag/0.12.1) and [pinned transport](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Base/Transports/HTTPServer/StatelessHTTPServerTransport.swift) | Already supports sessionless JSON HTTP without Mcp-Session-Id. Supported revisions end at 2025-11-25. Lenient dispatch allows calls before initialize, but does not implement the full 2026-07-28 protocol. Repeated initialization and concurrent response routing need qualification. |
| [Claude client runtimes](https://code.claude.com/docs/en/mcp#mcp-client-runtimes) | v2 documents modern support and legacy fallback; selection depends on runtime/version/provider/flags. Observing the installed CLI version is insufficient. Desktop embedded runtime still needs separate proof. |
| [Codex MCP](https://developers.openai.com/codex/mcp) | Streamable HTTP and credential helpers are documented, but the inspected evidence does not establish current handshake-free runtime compatibility in either selected Codex surface. Prove each; do not infer support from the protocol release date. |
| [SwiftMCP v1.14.0](https://github.com/Cocoanetics/SwiftMCP/releases/tag/v1.14.0), released 2026-10-07, and [modern response tests](https://github.com/Cocoanetics/SwiftMCP/blob/v1.14.0/Tests/SwiftMCPTests/Connection/ModernResponseShapeTests.swift) | Has an unadvertised modern request path and passing published test CI. Advertised revisions remain legacy; discovery returns -32601 so clients fall back to initialize. This is partial modern support, without verified full modern conformance. |
| [axiom-orient/swiftMcp 0.4.2](https://github.com/axiom-orient/swiftMcp/releases/tag/0.4.2) and [mgcrea/swift-mcp-kit at a pinned commit](https://github.com/mgcrea/swift-mcp-kit/tree/34a80c36960294638e8cdcf7fe39ce170a83d5d6) | Both contain reusable native modern implementations. Axiom is modern-only, with runtime conformance and external review unverified. Mgcrea also supports legacy, but inspected discovery/metadata gaps and failing current test CI prevent a qualification claim. |
| [iMessage Max v1.7.1 modern dispatcher](https://github.com/cyberpapiii/imessage-max/blob/v1.7.1/swift/Sources/iMessageMax/Server/ModernProtocol.swift) and [HTTP adapter](https://github.com/cyberpapiii/imessage-max/blob/v1.7.1/swift/Sources/iMessageMax/Server/HTTPTransport.swift) | Maintained application-specific Swift code demonstrates a modern discovery/tools adapter around official SDK 0.12.1. It is not a reusable SDK or executed Planner/client proof. The official SDK gap does not mean native implementation is impossible. |
| [Current request metadata](https://modelcontextprotocol.io/specification/2026-07-28/basic/index) | clientInfo is optional self-reported information, not authenticated client-instance identity. Modern MCP provides no initialized-client roster for enforcing the earlier two-client/third-refusal wording. |

The [focused Swift SDK comparison](research/swift-mcp-sdk-options.md) records exact pins, source/tests, published CI and review limits. Another library is not required solely to omit transport sessions. Reusable modern Swift implementations exist; none has been qualified for Planner's four selected clients. The earlier report and Q21 wording were based on legacy initialization. Q30 C explicitly replaces the earlier cap with measured capacity.

At official SDK 0.12.1, a shared Server rejects a second initialize and retains client/version state. [Open PR #257](https://github.com/modelcontextprotocol/swift-sdk/pull/257) proposes a fix. The stateless transport also keys waiters/contexts by stringified caller request ID. Concurrent equal IDs can overwrite a waiter; integer 1 and string "1" can collide. [Issue #254](https://github.com/modelcontextprotocol/swift-sdk/issues/254) and [open PR #264](https://github.com/modelcontextprotocol/swift-sdk/pull/264) describe the defect and proposed routing fix. These fixes have not shipped in the pinned release. Lenient dispatch alone does not fix them. No safe release-level mitigation or Planner multi-client result is claimed.

## Decision tree after Q31 clarification and accepted Q32

| Settled prerequisite | Current independent follow-up | Held until its prerequisites settle |
| --- | --- | --- |
| Q27 chooses changed-field hashes, Q10 fixes partial-edit semantics; Q31 is withdrawn as repeated; Q33 A accepts the complete packet | Implement the accepted adapter and portable/native recovery forms through the existing facade. | Qualify concrete behavior in the owning prototypes; unchanged public approval carries forward. No separate conflict-policy round. |
| Q28 accepts the same-app reader; Q20 selects four clients; Q29 selects the official SDK; Q32 A selects authenticated ping | Carry exact reader observations into the prototype gates. | Qualify dependency pin, signing/Keychain/access, repeated initialization, reconnects and isolated concurrent routing. No custom protocol stack or XPC bootstrap is approved. |
| Q30 C accepts two-client proof without an extra app cap | Define measured native/SDK capacity evidence. | No profile-registration or custom two-call admission fields; a later extra limit needs measured stability justification and an explicit amendment. |
| Accepted manual Agent Control enablement/menu bar and Core ownership | Preserve enablement until Stop or app quit independently of transport. | Reader storage/access and final schema are concretized under the selected native/client policy. |

## Native reader storage/access candidate

Following the accepted native best-practice direction and Q28's same-executable choice, use Apple's data-protection Keychain candidate for the temporary credential, owned by Planner's private access group. Both app and reader are the same signed main executable, so neither clients nor Share extensions require Keychain access and no additional shared group is inherently needed. [TN3137](https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains) describes process/signing and implementation differences; the actual profile/entitlements and sandboxed invocation still require proof.

The [data-protection flag](https://developer.apple.com/documentation/security/ksecusedataprotectionkeychain) with [AfterFirstUnlockThisDeviceOnly](https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly) is a documented macOS candidate for access after first unlock until restart, including while locked, without migrating the item to another device. It does not itself enforce Planner's Stop or process-lifetime rules. Do not add user-presence/biometric requirements that contradict the accepted enabled locked-use behavior. A [noninteractive LAContext](https://developer.apple.com/documentation/localauthentication/lacontext/interactionnotallowed) makes a requirement fail instead of showing UI; it is not proof that access succeeds.

The reader emits only the required header JSON while Agent Control is enabled in the running main app and otherwise returns a controlled unavailable result without prompting. It cannot enable access, start a listener, initialize/migrate data or silently fall back to a plaintext credential in ordinary configuration. Prove continuation after long idle periods and lock/sleep, first-unlock/restart, manual Stop, app quit/forced termination and update/signing behavior with the same installed executable. Main-process liveness, access metadata and cleanup are part of the final reader contract; no implementation has been established.

A caller running under the local user's account may be able to invoke the configured executable too. The mode is not proof of vendor identity or client pairing. Accepted Q30 C introduces no profile-registration credentials or reader profile arguments. Credentials/window metadata are excluded from Planner portable backups and planning-data synchronization.

## Accepted Contract Q29: official Swift SDK

On 2026-10-08 the human answered "Q29 use the official sdk". Accept A: use modelcontextprotocol/swift-sdk and its supported sessionless HTTP protocol for the first prototype. The inspected release 0.12.1 supports 2025-11-25; record the exact tested dependency pin and resolved package file in the prototype. A later fixed official release may be evaluated within this package choice. Selecting an alternative SDK, fork or custom protocol implementation would require an explicit amendment. Q27, Q28 and Q30 C carry forward. The following alternatives retain the context of the settled decision.

❓ **Contract Q29** - **Which protocol baseline should the native MCP prototype target?**

The official Swift SDK already supplies sessionless HTTP. Its released protocol implementation ends at 2025-11-25 and has open initialization/request-routing defects that the prototype must resolve and test. The 2026-07-28 revision additionally removes the initialization handshake and requires per-request metadata plus discovery. Axiom 0.4.2 is a concrete modern-only Swift candidate, with runtime compliance and external review unverified. Cocoanetics has partial modern support; mgcrea has visible protocol and CI gaps. The [cited comparison](research/swift-mcp-sdk-options.md) corrects the earlier impression that no reusable modern implementation exists. No Planner connection has succeeded.

This decision chooses the minimum protocol requirement, not approval to implement a custom stack. All choices preserve manual enablement until Stop or app quit, no automatic expiry, accepted Q30 C and the four selected clients. Qualification must prove repeated connections and isolated concurrent responses, not merely demonstrate that a session header is absent.

- **A. Official Swift SDK baseline.** Accept 2025-11-25 sessionless HTTP for the first prototype, with client initialization where that revision requires it. No transport session manager. Qualify all four clients and resolve the pinned SDK's initialization/routing defects before declaring feasibility. Modern support can follow a maintained compatible release. This uses the official dependency without requiring a protocol upgrade now.
- **B. Current protocol plus compatibility.** Require 2026-07-28 and legacy fallback where selected clients need it. Qualify a maintained Swift library that supplies both, including its protocol/test gaps. This covers more client versions but adds dependency review and two protocol paths to test. No custom stack is presumed approved.
- **C. Current protocol only.** Require 2026-07-28 with no legacy branch. Axiom is a released native candidate. Fewer protocol paths, but a larger library-review burden and any legacy-only selected client blocks acceptance. None of the four selected Planner connections is proved compatible yet.

Accepted: **A, Official Swift SDK baseline**, subject to the named initialization and concurrent-routing evidence gates. Sessionless HTTP meets the no-transport-session requirement. The newest handshake-free revision is not required by this decision. The official label does not waive stability tests.

Status: accepted A, 2026-10-08. Q29 is settled and is not asked again. Four real-client connections, repeated initialization, request isolation and measured stability remain unproved prototype obligations. Exact reader and final public schemas remain contract work.

---

## Accepted Contract Q30: measured capacity without an extra app cap

The human accepted C on 2026-10-08. This supersedes Q21's hard third-client refusal. The alternatives below preserve the context of that settled decision.

Q21 accepted two initialized clients and refusal of a third. The modern protocol has no initialized-client roster; self-reported names do not identify authenticated clients. A hard client limit requires explicit credentials/registration. A request limit is simpler but is an amendment to the earlier rule, not an equivalent implementation. This choice is independent of which protocol baseline Q29 selects.

- **A. Two-client proof with bounded requests.** Demonstrate two clients together. Initially admit two concurrent tool calls and report busy/retry for excess work; additional clients can use free capacity. No hard third-client refusal or client roster. This explicitly replaces that part of Q21.
- **B. Two registered client profiles.** Issue separate credentials for at most two named profiles and refuse a third profile. Works independently of MCP sessions, but adds profile setup, reader arguments, credential lifecycle and tests. Sharing one profile credential still does not prove distinct client instances.
- **C. No additional app cap; measure capacity.** Demonstrate two clients together, use the selected SDK/OS handling and existing Core write coordination, and require load/memory evidence. No hard client registration or initial custom tool-call counter. A later additional limit requires measured stability justification and an explicit amendment.

Accepted: **C, No additional app cap; measure capacity**. Keep the two-client proof and require measured stability evidence before an additional limit. No initial client-profile registry, hard third-client refusal or custom two-concurrent-tool-call counter.

Status: accepted C, 2026-10-08. Q21's original initialized-client cap is historical; measured SDK/OS capacity and existing Core write coordination remain prototype evidence gates.

---

## Historical Q31/Q32 review

Accepted Q29/Q30 carry forward. The [content and credential-reader declarations](content-and-reader-review.md) supply concrete types, native source limits, before/after fixtures and six additional independent hash expectations. The following questions preserve review history. On 2026-10-09 Q31 was withdrawn as repeating Q27, and the human accepted Q32 A. Remaining adapter request/result/admin forms proceed under those settled rules; runtime proof is not inferred.

❓ **Contract Q31** - **Accept the complete content catalog and compound edit guards?**

The packet fixes Item/List/Itinerary/Category/Tag fields, native sRGB color values, ordered owned links, independent location, estimates and live label IDs. Completion/archive/reference actions stay separate under Q8. It guards a complete location or links replacement as one field. If Mac changes an address while iPhone edits coordinates from the old location, the iPhone edit is stale and must reread; unrelated notes/title edits still coexist. A nested value is a complete replacement, with explicit nullable members, so an incomplete location object cannot silently erase its other values.

- **A. Proposed catalog and compound guards.** Accept the packet's complete types. Simple read/edit shapes and atomic coordinate/order validation; any concurrent change within the same compound field requires reread.
- **B. Same catalog, finer nested guards.** Allow independent location-subfield/link-record edits to coexist. Requires additional field identities, patch grammar and coordinate/order consistency tests; those declarations must be revised before approval.
- **C. Amend the content catalog first.** Describe field/type changes. Keep existing domain/authority rules, but settle those changes before generating dependent adapter schemas.

➡️ Recommendation: **A, Proposed catalog and compound guards**. It keeps the changed-field guard simple without blocking independent title/notes edits.

Status: withdrawn as a repeated policy question, 2026-10-09. Q27's engineering-delegated per-field hash guard applies; this is not recorded as an invented A/B/C answer or another conflict-policy approval gate. New transport declarations belong in the complete final contract review.

---

❓ **Contract Q32** - **Which live confirmation should the same-app credential reader qualify?**

Q28 already chose this signed app executable as the reader; Q29 chose the official SDK. The packet fixes a no-UI `--mcp-headers` mode, noninteractive after-first-unlock Keychain access, fresh random credential per Enable, ephemeral main/window metadata and controlled unavailable outcomes. A stale PID/file alone cannot prove that the enabled app is alive. Both candidates preserve manual Stop, no expiry, no profiles, no plaintext fallback and unchanged Core authority.

- **A. Authenticated SDK ping and window check.** Before returning headers, verify the existing enabled endpoint with its standard SDK ping and matching window header. Adds one local HTTP request per reader invocation. Uses the already required listener; no extra IPC service or Planner tool. Actual signed/locked/lifecycle/client proof remains required.
- **B. Native anonymous XPC confirmation.** Keep the same reader/Keychain/output, but verify live main/window state through private native IPC. Avoids a reader MCP request; adds endpoint bootstrap, signing/sandbox and interruption work. The documented transfer uses an existing XPC connection; file-archive bootstrap is unproved and must be researched before this candidate is ready. No permanent launchd service is approved.

➡️ Recommendation: **A, Authenticated SDK ping and window check**. The pinned official SDK supports this read-only probe and response header without another protocol implementation.

Status: accepted A, 2026-10-09. Native documentation is factual evidence, not actual reader execution.

---

## Historical Q27/Q28 proposals

Q27's previous-value versus edit-token question is superseded by the human's hash-or-last-write delegation and the hash selection above. Q28's same-app-reader alternative A is accepted; its implementation remains unproved. The earlier round is preserved in [the prior packet](https://github.com/dvcol/planner/blob/f9bca8a61744aff9d3a11335347433faf963615a/docs/shared-command-contracts.md#current-frontier-contract-q27-q28). No earlier question remains unanswered.

## Historical round-one questions

The [original sixteen-question draft](https://github.com/dvcol/planner/blob/0c2a67fc67b2e169eac6e45543b7fb52474f6642/docs/shared-command-contracts.md) was replaced by the following expanded questions. Their recommendations show the proposed alternatives at the time; the accepted table above and each recorded answer govern current work.

❓ **Revised Contract Q1** - **Which completion scopes should integrations expose?**

Hotel appears twice in Tokyo Trip. Both local flags start Todo. The accepted rule is global Done OR local Done: completing one appearance gives 1 of 3 progress; completing Hotel globally makes both Hotel appearances Done. This question changes which commands agents and Shortcuts can invoke, not that approved rule. Should integrations offer global and contextual completion?

- **A. Both explicit scopes.** Expose separately named Item and appearance commands with the appropriate IDs. Agents can perform either action, but a missing scope is rejected.
- **B. Global completion only.** Agents and Shortcuts complete the source Item everywhere. Contextual completion stays in native Planner, reducing available automation.
- **C. Contextual completion only.** Agents and Shortcuts change selected planning appearances. Global completion remains an explicit action in the native Item view.

➡️ Recommendation: **A, Both explicit scopes**. It preserves useful automation while making the effect explicit.

Original proposal covered: Q1. Status: accepted A, with explicit ramifications in descriptions, 2026-10-08.

---

❓ **Revised Contract Q2** - **Who applies a capture requested by an agent?**

You ask an agent to save a Maps link to Tokyo Food. Capture produces one editable create/reuse proposal, retaining permitted original links; temporary provider details remain unsaved. Nothing is created before apply. Native app and Share Add/Cancel behavior is already approved. For the MCP capture flow, who should authorize applying the exact reviewed proposal?

- **A. Agent reviews and applies.** The enabled agent may inspect the preview and apply its bound token. No additional native click; changes to the payload or dataset require fresh review.
- **B. Human confirms in Planner.** The agent prepares the capture, but native Planner shows it for Add/Cancel. This adds an interruption for each agent capture.
- **C. Native capture only initially.** Do not expose the capture/reuse tool initially. Ordinary authorized Item creation remains available, but provider capture conveniences stay native.

➡️ Recommendation: **A, Agent reviews and applies**. Enabling ordinary agent editing can cover this explicit reviewed action without a second approval interface.

Original proposal covered: Q2. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q3** - **Who applies an agent's full-context bulk completion?**

Tokyo Food contains active Hotel and archived Museum. A current filter shows only Hotel, but accepted bulk completion targets both local child states. An agent's preview names the full target set; changing it invalidates the review. Global Item flags remain untouched. Should the enabled agent be able to apply this bulk preview?

- **A. Agent applies exact preview.** The agent may complete both local children after inspecting the preview. The activity result reports the full affected count, including hidden/archived targets.
- **B. Native confirmation each time.** The agent prepares the preview, then Planner requires a human confirmation. This provides a direct checkpoint but interrupts batch automation.
- **C. No MCP bulk command initially.** Single-appearance commands remain available. Full-context bulk stays native; loops of ordinary allowed edits are not reclassified as one atomic bulk action.

➡️ Recommendation: **A, Agent applies exact preview**. A full-target preview and explicit scope make the enabled session useful while retaining the approved local transaction and stale-target protections.

Original proposal covered: Q2. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q4** - **How much backup and account-recovery authority should integrations have?**

A backup can contain new Z, a replacement for List A, or a deleted-ID marker for X. The marker can suppress obsolete X even when X is absent locally. Therefore no Delete tool does not by itself prevent deletion through import. Native Skip/Overwrite, account separation and whole-apply authorization remain approved. Which integration profile should be available initially?

- **A. Native backup and recovery workflows.** MCP and Intents cannot apply JSON backups or inspect old-account recovery. Native Planner performs preview/import/restore. Active-dataset export is decided separately in Q5.
- **B. Non-destructive active import.** Permit Skip import into the current dataset only when the entire proposed apply has no forbidden deletion/restoration effect. Reject the whole apply otherwise; old-account recovery stays native.
- **C. Separately granted advanced access.** Add explicit authority for reviewed Overwrite/restoration and selected recovery namespaces. It enables more automation but requires further grant, confirmation and revocation decisions.

➡️ Recommendation: **A, Native backup and recovery workflows**. It covers the V2 native backup journey and keeps the first agent permission model small.

Original proposal covered: Q3 plus the old-account part of Q4. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q5** - **Is active-dataset JSON export included in MCP read access?**

An enabled agent can already query the active planner. A full portable export collects its content, identities, references, schedules and minimal deletion history in one result. It excludes app state, credentials and internal receipts. This question concerns returning data, not writing arbitrary filesystem paths or accessing another account's recovery copy.

- **A. Include export in default read.** The authorized agent can obtain the current complete backup without another permission. This supports automated backup handling by the client.
- **B. Separate export permission.** Ordinary queries work by default. Native Agent Control must grant bulk export explicitly before the tool can return the full backup.
- **C. Native export only initially.** The human exports through Planner. Agents retain ordinary query access but have no full-backup tool.

➡️ Recommendation: **A, Include export in default read**. It is a useful read operation over the same authorized dataset; account-recovery access is a separate boundary.

Original proposal covered: Q4. Status: accepted C, 2026-10-08.

---

❓ **Revised Contract Q6** - **May App Intents access Planner data while the device is locked?**

Shortcuts and Siri can invoke data actions without showing the main app. Apple's custom Intent authentication policy can allow locked-device execution unless configured otherwise. Consider both reading today's plan and marking Hotel Done. This choice governs authentication only; which commands exist and which bulk confirmation is required are separate decisions.

- **A. Authenticate all data intents.** Reads and changes require device authentication. Consistent behavior, with an authentication step for hands-free locked-device requests.
- **B. Read while locked; authenticate changes.** Today's plan/search may run while locked. Creating, editing, completing, archiving and scheduling require authentication.
- **C. Allow ordinary intents while locked.** Use an always-allowed policy where Apple permits it. More hands-free automation, including changes, without a Planner-imposed unlock step.

➡️ Recommendation: **A, Authenticate all data intents**. An explicit uniform policy is easier to explain and prove for a personal planner.

Original proposal covered: authentication part of Q5. Status: accepted C, 2026-10-08.

---

❓ **Revised Contract Q7** - **How should a bulk completion Intent obtain confirmation?**

A Shortcut says Mark Tokyo Food done. Its accepted scope includes Hotel and archived Museum regardless of the visible filter; it changes only local child flags. The Core review binds the current target set. A stored Shortcut may run repeatedly or through automation. What interaction should happen before applying that bulk action?

- **A. System confirmation with full scope.** Use native Intent confirmation describing the container and complete target count, including hidden/archived children. Cancellation changes nothing.
- **B. Open Planner for bulk review.** Show the native Planner review before apply. More space for target details, but the Shortcut cannot finish entirely in its current context.
- **C. Explicit invocation is sufficient.** The named bulk Intent applies without a second confirmation, subject to Q6 authentication. Easier automated use; the action's all-child effect must be clear in Shortcuts.

➡️ Recommendation: **A, System confirmation with full scope**. It keeps a visible confirmation without opening the full app for every bulk action.

Original proposal covered: bulk-confirmation part of Q5. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q8** - **What should Stop do to an already admitted MCP write?**

The later no-automatic-expiry amendment removes the expiry trigger in this historical question; accepted safe precommit cancellation still applies to manual Stop.

An agent starts creating an Item and its two memberships. You press Stop or the session expires before the response arrives. New work must fail immediately. A committed action cannot be promised rolled back, and incomplete recovery is already an approved distinct status. The open choice is what to do if the admitted action has not committed yet.

- **A. Attempt cancellation before commit.** If cancellation reaches a safe precommit point, apply nothing. If commit has happened, retain the entire action and resolve recovery/status truthfully.
- **B. Finish admitted operations.** Reject new work, but let the admitted action attempt its full commit/recovery even if it was not committed at Stop. Stop may still be followed by that saved change.

➡️ Recommendation: **A, Attempt cancellation before commit**. It makes Stop meaningful for unapplied work while respecting irreversible commit and recovery evidence.

Original proposal covered: Q6. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q9** - **How should locally known stale edits behave?**

An agent reads Hotel's notes as Original notes. Another local action saves Friday booking. The agent then submits Monday booking from its older read. Separately, a title-only edit may occur while notes remain unchanged. This concerns state visible to the receiving device, not the accepted native winner for offline CloudKit conflicts.

- **A. Reject changed edited fields.** Keep Friday booking and return stale-edit/current-value information. A title-only change does not block a notes-only edit. Requires field-specific expectations.
- **B. Reject any source revision change.** Reject the notes edit after either a notes or title change. A whole-source revision is simpler, but unrelated edits cause more refreshes.
- **C. Apply submitted fields as a new edit.** Save Monday booking over current notes, retaining unedited fields. Fewer retries, but known intervening notes changes can be replaced.

➡️ Recommendation: **A, Reject changed edited fields**. It prevents replacing a known newer value without making independent field edits unnecessarily conflict.

Original proposal covered: Q7. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q10** - **How should a partial-edit request express Set, Clear and Unchanged?**

Hotel has title Hotel, notes Friday booking and a 120-minute estimate. A client wants to clear only notes. The approved Core already has unchanged/set/clear; required title cannot be cleared and unmentioned fields must be retained. This choice is the JSON shape clients use, not a change to domain behavior.

- **A. Missing unchanged; null clears.** Send {"notes":null}; a value sets notes and omission leaves it unchanged. Compact and familiar, with careful missing-versus-null decoding.
- **B. Explicit action per field.** Send {"notes":{"action":"clear"}} or an action set with a value. More verbose, but each change is visible in the schema.
- **C. Set values plus clear-field list.** Send {"setValues":{},"clearFields":["notes"]}. Omitted fields remain unchanged; setting and clearing the same field is rejected.

➡️ Recommendation: **A, Missing unchanged; null clears**. It maps directly to the approved cases using native Codable and keeps common patches short.

Original proposal covered: Q8. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q11** - **How should full-range integers travel through JSON?**

Native minutes/ranks use Int64. The value 9007199254740993 can be rounded by a JavaScript client using ordinary JSON numbers. We already agreed to preserve the native range and reject fractional/overflow input; reducing the domain range is not an option. How should backup/API values avoid this loss?

- **A. Canonical decimal strings.** Use "9007199254740993" and "120" consistently. Native checked parsing preserves the full range and rejects noncanonical fractions/exponents/overflow.
- **B. Numbers when safe; strings when large.** Use 120 as a number and the large value as a string. Friendlier small values, but a union schema and proven strict numeric-token validation are required.

➡️ Recommendation: **A, Canonical decimal strings**. One representation avoids both client rounding and Foundation's permissive integer numeric fallback.

Original proposal covered: integer part of Q9. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q12** - **How should backups encode an exact native timestamp?**

Full backups must reproduce stored finite Date values, including submillisecond precision. Native Date Codable represents seconds since 2001-01-01 UTC as a Double; ordinary ISO formatting may round away precision. The UI and schedule-entry forms remain readable, and all-day civil dates remain separate. Both following choices aim to preserve the same native value.

- **A. Native numeric reference seconds.** Use an explicitly named JSON number for seconds since 2001. Close to native Codable; the epoch and round-trip rules need clear documentation.
- **B. Exact decimal-string reference seconds.** Use the shortest round-tripping Double text as a string. Avoids consumers treating it as another number type, but needs explicit finite parsing and encoding.

➡️ Recommendation: **A, Native numeric reference seconds**. A Date already uses binary64, so native numeric encoding is the simpler candidate; exact round-trip still must be proved.

Original proposal covered: date part of Q9. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q13** - **What should a supported-version backup do with unknown fields?**

A file declares the supported version but an Item contains notse instead of notes, or its envelope includes an unfamiliar informational field. Unsupported versions, malformed values, duplicate entity IDs and unresolved references already reject together. The open choice is whether unrecognized properties within a supported version are tolerated.

- **A. Reject unknown fields everywhere.** Reject the whole import and identify the property path. Catches typos and prevents a successful import silently dropping unknown content; less permissive compatibility.
- **B. Ignore unknown fields.** Decode known fields and leave unknown values out. More tolerant of external exporters, but information in those fields is not restored.
- **C. Tolerate envelope metadata only.** Ignore extra non-data envelope metadata, but reject unknown entity/reference fields. A limited compatibility allowance without silently dropping planner content.

➡️ Recommendation: **A, Reject unknown fields everywhere**. It makes data-loss and typo detection explicit for the quality-first backup contract.

Original proposal covered: unknown-field part of Q10. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q14** - **Must JSON with duplicate property names be rejected?**

One Item object contains title twice with two different values. This differs from duplicate Item UUIDs, which are already invalid. Ordinary Foundation decoding can collapse repeated property names before the app sees them. Guaranteed rejection is feasible with a proven parser capability, such as Jansson, but its Swift/platform integration is not yet verified.

- **A. Use native duplicate-property handling.** Require producers to emit unique names; decode once and use the same immutable result for review/apply. Do not promise duplicate-property rejection or a portable first/last rule.
- **B. Guarantee rejection before mutation.** Reject repeated names at any nesting level with a useful error. Stronger ambiguity detection, with an additional parser capability and compatibility proof.

➡️ Recommendation: **A, Use native duplicate-property handling**. It keeps native decoding and avoids a dependency solely for this guarantee; choose B if rejecting ambiguous producer input is worth that cost.

Original proposal covered: duplicate-property part of Q10. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q15** - **Which supplied representation determines capture order?**

One attachment offers URL U and text containing a different URL V; a second attachment supplies W. All permitted distinct links are retained, exact duplicates collapse once, and the first supported Maps link becomes the temporary preview. Async callback order must never determine that first link. The choice is the stable order of representations within an attachment.

- **A. URL before text.** Order input items, attachments, typed URL, then detected links in text order. U precedes V even when the text callback finishes first.
- **B. Text before URL.** Keep sender/attachment order, but place text-detected links before the typed URL. V becomes the first candidate in this example.
- **C. Producer's advertised format priority.** Use the provider's stable representation preference while collecting both lanes. It may vary between sharing apps, but not by callback completion.

➡️ Recommendation: **A, URL before text**. It is a simple app-wide rule users and fixtures can predict across providers.

Original proposal covered: Q11. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q16** - **What initial capture resource profile should the prototype target?**

A typical Maps share is small, but one invocation can contain many attachments or a long note. We need exact temporary limits, not a limit on stored Planner content. The figures below are proposed acceptance/loading budgets, not Apple-prescribed limits or proof of safe peak allocation: native object loaders can materialize data before size checks. How much capture breadth should we initially support?

- **A. Balanced capture profile.** 32 providers, 1 MiB total decoded URL/text, 128 distinct web links, four concurrent provider loads and ten seconds overall. Broad ordinary capture with bounded accepted work.
- **B. Larger capture profile.** 64 providers, 8 MiB, 512 links, four concurrent loads and twenty seconds. Supports larger shares; increases memory/lifecycle proof requirements and waiting.
- **C. Small capture profile.** Eight providers, 256 KiB, 32 links, two concurrent loads and five seconds. Earlier failure and less accepted work, but more otherwise-valid large shares need splitting.

➡️ Recommendation: **A, Balanced capture profile**. It is a reasonable starting workload for ordinary link/text capture; physical extension evidence must verify it.

Original proposal covered: resource-budget part of Q12. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q17** - **What may be saved when a supported input fails or exceeds the budget?**

The URL lane loaded, but a text lane timed out and may contain additional notes or links. Alternatively, one supported attachment exceeds the chosen resource budget. No Item is saved yet. Unsupported attachments are already reported under C9; failed Maps enrichment already permits partial save under C11. This question concerns intended capture inputs we could not fully retain.

- **A. Block Add until retry or explicit removal.** Keep the review and identify the failed/oversized input. The user retries or removes that input before Add, preserving a deliberate final input set.
- **B. Offer Save available inputs.** Show exactly which inputs are omitted and require an explicit omission confirmation. The user can finish faster with the loaded content.
- **C. Reject the whole capture invocation.** Do not permit dropping individual intended inputs. Cancel or retry the entire invocation; strongest all-input rule, least flexible recovery.

➡️ Recommendation: **A, Block Add until retry or explicit removal**. It avoids a silently incomplete capture while keeping a useful, editable recovery path.

Original proposal covered: failure-policy part of Q12. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q18** - **What should happen to an HTTP Maps bookmark during lookup?**

A captured original is an HTTP Apple/Google Maps URL. Original HTTP(S) bookmarks are retained. Ordinary website content is not fetched, and lookup stays on the proposed documented provider allowlist: maps.apple.com, maps.apple short-link hosts, maps.app.goo.gl, maps.google.com and `www.google.com/maps/`. Every redirect is checked. What request-scheme policy should apply?

- **A. Lookup HTTPS originals only.** HTTP originals remain usable bookmarks but receive no network lookup. HTTPS originals may resolve on allowed hosts; unsupported redirects keep partial capture.
- **B. Upgrade known HTTP provider requests.** Preserve the HTTP original, but form an HTTPS request for a recognized provider host/path. More legacy links can resolve; upgrade compatibility must be tested.
- **C. Allow provider HTTP and HTTPS.** Request supported HTTP originals and permitted HTTP redirects too. Broader legacy behavior, but HTTP request data lacks HTTPS transport protection.

➡️ Recommendation: **A, Lookup HTTPS originals only**. It is the simplest request policy with a truthful retained-bookmark fallback.

Original proposal covered: scheme/host-policy part of Q13. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q19** - **How long may one Maps preview lookup try?**

Review is editable while a selected Maps link resolves. Add never waits, lookup failure preserves the accepted partial bookmark, and Retry is explicit. Each redirect/request consumes the attempt's total budget; URLSession's request timeout alone is not an overall deadline. Which user-visible waiting and redirect budget should be proved?

- **A. Balanced lookup.** Eight seconds overall, four seconds per request, five redirects/six requests maximum. One selected-link attempt at a time.
- **B. Quick fallback.** Three seconds overall, two seconds per request, two redirects/three requests. Faster unavailable-preview feedback, with more slow valid links left unresolved.
- **C. Patient lookup.** Twenty seconds overall, eight seconds per request, eight redirects/nine requests. More opportunity for slow redirect chains, but a longer preview wait.

➡️ Recommendation: **A, Balanced lookup**. It gives a bounded best-effort attempt without making capture depend on network enrichment.

Original proposal covered: lookup-budget part of Q13. Status: accepted A, with appropriate loading feedback, 2026-10-08.

---

❓ **Revised Contract Q20** - **Which AI client surfaces are first-class proof targets?**

Research found documented local HTTP candidates but no successful Planner connection yet. Codex CLI success does not prove Codex desktop, and Claude Code CLI success does not prove Claude Desktop. Claude Desktop's Code tab has a documented local route; its Chat surface has no established direct local HTTP route and may need a bridge. Which workflow matters enough to be a prototype gate?

- **A. Four documented local routes.** Prove Codex CLI, local Codex desktop, Claude Code CLI and Claude Desktop's local Code tab separately. Wider supported use, four client qualification paths.
- **B. Both CLI clients first.** Prove Codex CLI and Claude Code CLI. Smaller initial gate; desktop surfaces remain unqualified until separately demonstrated.
- **C. Prioritize desktop Chat workflows.** Prioritize Codex desktop and Claude Desktop Chat. Claude Chat may require new compatibility research and an explicitly accepted local bridge.

➡️ Recommendation: **A, Four documented local routes**. It supports both vendors' documented local CLI/desktop routes without assuming the uncertain Chat bridge.

Original proposal covered: client-selection part of Q14. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q21** - **How many simultaneous MCP clients should be supported initially?**

Codex and Claude may both connect to one enabled Agent Control session and edit the same dataset. They must share Core rules and operation identity handling, without mixing client transport state. Sequential client demonstrations cannot prove concurrent behavior. This decision is independent of which client surfaces Q20 selects.

- **A. Support two simultaneous clients.** Prove two initialized client sessions, concurrent reads/writes and isolated transport state. A third is refused clearly until support is expanded.
- **B. Support one client at a time.** Reject a second initialized client while the first is active. Simplifies the initial gate but requires disconnecting to switch agents.
- **C. Support four simultaneous clients.** Qualify four concurrent client sessions and their resource limits. More flexibility, with additional load, shutdown and isolation checks.

➡️ Recommendation: **A, Support two simultaneous clients**. It covers using both vendors together without an unbounded first session workload.

Original proposal covered: concurrency part of Q14. Status: accepted A, 2026-10-08.

---

❓ **Revised Contract Q22** - **Should the MCP endpoint keep the same local port?**

Each enablement uses a fresh credential. A changed port also changes the client URL, which can require reload/restart; an unchanged URL does not guarantee renewed credentials reconnect automatically. Loopback-only and no listener while Off are settled. We still need occupied-port behavior. Credential handoff will follow the selected clients and address policy.

- **A. Stable configurable port.** Start with 127.0.0.1:51761/mcp. If occupied, fail clearly and offer an explicit port change. Ordinary re-enablement keeps the same URL.
- **B. OS-assigned port each enablement.** Avoid requiring one preferred port, but present new connection information and potentially reload client configuration for every session.
- **C. Preferred port with visible fallback.** Try the stable port, then choose a free port when occupied and prominently report the new address. More automatic recovery, less predictable URLs.

➡️ Recommendation: **A, Stable configurable port**. It reduces routine URL churn and makes collisions explicit rather than silently changing the connection.

Original proposal covered: address part of Q15. Status: accepted A, with default port 44444, 2026-10-08.

---

The following Q23-Q26 cards preserve the historical proposals and original answers. Their timer/expiry language is superseded by the accepted no-automatic-expiry amendment above.

❓ **Revised Contract Q23** - **What should the default absolute session duration be?**

Agent Control shows a countdown and can offer the brief's 15, 30 and 60-minute choices. It must not renew itself automatically. An absolute expiry still stops access even if a client repeatedly sends valid requests. Idle expiry, lock/sleep and window closure are separate decisions. Which duration should be selected by default?

- **A. Thirty minutes.** A moderate working session with occasional explicit extension. Fifteen and sixty minutes remain selectable.
- **B. Fifteen minutes.** Shorter exposure and earlier expiry, but more re-enablement during longer work.
- **C. Sixty minutes.** Fewer interruptions for long work, with authorized access lasting longer when the session remains active.

➡️ Recommendation: **A, Thirty minutes**. It fits a deliberate temporary working session while leaving shorter/longer choices visible.

Original proposal covered: absolute-duration part of Q16. Status: originally accepted C, then superseded on 2026-10-08 by the human amendment removing all automatic access expiry. Historical question; no duration choice remains required.

---

❓ **Revised Contract Q24** - **How quickly should an idle session stop?**

The brief requires an inactivity timeout in addition to manual Stop and the absolute countdown. I propose resetting idle time only on successful authorized tool calls; protocol pings and rejected requests do not keep access alive. An active client may still hit absolute expiry. Which idle interval should be used initially?

- **A. Ten minutes idle.** Allows a normal pause for reading/review, then stops unused access.
- **B. Five minutes idle.** Stops unused access sooner, with more reconnects after short breaks.
- **C. Twenty minutes idle.** Accommodates longer pauses, while unused access remains available longer until idle or absolute expiry.

➡️ Recommendation: **A, Ten minutes idle**. It balances temporary access with ordinary pauses; exact timer/reset boundaries remain test obligations.

Original proposal covered: inactivity part of Q16. Status: originally accepted A, then superseded on 2026-10-08 by the human amendment removing all automatic access expiry. Historical question; no idle interval remains required.

---

❓ **Revised Contract Q25** - **Should lock or sleep revoke an unexpired session?**

An agent is connected, then you lock the Mac or it actually enters system sleep. App quit must stop the listener. Apple documents system-sleep/wake hooks, but session-switch notifications do not establish detection of every screen lock; closing the lid can also leave a Mac awake with external displays. If access survives sleep, elapsed absolute/idle deadlines must be checked before requests resume. Which product rule should be required, given that universal lock detection still needs supported-API proof?

- **A. Stop on both lock and sleep.** Revoke credentials and require fresh enablement after unlock/wake. Every-lock detection is an explicit prototype gate using supported APIs; if it cannot be proved, this policy must be revisited before it can be advertised.
- **B. Keep through lock; stop on sleep.** A locked Mac can retain its unexpired session. Sleeping still revokes access and requires new enablement.
- **C. Keep through both while unexpired.** Resume only if the original deadlines still permit it. Convenient for long jobs, with access retained across these transitions.

➡️ Recommendation: **A, Stop on both lock and sleep**. It makes unattended access a deliberate new session, conditional on proving the lock guarantee rather than substituting display sleep or app deactivation.

Original proposal covered: lock/sleep part of Q16. Status: accepted C, 2026-10-08; later amended to retain enablement without the historical expiry/deadline qualifiers.

---

❓ **Revised Contract Q26** - **What should closing Planner's last window do?**

Closing the last Mac window can leave the app process running. If Agent Control continues, active access still needs a visible native indicator and Stop control. App quit always stops it. This is independent of lock/sleep and timeout choices. How should normal last-window closure behave during an active session?

- **A. Stop access with the last window.** Close the window and stop Agent Control. Simple visible ownership, but closing the UI interrupts the agent session.
- **B. Continue with a menu-bar indicator.** Keep unexpired access running and show session state/Stop in a native menu-bar item. Supports background work and adds a UI/lifecycle proof requirement.
- **C. Ask whether to keep access.** At last-window closure, offer Stop and close, Keep access and close, or Cancel. More deliberate choice, with a prompt during closure.

➡️ Recommendation: **A, Stop access with the last window**. It keeps the first session lifecycle easy to see and reason about.

Original proposal covered: window-close part of Q16. Status: accepted B, 2026-10-08; later amended to retain enablement without the historical expiry qualifier or countdown.

---

The documented Maps request-host candidate is exact maps.apple.com, exact maps.apple or a hostname ending at the DNS-label boundary .maps.apple, exact maps.app.goo.gl, exact maps.google.com, and exact `www.google.com` with path /maps/ or its descendants. Every redirect is checked. Legacy goo.gl/maps and suffix-spoofed hosts do not gain automatic request authority. Lookup consumes headers/redirects and does not parse page bodies or use a keyed Google service. The original string is retained separately from any request form.

## Required /tdd and other evidence

These are obligations and competing expected observations for later approved executable boundaries. Actual tests begin only after applicable public interfaces are accepted, one failing behavior and its minimum passing implementation at a time. Mock real I/O/module boundaries; use temporary real stores where persistence is the behavior.

| Boundary and level | Input and exact observation to establish |
| --- | --- |
| Completion unit, store/reopen and adapter equivalence | Use full UUID fixture above. Initial 0/3, first appearance Done 1/3, global Hotel Done 2/3, global Reopen 1/3; no Museum archive/global change. Equivalent authorized native/Intent/MCP requests have these same effects. |
| Full-context bulk unit, real-store and native confirmation | Tokyo Food contains active Hotel and archived Museum, with UI showing only Hotel. Mark All Done sets both local flags; progress 2/2. Global flags remain Todo. Mark All Undone yields 0/2 unless a source is globally Done. Changed targets reject stale review. True save failure changes neither child; postcommit recovery failure retains both applied flags and blocks further domain mutation. |
| Reference unit, store and physical convergence | Removing membership 401 preserves Hotel 101, Trip Prep membership 403 and Schedule 601. Ordinary re-add gets a new membership local Todo. Reordering itinerary 501/502/503 retains identities/flags. Identical operation replay creates no second entry; a new intentional Hotel-add operation creates a separate appearance. Use accepted duplicate, deletion and restoration-family device fixtures from the packet. |
| Query unit/store/UI | All four global completion/archive pairs, generic no-location Item, all accepted search sequences, past direct/indirect schedules and unschedule identity sets. Keep valid filtered-out detail; removed appearance returns missing reference. A stale row-window generation does not mix snapshots. Search quality dataset remains 5,000 Items/200 Lists and 300 ms on each device, not a count cap. |
| Partial edit and stale unit/store | Q9/Q10/Q27 require rejection retaining Friday booking when the returned notes hash no longer matches, acceptance after title-only change, and rejection of required-title null or missing required field hash. Missing fields retain their values. A notes-only patch retains title/estimate, memberships, archive/global/local values. Compare under the writer gate; stable field hashing across processes and absent/Unicode/collection/native-value fixtures require final schema proof. |
| Wire value unit and actual round-trip | Q11/Q12 fix canonical Int64 strings and finite numeric native Date values. Required tests include Int64 max 9223372036854775807, rank min -9223372036854775808, overflow 9223372036854775808, fraction 1.0000000000000001, exponent and leading-zero strings, finite submillisecond native Date and distant finite dates, UUID case variants, malformed IDs, invalid civil dates and non-finite coordinates. Do not impose a new practical domain range. |
| JSON version/structure unit | Q13 rejects unknown supported-version backup fields; Q14 uses native repeated-property handling without a rejection guarantee. Unsupported version, malformed input, duplicate record IDs and unresolved references reject the whole backup with zero mutation. Assert useful unknown-property errors. For repeated properties, assert one immutable decoded proposal reaches preview/apply; do not assert an undocumented first/last winner. No shortened successful export of an unresolved native graph. |
| Import unit/store/native preview | Accepted Skip keeps matching whole owners; Overwrite replaces represented whole owners after review; omission from file preserves sources. Current A=[X] with local Done plus incoming A=[X,Z] produces A unchanged and new Z in Skip. Invalid backup rejects together. Incoming deleted markers, restoring IDs, conflict-dependent skipped owners and independent records follow the architecture's exact accepted examples. |
| Authority unit and real MCP server | Forbidden source/label Delete and any unauthorized indirect apply reject before mutation, including the case where X is absent at preview but its obsolete lifetime may arrive later. Disabled/revoked access fails. Ordinary authorized reference removal preserves protected sources. Q1-Q8/Q5 require separately described completion scopes, agent-applied exact capture/bulk review and native-only backup administration/export. No backup or admin command is registered in MCP/Intents, and indirect forbidden commands reject with zero mutation. |
| Receipt/recovery integration and host-closed Share | Same operation/payload creates one result. Changed-payload replay rejects only that attempt. Failure before commit leaves action unapplied; failure after commit retains complete Item/memberships, reports recovery incomplete, blocks dataset writes and retries copy only. Kill at every approved prepare/commit/copy/receipt checkpoint and query actual surviving evidence; prepared-only stays unverified. |
| Scheduling unit/store/native picker/device | Inclusive Friday-Sunday dates, fixed Tokyo 10:00-11:00 to Paris 03:00-04:00 display, valid start-only, strictly-later end, spring gap rejection, earlier/later repeated occurrence and coupled DST endpoints. Planning-zone-only edit preserves both instants. Every accepted Q5-Q14 fixture remains required; no EventKit check substitutes. |
| Capture loader/parser unit, real store and physical payload | Reverse loader completion and retain U then V; Unicode/prose/link retention exactly matches C8-C10. Typed URL-object spelling is distinguished from original text. Unsupported/file-only, conflicting parameters, missing own coordinate and finite bounds follow accepted C9/C13. Q15-Q17 require typed URL first within attachment order; test just below/at/above each accepted budget, reverse callback completion, four-loader maximum and ten-second total deadline. Failed supported inputs block Add until retry or explicit removal. Never silently omit a supported lane. |
| Capture transport unit and actual extension lifecycle | Q18/Q19 require HTTPS originals only, eight-second total/four-second request budgets, five redirects/six requests, with visible pending-preview feedback. Test exact hosts versus suffix spoofs, HTTP-original behavior selected in Q18, disallowed hop, loops, missing Location, each boundary and deadline, obsolete callbacks after input edit/Add/Cancel, partial Save without lookup, no ordinary-page body fetch and no automatic preview retry. Native allocations and extension lifecycle must be measured; post-load byte checks are insufficient proof. |
| Export/recovery account integration/physical | Complete active backup retains IDs/manual order/schedules/minimal lineage and excludes app state/credentials/cache/receipts. Inspect/export old recovery does not mutate or upload into current account. Explicit empty-dataset restoration reproduces accepted data; coherent ownership cutoff preserves good independent copy under resets. Q4/Q5 keep backup/export/recovery administration native-only; verify no equivalent public MCP/Intent path. |
| App Intents native and adapter parity | Q6/Q7 allow ordinary locked-device Intents where Apple permits, while bulk uses system confirmation. Execute locked/unlocked/system-restricted/canceled cases, unsupported/removed IDs and archived hidden bulk children. No ambiguous completion fallback. Capture native review cancellation creates zero Items. |
| Selected-client and native MCP integration | Q20-Q26 require four separately demonstrated clients, two-client qualification and accepted Q30 C without an extra app-imposed client/request cap, occupied 44444 failure, fresh credentials on enablement and no listener while Off. No maximum duration or idle expiry. Long idle periods and lock/sleep retain enabled access; wake resumes requests while Planner remains running. Last-window closure retains menu-bar status/Stop; app quit ends access. Test before/after-commit cancellation status. Accepted Q32 A uses authenticated SDK ping and unchanged-window metadata before same-app reader output; prove denied/locked Keychain, stale metadata, wrong response/window, Stop/quit races and absence of GUI/startup/domain writes. No secrets in ordinary logs/configuration. CLI success cannot stand in for desktop proof. |
| Native lifecycle and menu-bar proof | Enable at 09:00. With no intervening tool calls, an authorized read at 12:00 still succeeds. Sleep at 12:05 and wake at 13:15: access remains On and an authorized read succeeds while Planner remains running. Locked requests retain normal authority. Closing the last window keeps menu-bar On/Stop without a countdown. Stop removes the listener; re-enable uses a fresh credential and rejects the previous one. Quit/forced termination removes the listener; relaunch starts Off and the reader returns unavailable. Cover elapsed-time policy through public-boundary unit fixtures and actual sleep/window/quit behavior through native integration. These are future observations, not executed tests. |

Accepted Q29 A requires supported official-SDK protocol negotiation and authenticated calls without a required protocol session ID. Test repeat initialization by one client, initialization by a second independent client, disconnect/reconnect and isolated per-caller version/capability context. Lenient direct legacy calls, if used, cannot be reported as full modern compliance. Record the exact official package pin, dependency resolution and shipped fix or qualified native integration used. The inspected 0.12.1 defects are not assumed resolved. Unsupported versions return useful failure, never an accidental successful downgrade. Request cancellation still preserves an already committed operation and its receipt. These are future evidence gates, not passing tests.

Accepted Q30 C requires two selected clients concurrently, additional callers without a registration refusal, concurrent native access, truthful cancellation/replay and measured memory/latency under increasing load. Two concurrent independent HTTP requests using JSON-RPC ID 7 must each receive their own requested Item exactly once, with no exchanged, overwritten or unresolved response. Also distinguish integer 1 from string "1". Protocol request IDs do not replace the Core operation identity. Use SDK/OS handling and the approved Core writer coordination. Do not add an initial custom client or two-call cap. Record actual saturation behavior and fixture outcomes; measured stability failures can justify a later explicit limit amendment. No unlimited-throughput claim is made.

## Accepted complete contract packet

The [adapter contract](adapter-contract.md) and [portable data/native recovery contract](portable-data-contract.md) now declare the remaining request/result/status, full data-only backup and native administration forms. They use the approved facade and accepted Q1-Q30/Q32 behavior; Q31 does not reopen Q27. Exact future inputs are linked from each packet, including 24 adapter cases, 13 import/delete cases, six concrete lineage cases, seven recovery-evidence cases and independent Schedule/payload fingerprint bytes.

Before review, the starting state was accepted behavior with incomplete adapter/portable encodings. After acceptance, those declarations can be used at the existing public seams for prototype /tdd. The initial App Intent catalog keeps permanent source/label Delete in native Planner; this catalog detail is included in this review rather than attributed to a nonexistent blanket human decision. Runtime compilation, stores, migration, physical-device sync/Share and all-four-client qualification remain the prototypes' gates.

Accepted Contract Q33 A on 2026-10-09. The human approved the complete packet for prototype work. This accepts the concrete declarations and initial integration catalog, with unchanged A21/A22 and Q1-Q30/Q32 behavior carried forward. Runtime compilation, stores, migration, native UI, physical-device sync/Share and real-client qualification remain required prototype evidence. No hash-policy, timeout, client-capacity or credential-reader choice is reopened.

[Published contract resolution](https://github.com/dvcol/planner/issues/13#issuecomment-6070841289) records acceptance and delegates executed proof to the owning prototypes.

Navigation prototype later accepts Q43 A, Q44 A, Q45 A and Q46 A. The [row contract amendment](navigation-row-contract-review.md) extends the existing public lightweight read, binds row time/zone to its query generation, fixes the globally Done contextual affordance and selects one actual Schedule and website preview link. The [adapter declaration](adapter-contract.md#row-presentation-context-and-schedule-summary) and Core packet reflect this additive read amendment. The literal row scenarios assign subsequent unit/store/provider-I/O/native UI obligations; no new runtime proof, editable content or backup fields are introduced.

## Definition of done

- [x] Human accepts the final command/query schemas, wire validation and integration authority under Q33 A.
- [x] Representative complete JSON/typed Swift requests and results include exact UUIDs, error and retained-state expectations.
- [x] No adapter duplicates Core rules or obtains forbidden authority through alternate commands.
- [x] Accepted grammar/resource/access choices have executable-boundary fields and exact future unit/store/UI/device/client obligations.
- [x] Document checks pass; publish/read back committed source and progress/resolution evidence.
- [x] Close only after this decision's applicable human/evidence criteria pass, then append its named resolution pointer to the map. Runtime checks remain owned by the prototypes.
