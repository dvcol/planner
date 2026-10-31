# Core capture draft edits

`updateCapture(session:draftId:generation:edit:)` edits an unsaved Core draft. Own field edits, link replacement, input removal and retained direct-input retry return a fresh generation without writing an Item, membership, receipt or recovery checkpoint. Storage schema remains 18 and portable format remains 2.

## Context and goal

[Direct preparation](core-capture-preparation.md) returned a read-only proposal. A caller could read or cancel it, but could not correct content, remove a blocking input or retry a retained value through the accepted facade.

This step makes that proposal editable under the [capture contract](../adapter-contract.md#capture-preparation-and-apply). The result retains the draft identity, exact original URLs and surviving draft-link identities. Failed edits leave the previous generation and complete draft unchanged. Saved content remains unchanged throughout this lifecycle.

## Definition of ready

Q33 accepted the public facade, C1-C16 define capture ownership and cancellation, and Contract Q16 defines intake budgets. Tests use the confirmed public Core/native store boundary. Existing typed Item changes and validators remain the source of field rules; callers cannot supply origin flags. No test-only production dependency or additional package was added.

## Definition of done for this step

- Own title, subtitle, notes, location, estimate and label selections are editable. Category/Tag identities must resolve against the current dataset. Explicit edits and optional clears survive later input rebuilding.
- Link replacement supports retained draft identities, ordering, labels and new links. Retained identities must belong to this draft. New identities survive subsequent edits. Exact duplicate original strings collapse once; edited links respect the 128 distinct-link bound.
- Input removal retains original input indexes and preserves links still supplied by another path. Explicit overrides remain independent of the removed input. Retrying an immutable retained direct value reevaluates it without resetting own edits or making a network request.
- Byte-discarded oversized input retains its issue/index without retaining its raw value. It can be removed; retry explains that it must be prepared again. No action silently drops a blocking supported input.
- Every successful edit rotates generation and refreshes exact-link reuse candidates. Stale edits/cancellation cannot alter the current draft. Preview returns to `notRequested`; this step does not launch provider lookup.
- An automatic `Saved link` title follows usable links. Removing the last link clears that fallback and disables saving. Adding a link to an empty draft restores it. An explicitly entered title survives, including an explicit title whose text is `Saved link`.
- Validation, unknown indexes, conflicting remove/retry actions, foreign link identities and over-budget edits reject together. No failed edit changes content, links, issues, save eligibility or generation.

## TDD and review

Eight public-boundary functions cover 19 invocations. They verify field edits and stale generations, oversized-input removal, overlapping input paths and explicit clear, link identity/order across subsequent edits, retained-input retry, nine rejection cases, edited link counts 127/128/129, and automatic versus explicit titles starting from both empty and URL-only drafts. Full native exports remain unchanged after successful and rejected edits.

Red/green traces establish the absent facade, input removal, link editing, retry/admission and edited-link budget behavior. Spec review found that explicit link replacement left the automatic title stale. A public regression reproduced the failure before the fix; it now covers both last-link removal and supplying the first link. Standards and Spec rechecks reported no remaining confirmed findings in this slice.

## Qualification

Mac and iPhone Simulator each passed 153 affected Core functions in 68 suites, covering 405 invocations. Native HTTP passed 16 functions in four suites, covering 22 invocations. Failures and skips were zero. Four affected Swift files passed strict lint; the Mac app and navigation test host compiled successfully.

Execution evidence records commands, final source hashes, completed result summaries, test trees and red/green logs. Native UI runtime and physical Share/capture execution remain unqualified.

## Remaining map work

Core-owned NSItemProvider loading and classification, provider-count/concurrency/deadline/peak-allocation proof, Maps lookup and obsolete callbacks, reviewed durable create/reuse with atomic memberships, native capture review and Share/Intent/MCP integration remain required. Retried direct values are not proof of native provider retry. Import reconciliation/results/forms, direct database-save failure, Calendar, scale/paging, physical sync/account/Share and final native UI polish remain open.
