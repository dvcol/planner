# Planner

A personal native planning app for iPhone, iPad, and Mac. The project is currently finding its way to an implementation-ready specification.

- [Native personal planner decision map](https://github.com/dvcol/planner/issues/1) is the canonical plan. Read it first when continuing the project.
- [Product brief](docs/product-brief.md) preserves the original requirements. The map records the agreed scope refinements.
- [Working through the map](docs/wayfinding.md) defines ticket readiness, completion, research, prototypes, and `/tdd` expectations.
- [Release goals](docs/release-goals.md) records the accepted V0–V3 stages, native platform expectations, and quality gates. V2 is the first daily-use release; there is no deadline.
- [Glossary](GLOSSARY.md) records the planner's domain terms. [Planner vocabulary](docs/planner-vocabulary.md) records accepted state, membership, shared-label and reference behavior, with concrete future test obligations.
- [Duration and search](docs/duration-and-search.md) records accepted estimate units/pickers, cumulative filters, lexical matching, remembered sort controls and long-list quality gates. [Search fixtures](docs/search-fixtures.md) supplies exact future test inputs and result sequences.
- [Itineraries and scheduling](docs/itineraries-and-scheduling.md) records flat composition, repeated live references with independent local completion, schedule forms and instant-preserving planning-zone edits. [Completion scopes](docs/completion-scopes.md) records global precedence and local-only bulk actions; progress counts independently completed item appearances, including repeats.
- [Offline conflicts and recovery](docs/offline-conflicts-and-recovery.md) records Archive plus confirmed Delete with no Trash, contextual completion retention, deletion precedence, unique memberships, converged order, data-only JSON backups, reviewed Skip/Overwrite imports, whole-invalid-file rejection, separate account recovery and truthful save/status policy. Concrete future tests distinguish product requirements from unproven Apple runtime behavior.
- [URL and share capture](docs/url-and-share-capture.md) records accepted link/identifier-first capture, editable review, text/mixed-input handling, destinations, duplicate/reuse choices, temporary lookup previews, cancellation/replay and local save behavior. Exact public interfaces/limits and native UI/runtime proof remain architecture, contract and prototype gates.
- [Core architecture](docs/core-architecture.md) records accepted A1-A22. The [approved blueprint](docs/architecture-blueprint.md) fixes project/package ownership, records and focused native commands. The [approved architecture packet](docs/architecture-review-packet.md) defines concrete public fields/methods, native validation, reference/provenance ownership and prototype evidence. Runnable projects, compilation and runtime feasibility remain prototype gates.
- [Shared command contracts](docs/shared-command-contracts.md) is an in-progress review of integration authority, wire formats, capture limits, Agent Control and MCP client behavior. Its Contract Q1-Q26 choices are accepted with the later amendment removing maximum duration, idle expiry and countdown: access stays enabled until Stop or app quit. Q27 selects field-hash edit guards and Q28 accepts a same-app credential reader. Q30 C removes extra app-imposed client/request caps, retaining concurrent-client proof and measured capacity. Modern MCP compatibility and final contract review remain open; approved Core behavior carries forward.

The agreed stack is Swift, SwiftUI, SwiftData with private CloudKit sync, and native MapKit, targeting iOS, iPadOS, and macOS 27 or newer. Shared domain services will support the UI, App Intents, and manually enabled localhost MCP access.

The accepted [Build workflow](https://github.com/dvcol/planner/issues/18) uses a committed native Xcode project and Swift Package Manager. Runnable projects and build/test commands will be introduced with the prototypes; this checkout currently contains planning documents.

Open decisions are native child issues of the map, with native blocking dependencies. Start with the first unblocked, unassigned child, or the decision named by the user.

Planner's own calendar, private iCloud synchronization and JSON portability are included. [Apple Calendar export](docs/itineraries-and-scheduling.md#accepted-export-scope-scheduling-q7) is deferred outside the current V0-V3 map.
