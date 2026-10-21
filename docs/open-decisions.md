# Decision register

## Current frontier, 21 October 2026

Q116 A is implemented. Item/Itinerary edits return exact new bookmark references, and the native Add Link actions use them without a second read. The [Core result qualification](prototypes/core-owned-link-edit-results.md) and [native adapter qualification](prototypes/native-add-link-intents.md) retain their tests and limits. Native [List notes](prototypes/native-list-notes.md) are also implemented. Neither checkpoint closes the map.

Further local work qualifies [native unsupported backup-version rejection](prototypes/native-backup-version-rejection.md), valid-file retry and retained Tag identity on phone and dark-mode tablet. Its failed controller attempts remain separate from four final passing invocations. This does not consume a pending choice or close signing, physical, Mac runtime or full-graph import gates.

The [unresolved-reference follow-up](prototypes/native-backup-unresolved-reference.md) also passes on phone and dark-mode tablet: a new List's missing Item blocks confirmation, current data survives, and no partial List appears after relaunch. Other invalid bindings and broad import/recovery gates remain open.

The [full-graph native file follow-up](prototypes/native-backup-full-graph-file.md) passes empty import/relaunch/scoped state and verifies actual delivered exports against every fixture field on both mobile layouts. The shared exporter regression also passes. Reinspection of both original dark iPad List captures confirms that Estimate and Remaining titles are visible; the earlier missing-title finding was an inspection error. No pending choice is inferred from these checks.

The [nonempty graph follow-up](prototypes/native-backup-graph-conflicts.md) qualifies native Skip/Overwrite for shared Item content and List-local completion/history, plus an independent new Item. Phone and dark iPad pass, and their actual delivered files match both complete expected graphs. Two earlier controller failures remain failed. No production change or pending feature approval is inferred.

The [referenced-Item restoration follow-up](prototypes/native-backup-item-restoration.md) adds a native rejection/restoration journey and corrects an iPad presentation stall after Cancel. The review consumes its displayed shared error on dismissal; saved data and recovery blocks are unchanged. Final phone/dark iPad restoration and successful-import regression pass, preserving original public identities and independent completion. Mac compilation and affected lint also pass. Three earlier restoration failures remain recorded; no map gate is broadly closed by this slice.

The user accepted A for all eight choices below on 21 October 2026. Local implementation checkpoints are linked below. The user has also accepted Q124 A, Q125 A and Q126 A, approving the concrete Schedule and plan-opening contracts.

