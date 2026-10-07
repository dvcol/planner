# Planner

A personal native planning app for iPhone, iPad, and Mac. The project is currently finding its way to an implementation-ready specification.

- [Native personal planner decision map](https://github.com/dvcol/planner/issues/1) is the canonical plan. Read it first when continuing the project.
- [Product brief](docs/product-brief.md) preserves the original requirements. The map records the agreed scope refinements.
- [Working through the map](docs/wayfinding.md) defines ticket readiness, completion, research, prototypes, and `/tdd` expectations.

The agreed stack is Swift, SwiftUI, SwiftData with private CloudKit sync, and native MapKit, targeting iOS, iPadOS, and macOS 27 or newer. Shared domain services will support the UI, App Intents, and temporary localhost MCP sessions.

The accepted [Build workflow](https://github.com/dvcol/planner/issues/18) uses a committed native Xcode project and Swift Package Manager. Runnable projects and build/test commands will be introduced with the prototypes; this checkout currently contains planning documents.

Open decisions are native child issues of the map, with native blocking dependencies. Start with the first unblocked, unassigned child, or the decision named by the user.
