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
- [Core architecture](docs/core-architecture.md) records accepted A1-A15 and pending A16-A20. The [architecture blueprint draft](docs/architecture-blueprint.md) proposes project/package ownership, records, public command/query outlines and focused native build/test commands. Public interfaces and runtime feasibility remain review and prototype gates.

The agreed stack is Swift, SwiftUI, SwiftData with private CloudKit sync, and native MapKit, targeting iOS, iPadOS, and macOS 27 or newer. Shared domain services will support the UI, App Intents, and temporary localhost MCP sessions.

The accepted [Build workflow](https://github.com/dvcol/planner/issues/18) uses a committed native Xcode project and Swift Package Manager. Runnable projects and build/test commands will be introduced with the prototypes; this checkout currently contains planning documents.

Open decisions are native child issues of the map, with native blocking dependencies. Start with the first unblocked, unassigned child, or the decision named by the user.

Planner's own calendar, private iCloud synchronization and JSON portability are included. [Apple Calendar export](docs/itineraries-and-scheduling.md#accepted-export-scope-scheduling-q7) is deferred outside the current V0-V3 map.