| Question | Accepted decision | Choice and consequence | Concrete review |
| --- | --- | --- | --- |
| Q115 | Shortcuts estimate inputs and exact range | A: Quantity, six-unit selection and Additional minutes. Preserves the complete accepted integer range and mixed durations. | [Estimate inputs](native-estimate-intent-input-review.md) |
| Q117 | Reading saved content from native entities | A: On-demand deferred properties, with production getter tests. Avoids hydrating full content for every picker row; individual reads can fail or observe different generations. | [Saved-content properties](native-deferred-content-read-contract-review.md) |
| Q118 | Schedule creation action layout | A: Four focused actions for timed/all-day Item/Itinerary bookings. Required inputs are explicit; the action library gains four entries. Occurrence and full form-edit choices follow this decision. | [Schedule workflows](native-schedule-intent-workflow-review.md#q118-creation-action-layout) |
| Q119 | Relevant timed Schedule choices and their test boundary | A: A native DynamicOptionsProvider with direct production results tests. Offers timed choices while retaining execution-time validation; actual system picker behavior remains separate. | [Timed choices](native-schedule-intent-workflow-review.md#q119-timed-schedule-choices-and-test-boundary) |
| Q120 | Confirmed bulk adapter contract and local test boundary | A: Three focused actions and direct production store preparation/submission tests. Tests exact reviewed writes locally without fabricating system confirmation. | [Confirmed bulk completion](native-bulk-intent-contract-review.md) |
| Q121 | Category/Tag icon selection | A: A native Picker with a small named symbol set and Default. Retain an existing custom symbol until explicitly changed or cleared. | [Label appearance](native-label-appearance-review.md) |
| Q122 | Open List/Itinerary window and draft behavior | A: Reuse one foreground main window, preserving Save, Discard and Keep editing. Other windows retain their selection; the concrete handoff follows the choice. | [Opening saved plans](native-plan-opening-shortcuts-review.md#q122-opening-a-saved-plan) |
| Q123 | Initial discoverable App Shortcut set | A: Create Item, Find Items, Find Lists and Find Itineraries. Existing ordinary actions remain available; the initial provider does not depend on unfinished Open actions. | [App Shortcut discovery](native-plan-opening-shortcuts-review.md#q123-the-initial-discoverable-app-shortcuts) |

[Exact estimate setting](prototypes/native-estimate-setting-intents.md) now implements Q115 A at the approved local boundary. Seven setting tests and ten reset regressions pass, with matching Mac/Simulator/unsigned device builds and retained native contracts. Actual system input/invocation remains open.

[Timed Schedule choices](prototypes/native-timed-schedule-options.md) implement Q119 A locally. Four production-provider tests and 22 affected Schedule read/zone regressions pass, with matching platform builds. The ordinary Schedule query and execution-time form validation remain intact; actual system picker invocation is still open.

[Four initial App Shortcuts](prototypes/native-app-shortcut-discovery.md) implement Q123 A as native metadata. Exact create/find entries and all ordinary contracts verify across matching platform builds; 19 underlying adapter cases pass. Actual system discovery/prompting/Siri remain separate.

[Live saved-content properties](prototypes/native-deferred-content-properties.md) implement Q117 A locally. Seven getter cases and 69 affected adapter cases pass, with matching platform builds and preserved prior contracts. Actual system property fetching, including cold dependency initialization, remains open.

[Reviewed bulk completion](prototypes/native-bulk-completion-intents.md) implements Q120 A locally. Fourteen new cases and 58 affected regressions pass through the approved store/Intent boundaries. Native confirmation, Cancel and dependent picker execution retain separate system gates.

[Schedule creation and replacement](prototypes/native-schedule-form-intents.md) implement Q118 A, Q124 A and Q125 A locally. Twenty new cases and 48 affected regressions pass, preserving identities, civil-time rules and truthful recovery. Actual system picker serialization and invocation remain open.

## Accepted concrete follow-ups

The user accepted A for Q124, Q125 and Q126 on 21 October 2026. No question in this frontier remains unanswered. Implementation and qualification continue under these contracts.

| Question | Concrete decision | Accepted choice and impact | Review |
| --- | --- | --- | --- |
| Q124 | Civil inputs for the four approved Schedule creation actions | A: native date/dateTime fields, a separate planning zone, and explicit Earlier/Later choices for repeated timed endpoints. Reject normalization and unsupported seconds. | [Civil input contract](native-schedule-civil-intent-contract-review.md#q124-concrete-creation-inputs) |
| Q125 | Full Schedule replacement action layout | A: two focused Timed/All Day replacement actions. Retain Schedule/owner identity; omitted End clears it. | [Replacement actions](native-schedule-civil-intent-contract-review.md#q125-full-schedule-replacement) |
| Q126 | Single-window handoff and added test boundary | A: one production coordinator with exclusive claims, truthful pending/busy outcomes and existing draft protection. Direct production-interface tests supplement actual window/system journeys. | [Directed handoff](native-plan-opening-handoff-contract-review.md) |

## Remaining gates

The [List pane header correction](prototypes/native-list-pane-header.md) addresses the user's latest title, alignment and control-spacing review through the existing native UI boundary. Its own qualification report distinguishes containment, interaction, visual inspection and outstanding platform checks. [Completed-result cleanup](prototypes/native-local-storage-cleanup.md) separately removes 7.75 GiB of temporary artifacts with retained evidence.

The [grouped Undo Mac follow-up](prototypes/native-owned-association-undo.md#mac-follow-up-21-october-2026) now passes actual Item and Itinerary Command-Z/restoration/relaunch journeys. Its exact bookmark identity/order and retained-note assertions supplement the existing Core, controller and mobile results; no signed or whole-app gate is closed.

The [Category driver follow-up](prototypes/native-label-appearance.md#mac-driver-and-execution-follow-up-21-october-2026) adds actual Mac name/icon/optional-color results and reruns mobile cases through corrected native row/picker locators. Phone sheet and tablet popover RGB readback pass after relaunch. Mac RGB-panel entry and complete Mac label-file qualification still need local evidence; this is not a signing-only frontier.

- Q115, Q117–Q120, Q123, Q124 and Q125 have local checkpoints above. Q121 has its [local native editor checkpoint](prototypes/native-label-appearance.md). Q122/Q126 have a [directed-opening implementation checkpoint](prototypes/native-plan-opening-handoff.md). All 13 post-focus-fix handoff cases now pass through both the established direct module runner and Xcode's ordinary Mac hosted workflow, including both Open Intent adapters. Actual native/system opening remains open; production-interface results do not replace it.
- After the user's readiness confirmation, both unchanged phone completion controls pass and Mac UI automation starts. The [current diagnosis](prototypes/native-xctest-runtime-diagnosis.md#mac-draft-and-resize-qualification) retains prior failures, two passing ordinary Mac draft-guard runs with native filled-window setup, and the passing actual narrow/wide rich-editor/relaunch journey. Remaining native window/feature checks continue. No evidence establishes a restart cause or a paid-signing fix.
- Actual Shortcuts/Siri execution and picker injection remain unqualified. Apple's system test service rejected the Customer build; passing production-interface tests does not replace system invocation or establish that a paid account fixes it.
- Signed/shared storage, Agent Control against that storage, CloudKit convergence and account transitions, installed Share extensions and physical-device performance remain open. Signing/account setup is deferred at the user's request.
- Final whole-app UI polish follows feature completion under [its dedicated contract](native-ui-polish.md). Earlier scoped layout, contrast and dark-mode corrections do not close it. Specification handoff also needs the remaining prototype gates and the user's final coherence review.

The [map](https://github.com/dvcol/planner/issues/1) and open prototype issues retain their original Context, DoR, DoD and required tests. This register separates human choices from implementation and platform evidence; it grants no new test boundary or feature approval.

## Historical decisions and checkpoints

The human accepted Q108 A, Q109 A and Q110 A on 19 October 2026. The additional production history-controller test boundary is approved. Move Undo reverses the whole Move atomically; one editor Save issues one atomic group for its removed associations. Their concrete extension contract and literal fixtures follow those choices before implementation. Q102's account/team setup remains deferred. An accepted choice alone does not establish implementation or platform acceptance. The following historical entries retain their original context. Current implementation reports and later status entries supersede their earlier starting-state wording.

The human accepted A for Q94, Q95 and Q96 on 17 October 2026. Their concrete presentations, production interfaces and test seams are approved. The human also accepted A for Q97: extend the shared loader for standalone List windows. The 18 October UI-review request brought the navigation and appearance slice forward. Q94–Q97's local implementation checkpoints are linked below; their broader qualification gates remain open.

The human settled this batch on 12 October 2026. None of the nine questions below remains unanswered. Accepted behavior is a requirement, not evidence that its implementation or native qualification is complete. Earlier execution records that describe these choices as pending are historical.

Earlier prompts reused Q48/Q49 and changed Q51's option lettering. This register keeps one meaning per number. Q74 is the duration-layout choice previously restated as Q48; Q49 retains its original editor-placement meaning.

| Question | Accepted choice | Required behavior and impact |
| --- | --- | --- |
| Q48, estimate unit changes | A | Preserve exact duration. One 365-day year displayed as months is twelve 30-day months plus five days. Unit selection changes representation; quantity edits change the value. |
| Q49, estimate editor | A | Inline Activity estimate section in the native grouped Item form, governed by the Item's existing Save/Cancel and No estimate choice. |
| Q51, editing a pinned address | B | Explicit staged Keep saved pin / Remove saved pin choice under the same Save/Cancel. Automatic lookup never silently replaces owned coordinates. |
| Q52, controlled preview testing | A | Dedicated fixture app and Xcode scheme using production views with controlled providers. Image/no-image/error, address ambiguity and delayed-result native journeys remain required. |
| Q57, referenced List filtering | Human refinement | Show the List group when the List itself matches the cumulative filters or at least one child matches. Hide it when neither matches. A matching List can remain visible with zero matching children. Filters never change full progress or saved route order. |
| Q58, loading fixture | B | First create forty Items and four Lists through native controls and test traversal, selection and refresh. Keep the separate 5,000-Item/200-List performance gate. |
| Q72, archived container's own progress | B | Keep its own child-based progress while showing zero remaining time because the container is archived. Its archived branch still counts as finished in a parent itinerary. Preserve child Done flags and the full estimate. |
| Q73, import with omitted source owner | A | Preserve the omitted owner and its owned records in both Skip and Overwrite. Report incoming owned records as skipped; import independent sources. Replacing an owner requires its source record in the file. New declared Lists referencing existing external Items remain valid. |
| Q74, native duration controls | A | Unit/count controls with exact smaller-unit remainders, such as two hours plus five minutes. Preserve one-minute precision and use native controls without raw numeric text input. |

Required /tdd coverage belongs to each affected feature's definition of done. These answers unlock that work; they do not close import application/restoration, native preview/loading, aggregate/calendar, physical sync/account/Share or whole-app polish gates.

## Q75, List-header filter applicability

The human accepted A on 12 October 2026. Every selected criterion applies when evaluating the List header's own match. An active Item-only restriction makes that header match false because Lists do not own those fields; a matching child can still keep the group visible. For example, searching Tokyo Food with a Rainy day Tag restriction hides that group when no child matches both criteria. The [native itinerary filter slice](prototypes/native-itinerary-filters.md) retains the required tests. Matching headers may have zero matching children; they never reveal children that fail the filters. No question in this recorded frontier remains unanswered.

## Q76, missing finished estimates

The human accepted A on 12 October 2026 for [container remaining estimates](container-estimates-and-calendar.md). A partial manual budget deducts only known finished estimates and shows the result as an upper bound, with a warning counting finished appearances whose estimates are missing. It never manufactures a child estimate. A manual total of 240 minutes with unknown finished Lunch and unfinished Museum shows up to 240 remaining; adding Lunch's 60-minute estimate gives 180. Every child finished gives 0, with the manual 240 retained. Apply the same rule to a partial manual List branch inside an itinerary. No recorded question remains unanswered. [Core and HTTP budget reads](prototypes/core-container-estimates.md) and [native root controls](prototypes/native-container-estimates.md) are qualified; the remaining native context fixtures and broader map gates stay open.

## Q77, native Maps encoded payload budget

The human accepted B. Each encoded native Maps payload may contain up to 8 MiB; the aggregate decoded text budget remains 1 MiB. The existing attachment count, concurrency and capture deadline still apply. [Native Maps loading](prototypes/core-native-map-capture.md) is committed and qualified at its recorded Core boundaries. Physical Share sender allocation and lifecycle tests remain required.

## Q78, controlled Maps HTTP lookup tests

The human accepted A on 2026-10-13. Add a production HTTP transport boundary returning status and headers, test Core's redirect/deadline/draft rules with controlled results, and separately qualify the real URLSession delegate. Planner's public capture API must not gain test-only dependency parameters. Live services cannot reliably reproduce these outcomes. The native probe showed that global URLProtocol registration did not intercept an ordinary ephemeral URLSession, while explicit session configuration did. The [native HEAD module](prototypes/native-capture-http-transport.md) and [Core Maps lookup](prototypes/core-maps-capture-lookup.md) now have their recorded qualifications. Native/agent preview integration, live provider/socket proof, iOS transport runtime and physical allocation/Share gates remain open.

## Q79 through Q81, remaining Calendar layout and reads

The human accepted A for each question on 2026-10-13. They do not reopen accepted Schedule semantics or Calendar mode scope. Implementation remains open.

- Q79 uses the main Calendar content width on iPad/Mac with native inspector details that can be shown or hidden. Phone details push through native navigation. Ordinary List/Item navigation retains third-panel details.
- Q80 uses decorated pre-made UICalendarView and a selected-day agenda on mobile, plus a SwiftUI event grid on Mac. Mobile month cells show compact indicators; the agenda supplies event names. The [component investigation](research/native-calendar-display-components.md) establishes the platform capabilities and limits.
- Q81 adds a shared typed Core Calendar date-window query returning Schedule forms and live owner identities/titles with generation-bound paging. Native views and agents share those reads. The [qualified Core window reads](prototypes/core-calendar-windows.md) implement the approved contract. Native adoption and measured storage performance remain separate gates; a facade extension alone does not prove batched storage or performance.

## Q82, concrete Calendar window contract

The human accepted A on 14 October 2026. The [approved contract](calendar-window-contract-review.md) defines inclusive civil-date bounds and display zone, consistent Schedule/owner/title/form pages, unchanged stored Schedule semantics, stale-generation rejection, retained archived-owner schedules, and exact timed/all-day boundary fixtures. The [Core and HTTP qualification](prototypes/core-calendar-windows.md) records the implementation and executed tests. Native Month/Day/Week consume that shared query. [Storage scale](prototypes/calendar-window-scale.md) and [unchanged capture reuse](prototypes/calendar-capture-retention.md) retain measured evidence and their remaining limits. Broader Calendar qualification remains open, including the later Q83 presentation choice.

## Q83, Calendar clock-change alignment

The human accepted A on 15 October 2026: align Day/Week by local clock time. Equal clock times align across days; repeated times occupy separate lanes with explicit timezone names. The [decision and required tests](calendar-time-grid-alignment-question.md) cover skipped/repeated hours, half-hour changes, crossing spans and overnight clipping. Saved instants, planning zones, Schedule identities and all-day dates remain unchanged.

[Repeated-hour previews](prototypes/native-calendar-repeated-times.md), [booked-span](prototypes/native-calendar-booked-clock-change.md) and [start-only source-row](prototypes/native-source-clock-change-points.md) descriptions have their earlier native qualifications. Those captures used elapsed-time placement. The [native alignment slice](prototypes/native-clock-alignment.md) now supplies implementation and focused phone/tablet evidence. Broader Calendar, Mac runtime and physical-device gates stay open.

## Q84, query-generation lifetime

The human accepted C on 15 October 2026. Keep the current in-memory retention and lazy cleanup, as recorded in the [decision and impacts](query-generation-retention-question.md) and [public lifetime contract](adapter-contract.md#queries-catalogs-and-reads). Distinct generations remain readable in their issuing Core instance while their dataset/session/history bindings remain valid. Later queries and elapsed time do not evict otherwise valid generations. Saved-history changes still invalidate reads; subsequent queries prune stale-history bindings and stale page reads remove their requested binding.

Equivalent Calendar capture reuse remains implemented. There is no new early eviction, expiry, disk spill, release operation, retained-result cap or agent-access restriction. This accepts existing production behavior and requires no code change. The public Calendar probe keeps 100 distinct large generations readable with an unchanged full backup; its varying resident-memory observations establish neither exhaustion nor a mobile budget. Native moving-window, physical responsiveness and broader read qualification stay open. Q84 is resolved; later questions are recorded below.

## Q85, top-level container catalog sorting

The human accepted A on 15 October 2026. Extend shared Core catalog sorting to Title, Created date, Last updated and Full estimate in both directions, with native controls and per-device/dataset/catalog preferences. Native views and agents share the sequence; API callers omitting sort retain alphabetical order. Route/child order, completion and bookings remain unchanged. The [proposal, impacts and required tests](container-catalog-sorting-question.md) retains the unselected alternatives. Q86 settles uncertain-duration placement and Q87 approves the concrete contract for implementation. Earlier pending records are historical.

## Q86, incomplete full-estimate ordering

The human accepted A on 15 October 2026. Sort exact full estimates first, incomplete lower bounds next and unavailable totals last in both directions. Sort each numeric group by the selected direction. Manual overall budgets count as exact full estimates; warnings remain visible. The [question and test obligations](container-catalog-sorting-question.md#q86-incomplete-full-estimates) retain the alternatives for context. This changes catalog ordering only, without changing remaining-time, manual-budget, completion, route or booking rules. Earlier records describing Q86 as pending are historical.

## Q87, concrete container catalog sort contract

The human accepted A on 15 October 2026 after Q85 A and Q86 A. The [approved contract](container-catalog-sort-contract-review.md) declares the optional Core/MCP sort values, omitted-sort compatibility, deterministic ties, accepted uncertainty groups, strict errors, generation-bound paging, native preference scope and required public Core/HTTP/native tests. The existing read boundary remains in use; no new testing seam is proposed. Implementation and qualification remain required. Earlier records describing Q87 as pending are historical; this recorded decision frontier has no unanswered question.

## Q88 through Q93, accepted creation and selection behavior

The human accepted A for Q88 through Q92 and approved Q93's concrete ordinary-creation contract. These are settled product choices. Their implementation and platform qualification retain the limits in the linked reports.

| Question | Accepted behavior | Contract or evidence |
| --- | --- | --- |
| Q88, List creation actions | One native Add menu offers New Item, Add existing Item and From Link or Text. New Item creates its shared source and originating List appearance together; Cancel creates neither. | [Native creation](prototypes/native-item-creation.md), [ordinary creation contract](create-item-in-list-contract-review.md) |
| Q89, selection after deletion | When confirmed entity deletion removes the selected identity, select the first visible survivor in the same context on Mac and regular iPad, including its first visible child when replacing a List. Compact iPhone returns to its containing list. Deleting an unselected row preserves valid selection. Ordinary reference removal clears invalid selection and explains why under A3. Truly empty results retain an empty state; filtering a valid selection out does not replace it. | [Creation and selection contract](native-creation-and-selection.md), [selection and layout checks](prototypes/native-layout-compatibility.md) |
| Q90, full New Item editor | Use the detail column on Mac and wide iPad, and a native pushed page in compact layouts, with explicit Save and Cancel. Keep the original destination and draft through layout changes. | [Rich-draft layout checks](prototypes/native-rich-draft-layout.md) |
| Q91, edited-draft navigation | Offer Save, Discard and Keep Editing before leaving an edited draft. Invalid Save retains the draft and errors. Discard creates nothing; Keep Editing cancels navigation. An untouched blank draft can close directly. | [Native creation and guarded navigation](prototypes/native-item-creation.md) |
| Q92, saved Maps links | Show a live temporary map card from the original saved Maps link. Owned address/pin data takes precedence. Unavailable or ambiguous lookup keeps a useful fallback; temporary provider results stay outside saved content and backups. | [Saved Maps lifecycle](prototypes/native-saved-maps-lifecycle.md) |
| Q93, atomic ordinary creation | Extend createItem with an optional active List destination. Create the source and one local Todo membership together, preserving ordinary authored bookmarks and replay behavior. Capture retains its separate deduplication policy. | [Approved concrete contract](create-item-in-list-contract-review.md) |

[The current creation compatibility checks](prototypes/native-new-item-dynamic-type.md) link earlier creation, duration and layout evidence and qualify ordinary/maximum-size phone and tablet rich creation. Individual passing journeys do not close the complete native, physical, signing, accessibility, performance or final-polish gates.

## Q94, label selection during a New Item draft

The human accepted A on 17 October 2026. Use a native popover on larger layouts with compact sheet adaptation for Categories and Tags inside New Item. The Item itself retains its accepted detail-column/pushed-page layout. Preserve the same draft, label identities, explicit Save/Cancel and guarded navigation; verify label return, Discard, Save, relaunch and layout regressions through the existing native UI seam. The [earlier diagnosis](prototypes/native-new-item-labels.md) retains the unwanted leaving prompt and unsuccessful pushed-navigation experiments. Approval does not claim the fix is implemented or qualified.

## Q95, native Item catalog windows and test seam

The human accepted A on 17 October 2026, approving the [concrete native loader contract](native-item-window-contract-review.md). Items/Inbox display their first up-to-64-row page before full result accumulation, load visible pages and retain at most one adjacent page on each side. Preserve Core ordering, identities, selection and mutation scope; supersede obsolete work and refresh stale generations. Test the production loader interface against real Core in the existing app-hosted target, followed by native scrolling/refresh/layout qualification. No new package, target or test-only controls. Other collection views follow on the map. Q84's Core generation lifetime remains unchanged, including its retained identity sequence and captures, so this does not promise bounded total memory. Implementation and measured performance evidence remain required.

## Q96, native schedule clock input and unit seam

The human accepted A on 17 October 2026, approving the [concrete clock-input module and real-Foundation unit seam](native-schedule-time-input-contract-review.md) alongside the existing Core/native UI seams. Use one app-internal value module for Start and End with native controls, retained civil fields, nonexistent-time rejection and explicit repeated-time selection. Preserve exact unchanged stored instants and timezone-only edits, including fractional seconds. A new or explicitly rescheduled endpoint requires a choice when a zone change produces a repeated minute; same-minute picker normalization preserves unchanged stored fractions. Core/MCP schedule forms, backups, packages and targets remain unchanged. The [repeated-time investigation](prototypes/native-schedule-clock-input.md) and [missing-time diagnostic](prototypes/native-schedule-missing-time-input.md) retain actual native failures. The approved interface now permits TDD implementation; those failures are not an implemented correction or persisted-outcome proof.

Q94 implementation evidence: [native New Item label selection](prototypes/native-new-item-label-picker.md) records the picker-return correction and its mobile qualifications. [Q95 Items/Inbox presentation windows](prototypes/native-item-windows.md) have seven passing real-Core loader tests and focused phone/tablet query, page-release and settled-rotation journeys. Draft resizing, selected-deletion replacement and Inbox compatibility also pass on both mobile layouts. [Q96 native clock input](prototypes/native-schedule-time-input.md) has nine passing Foundation/Core functions, four passing clock-input scenarios on each mobile layout, three passing existing scheduling regressions on each, and two passing tablet Itinerary caller regressions. Original captures are individually inspected. The [navigation and appearance slice](prototypes/native-design-pass.md) addresses the reported floating-tab/title stack and retains its focused light/dark checks. Broader native compatibility, performance, Mac runtime, physical qualification, signing and [final whole-app polish](native-ui-polish.md) remain separate gates.

## Q97, standalone List presentation windows

The human accepted A. The [approved List window contract](native-list-window-contract-review.md) extends the existing app-internal loader to complete typed row identities and generation-validated List source metadata. Preserve full matching counts, full-scope progress/estimates, membership action scope, selection and manual reorder anchors while releasing offscreen presentations. The expanded production interface and real-Core/native UI seams are approved. The [List-window implementation report](prototypes/native-list-windows.md) records its local qualification; later Q98/Q103 reports cover Itinerary hierarchy and catalog/picker adoption. These checkpoints do not establish physical performance or full navigation acceptance.

## UI review brought forward

On 18 October the human requested a new UI pass, correct dark mode across devices and a correction to the empty space above sidebar filters. The [native navigation and appearance review](prototypes/native-design-pass.md) records the current slice and its qualification. It uses a Notes-style native sidebar on wide iPad and Mac, phone tabs, compact native pane titles and system appearance. This advances the reported layout correction without marking final whole-app polish, physical devices or signing complete. No new product question is pending.

## Q98 through Q103, accepted windows and native presentation

| Question | Accepted choice and behavior | Implementation or qualification record |
| --- | --- | --- |
| Q98, Itinerary presentation windows | A. Extend the shared loader with typed hierarchy and contextual identities, preserving full summaries, saved order and selection while releasing offscreen presentations. | [Approved contract](native-itinerary-window-contract-review.md), [implementation](prototypes/native-itinerary-windows.md), [compatibility](prototypes/native-itinerary-window-compatibility.md). Broader platform/performance acceptance remains open. |
| Q99, native contrast correction | A. Correct the selected row/detail foregrounds while retaining native controls and readable appearance. | [Foreground correction](prototypes/native-selection-contrast-fix.md). Q101 subsequently resolves the represented Capture overlap. The [later Itinerary caption correction](prototypes/native-itinerary-caption-contrast.md) qualifies its own scenes. No whole-app accessibility acceptance is implied. |
| Q100, protected Agent Control | B. Retain actual signed-storage and native Mac workflow qualification before implementing/accepting the deferred native access path. | [Native access readiness](prototypes/mcp-native-access-readiness.md). Protected storage, actual Mac runtime and required signing/capability setup remain open. |
| Q101, Items/Inbox creation controls | A. One native Add menu offers New Item and From Link or Text. Filters and Sort remain separate. | [Add-menu implementation](prototypes/native-catalog-add-menu.md). Its scoped results do not close the whole scene inventory. |
| Q102, signing setup | The human asked whether a paid membership is necessary and then authorized continuing local work until signing/real-device testing is required. No team, account enrollment or purchase was selected. | [Apple test access](setup/apple-test-access.md). Local implementation continues; gated provisioning still needs the human's setup decision/action. |
| Q103, container catalogs and pickers | A. Extend the existing loader with the typed catalog overload, preserving identities, counts, sort, archive rules and remembered destinations. | [Approved contract](native-container-window-contract-review.md), [catalog and picker qualification](prototypes/native-container-catalog-windows.md). No bounded total-memory or physical-performance claim is made. |

## Q104 through Q107, original-association Undo

Q104 A keeps removal history in memory for the current app run. Q105 A preserves a newer recreated relationship and rejects the old Undo with an explanation. Neither choice adds Trash or deleted-source recovery.

Q106 A approves the [concrete native-only snapshot/restore contract](native-association-undo-contract-review.md) for explicit List-membership and Itinerary-entry removals. Restore preserves the original public association identity, order and local state under a fresh lifetime, retaining unrelated source edits and rejecting invalid/superseded bindings. Q107 A integrates named window UndoManager actions and explicit mobile Undo, without association Redo in this slice.

The [implementation report](prototypes/native-association-undo.md) records the affected real-store/HTTP results and represented phone/iPad restoration, conflict and filter/selection journeys. Actual Mac history interaction, additional asynchronous-history qualification and the remaining owned-association/Move work are not complete.

## Q108 through Q110, accepted Undo follow-up

- Q108 A approves [additional native history-controller tests](native-association-history-test-contract-review.md), using production history, actual Foundation UndoManager and real Planner storage/filesystem failures in the existing app-hosted target. The [five-function qualification](prototypes/native-association-history-controller.md) passes without production changes. Mac window/text-field qualification remains separate.
- Q109 A reverses a whole Move atomically. Restore the origin identity/order/local state, remove a destination membership only when that Move created it and reversal remains safe, and preserve a preexisting destination. Reject the whole unsafe inverse while retaining unrelated Item edits. The [worked proposal](native-owned-association-undo-proposal.md) records the cases.
- Q110 A creates one atomic association-removal history group per editor Save. Restore original identities, link order and owned fields together, preserving edited notes and independent additions. Reject the whole unsafe group. Label association removal remains distinct from shared-label Delete.

Q108's tests pass at the approved boundary. Q111 subsequently approves Q109/Q110's concrete capability/result/restore contract and literal fixtures. These accepted choices add no association Redo, source-Delete recovery or persistent editing history. Signing, physical sync/account/Share, scale and final whole-app polish retain their separate gates.

## Q111, accepted compound-association Undo contract

The human accepted Q111 A on 19 October 2026. The [concrete compound-association Undo contract](native-compound-association-undo-contract-review.md), including Move destination guards, whole-group issuance/restoration, bookmark anchor placement and literal fixtures, is approved for tests and implementation. Q108 through Q111 are answered; no question in this Undo decision frontier remains open. Their platform and implementation acceptance gates remain separate.

The [Core Move implementation](prototypes/core-move-undo.md) passes 27 affected functions in nine suites. The [native Move follow-up](prototypes/native-move-undo.md) qualifies the named action, compact navigation, original Done appearance and relaunch on phone/iPad, plus six controller and thirteen HTTP functions. The later [grouped link/label Core checkpoint](prototypes/core-owned-association-undo.md) passes 47 affected functions in seventeen suites, including whole-group rejection, fresh lifetimes, native write failure and checkpoint-only repair. The [native grouped follow-up](prototypes/native-owned-association-undo.md) passes both editor journeys on phone/iPad, seven controller functions and thirteen HTTP functions. Actual Mac window/text-field interaction and broader map gates remain open.

## Q116, accepted generated bookmark results

Q116 A is accepted on 21 October 2026. New Item/Itinerary edit results append exact newly generated bookmark references in saved order after their existing prefixes. Old receipts remain exact, and creation results stay unchanged. The [concrete contract](owned-link-edit-result-contract-review.md), [Core qualification](prototypes/core-owned-link-edit-results.md) and [native Add Link follow-up](prototypes/native-add-link-intents.md) record the implemented slices. Q115's estimate-input choice remains pending; actual system invocation and the broader map gates stay open.
