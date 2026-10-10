# Native UI polish after feature completion

Status: planned in [ticket 23](https://github.com/dvcol/planner/issues/23). This pass follows feature implementation and does not replace the behavior, persistence, sync or recovery gates in the [decision map](https://github.com/dvcol/planner/issues/1).

## Context and goal

Planner must feel at home on iPhone, iPad and Mac. The navigation prototype establishes native tabs, split columns, disclosure groups and detail forms, while saved-data features are being implemented in separate slices. The user's screenshot reviews found sparse layouts, confusing progress counts, technical detail fields and a map available only in one prototype layout. Immediate behavior corrections remain in the Navigation prototype ticket.

The goal of this final pass is a coherent daily-use application built primarily with system SwiftUI components. Use Reminders for compact, checkable rows and metadata, Notes for readable content and sidebar/detail hierarchy, and Calendar for date and time presentation. Use native Liquid Glass navigation and controls; additional spacing or tint must improve hierarchy without replacing system interactions.

## State before and after

Before: all release features have their own completed behavior checks, but scenes have been built incrementally. Layout, spacing, secondary information, empty states and interaction feedback may differ across features. Prototype captures are useful references but cannot establish the final saved application's presentation.

After: every reachable product scene has been reviewed with real saved data on each supported platform. Navigation, row selection, completion, filters, progress, rich details, maps, errors and loading feedback have consistent hierarchy and accessible native controls. A compact phone presents a proper navigation stack; iPad and Mac use their available space without stretching phone layouts. Technical diagnostics remain explicitly separated from ordinary product content.

## Definition of ready

- Release feature workflows and their acceptance criteria are implemented, including the saved graph, capture, calendar, agent data access and recovery. Any unresolved behavior is assigned to its feature ticket before polish starts.
- The scene inventory includes catalogs, Inbox, Lists, Itineraries, calendar, capture/Share review, Item details, labels, settings, Agent Control and manual data administration, with empty, populated, filtered, archived, loading, failure and offline states where applicable.
- Review datasets exercise repeated itinerary appearances, live List groups, long lists, long titles, notes, links, owned locations, mixed completion/archive states, timed and all-day schedules, and unavailable previews.
- Agreed completion scopes, appearance identities, cumulative filtering, full-scope progress, saved Manual order and per-device presentation preferences are recorded and protected by existing behavior tests.
- Simulator and local Mac builds are reproducible. Signing and physical devices are available before the physical review portion is signed off; their availability does not block preparation or local review.

## Work and definition of done

- Review the whole scene inventory and record the component used, issue found, correction and evidence for each platform. Prefer NavigationSplitView, TabView, List/Table, Form/Section, Menu/Picker, Toolbar, DisclosureGroup, ProgressView and ContentUnavailableView wherever they fit the task.
- Make Item rows checkable with compact useful metadata. Distinguish live List groups with readable headers, child indentation and full-scope progress. Explain filtered counts separately from completion totals and container composition. Archive visibility remains an explicit cumulative filter.
- Keep useful details in the selected pane or phone stack. Show available owned-location maps and website previews without hiding content when a provider fails. Do not introduce eager network requests for offscreen rows or copy provider caches into backups.
- Review navigation, contextual menus, keyboard shortcuts, focus, drag/drop, selection after refresh, cancellation, confirmations, loading and errors with the finished saved-data workflows. Preserve the scope and outcome of each existing command.
- Inspect phone and tablet portrait/landscape, iPad split widths, and narrow/wide Mac windows. Verify readable content, nontruncated controls, stable selection and appropriate use of available space.
- Review VoiceOver reading order and labels, Dynamic Type on mobile, keyboard-only operation on Mac, contrast, Reduce Motion and Reduce Transparency. Grouping must remain understandable without color alone.
- Compare long-list responsiveness and memory with the established feature baseline. Fix any regression introduced by presentation changes and retain the existing performance acceptance thresholds.
- Attach final captures of representative populated, empty, filtered and error states. Complete local and physical review records with actual destinations and limitations; unresolved acceptance failures keep this ticket open.

## Required tests and other validation

Use `/tdd` for behavior changes found during polish. First reproduce the specific user-visible failure at an agreed public native UI, Core or provider I/O boundary, observe it fail, then make the smallest correction and rerun affected journeys. Examples include a row checkbox targeting the wrong appearance, filtering changing progress, a valid selection being lost, an ordinary location detail omitting its map, and a provider failure hiding saved content.

Retain meaningful existing unit/store tests for command scope, identity, completion precedence, filtering, order and recovery. Add unit tests only when a new behavior belongs to the public Core interface. Do not add tests that mirror SwiftUI structure, assert padding/color constants or compare screenshots as a substitute for reviewing readability.

Run affected Swift formatting/lint, compiler checks and focused native UI journeys on Mac and both simulator form factors after each relevant correction. Inspect their actual captures. Perform the final accessibility, keyboard, resizing/orientation and physical-device review separately, recording evidence and any unavailable checks. The test report must distinguish executable behavior proof from visual judgment and live network/provider availability.

## Dependencies and completion boundary

Depends on the finished saved feature work and qualification tracked by [Navigation prototype](https://github.com/dvcol/planner/issues/14), [Sync and Share prototype](https://github.com/dvcol/planner/issues/15), [MCP prototype](https://github.com/dvcol/planner/issues/16) and [Specification handoff](https://github.com/dvcol/planner/issues/17). The map remains open until its release gates are met. This ticket is complete only after the whole final application has passed the review above; completing a prototype screenshot correction does not complete it.
