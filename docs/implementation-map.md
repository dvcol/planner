# Native Planner implementation map

Planner is a personal native iPhone, iPad and Mac app using Xcode, SwiftUI and shared Core interfaces. Platform layouts must feel native. Quality and stability take priority over schedule; there is no deadline. Apple Calendar export remains outside this map.

This map remains open. Signing is deferred, and it is not the only remaining gate. The [decision register](https://github.com/dvcol/planner/blob/6595ecea/docs/open-decisions.md) distinguishes accepted behavior, current implementation and executed evidence. An accepted choice, successful build or isolated test does not close a broader requirement.

## Decisions and external actions needed

- **Q127, Mac Calendar presentation.** Narrowing the current inspector aborts Planner with a constraint-update exception. The reviewed alternatives are a hideable native Mac split pane, recommended, or a native sheet. The user has not chosen; failed placement/size/toolbar experiments are reverted. The iPad inspector stays unchanged. [Diagnosis and alternatives](https://github.com/dvcol/planner/blob/dc8c1789/docs/prototypes/native-calendar-mac-inspector-resize.md).
- **Current Mac readiness.** The latest Schedule UI request executes zero cases after automation initialization times out. A current awake/unlocked/idle confirmation is pending before the focused retry. Earlier actual Mac passes remain valid for their recorded epochs. Neither this failure nor Q127 establishes a signing cause. [Runtime diagnosis](https://github.com/dvcol/planner/blob/4d03fbff/docs/prototypes/native-xctest-runtime-diagnosis.md#mac-automation-and-item-startup-follow-up-22-october-2026).
- **Signing and physical access.** Account/team setup remains deferred. Q100 B requires actual signed protected storage before native Agent Control. Signed shared storage, installed Share, physical CloudKit/account transitions and device performance still need their actual capability/device evidence. Local-only substitutes do not close them.

## Current local evidence

These are implementation checkpoints with explicit limits, not release completion.

| Area | Executed evidence | Remaining scope |
| --- | --- | --- |
| Directed plan opening | [All 13 post-focus-fix production-interface cases](https://github.com/dvcol/planner/blob/9de04bdf/docs/prototypes/native-plan-opening-handoff.md) pass in both direct and ordinary Xcode-hosted Mac execution. | Actual external/cold/system activation, recipient focus and external-request draft decisions. Ordinary window/draft tests do not prove system delivery. |
| Native List header | [One shared Mac toolbar](https://github.com/dvcol/planner/blob/9de04bdf/docs/prototypes/native-list-pane-header.md#unified-top-toolbar-follow-up) owns the leading title and selected-Item actions. Six Mac cases and two mobile executions pass, including empty/populated, narrow/wide and guarded drafts. | Complete app visual/accessibility review and physical acceptance. |
| Undo and labels | [Grouped association Undo](https://github.com/dvcol/planner/blob/e8663be1/docs/prototypes/native-owned-association-undo.md#mac-follow-up-21-october-2026) passes represented Mac Command-Z/restoration/relaunch. [Label appearance/files](https://github.com/dvcol/planner/blob/fd7ee6b6/docs/prototypes/native-label-appearance.md#mac-file-follow-up-22-october-2026) pass, including six exact exports. | Native Edit-menu expiry and broader Mac import-conflict/restoration. |
| Calendar | [Three cases across Mac, phone and tablet](https://github.com/dvcol/planner/blob/b2c67502/docs/prototypes/native-calendar-day-week.md#mac-runtime-follow-up-22-october-2026), nine executions, verify date accessibility, Month/display zone, identity/relaunch, overflow and overlap. | Mac all-day span/date entry, source-row actions, Q127 resizing and broader stability. The earlier iPad startup failure and unchanged passing retry remain recorded. |
| Windowed scale | [Both retained exhaustive runs](https://github.com/dvcol/planner/blob/ba052c13/docs/prototypes/native-item-windows.md#scale-evidence-and-current-fixture-follow-up-22-october-2026) already use the windowed loader and each records 5,000 distinct identities. Current fixture page/selection/rotation checks pass on both simulators with 1,061 matching inputs. | Historical exhaustive epochs remain separate from the current focused runs. Physical memory/latency, hitches and final visual acceptance remain open. |
| Native capture HTTP | [Eight functions/nine invocations](https://github.com/dvcol/planner/blob/d3d0dd14/docs/prototypes/native-capture-http-transport.md#real-socket-follow-up-22-october-2026) pass on each of Mac and iOS. Real sockets cover HEAD, redirect, cancellation, timeout and client closure. Two documented live Mac links return HTTP 200. | General provider behavior, redirect families, protocol/allocation limits and physical lifecycle. |
| Genuine native map references | [Independent iPhone/iPad Simulator archives](https://github.com/dvcol/planner/blob/82ec576a/docs/prototypes/genuine-native-map-reference.md#ios-follow-up-22-october-2026) pass public capture/edit/save/export. Genuine references remain temporary and provider fields stay out of saved content/backups. | Actual Maps sender envelope, original URL binding and installed/physical Share. |
| Native preview SDK | [The unchanged preview package](https://github.com/dvcol/planner/blob/6595ecea/docs/prototypes/native-preview-qualification.md#ios-sdk-follow-up-22-october-2026) passes 18 functions/28 invocations per iOS simulator with real Apple image/plain metadata and fixed-address geocoding enabled. All 751 inputs and products reconcile. | Arbitrary websites, saved-app integration with these live results, physical allocation/latency and final UI review. Controlled cache tests are distinct from live SDK calls. |

Earlier failed attempts retain their failure status. Native Swift Testing counts are taken from executed cases and structured results, not a wrapper exit alone. Current captures and interface tests do not establish unexecuted physical or system behavior.

## Remaining implementation and acceptance

1. Resolve Q127 and complete the chosen Mac Calendar presentation, actual resizing and affected native regressions.
2. Retry the outstanding Mac UI workflows after readiness, including Calendar, import/restoration, keyboard/Undo and remaining compatibility cases.
3. Implement native Agent Control under Q100 B after actual protected signed-storage qualification, then verify native menus/windows and real clients against that storage.
4. Complete signed/shared-store, installed Share, CloudKit/account recovery, deletion/concurrent-edit convergence, interruption and physical performance gates. Simulator or local-store evidence cannot replace these.
5. Qualify actual Shortcuts/Siri, system picker/property/confirmation behavior, background/locked invocation and external plan opening. The Customer-build rejection does not prove a paid account fixes the system-test framework.
6. Complete the feature-complete whole-app UI pass, including light/dark, accessibility, all scene states, native controls, resizing/orientation and physical review. Existing floating-bar, repeated-title and other retained findings stay open until reviewed and resolved.
7. Reconcile the complete specification and obtain the user's final coherence/layout acceptance before handoff and closure.

Backups, import/export and account recovery remain manual administration. Agent access stays at the accepted data layer. No timer/session restriction, new scope reduction, weaker conflict policy or signing workaround is introduced by this index.

## Tickets, contracts and original scope

The existing tickets retain their Context, starting/end state, DoR, DoD and required unit/native/HTTP/physical tests. This index neither replaces those criteria nor marks them complete:

- [Apple test access, issue 7](https://github.com/dvcol/planner/issues/7).
- [Navigation prototype, issue 14](https://github.com/dvcol/planner/issues/14).
- [Sync and Share prototype, issue 15](https://github.com/dvcol/planner/issues/15).
- [MCP prototype, issue 16](https://github.com/dvcol/planner/issues/16).
- [Specification handoff, issue 17](https://github.com/dvcol/planner/issues/17).
- [Whole-app UI polish, issue 23](https://github.com/dvcol/planner/issues/23).

The complete former issue body, including original requirements and implementation history, is retained in the [readable 22 October snapshot](https://github.com/dvcol/planner/blob/86ff02f4/docs/history/decision-map-2026-10-22.md). Its [exact original source](https://github.com/dvcol/planner/blob/86ff02f4/docs/history/decision-map-2026-10-22.source.txt) and [provenance](https://github.com/dvcol/planner/blob/86ff02f4/docs/history/decision-map-2026-10-22.provenance.json) verify that no nonblank payload line changed. Only blank-line formatting differs in the readable copy.

[Verified storage cleanup](prototypes/native-local-storage-cleanup.md) retains the previous audits and the latest 0.86 GiB, 0.42 GiB and 0.20 GiB nominal-file removals. Source copies referenced by tools, needed app/UI products, native archives and datasets remain. These nominal totals do not promise an equal APFS free-space increase.
