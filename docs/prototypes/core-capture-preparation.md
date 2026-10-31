# Core direct capture preparation

Core prepares transient capture drafts from ordered direct URL/text inputs. `prepareCapture`, `readCapture` and `cancelCapture` use the authorized dataset session. Preparation, reading and cancellation do not create an Item, membership, receipt or recovery checkpoint. Storage schema remains 18 and portable format remains 2.

## Context and goal

The [shared capture contract](../adapter-contract.md#capture-preparation-and-apply) had no executable draft boundary. Existing native creation used ordinary Item commands, which did not prepare a capture review or find exact-link reuse candidates.

The completed step returns an immutable draft with fresh identity/generation, proposed owned content, original links, input issues, preview selection and saved-Item candidates. It retains no native provider objects. A cancelled draft becomes unavailable; a live unsaved draft is also unavailable in a new Planner instance. A stale cancellation cannot discard the current draft, and a foreign dataset session cannot read it.

## Readiness and completion

Q33 accepted the public facade and [C1–C16](../url-and-share-capture.md#accepted-first-capture-round-c1-c7) define the content, cancellation and reuse rules. Tests use the approved public Core/native store boundary. Foundation provides link detection and UTF-16 line ranges; no dependency or test-only production seam was added.

Completion of this step requires exact proposed content, deterministic original-link order and candidate identities, useful input issues, and unchanged full exported data after draft actions. This is preparation, not capture execution. Native loaded input, draft edits, automatic/explicit Maps lookup and reviewed `applyCapture` remain separate required work.

## Implemented behavior

- Native link detection retains each supported URL's exact supplied substring. Duplicate original strings collapse once in input/detection order. It does not normalize URL spelling or infer a shared physical place from names or coordinates.
- The first nonempty independently supplied text line becomes the title. Remaining text and internal line endings are retained in notes. Multiple accepted text lanes are joined with one LF. Link-only lanes remain in notes when the capture also has prose; when the complete capture contains only links, the title is the app fallback `Saved link` and notes remain absent.
- Unsupported typed URLs produce nonblocking issues. Independently supplied non-web text remains editable text. Empty or whitespace-only preparation has no usable title and reports `saveAllowed == false`. No input is opened and no web page is fetched.
- The accepted 1 MiB decoded URL/text and 128 distinct-link bounds produce blocking oversized-input issues. An oversized lane contributes no partial owned content. Distinct links are bounded before building the final draft. The 32-provider/four-load/ten-second bounds belong to native loading; they are not an additional cap on direct URL/text lanes. These checks do not prove native loading allocation or deadline behavior.
- Exact-original candidates retain their Item identities, titles, completion/archive facts and matching saved link identities. Different URL spelling is not an exact match. Multiple candidates remain distinct, in stable UUID order. Preparation does not choose one, unarchive it, change its content or add memberships.
- A first supported Maps link is selected in a `notRequested` preview with no provider candidate. This is a lookup starting point; enrichment and automatic lookup are not implemented. Original links are not saved with fabricated provider references.

Draft origins are held internally for later reviewed execution: an app fallback remains distinct from independently supplied title/notes. This step does not qualify applying those origins to saved capture data. [Native origin/place-reference persistence](core-native-import-providers.md), [reviewed import restoration](core-native-import-restoration.md) and [saved import summaries](core-native-import-results.md) remain established persistence evidence.

## Tests and findings

Six public-boundary functions cover 19 invocations: original-link prepare/read/cancel/reopen, Unicode/CRLF prose and exact detected URLs, exact candidate identities and unchanged existing Items, below/at/above byte/link limits plus direct-input ordering, six empty/unsupported/link-only examples, and mixed-lane notes preservation. Full native exports stay unchanged after preparation and cancellation.

The initial interface test confirmed the APIs were absent. Functional red/green traces reproduced missing text preparation, absent candidates, missing byte/link admission and unsupported-URL rejection. Review then reproduced lost link-only text in mixed notes and undeclared failure codes. Both were fixed through public regressions; failure classifications now use the approved `captureInputFailure`/`captureDraftUnavailable` codes while preserving existing session failures.

The first budget draft incorrectly applied the native 32-provider bound to direct lanes. It was corrected before qualification. An exploratory Unicode URL identity counterexample failed earlier at the native bookmark validation boundary, so it did not establish an identity bug. Its diagnostic is retained; no speculative identity-rule change was made.

## Qualification

Mac and iPhone Simulator each passed 145 affected Core functions in 67 suites, covering 386 invocations. Native HTTP passed 16 functions in four suites, covering 22 invocations. Failures and skips were zero. Three affected Swift files passed strict lint. The native Mac app and navigation test host compiled successfully. Both read-only review rechecks found no remaining confirmed findings.

Evidence records exact commands, completed native result summaries, source hashes and red/green traces. No native UI runtime or physical capture/Share execution is claimed.

Remaining capture work includes Core-owned NSItemProvider loading/provenance, provider limits and lifecycle, update/remove/retry, Maps lookup and obsolete-result handling, reviewed create/reuse with atomic memberships and durable recovery, native review/Share/Intent/MCP integration, and physical sender/extension evidence. Import reconciliation/results/forms, direct database-save failure, Calendar, scale/paging and final native UI polish remain open.
