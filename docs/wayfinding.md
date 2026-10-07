# Working through the planner map

The canonical plan is the GitHub issue linked from the README. Read that map first when continuing planning, selecting a ticket, or evaluating completion. The original [product brief](product-brief.md) is preserved as supplied; the map's agreed boundaries govern refinements to it.

## Choose and resolve a ticket

1. Read the map's destination, notes, resolved-decision pointers, and remaining fog.
2. Select an open, unblocked, unassigned native child in sub-issue order, or the ticket named by the user. Use GitHub's native dependencies to identify blockers.
3. Assign the ticket to `dvcolomban` before work. Read prerequisite resolution comments and linked artifacts as needed.
4. Verify every definition-of-ready item. Establish the exact public test interfaces with the user before writing tests; prior explicit agreement carries forward.
5. Work the ticket using its named skill. Human decisions require the user's answers. Resolve at most one human-in-the-loop ticket per session; research tickets may run in parallel.
6. Post the answer as a resolution comment with named source/artifact links, rationale, evidence, and limitations. Preserve the original question and acceptance criteria in the issue body.
7. Close the issue and append only its named link and a short gist to the map. Read the current map before updating it so concurrent resolutions are preserved.
8. Turn newly precise questions into native child issues, then wire dependencies after creation. Remove graduated fog from the map. Revisit invalidated decisions explicitly rather than silently changing their answers.

Research uses primary sources and a throwaway `research/<name>` branch with a committed report linked from its ticket. Prototypes are temporary evidence, not production delivery. Add a glossary definition when a domain term is settled; use an ADR only for a consequential, non-obvious tradeoff.

## Ticket standard

Every ticket must contain substantive, ticket-specific sections:

```markdown
## Context
## Starting state
## Goal and question
## Expected end state
## Definition of ready
## Required tests and validation
## Definition of done
```

Context explains why the question matters and links requirements and prerequisite decisions. Starting state separates verified facts from uncertainties. Goal states one session-sized question; expected end state names observable outputs downstream work can use.

Readiness lists native blockers, access, fixtures, and confirmed interfaces where code is involved. Completion lists decisions, artifacts, validation, user confirmation where required, and map updates. Use checklists for both.

Tests identify the public interface, level, inputs, expected outcomes, and execution environment. Each scenario must have a concrete expectation by resolution; a title such as "test sync" is insufficient. For behavior still being decided, record the competing scenario and settle its expected outcome with the user rather than assuming it.

Research and grilling tickets define tests for subsequent implementation and close with evidence or an agreed decision. Code-producing prototypes close only after their required automated and device checks pass. A documentation ticket can state that unit tests are inapplicable, with a reason and its actual evidence checks. Link downstream test obligations instead of pretending they already passed.

The map is an index. Open tickets live in native sub-issues, dependency state lives in native blocking relationships, and an answer lives in its resolution comment and linked artifacts.

## Use /tdd for code

Consult the installed `tdd` skill before writing tests. Agree public test interfaces first. Work one vertical slice at a time: one failing behavior test, the minimum implementation that passes, then the next scenario. Record the red and green evidence.

Test observable behavior through public interfaces and independently specified expected values. Mock genuine external boundaries, prefer real temporary persistence stores, and avoid test-only production parameters. Use Swift Testing for unit and suitable integration checks, XCTest/XCUITest for UI automation, and reproducible physical-device procedures for CloudKit behavior automation cannot establish.

For each code-producing ticket, record commands, SDK/device versions, fixtures, results, and limitations. Run affected-target build/type checks and applicable lint before completion. Investigate failures against the change before attributing them to the baseline. Full-repository local validation requires explicit user authorization; use affected-target equivalents otherwise.

## Tracker operations

Use `gh` against `dvcol/planner`. The map has the `wayfinder:map` label. Each child has exactly one type label: `wayfinder:grilling`, `wayfinder:research`, `wayfinder:prototype`, or `wayfinder:task`.

Create child issues first, then add native sub-issue relationships and native dependencies. Dependency REST operations use a blocker's database issue ID, not its issue number. Native relationships remain canonical; use body fallbacks only when the tracker itself lacks support.

Claim with `gh issue edit --add-assignee dvcolomban`. Resolve with an issue comment and close operation. Refer to maps and tickets by their exact titles wrapped around links, not bare numbers.

Before any commit in a worktree, confirm its working directory. Keep research branches isolated. Ask before opening an upstream pull request, and open it as a draft.

## Completion

Charting is complete when the actual map and all populated children are published, their labels and native relationships verified, and the planning source is committed and pushed.

The whole map is complete only when every in-scope ticket and fog patch is resolved, required prototypes pass, and the specification's requirement-to-decision-to-test coverage is audited. Production implementation tickets inherit the resolved context, interfaces, and test obligations.
