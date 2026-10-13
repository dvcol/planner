# MCP capture

## Context and goal

Core and the native text/link review could prepare and save captures. The authenticated MCP endpoint exposed ordinary commands and bulk completion, but did not advertise or route capture drafts or reviewed apply. Agents therefore could not complete the accepted C14/C16 capture flow.

This slice adds direct URL/text preparation, read, edit, removal/retry and cancellation tools. Capture review describes new content or only missing additions on reuse. Apply uses the same durable operation identity, required review token and Core command as native capture. No integration-specific save or conflict policy is introduced.

## Definition of ready

Q33 accepted the [adapter contract](../adapter-contract.md#capture-preparation-and-apply) and the real authenticated HTTP test seam. C14–C16 define exact reuse, reviewed destinations and save/cancellation behavior. Contract Q2 explicitly permits the enabled agent to review and apply without another native click. The official Swift SDK and existing stateless listener remain in use. Q78 is still required for Maps HTTP lookup and does not block direct capture.

## Definition of done for this slice

- Advertise and route `planner_prepare_capture`, `planner_update_capture`, `planner_read_capture` and `planner_cancel_capture` only through the existing authorized dataset handler.
- Preserve ordered original URLs, draft generations, owned content, temporary previews, input issues and exact candidate identities. Capture helpers save no domain data or receipt.
- Parse the same typed Item patch as ordinary edits. Unknown fields, fabricated origins, invalid IDs/coordinates and noncanonical input-index strings reject with useful paths. Remove/retry indices remain Core commands, not adapter-side omission.
- Review/apply accepts only the exact Create new or chosen existing Item and selected Lists. Missing or stale tokens cannot save. Reuse retains owned fields, global/archive state and existing local completion, adding only reviewed missing links/memberships.
- A completed capture cannot be undone by draft cancellation. Reopening and replay preserve the saved identities and complete operation result, without a live draft.
- Native HTTP journeys and relevant execution/review regressions pass, with strict lint and affected build/type checks. Broader client, provider and physical-device gates remain open.

## TDD and qualification

The first authenticated HTTP lifecycle test failed at the missing preparation route. Preparation/read/cancel then passed and exported saved data remained unchanged. The edit/review/apply journey next failed at the missing update route. A function-filter probe selected zero Swift Testing functions and is not qualification; the suite run established the actual failure. Build diagnostics during shared decoder extraction were corrected, preserving the List and Itinerary parsers. A source-read test was corrected to use the existing `value` envelope.

Five capture functions passed at the real HTTP boundary. They cover advertised schemas and absent administration/lookup, prepare/read/edit/remove/retry/cancel without saved changes, typed edits with required review and two destination memberships, durable replay after reopening, exact reuse preserving owned/global/archive/local state, eleven malformed-input cases and stale review/cancellation. The existing source-read and appearance envelopes and Core's coordinate error path were used; no failure semantics changed.

The final affected run passed 24 functions in seven suites, covering 31 invocations, with zero failures and zero skips. It includes capture, authentication, source reads, ordinary commands, bulk admission/review, operation status and manual estimates. The macOS app and test host compiled in that run. Five affected Swift files passed strict lint. Both review axes found no remaining confirmed source findings.

[Execution evidence](evidence/navigation/mcp-capture/execution.json) records exact narrow commands, completed result summaries and hashes. Source hashes were checked after the process exited. A disk-full build attempt could not start; only regenerable task build caches were removed before qualification resumed. Test storage cleanup is deferred until the process exits, rather than unlinking an open native store. The separate pending Maps lookup work is excluded from the commit and evidence.

## Remaining map work

Maps lookup advertisement/transport waits for Q78. Native provider/Share and Intents, complete capture editing/preview presentation, interruption/recovery UI, physical sender budgets and genuine native place binding remain open. This slice does not qualify the four real client applications, authenticated credential-reader UX, Mac UI runtime, physical sync/account/Share, Calendar choices Q79–Q81, scale/paging or whole-app polish.
