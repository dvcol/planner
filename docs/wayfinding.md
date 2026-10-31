# Working through the Planner map

The [Native personal planner decision map](https://github.com/dvcol/planner/issues/1)
is canonical. Read its destination and notes before choosing work. Its native
child issues and blocked-by relationships define the current frontier.

## Current destination and execution boundary

The user carried execution into this map. Its destination is now an implemented,
reviewed core V2 daily-use MVP with explicit human acceptance. The accepted
[release amendments](release-goals.md) govern scope. Advanced portability and
restoration, installed Mac Share, further iCloud stress checks and V3 system/agent
integration are outside the current frontier; preserve their evidence and limits.

The map is a low-resolution index, not a chronological progress log. Keep only
Destination, Notes, Decisions so far, Not yet specified and Out of scope in its
body. Open tickets are native children, not another body checklist. Detailed
answers belong in their resolution comments and linked assets. The local
[implementation map](implementation-map.md) mirrors that index; its linked
checkpoint archives are historical evidence, not competing task queues.

## Choose and work a ticket

1. Read the map, then choose an open, unblocked, unassigned native child in
   sub-issue order, or the ticket the user named.
2. Claim it by assigning `dvcolomban` before work. Read its type label,
   prerequisites, question and existing resolution context.
3. Check readiness. Prior explicit interface, test-boundary and action approvals
   carry forward; do not repeatedly request them. Device availability and manual
   automation approval are separate from signing readiness.
4. Use the ticket's named workflow. A new human decision requires the human's
   answer; an agent must not infer final layout or daily-use acceptance.
5. Post the answer as a resolution comment with named evidence links and exact
   limitations. Close only when that ticket's applicable criteria pass.
6. Add a named context pointer and short gist to Decisions so far. Scope
   dispositions belong in Out of scope. Preserve the current map when updating
   it so another session's changes are not lost.
7. Create newly precise child tickets first, then wire native dependencies.
   Unformulated in-scope questions remain fog; known deferred work does not.

Resolve at most one new human-in-the-loop decision per session. The user's
explicit bulk-cleanup request permits administrative reconciliation of already
completed setup, duplicate tickets and accepted scope changes; it does not
permit inventing human answers or claiming missing acceptance passed.

## Ticket standard

Each child carries exactly one type label: `wayfinder:research`,
`wayfinder:prototype`, `wayfinder:grilling` or `wayfinder:task`. Use no triage
labels on map tickets. Name tickets in human-facing prose and wrap their links
around those names; do not substitute bare numbers or slugs.

Keep a precise `Question` and substantive ticket-specific Context, Starting
state, Expected end state, Definition of ready, Required tests and validation,
and Definition of done. Checklists identify observable outcomes and actual
prerequisites. A task earns its place by unblocking a decision or the expressly
authorized MVP acceptance, not by expanding the destination.

A historical prototype can be consolidated when its remaining review has one
explicit successor. Post the disposition, preserve its original question and
evidence, and close as superseded/not planned rather than pretending every
original criterion passed. Close an out-of-scope ticket as not planned and
retain its context in the map's Out of scope section. A future effort charts a
fresh frontier rather than silently reopening the deferred work as MVP.

## Native tracker operations

Use the matching authenticated connector where sufficient. The repository's
configured `gh` is the fallback for unavailable connector capabilities or write
permissions. Always target `dvcol/planner` explicitly.

- The map carries `wayfinder:map`; its tickets use native sub-issue relationships.
- Read sub-issues with `GET /repos/dvcol/planner/issues/1/sub_issues`.
- Read blockers with `GET /repos/dvcol/planner/issues/{number}/dependencies/blocked_by`.
- Add/remove blocking relationships with GitHub's native dependency endpoints.
  They require the blocker's database issue ID, not its issue number.
- Create tickets before wiring edges. Reject self-dependencies and cycles.
  Independent acceptance tickets must not wait for each other unnecessarily.
- Preserve unrelated assignees/edits and check current bodies before replacing
  them. Keep an exact before snapshot when condensing large historical bodies.

Use structured JSON or body files for writes, then read back issue state,
labels, native parents and dependencies. A successful command alone is not
proof that the intended frontier is visible. A body convention is appropriate
only if the tracker itself lacks native dependencies.

## Code and verification

Load `code-quality`, `code-architecture` and `code-testing` when applicable.
Use TDD when the user requests it. Reuse already approved public Core, native UI
and provider boundaries; no test-only production controls to ease acceptance.

Follow the accepted [Build workflow](https://github.com/dvcol/planner/issues/18):
committed native Xcode configuration, shared schemes, local Swift packages and
pinned dependencies. Use serial affected-target builds/tests. Record actual
source/product versions, destinations, discovered/executed cases and original
captures. Inspect real readability; compilation, wrapper success or a metadata
preview does not establish native behavior.

Reuse passing evidence unless a relevant change, defect or unresolved concern
justifies more work. Distinguish functional results, visual judgment, provider
availability, Simulator behavior and physical/system acceptance. Preserve failed
attempts and investigate current changes before calling a failure pre-existing.
Documentation-only tracker cleanup needs link/state/graph/evidence checks, not
another application, device or iCloud suite.

## Publication and completion

Before staging or committing, confirm the repository working directory and
follow the personal Git instructions. Ask before opening an upstream PR and
create it as a draft. Tracker-maintenance authorization does not itself publish
all unrelated local application commits; identify unpublished checkpoints
honestly and avoid links to nonexistent remote artifacts.

New charting is complete when the map, child tickets and native relationships
are published and verified, with its planning artifacts committed and pushed.
For an existing-map cleanup, verify the published tracker changes and commit
its local mirror/history; record any source/evidence publication still pending
in the final handoff ticket.

The MVP map closes only after its in-scope acceptance children resolve and the
human gives the final daily-use/coherence approval. Deferred work and recorded
coverage limits remain explicit; administrative issue cleanup is not release
acceptance.
