# Native Item title and notes Intent

Status: title/notes editing is locally qualified. All 17 focused Item Intent tests pass; Mac and iPhone/iPad Simulator compilation and extracted five-action metadata pass. Actual system invocation and complete catalog parity remain separate gates.

## Context and starting state

The approved Q33 ordinary Intent catalog includes Item editing, and Q112 A approves production App Intent invocation and EntityQuery tests through the existing app-hosted target, Apple's dependency manager and disposable real Planner storage. The app currently exposes Create, Get, global completion and Archive actions, but no edit action. Core already implements partial Item edits with field-specific stale guards.

## Goal and expected end state

Add Edit Item for title and notes. Its Item parameter retains the source UUID; cached entity title and completion must not replace live values. An omitted field stays unchanged. Supplying empty notes clears notes; a supplied blank title is rejected by Core. At least one field must be supplied. The action reads the current canonical source, then submits only requested fields with Core's current field hashes. Core still compares the edited fields under its writer gate. This does not grant an external caller a long-lived stale-edit token or bypass a changed-field rejection.

The action preserves other content, links, locations, labels, archive, global completion and every local appearance. A missing source fails without resurrection. An applied change with incomplete recovery reports its actual local outcome and blocks further mutation until the native app completes recovery. Backup/export/recovery administration and source Delete remain unavailable to Intents. This slice adds no Core API, target, package, injected service or test hook.

## Definition of ready

- Q33 ordinary editing, Core's unchanged/set/clear and field-hash semantics are accepted.
- Q112 A already approves the production Intent interface and actual storage/recovery failure boundary.
- The refreshed Mac session executes the existing app-hosted and native UI tests again.
- Account and signing changes remain deferred.

## Required tests and definition of done

Use `AppIntent.callAsFunction(donate: false)` and real Core reads after reopening. First establish an executable missing-implementation red for a notes-only edit of an existing rich Item, then implement that behavior. Require the original UUID, live title, other owned content and independent global/local states to survive. Follow with title and clear-notes behavior, invalid/missing parameters, missing/deleted identities and actual recovery-save failure. Implement one behavior at a time.

Run the affected Item Intent regression class, compile the actual mobile app/native test target, inspect extracted Intent metadata, and run strict Swift formatting lint and diff/document checks. Record exact source epochs, command/result evidence and limitations. Actual Shortcuts/Siri discovery/invocation, background launch, system restrictions, shared account storage and full catalog parity remain separate gates.

## Executed vertical slices

| Behavior | Executable red | Following green |
| --- | --- | --- |
| Notes-only edit preserves the rich source and independent completion | Missing implementation throws through public Intent invocation, 0.568 s | 0.261 s; original UUID, live title, subtitle, location, link identities, estimate, references, global Done, archive and separate local flags survive reopening |
| Title-only edit retains omitted notes | Notes-only implementation rejects the title request, 0.250 s | 0.030 s; notes-only regression also passes, 0.267 s |
| Rename and explicit clear together | Nil assertion fails because empty notes were stored as an empty String, 0.391 s | Empty notes now map to Core clear; combined edit passes, 0.176 s, with both earlier edits passing |

The implemented action reads the live source and uses its returned field hashes. Only the supplied title/notes fields become changes. It uses the existing app-owned command path, admission, atomic Core validation and truthful complete/incomplete/unverified outcome handling. No duplicate editing service or alternate persistence path is added.

The required invalid-input and unavailable-identity qualification passes on first execution against that implementation, 0.065 seconds. No-field and blank-title-plus-notes requests leave every original field hash unchanged. Native reviewed deletion removes the original Item; later edits to either its cached identity or a never-existing identity fail without recreating a row.

The existing real post-save filesystem obstruction qualifies incomplete recovery in 0.199 seconds. The title and notes remain applied after reopening, the next edit is blocked with the same incomplete operation retained, native recovery retry completes that original operation without changing its content hashes, and an explicit later edit succeeds on the same source. These two qualification cases required no production correction; they are not claimed as new executable reds.

Exact frozen sources, original logs, commands and exits are retained under [the navigation compatibility evidence](evidence/navigation/native-itinerary-window-compatibility/), in the packets named `app-intent-edit-notes-executable-red`, `app-intent-edit-notes-first-green`, `app-intent-edit-title-red`, `app-intent-edit-title-green`, `app-intent-edit-clear-notes-red`, `app-intent-edit-clear-notes-green`, `app-intent-edit-invalid-identity` and `app-intent-edit-recovery`.

## Final focused adapter qualification

All 17 `PlannerItemIntentTests` execute on the final source with zero failures or skips, in 6.320 seconds. The [final regression packet](evidence/navigation/native-itinerary-window-compatibility/app-intent-edit-final-qualification/) retains the complete original log and frozen source overlay. This is the current Item adapter class, including five new edit cases, three Archive cases and the nine earlier creation/read/query/completion cases. It is not the complete Intent catalog or a full-repository test run.

The Mac app's extracted metadata declares five actions, including `EditPlannerItemIntent`, plus the existing Item entity and query. The recorded metadata digest and identifiers supply compiler/discovery-artifact evidence only. They do not prove system discovery or invocation. Mobile compilation and its extracted metadata are recorded separately below when available.

## Mobile compilation and limits

The [mobile build packet](evidence/navigation/native-itinerary-window-compatibility/app-intent-edit-mobile-build/) records the actual production app and existing native UI target compiling for generic iPhone/iPad Simulator with signing disabled. The final source overlay matches the build inputs. Its extracted metadata contains the same five Item actions, existing Item entity and query as Mac. This is compiler/metadata evidence, with no Simulator Intent invocation or physical-device runtime credit.

Strict Swift formatting lint passes the two changed Item Intent files; Markdown lint and diff whitespace checks pass. The related Mac-only Picker assertion correction is qualified separately in [the native Mac report](native-mac-session-refresh.md). No Core, backup, HTTP, entitlement, package or target contract changes are introduced here.

The action covers title and notes only. The remaining content fields, other source kinds, organization/scheduling/contextual and bulk actions still need their appropriate Intent presentation and tests. Actual Siri/Shortcuts discovery/invocation, background launch and locked/system-restricted behavior remain open. The installed Customer-build system-test restriction is not bypassed, and no signing/account setup is undertaken. Local adapter passes do not close the MCP session prototype or the map.
