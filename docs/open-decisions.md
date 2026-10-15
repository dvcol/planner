# Decision register

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

The human accepted A on 15 October 2026. Extend shared Core catalog sorting to Title, Created date, Last updated and Full estimate in both directions, with native controls and per-device/dataset/catalog preferences. Native views and agents share the sequence; API callers omitting sort retain alphabetical order. Route/child order, completion and bookings remain unchanged. The [proposal, impacts and required tests](container-catalog-sorting-question.md) retains the unselected alternatives. Q86 now settles uncertain-duration placement; concrete contract review remains open before implementation. Earlier records describing Q85 as pending are historical.

## Q86, incomplete full-estimate ordering

The human accepted A on 15 October 2026. Sort exact full estimates first, incomplete lower bounds next and unavailable totals last in both directions. Sort each numeric group by the selected direction. Manual overall budgets count as exact full estimates; warnings remain visible. The [question and test obligations](container-catalog-sorting-question.md#q86-incomplete-full-estimates) retain the alternatives for context. This changes catalog ordering only, without changing remaining-time, manual-budget, completion, route or booking rules. Earlier records describing Q86 as pending are historical.

## Q87, concrete container catalog sort contract

Pending review of the [concrete contract](container-catalog-sort-contract-review.md) after Q85 A and Q86 A. It declares the optional Core/MCP sort values, omitted-sort compatibility, deterministic ties, accepted uncertainty groups, strict errors, generation-bound paging, native preference scope and required public Core/HTTP/native tests. The existing read boundary remains in use; no new testing seam is proposed. This review concerns the concrete extension before its tests and implementation, not whether catalog sorting is in scope.
