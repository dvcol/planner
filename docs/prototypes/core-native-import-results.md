# Saved native import summaries

The saved native operation result now retains the import summary accepted in the portable-data contract. Review categories and input paths remain intact. After summaries and dependency lifetimes come from the verified applied graph, including explicitly restored identities.

## Context and goal

Before this change, import review described additions, conflicts, replacements, deletions and restoration, but the receipt returned only generated and affected identities. A caller reopening Planner or checking an operation could not recover that explanation.

After this change, `PlannerAppliedResult.importSummary` contains the same eight categorized arrays. Before summaries preserve the reviewed state; after summaries describe saved content and associations. Replay returns the original result after later native edits. Ordinary results have no summary, and older result evidence without the optional field still decodes. MCP administration remains forbidden.

## Readiness and completion

The agreed Core public boundary, native import execution, reviewed restoration and independent recovery were already available. This step uses those interfaces and adds no test-only injection or database model fields. Storage schema 16 and portable format 2 remain unchanged.

Completion requires saved summaries through execute, reopen, status, replay and recovery retry, with actual restored lifetimes and unchanged ordinary-operation serialization. Native import forms, broader family reconciliation and other remaining map gates are separate work.

## Tests

Four new public-boundary test functions cover five invocations:

- Full fixture import retains all eight categories, explicit null fields, seven source additions and deletion metadata. Result encoding round-trips; reopen, status, replay and recovery retry retain the same result without changing exported data.
- Explicit restoration reports the saved Item lifetime in the restoration and referring List dependencies. The regression first failed with the obsolete predecessor lifetime.
- Skip and Overwrite classify a changed Item, six unchanged owners and one new Tag. A later native title edit survives replay, which returns the original import summary. Ordinary edit receipts omit the summary.
- A real post-save recovery obstruction leaves the summary in committed evidence. Reopen reports incomplete recovery; retry repairs its checkpoint without reapplying imported data.

Existing source-deletion and owned-reference-removal matrices also compare saved deletion summaries with their reviewed impacts. Their independent expected graphs, recovery and reopen assertions remain in place.

The initial test failed because the result lacked `importSummary`. A compiler failure from private coding keys in a separate extension file was corrected by keeping those encoders beside their declarations. Both diagnostic logs are retained.

## Qualification

macOS and iPhone Simulator each passed 123 Core functions in 55 suites, covering 345 invocations. The native HTTP regression passed 16 functions in four suites, covering 22 invocations. Failures and skips were zero. Eight affected Swift files passed strict lint. The Mac app and navigation test host compiled successfully. No native UI runtime was exercised for this Core change.

[Evidence](evidence/navigation/core-native-import-results/execution.json) records commands, source hashes, red/green logs and completed Xcode result summaries.

Incoming candidate/family consolidation, broader rebinding, origin/provider persistence, native import forms, complete generated/affected result coverage and direct database-save failure proof remain open. Physical CloudKit convergence, account changes, Share, Calendar and whole-app polish are not qualified by this step.
