# Native Item Archive Intent

Status: the action is implemented; Mac and iPhone/iPad Simulator compilation pass. Its executable red is recorded; green validation is pending after two XCTest startup attempts fail to enter a test. Actual system invocation remains a separate gate.

## Context and goal

At `b0ee38ef`, App Intents can create and read Items or change their global completion. They cannot archive or unarchive an Item, although ordinary archive authority is accepted under Q33 and the canonical Core command already exists.

Add one native action using that same Item identity and Core command. Archive changes the shared Item's visibility and derived plan progress; it preserves its content, references, global Done and each appearance's retained local Done. Unarchive reveals those retained states. A cached shortcut title or state must not select a different source.

## Readiness and test boundary

Q112 A already approves invoking production `AppIntent.callAsFunction(donate: false)` and EntityQuery interfaces in the existing app-hosted target. Use Apple's dependency manager, disposable real Planner storage, canonical reads after reopening and the existing real recovery-filesystem failure. No new test interface, target, dependency or persistence path is required. This action adds no backup, export, recovery administration or Delete authority.

Signing/account changes stay deferred. Local ad hoc Mac execution qualifies the adapter, not installed system discovery, automatic dependency injection, background launch or locked-device behavior.

## Implementation

The action accepts an Item entity and the desired Archive flag, then submits Core's existing `setArchive` command using the entity's identity. It does not use the entity's cached title, completion or archive values. Execution stays in the main app with the accepted background and authentication policy. A rejected command throws its actual reason; an unverified outcome stays explicit. Complete and recovery-incomplete results have different dialogs, and the latter reports that the change applied locally without claiming a complete recovery copy.

## Local evidence

The first test invokes the production action with two real List memberships, one locally Done and one Todo. The missing implementation throws through Apple's public invocation in 0.577 seconds, establishing an executable red. The test then requires archive/unarchive to retain the original source, notes and membership identities with those separate local flags after reopening the store.

After implementation, the Mac app and app-hosted test target compile. The production mobile app and existing native UI-test target also compile. Extracted app metadata on both platforms contains the fourth Item action alongside the existing Create/Get/Global Completion actions, Item entity and query. Both affected source hashes match each final compilation/startup epoch. This is compiler evidence only.

The first green attempt launches the host but records no Test Case start. A one-second sample locates the wait in XCTestDriver's IDE-session setup, before the test body. The same Intent-registration warning appears in the executable red, so that warning alone does not establish this startup failure's cause. The owned attempt is stopped and a bounded retry uses the same compiled test without rebuilding. That repeat times out after 240 seconds before any test starts. Both attempts receive no green credit; owned hosts are closed, with no system-service or signing changes. Source epochs, logs, actual startup sample and interrupted outcomes are retained under [navigation compatibility evidence](evidence/navigation/native-itinerary-window-compatibility/).

The current Mac availability answer is pending. Do not infer an Archive regression or successful behavior from these startup attempts. Strict lint on the two changed Swift files and diff whitespace checks pass. The remaining scenarios below must still execute before this slice is qualified.

## Required completion evidence

- Executable red through the production Intent interface, followed by archive/unarchive persistence with the original source and membership identities, content and independent completion.
- Missing or deleted identities fail without creating or resurrecting data.
- An applied change with incomplete recovery retains its real state, blocks the next mutation and supports explicit native recovery retry without applying the archive twice.
- Focused existing Intent regressions, affected native compilation, strict Swift lint and Markdown/diff checks.

Actual Siri/Shortcuts invocation, complete adapter parity, CloudKit/account integration and physical-device qualification remain open on the map.
