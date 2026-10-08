# Shared command contracts

In-progress review for [Shared command contracts](https://github.com/dvcol/planner/issues/13), claimed on 2026-10-08. The [approved Core architecture](core-architecture.md) and [A21/A22 packet](architecture-review-packet.md) are the baseline. Contract Q1-Q16 below are proposals awaiting the human. No contract question has been accepted, no Swift declarations compiled and no unit, store, UI, device or client test executed here.

## Context

The native app, Share extensions, App Intents and temporary macOS MCP adapter must call one PlannerCore implementation. Release stages V0-V2 establish ordinary planning, capture and portable backups. V3 adds the system and agent integrations. Different integrations may have different authority; they must retain the same domain meanings for the operations they can invoke.

An MCP tool annotation or a Core review token does not grant permission. Validation of the decoded command, resulting impact and authorized dataset happens before mutation. An import can apply deletion metadata even when its target is absent locally, so hiding a Delete tool is insufficient.

## Starting state

[Core architecture is resolved](https://github.com/dvcol/planner/issues/12#issuecomment-6057782494). The approved facade, typed source/appearance identities, field changes, review/result/status shapes, native validation and save/recovery sequence carry forward. Their approval must not be requested again for unchanged behavior.

[Local MCP compatibility](https://github.com/dvcol/planner/issues/6) establishes documented candidates and limits, with [committed research](https://github.com/dvcol/planner/blob/research/local-mcp-compatibility/docs/research/local-mcp-compatibility.md). No successful client connection or minimum supported client version is proved. Permissions, selected clients, handoff and lifecycle remain choices here.

The original ticket mentions earlier keep-current imports and wholly unapplied failures. The accepted architecture amendments govern the final contract: default whole-record Skip, reviewed Overwrite, data-only backups including minimal deletion lineage, and the A15 distinction between true precommit failure and a fully applied action with incomplete recovery. Q12/Q14 require independent itinerary appearances and appearance-count progress. These are carried-forward resolutions, not new questions.

## Goal and expected end

Agree exact command/query transport forms, integration authority, stale-edit handling, JSON grammar and capture resource limits. Produce representative MCP JSON and corresponding typed Swift requests using the approved facade. Record independently specified state/error observations and the unit, real-store, native UI, physical-device and client evidence each prototype must supply.

Resolution requires human answers and concrete follow-up field schemas. This draft has not reached that end state. Questions dependent on an answer, such as the precise stale-edit token or a duplicate-property rejection capability, wait for the next frontier.

## Definition of ready

- [x] Read the approved architecture and domain resolutions, release journeys and local MCP compatibility research.
- [x] Inventory the release journeys and required command/query families below.
- [x] Prepare valid UUID fixtures, retained reference graphs and explicit competing stale-edit results.
- [ ] Accept this frontier's remaining behavior, authority and wire choices.
- [ ] Specify and accept changed or newly concrete request fields after their prerequisite answers. Unchanged A21/A22 public approval carries forward before /tdd.

## Release journeys and shared operations

| Journey and before state | Commands/queries and required end | Integration/evidence owner |
| --- | --- | --- |
| V0, empty offline planner | Create Book train tickets, read/search, edit its notes, relaunch with the same identity and content. No cloud account is needed to save. | Native app; Navigation and Sync and share prototypes prove their applicable paths. |
| V0, Hotel in two Lists | Add/remove/move memberships, explicit global/contextual completion, archive/unarchive. Removing one membership preserves Hotel and the other membership. | Core semantics approved. Exact authorized adapter operations are finalized here. |
| V1, generic Item without location | Read/search/filter/sort works without map coordinates; completion and archive remain independent. | Approved search fixtures plus public-query/store/UI checks. |
| V1, shared labels | Create/edit references by UUID; rename updates all uses; duplicate names remain distinct. Referenced label Delete is native-confirmed and preserves its owners. | Native UI and authorized label-edit adapters share Core. |
| V2, mixed URL/text capture | Decode supported inputs into one review, optionally look up the selected Maps link, then reviewed create/reuse. Cancel-before-Add creates nothing; saving includes selected memberships together. | Native app/Share; proposed integration profile is below. |
| V2, Hotel, Museum, Hotel itinerary | Add distinct live entries, reorder without resetting local flags, read appearance progress and schedule source references. Editing Hotel's source content updates both appearances. | Native app; Core, UI and device evidence. |
| V2, timed/all-day schedules | Create/edit/remove only the selected Schedule. All-day civil dates survive travel; zone-only edits preserve instants; no estimate fills an end. | Scheduling fixtures; no Calendar export/EventKit operations. |
| V2, portable data | Export full data-only backup; decode/review/apply Skip or Overwrite. Invalid backup rejects together; absent-file sources survive. | Native UI initially proposed; permission decision pending. |
| V2, known recovery incomplete | Read/search/export remain available. Retry only the known-applied checkpoint, then unblock domain changes. | Core result/status is approved; native and Share interruption proof. |
| V2, account changed | Inspect/export the old independent recovery namespace without changing the active dataset; explicit restore/merge is separately reviewed. | Native recovery initially proposed; coherent account cutoff is a hard device gate. |
| V3, Shortcuts action | Resolve stable IDs, invoke explicit scoped ordinary action, return the Core outcome. Confirm required bulk targets and route capture to Add/Cancel. | Intent profile pending; native intent behavior must be demonstrated. |
| V3, Agent Control Off/On | No listener while Off. Enabled authorized client performs permitted operations; stop/expiry revokes access and operation status remains truthful. | Selected-client/session profile pending; MCP session prototype proves it. |

## Command and authority inventory

Command names below identify proposed adapter operations within the approved Core families. They do not replace the approved facade with another domain service. Final JSON/Swift constructor declarations depend on the accepted wire/authority answers.

| Family | Identity and action | Carried-forward invariant or pending boundary |
| --- | --- | --- |
| Create/edit Item, List, Itinerary | Planner-generated source identity on create; explicit source UUID and changed fields on edit. | Item content/label associations are separate from completion/archive. A6 own-Item timestamps have no contextual or label-rename fan-out. Partial/stale wire rules are pending. |
| Set Item completion | Item UUID plus Done/Todo. | Global Done overrides every appearance's display, retaining local flags; global Reopen reveals those flags. Integration availability is Contract Q1. |
| Set appearance completion | Exact typed List membership, direct itinerary entry or expanded List-child appearance plus Done/Todo. | A source UUID cannot substitute for an appearance; missing/removed appearances do not retarget globally. |
| Set full-context completion | List, Itinerary or itinerary List-entry scope plus Done/Todo and Core-issued exact-target review. | Hidden/archived appearances included once each; global flags untouched. Empty remains No items. MCP authority to apply a review is Contract Q2. |
| Archive/unarchive | Item/List/Itinerary source UUID plus independent archive state. | Container-only effects; shared source content and global/local completion retained. |
| Organize | Source/destination and association/entry identity, placement and operation identity. | Brief already includes remove-from-list and unschedule. Planning-reference removal retains shared source Items/Lists. Standalone membership uniqueness and intentional itinerary repeats differ. |
| Schedule | Item/Itinerary source and selected Schedule identity with typed timed/all-day values. | Removing one Schedule preserves source/other Schedules. These ordinary planning edits must not authorize source/label Delete. |
| Create/edit labels | Category/Tag UUID and own name/metadata; owner association edits retain label identity. | Same-name labels allowed; shared edits live everywhere. Permanent label Delete remains a separate authority/confirmation path. |
| Permanent Delete | Source/label identity plus bound impact review. | Default MCP cannot invoke it directly or indirectly. Native confirmation lists affected references; container sources remain. |
| Capture create/reuse | Reviewed draft/origins, original links, selected List IDs, chosen create/reuse and operation identity. | Provider preview stays unsaved. Reuse retains existing fields/state and adds reviewed missing links/memberships. Native Add/Cancel and C16 in-flight rules retained. |
| Backup apply/recovery restore | Validated immutable backup, Skip/Overwrite and exact impact review. | Incoming deletion/lifetime effects require authority even for absent local targets. Surface availability is Contract Q3. |
| Read/export/recovery status | Current authorized dataset or separately authorized recovery namespace. | Read failure is not empty data; portable backup excludes credentials, internal receipts and presentation state. Access is Contract Q4. |

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

For stale-edit discussion, read Original notes, then locally save Friday booking, then submit Monday booking based on the old read. Contract Q7 chooses either rejection with Friday booking retained or acceptance of Monday booking. Title-only changes are not notes-field conflicts in the recommended policy. This is a competing observation, not a test or new public token declaration approved in advance.

## Wire and outcome proposals

Core-issued dataset ownership and epoch values remain opaque. A MCP client cannot choose an account by supplying JSON ownership fields. The adapter binds the request to its authorized active session and calls the same Planner facade. Read/review/operation values remain immutable and dataset-bound.

Proposed partial-edit JSON has an operationId, selected Item UUID and a changes object containing only edited fields. A notes-only value sets notes, a null clears it and absent fields stay unchanged if Contract Q8 is accepted. The corresponding typed request uses the approved PlannerFieldChange set/clear/unchanged cases and PlannerOperation passed to Planner.execute. The expected-read field/token is deliberately not invented before Contract Q7 is answered.

Proposed completion wire distinguishes set_item_completion with itemId from set_appearance_completion with a typed appearance object. For the first Hotel itinerary appearance, its object contains kind directItineraryItem, itineraryId 301 and entryId 501 using their full UUID strings. Expanded List children additionally require listEntryId and membershipId. Their typed equivalents are PlannerCompletionScope.globalItem or .appearance with the corresponding approved PlannerAppearanceID case. A request missing its required scope/identity is rejected without guessing.

Proposed stable attempt failure categories include invalidInput, unsupportedVersion, invalidBackup, notFound, staleEdit, staleReview, staleDatasetSession, permissionDenied, recoveryBlocked, operationPayloadMismatch and unavailable. These map to the approved rejected/applied/unverified results. They are not a replacement for structured result evidence. Final category fields and wire spelling require the accepted schema follow-up.

An applied result with recovery incomplete is a complete applied domain action and cannot be represented as an ordinary failed/unapplied tool call. A later rejected replay is an attempt failure and cannot replace the recorded successful original status. Missing evidence means noReliableEvidence or preparedUnverified, never automatic rollback. Cancellation after commit retains applied state; status/readback resolves response loss. These meanings are already approved in A21/A22.

## Verified platform facts

Read-only facts checked against installed OS 27 declarations and primary sources. These do not establish the shipped implementation's runtime results.

| Fact | Contract implication |
| --- | --- |
| Native [Int64 JSON decoding](https://github.com/swiftlang/swift-foundation/blob/2df17f28d6cd4aa0cf27cc66598fcabbcde8292c/Sources/FoundationEssentials/JSON/JSONDecoder.swift#L1112) can accept integral decimal/exponent forms and a rounded tiny fractional value; [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259#section-6) describes binary64 interoperability limits. | Canonical decimal strings plus native checked conversion avoid a JavaScript precision cap and strict-lexeme ambiguity. Policy remains Contract Q9. |
| Native [Date Codable](https://github.com/swiftlang/swift-foundation/blob/2df17f28d6cd4aa0cf27cc66598fcabbcde8292c/Sources/FoundationEssentials/Date.swift#L346) uses Double seconds since 2001-01-01 UTC; inspected [ISO8601 fractional formatting](https://github.com/swiftlang/swift-foundation/blob/2df17f28d6cd4aa0cf27cc66598fcabbcde8292c/Sources/FoundationEssentials/Formatting/Date%2BISO8601FormatStyle.swift#L354) rounds to milliseconds. | Full backup cannot claim arbitrary Date fidelity from ordinary ISO formatting. Lossless finite native round-trip remains a focused runtime gate. |
| [decodeIfPresent](https://developer.apple.com/documentation/swift/keyeddecodingcontainer/decodeifpresent(_:forkey:)-w7f) conflates missing/null; contains plus decodeNil can distinguish them. Native UUID Codable uses UUID string conversion. | Patch semantics can use native Codable. Producers use canonical hyphenated UUID output; accepted case variants do not create new identities. |
| Ordinary Foundation keyed decoding collapses repeated property names before allKeys; [RFC 8259 object names](https://www.rfc-editor.org/rfc/rfc8259#section-4) should be unique. | Repeated JSON properties differ from duplicate entity UUIDs. Native handling versus guaranteed rejection is an explicit open guarantee. |
| [NSItemProvider](https://developer.apple.com/documentation/foundation/nsitemprovider) typed loadObject supports NSURL, NSString and MKMapItem in installed SDK 27; callbacks are asynchronous and return Progress. | Collect supported typed lanes with fixed positions. Do not infer content authorship from loader class or callback order. File URLs are excluded; unsupported formats reported. No arbitrary binary-data fallback is proposed. |
| [Plain text](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/plaintext) has unspecified encoding; native object loading materializes a result before a size check. | NSString avoids an assumed UTF-8 byte decode. A post-load acceptance bound is not proof of bounded peak memory. |
| [Unified Maps URLs](https://developer.apple.com/documentation/mapkit/unified-map-urls) documents Apple place/viewport distinctions and shortened maps.apple-host URLs resolved from redirects. [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started) defines no-key map URLs. | Retain original bookmarks. Preview interpretation follows documented parameters; no opaque path decoding or promotion of provider descriptions to own content. |
| The [Google resolution API](https://developers.google.com/maps/ai/grounding-lite/resolution-api) needs billing-enabled setup and credentials. | It cannot be the approved no-key baseline. Unknown/legacy links can remain bookmarks without promised lookup. |
| [URLSession request timeout](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/timeoutintervalforrequest) resets when data arrives; a non-background [redirect delegate](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/urlsession(_:task:willperformhttpredirection:newrequest:completionhandler:)) can inspect/refuse each redirect. | A whole-preview deadline is separate. Use headers/redirect inspection and cancellation rather than body-fetch convenience methods; HEAD success is not assumed. |
| [MCP tool annotations](https://modelcontextprotocol.io/specification/2025-11-25/schema#toolannotations) are hints; [structured tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools) may return domain evidence. | Enforce authority in command admission/impact, with unambiguous applied/recovery status. |
| [Intent authentication policy](https://developer.apple.com/documentation/AppIntents/IntentAuthenticationPolicy) and confirmation are separate mechanisms; custom intents can default to alwaysAllowed. | Choose authentication explicitly rather than treating invocation or confirmed true as independent human approval. |

Guaranteed duplicate-property rejection is feasible through the established C library [Jansson's JSON_REJECT_DUPLICATES](https://jansson.readthedocs.io/en/latest/apiref.html#decoding). Its [current releases](https://github.com/akheron/jansson/releases) and [source/tests](https://github.com/akheron/jansson) show maintenance. It is not a verified drop-in Swift package; native platform integration and grammar compatibility would need proof if selected. No dependency has been added. Contract Q10 chooses the required guarantee before capability selection.

## First contract frontier

The human may accept the recommendations together or refine individual questions. These choices are unaccepted until a reply arrives. No dependent next round will be asked while these answers are pending.

### Contract Q1: Completion available to integrations

Hotel appears twice in one itinerary. Completing one appearance changes only that appearance; completing the source Item makes both appear Done through the approved global precedence rule. I recommend exposing both operations to MCP and App Intents with explicit names and IDs: Set Item completion and Set appearance completion. An ambiguous request must ask for its scope rather than choosing silently. List/Itinerary UI actions remain local. Should integrations expose both scopes?

Recommendation: Both explicitly named scopes. Alternative: Global Item completion only. Free-text refinements are welcome. Status: awaiting human answer.

### Contract Q2: Agent review and apply

An enabled MCP session reviews Mark all Done for List A, which contains visible Hotel and hidden archived Museum. The preview names both targets. Link capture likewise returns its reviewed create/reuse choice. I recommend allowing the authorized agent to apply that exact Core-issued preview without another native approval prompt. Changed payload, targets or dataset require fresh review; native app/Share capture still requires Add. Alternatively, every MCP capture/bulk apply can require native human approval. Which workflow do you want?

Recommendation: Agent may apply bound preview. Alternative: Native approval for each apply. Free-text refinements are welcome. Status: awaiting human answer.

### Contract Q3: Backup import and recovery authority

A backup can replace List A's contents, revive a deleted Item or carry a deletion marker that removes X now or suppresses an obsolete X arriving later. These effects can bypass a missing Delete tool. I recommend keeping JSON backup import, Overwrite, deleted-ID restoration and old-account recovery in native Planner initially. MCP/App Intents would expose ordinary authorized planning changes and reviewed link capture. Would you instead include backup apply under separately granted authority?

Recommendation: Native backup and recovery actions. Alternative: Add separately granted backup apply. Free-text refinements are welcome. Status: awaiting human answer.

### Contract Q4: Current backup export

MCP's default read permission already gives access to the active Planner dataset. I recommend allowing it to return that dataset's complete portable JSON backup, including accepted minimal deletion history, without writing arbitrary filesystem paths. Separate old-account recovery copies remain inspectable/exportable only through native Planner. This keeps current-data export usable while preserving the accepted account separation. Should current JSON export be part of default MCP read?

Recommendation: Allow active-dataset export. Alternative: Keep all backup export native. Free-text refinements are welcome. Status: awaiting human answer.

### Contract Q5: App Intents execution profile

Shortcuts may run without opening Planner, and Apple's default custom Intent policy can permit locked-device execution. I recommend explicitly requiring device authentication for Planner data intents. Ordinary read/create/edit, explicit completion, archive, organization and scheduling may then run directly. Full-context bulk asks confirmation naming hidden/archived targets; URL capture opens the native Add/Cancel review. Permanent Delete, backup import and account recovery stay native initially. Do you accept this Intent profile?

Recommendation: Authenticated ordinary intents. Alternative: Intents open Planner for changes. Free-text refinements are welcome. Status: awaiting human answer.

### Contract Q6: Stop or expiry during a write

You stop Agent Control while a write is admitted. I recommend immediately rejecting new work and attempting to cancel admitted work before commit. If commit has already occurred, retain the complete action, finish or retry independent recovery and report the actual operation status; a lost response never means rollback. A later authorized status query can resolve it when the dataset still matches. Alternatively, let every admitted operation finish even if it has not committed. Which rule should apply?

Recommendation: Attempt cancellation before commit. Alternative: Finish all admitted operations. Free-text refinements are welcome. Status: awaiting human answer.

### Contract Q7: Stale edits known on this device

A client reads Hotel's notes as Original notes. Another local change saves Friday booking. The client now submits Monday booking using its old read. I recommend rejecting this known stale notes edit and returning the current value for fresh review. A concurrent title change should not block a notes-only edit. This concerns locally observable stale reads; accepted offline CloudKit conflict rules still apply. Alternatively, accept the submitted notes as a new edit over the current value. Which policy do you prefer?

Recommendation: Reject changed edited fields. Alternative: Accept submitted field values. Free-text refinements are welcome. Status: awaiting human answer.

### Contract Q8: Partial edit JSON

Hotel currently has notes and a duration estimate. I recommend mapping an omitted JSON field to Unchanged, null to Clear for optional fields, and a supplied value to Set. Thus {"notes":null} clears only notes, while {} changes nothing. Clearing a required title or supplying an unknown edit property is rejected before mutation. Whole backup records are complete records, not these patches. Does this mapping fit your integrations?

Recommendation: Omitted unchanged; null clears. Alternative: Use explicit change objects. Free-text refinements are welcome. Status: awaiting human answer.

### Contract Q9: Lossless portable values

Swift's full Int64 range exceeds JavaScript's exact integer range, and ordinary ISO date formatting can discard timestamp precision. I recommend canonical decimal strings for full-range minutes/ranks and native Date's numeric seconds since 2001-01-01 UTC in backups. Civil dates stay separate year/month/day values. Human schedule requests use Gregorian components, zone and explicit repeated-time choice; display remains readable. UUIDs use native string handling. Alternatively, we can research a different lossless text encoding for timestamps. Which representation should we plan?

Recommendation: Lossless native backup values. Alternative: Research lossless timestamp text. Free-text refinements are welcome. Status: awaiting human answer.

### Contract Q10: Supported JSON grammar

I recommend strict supported-version checks and rejecting unknown properties, malformed values and duplicate record IDs before any mutation. One remaining tradeoff is repeated JSON property names, such as two title properties in one object. Apple's normal decoder can collapse them without exposing duplicates. My minimal native recommendation requires producers to emit unique property names but does not promise duplicate-property rejection; review/apply uses one decoded value consistently. Guaranteed rejection would require a separately verified parser capability. Which guarantee do you want?

Recommendation: Use native duplicate-property handling. Alternative: Require duplicate-property rejection. Free-text refinements are welcome. Status: awaiting human answer.

### Contract Q11: Stable capture input order

One Share provider supplies URL U and text-only URL V; another supplies W. Callback completion order must not decide the retained links or default Maps preview. I recommend input-item order, then attachment order, then typed URL before text, then link position within text. Collect URL and text independently, collapse exact original-string duplicates at their first position, and keep MKMapItem as temporary preview only. The approved content-origin rules still apply. Does that stable ordering fit?

Recommendation: Sender order; URL then text. Alternative: Sender order; text then URL. Free-text refinements are welcome. Status: awaiting human answer.

### Contract Q12: Capture loading budget

Share extensions are short-lived. I propose accepting at most 32 attachment providers, 1 MiB total decoded URL/text and 128 distinct web links per capture, loading at most four providers concurrently with a ten-second overall loading deadline. Over-limit or unfinished supported input is reported and blocks Add until retried or explicitly removed; never save a silently truncated draft. These are capture limits, not limits on stored Planner text or record counts, and size checks after native loading do not bound peak allocation. Are these initial prototype budgets acceptable?

Recommendation: Use proposed capture budgets. Alternative: Choose different capture budgets. Free-text refinements are welcome. Status: awaiting human answer.

### Contract Q13: Maps lookup hosts and deadline

The proposed allowlist is exact maps.apple.com, exact maps.apple, a host ending at a DNS-label boundary in .maps.apple, exact maps.app.goo.gl, exact maps.google.com, and exact `www.google.com` with path /maps/ or its descendants. Spoofed suffixes and legacy goo.gl/maps never gain request authority. Use one initial GET plus at most five redirect GETs, consume response/redirect headers and cancel on final response; no HEAD success is assumed. The request form is separate from the retained original string. Provider URL-construction constraints can reject lookup without discarding the bookmark.

I recommend retaining original HTTP(S) bookmarks but making lookup requests only over HTTPS. Permit maps.apple.com and documented maps.apple short-link hosts, plus maps.app.goo.gl, maps.google.com and `www.google.com/maps/`. Check every redirect; allow at most five hops, six requests, four seconds per request and eight seconds overall, with one selected-link lookup at a time. Unknown hosts, disallowed redirects or timeout keep partial capture; Add never waits. No page-body parsing or keyed Google service. Do you accept this lookup policy?

Recommendation: Use bounded HTTPS lookup. Alternative: Choose other hosts or budgets. Free-text refinements are welcome. Status: awaiting human answer.

### Contract Q14: AI client proof targets

The compatibility research found documented local HTTP candidates but has proved no connection yet. I recommend testing Codex CLI, Codex desktop running locally, Claude Code CLI and Claude Desktop's local Code tab, with two clients usable concurrently in one authorized session. Claude Desktop Chat does not have an established direct local HTTP route; including it may require an explicitly accepted bridge. Which client set should the prototype prove?

Recommendation: Four local CLI and desktop routes. Alternative: Codex and Claude Code CLI first. Free-text refinements are welcome. Status: awaiting human answer.

### Contract Q15: MCP address and credential handoff

A new port requires client configuration reload, and a new environment credential cannot update an already-running client. I recommend a stable configurable loopback address, initially `http://127.0.0.1:51761/mcp`, with clear failure if occupied. Each enablement gets a fresh credential and explicit protected client launch/handoff; no credential helper or automatic bridge initially. Re-enabling may require reconnecting or restarting the client. Alternatively, use an OS-assigned port and new connection information each session. Which handoff should we prove?

Recommendation: Stable address; explicit handoff. Alternative: New port for each session. Free-text refinements are welcome. Status: awaiting human answer.

### Contract Q16: Session time and lifecycle

I recommend a 30-minute default absolute session duration, selectable as 15, 30 or 60 minutes, plus a ten-minute inactivity timeout reset only by successful authorized tool calls. Protocol pings do not keep access alive. Stop on Mac lock, sleep, app quit or closing the last Planner window; wake/reopen requires new enablement. Explicit extension from native Agent Control is allowed before expiry, without automatic renewal. Do you accept this session profile, or prefer keeping an unexpired session through lock/sleep/window closure?

Recommendation: Use timers and stop on transitions. Alternative: Keep unexpired session on transitions. Free-text refinements are welcome. Status: awaiting human answer.

## Required /tdd and other evidence

These are obligations and competing expected observations for later approved executable boundaries. Actual tests begin only after applicable public interfaces are accepted, one failing behavior and its minimum passing implementation at a time. Mock real I/O/module boundaries; use temporary real stores where persistence is the behavior.

| Boundary and level | Input and exact observation to establish |
| --- | --- |
| Completion unit, store/reopen and adapter equivalence | Use full UUID fixture above. Initial 0/3, first appearance Done 1/3, global Hotel Done 2/3, global Reopen 1/3; no Museum archive/global change. Equivalent authorized native/Intent/MCP requests have these same effects. |
| Full-context bulk unit, real-store and native confirmation | Tokyo Food contains active Hotel and archived Museum, with UI showing only Hotel. Mark All Done sets both local flags; progress 2/2. Global flags remain Todo. Mark All Undone yields 0/2 unless a source is globally Done. Changed targets reject stale review. True save failure changes neither child; postcommit recovery failure retains both applied flags and blocks further domain mutation. |
| Reference unit, store and physical convergence | Removing membership 401 preserves Hotel 101, Trip Prep membership 403 and Schedule 601. Ordinary re-add gets a new membership local Todo. Reordering itinerary 501/502/503 retains identities/flags. Identical operation replay creates no second entry; a new intentional Hotel-add operation creates a separate appearance. Use accepted duplicate, deletion and restoration-family device fixtures from the packet. |
| Query unit/store/UI | All four global completion/archive pairs, generic no-location Item, all accepted search sequences, past direct/indirect schedules and unschedule identity sets. Keep valid filtered-out detail; removed appearance returns missing reference. A stale row-window generation does not mix snapshots. Search quality dataset remains 5,000 Items/200 Lists and 300 ms on each device, not a count cap. |
| Partial edit and stale unit/store | Contract Q7/Q8 settle competing observation above. Unknown fields/required-title null reject. A notes-only accepted patch retains title/estimate, memberships, archive/global/local values. Unrelated title edit does not block notes under the recommended field-specific expectation. |
| Wire value unit and actual round-trip | Contract Q9 fixes grammar. Proposed tests include Int64 max 9223372036854775807, rank min -9223372036854775808, overflow 9223372036854775808, fraction 1.0000000000000001, exponent and leading-zero strings, finite submillisecond native Date and distant finite dates, UUID case variants, malformed IDs, invalid civil dates and non-finite coordinates. Do not impose a new practical domain range. |
| JSON version/structure unit | Contract Q10 settles repeated-property treatment. Unsupported version, unknown properties, malformed input, duplicate record IDs and unresolved references reject the whole backup with zero mutation. No shortened successful export of an unresolved native graph. |
| Import unit/store/native preview | Accepted Skip keeps matching whole owners; Overwrite replaces represented whole owners after review; omission from file preserves sources. Current A=[X] with local Done plus incoming A=[X,Z] produces A unchanged and new Z in Skip. Invalid backup rejects together. Incoming deleted markers, restoring IDs, conflict-dependent skipped owners and independent records follow the architecture's exact accepted examples. |
| Authority unit and real MCP server | Forbidden source/label Delete and any unauthorized indirect apply reject before mutation, including the case where X is absent at preview but its obsolete lifetime may arrive later. Disabled/expired access fails. Ordinary authorized reference removal preserves protected sources. Contract Q1-Q6 govern final operation availability and confirmation. |
| Receipt/recovery integration and host-closed Share | Same operation/payload creates one result. Changed-payload replay rejects only that attempt. Failure before commit leaves action unapplied; failure after commit retains complete Item/memberships, reports recovery incomplete, blocks dataset writes and retries copy only. Kill at every approved prepare/commit/copy/receipt checkpoint and query actual surviving evidence; prepared-only stays unverified. |
| Scheduling unit/store/native picker/device | Inclusive Friday-Sunday dates, fixed Tokyo 10:00-11:00 to Paris 03:00-04:00 display, valid start-only, strictly-later end, spring gap rejection, earlier/later repeated occurrence and coupled DST endpoints. Planning-zone-only edit preserves both instants. Every accepted Q5-Q14 fixture remains required; no EventKit check substitutes. |
| Capture loader/parser unit, real store and physical payload | Reverse loader completion and retain U then V; Unicode/prose/link retention exactly matches C8-C10. Typed URL-object spelling is distinguished from original text. Unsupported/file-only, conflicting parameters, missing own coordinate and finite bounds follow accepted C9/C13. Contract Q11/Q12 supplies exact order/boundary/deadline observations. Never silently omit a supported lane. |
| Capture transport unit and actual extension lifecycle | Contract Q13 fixes allowlists and budgets. Test exact hosts versus suffix spoofs, HTTP bookmark with no HTTP request, disallowed hop, loops, missing Location, each boundary and deadline, obsolete callbacks after input edit/Add/Cancel, partial Save without lookup, no ordinary-page body fetch and no automatic preview retry. Native allocations and extension lifecycle must be measured; post-load byte checks are insufficient proof. |
| Export/recovery account integration/physical | Complete active backup retains IDs/manual order/schedules/minimal lineage and excludes app state/credentials/cache/receipts. Inspect/export old recovery does not mutate or upload into current account. Explicit empty-dataset restoration reproduces accepted data; coherent ownership cutoff preserves good independent copy under resets. Contract Q3/Q4 govern integration access. |
| App Intents native and adapter parity | Contract Q5 settles authentication/confirmation. Execute locked/unlocked/denied/canceled cases, unsupported/removed IDs and archived hidden bulk children. No ambiguous completion fallback. Capture native review cancellation creates zero Items. |
| Selected-client and native MCP integration | Contract Q14-Q16 settles proof matrix/address/handoff/time/lifecycle. Demonstrate each client separately, simultaneous clients if required, occupied port, token renewal, no listener while Off, timeout/Stop/lock/sleep/window/quit and actual before/after-commit status. No secrets in ordinary logs/configuration. CLI success cannot stand in for desktop proof. |

## Definition of done

- [ ] Human accepts the final command/query schemas, wire validation and integration authority.
- [ ] Representative complete JSON/typed Swift requests and results include exact UUIDs, error and retained-state expectations.
- [ ] No adapter duplicates Core rules or obtains forbidden authority through alternate commands.
- [ ] Accepted grammar/resource/session choices have executable-boundary fields and exact future unit/store/UI/device/client obligations.
- [ ] Document checks pass; publish/read back committed source and progress/resolution evidence.
- [ ] Close only after this decision's applicable human/evidence criteria pass, then append its named resolution pointer to the map. Runtime checks remain owned by the prototypes.
