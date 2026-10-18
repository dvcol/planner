# Native UI polish after feature completion

Status: final review planned in [ticket 23](https://github.com/dvcol/planner/issues/23). The human brought forward a [navigation and appearance slice](prototypes/native-design-pass.md) on 18 October; its findings and evidence do not close the final review. This pass follows feature implementation and does not replace the behavior, persistence, sync or recovery gates in the [decision map](https://github.com/dvcol/planner/issues/1).

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

## Observations retained from compatibility checks

The [New Item Dynamic Type slice](prototypes/native-new-item-dynamic-type.md) supplies sixteen inspected ordinary/maximum-size phone/tablet captures and passing interaction/persistence journeys. At maximum size, review the tablet's broken-word Estimate/Remaining summaries, truncated Item-row metadata and long single-line place/address/URL inputs. Review the phone's content around its floating native TabView while scrolling. The fields remain operable in the represented journey, but these captures do not establish full readability, accessible scene hierarchy or visual acceptance. Revisit these concrete states during this pass using native adaptive layouts, without reducing the user's selected text size.

On 17 October the user also identified odd spacing above content around the floating native navigation bar. Review the combined TabView, NavigationSplitView, toolbar, search and safe-area layout in populated and scrolled states. Check phone/tablet portrait and landscape, compact widths and large text. Compare the system-reserved space with app-added insets before changing layout; remove redundant spacing where found. Preserve unobscured rows, reachable controls and the platform's native floating navigation behavior. Record original before/after captures and functional resizing/scroll checks, rather than tests for padding constants. This is an explicit polish requirement, not a visual acceptance already met by the compatibility runs.

The retained [iPad catalog capture](prototypes/evidence/navigation/native-item-windows/tablet-window-row-rotation/26C2A899-682A-46D0-82DA-2BE022E282A8.png) shows three stacked elements at the top: the floating main tabs, the column toolbar/search controls and a large detail title. The same Item title is repeated in the first Form section. Review title display modes and toolbar placement together with the top spacing. The current root uses native TabView around NavigationSplitView; this observation does not establish that removing a safe-area inset is the right correction.

Apple's title modes provide a native way to review this hierarchy. The [large toolbar title mode](https://developer.apple.com/documentation/swiftui/toolbartitledisplaymode/large) places the title below the navigation bar at the top of scrolling content; [inline navigation titles](https://developer.apple.com/documentation/swiftui/navigationbaritem/titledisplaymode/inline) stay within the standard bar bounds. Compare those modes at regular widths before adding or subtracting manual top padding. This is an investigation candidate, not proof of a spacing fix. The [sidebar-adaptable TabView style](https://developer.apple.com/documentation/swiftui/tabviewstyle/sidebaradaptable) also provides a top bar/sidebar choice on iPad, but adopting it changes navigation presentation and is not assumed necessary to fix the observed gap.

The [phone draft layout capture](prototypes/evidence/navigation/native-schedule-time-input/phone-clock-endpoint-qualified-attempt/59495FDE-21CD-4737-A43A-5C4778D196E2.png) shows the floating bottom TabView overlapping the Add Link area in landscape. Review native bar visibility and scroll safe-area behavior for the pushed New Item editor as part of the same spacing pass. The longer-allowance journey formally passes its field, identity, original-List and relaunch checks. That functional result does not establish full visual acceptance. Earlier teardown-timeout evidence remains recorded separately.

The [native clock-input captures](prototypes/native-schedule-time-input.md) also retain raw planning-zone identifiers, a technical "resolved time" footer and duplicated Item titles. Review their wording and hierarchy in the final pass while retaining the date-specific occurrence abbreviations and UTC offsets needed to distinguish repeated times.

The final iPad compatibility run makes the spacing difference visible across destinations: compare [Itinerary content](prototypes/evidence/navigation/native-schedule-time-input/tablet-clock-itinerary-and-catalog-compatibility/045D3E2C-4C55-4847-84F5-D8ED91067A37.png) with [Item details](prototypes/evidence/navigation/native-schedule-time-input/tablet-clock-itinerary-and-catalog-compatibility/1C293DE8-3C58-43E0-B506-E46B2886E28F.png). The Itinerary toolbar starts farther below the floating tabs. Review the scene's navigation/toolbar hierarchy before applying manual spacing. This records the observed difference; its cause and correction still need qualification.

## Navigation and appearance correction brought forward

The [18 October native design review](prototypes/native-design-pass.md) replaces the regular iPad's floating-tab/per-destination-sidebar stack with one Notes-style native sidebar and panes, retaining system bottom tabs on iPhone. Native inline toolbar titles and readable List/Itinerary content headings remove the extra title tier and retain context when controls crowd the toolbar. Native Form/List surfaces follow device appearance. The review also repairs lost Itinerary presentation state, hidden List-catalog navigation and Calendar inspector dismissal during rotation. Its report links the executed light/dark mobile journeys, original representative captures, source reviews and compiler/runtime limitations.

These observations supersede the earlier unresolved layout candidate for that specific tablet shell. They do not close the phone scroll/large-text observations, all scene/state visual review, accessibility, Mac runtime or physical qualification. The original requirements and historical captures remain available above; final ticket 23 acceptance still follows the full inventory and gates.

## Follow-up native refinement

The requested [native UI refinement](prototypes/native-design-refinement.md) removes redundant sidebar hierarchy, uses plain collection rows beside grouped detail Forms, adds direct global completion to Item/Inbox rows and compacts the empty Calendar agenda with a native GroupBox. It also improves title wrapping, completed-title treatment and List-heading contrast using semantic styles. Its report distinguishes executed mobile checks and inspected captures from source-only review and deferred Mac/physical/accessibility acceptance.

The same refinement report now includes a native pane consistency follow-up. It aligns contextual touch targets, uses inline itinerary detail titles, corrects inherited faint header text and stacks estimate metrics at accessibility sizes. Selected dark phone/tablet, filtered drag/drop, independent completion and maximum-text creation/relaunch checks supply focused evidence. Complete scene/state review, Mac runtime, physical devices and the remaining accessibility checks still gate final ticket 23 acceptance.

## Settings and capture appearance checkpoint

The [focused scene review](prototypes/native-scene-appearance.md) adds dark phone/tablet Settings, Manage Labels, Review Capture and saved native Maps-card evidence. It fixes an outdated phone-tab assumption in the capture test controller and records the actual staged editor, without changing production behavior. The report preserves the failed iPad attempt, separate passing label results, final capture/map journeys, inspected captures and compiler-only Mac result. Technical Maps wording, selected-row metadata contrast and floating-bar scroll readability remain review candidates; these checks do not close final scene, accessibility, physical or Mac runtime acceptance.

## Selected-row contrast finding

The [native selected-row diagnosis](prototypes/native-selected-row-accessibility.md) retains the reproducible dark iPad contrast failure and minimal stock-row comparison. Accepted Q99 A is followed by the [foreground correction](prototypes/native-selection-contrast-fix.md), with passing represented light/dark phone and iPad checks. Dark iPad Increase Contrast still flags bottom-row text beneath Capture; Q101's toolbar grouping choice remains pending. The correction preserves native controls and supplies no whole-app accessibility acceptance. The [Maps wording correction](prototypes/native-maps-preview-copy.md) separately replaces technical warnings with plain language without changing provider-data semantics.

The [current native access review](prototypes/mcp-native-access-readiness.md) records a further bounded Mac attempt against the current compiled source. XCTest again fails before any Test Case starts, so it adds no Mac UI credit. Native Agent Control/menu-bar scenes remain unimplemented. Accepted Q100 B defers that feature until signing and working Mac UI automation; the alternative credential-I/O interface is unapproved. This remains feature work before final whole-app polish.

The subsequent [Q101 native Add menu](prototypes/native-catalog-add-menu.md) groups New Item and From Link or Text in Items/Inbox, preserving separate Filters and Sort. Its dark increased-contrast iPad checks resolve the recorded Capture overlap. The unlocked Mac now passes the actual Capture/save/relaunch journey after correcting native popup assertions and the saved duration's static-text accessibility trait. The report retains failed attempts and inspected original captures. Free signing/capability qualification remains necessary for Q100; paid CloudKit access or a reviewed subscription-free sync replacement remains unresolved. These focused results do not close the final scene inventory or whole-app acceptance.
