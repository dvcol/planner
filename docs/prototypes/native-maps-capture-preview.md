# Native Maps capture preview

## Context and goal

Core and MCP can resolve a selected Maps link through the bounded production HTTP transport. Native capture review previously showed only owned fields and bookmarks, without the temporary place preview, map or lookup controls.

This slice adds the preview to the existing native review Form. It reuses the Item location Map, keeps provider fields temporary, and saves only independently supplied content and original bookmarks. Several Maps links have a native source Picker. Edited links require explicit refresh; failed or invalidated lookup offers Retry. Add and Cancel remain available during network lookup.

## Definition of ready

- C1 and C10–C12 in [URL and Share capture](../url-and-share-capture.md) settle retention, stable source order, bounded automatic lookup, partial Add, explicit Retry and obsolete callbacks.
- Q52 accepts the dedicated fixture application and native UI journeys. Q78 accepts the real production HTTP transport boundary used by its controlled provider fixture.
- The qualified [Core Maps lookup](core-maps-capture-lookup.md) owns URL eligibility, HEAD redirects, deadlines, draft generations and save/cancel protection. The native adapter adds no independent provider parser or retention policy.

## Definition of done for this slice

- Automatically request the initial supported Maps link after capture preparation. Present native loading, place text, attribution and coordinate map where supplied.
- Select among supported Maps links in stable review order without combining places or changing owned fields.
- Hide a preview as soon as its links change. Explicit refresh stages edits through Core, adopts successful draft generations, preserves deliberate titles and reconciles an untouched automatic title.
- Repair selection after normalized edits introduce or remove Maps links. When none remain, remove the preview section without querying a removed identity.
- Keep explicit Retry after failure or invalidation, including an edit reverted while lookup is pending. Reject obsolete UI results even if the original input is restored.
- Add during lookup saves one partial Item; Cancel saves none. Provider content does not enter saved fields after relaunch.
- Run affected native journeys, relevant existing capture regressions, strict Swift lint and native platform compilation. Record outcomes separately from live-provider, physical and Mac UI runtime qualification.

## TDD and qualification

The initial native journey reproduced the absent preview. Subsequent failing journeys reproduced the absent multi-link Picker and a stale preview after editing its URL. Review found an automatic-title and draft-generation reconciliation gap; the iPad removal/refresh journey reproduced Add remaining enabled for an empty automatic-title capture. That journey passed after successful edits were adopted before guarding the later preview response. A further controlled-delay journey reproduced missing Retry after an edit was reverted while lookup remained pending.

Early test attempts also exposed text-versus-button selectors, replacing a field by a query tied to its changing value, and native Select All being absent for a short URL. The helper uses native selection with a triple-tap fallback and verifies the complete replacement value. These were test corrections, distinct from the product failures. The initial regression command selected the wrong scheme and ran no tests; qualification uses the existing PlannerNavigation scheme.

The final fixture run passed all nine functions on both iPhone and iPad, with no failures or skips. Four existing capture regressions also passed on the final iPhone production build. The qualified selection therefore contains thirteen functions across three suites on iPhone and nine functions in one suite on iPad. Earlier passing regressions and failed diagnostic runs are recorded separately and excluded from those counts.

Four changed Swift files passed strict lint. The final macOS production app built successfully; Mac UI runtime was not executed. Both source and spec reviews found no remaining confirmed findings after the corrections. Four original screenshots were visually inspected for the native map, source selection and adaptive review Form. [Execution evidence](evidence/navigation/native-maps-capture-preview/execution.json) records the completed bundle summaries, exact function outcomes, diagnostics, source/product hashes and original screenshots. Source hashes were checked after all build/test processes exited.

## Remaining map gates

These are the gates at this original checkpoint. [Later native HTTP qualification](native-capture-http-transport.md#real-socket-follow-up-22-october-2026) adds real-socket outcomes and two live long-link observations; it does not replace native preview, short-link, physical or signed qualification.

The controlled fixture supplies HTTP status and headers through the actual Core transport composition. It does not qualify live provider services, real network allocation/deadline behavior, physical Share payloads or signed-device capture. Mac UI runtime, provider intake, Share and App Intents, changed-target/save/read failure and termination fixtures, Calendar Q79–Q81 with pending Q82, moving-window performance, physical sync/account recovery and whole-app polish remain open.
