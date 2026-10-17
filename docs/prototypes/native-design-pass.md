# Native navigation and appearance review

Status: navigation and appearance changes implemented after the user's 18 October request to bring the UI review forward. Focused mobile checks and both platform compilations pass; Mac UI startup remains blocked before test execution. The approved List-window work remains next. This review does not complete ticket 23 or the map's release gates.

## Context and goal

Planner currently places an app-wide TabView around separate NavigationSplitViews on iPad. The retained tablet captures show floating tabs, another toolbar, a large title and search stacked above content. The user reports an empty band above filters and requests correct dark mode across devices. Notes and Reminders provide the model for collection navigation and selected details; Music demonstrates that the system tab bar belongs at the top on iPad and at the bottom on iPhone.

Before: iPad uses floating tabs plus per-destination sidebars, with automatic large navigation titles. Mac already uses a shared sidebar. Phone uses native tabs and collapsed navigation. Ordinary scenes use system text styles, Form/List backgrounds, SF Symbols and materials; no forced product color scheme or fixed white/black surface was found in the source audit.

After: wide iPad and Mac use one native sidebar for main destinations and Lists. iPhone and compact layouts keep native tabs and pushed details. Navigation titles stay in their toolbar, with meaningful title content in the selected detail. Search, filters, progress and rows keep native placement and semantics. Device appearance controls light/dark rendering without a separate application theme.

## Definition of ready

- Existing public native UI journeys are the agreed test boundary. No new provider, Core or production test seam is required.
- Selection identities, draft guards, completion scopes, filters and Calendar inspector semantics remain protected by existing journeys.
- The original tablet captures and a new native baseline are retained before changing production layout.
- Simulator and local Mac compiler checks are available. Signing and physical-device qualification remain deferred.

## Definition of done for this slice

- Demonstrate a failing native navigation journey before adopting the shared iPad sidebar.
- Confirm saved Item creation and rereading while switching between Lists, Items, Inbox, Itineraries and Calendar.
- Inspect original light/dark phone and tablet captures, including the Item editor and selected details. Record observed layout problems without treating an assertion pass as visual approval.
- Run the existing draft resizing journey on affected mobile layouts, plus focused List/Itinerary/Calendar checks where the shell changes their presentation.
- Run affected strict Swift formatting and compiler checks for iOS Simulator and macOS. Record any unavailable runtime checks.
- Preserve native safe areas and adaptive system colors; do not force compact size classes, draw a custom floating tab bar, or replace system insets with negative offsets.

## Design references

- [Apple tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars) establishes platform placement, including Music's iPad top tabs.
- [Apple sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars) covers collection and top-level navigation in pane layouts.
- [Apple Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode) recommends semantic colors that follow appearance.
- [Apple materials](https://developer.apple.com/design/human-interface-guidelines/materials) covers system vibrancy and readable text over materials.
- The installed web-design-guidelines checklist supplies general review prompts for focus, labels, content overflow and interaction states. Its HTML/CSS requirements do not apply to SwiftUI.

## Corrections found during review

- Regular-width iPad now reuses the native sidebar and pane layout. iPhone keeps tabs even when its landscape size class is regular.
- Main catalogs, content panes and New Item use inline native toolbar titles. Native content headings keep List and Itinerary names readable when their toolbars are crowded. The original top floating-tab tier is absent from regular iPad layouts; no negative safe-area offsets or forced compact traits were added.
- Empty List guidance is a secondary row inside the shared sidebar's Lists section. The compact Lists-only screen retains its native empty view.
- The Itinerary catalog archive choice survives opening a route and returning. The native regression first observed All Itineraries changing to Active Itineraries.
- Itinerary search, cumulative filters and expanded groups are retained by rendered source identity, including Calendar details. Dataset changes clear that presentation cache; confirmed deletion removes its owner. The native search regression first observed the entered query disappear after switching destinations.
- The main Lists destination keeps its catalog sidebar visible; selecting an individual List opens its content/detail panes. New List uses the native primary-action placement.
- Calendar's inspector is attached to the outer split view so sidebar adaptation does not close the selected details. The same Week resizing journey failed with the inner host and passed with the outer host.
- UI arrivals use destination-specific content or actual phone tab selection. Phone Inbox can correctly retain the selected Item detail; its catalog assertion follows the native Back button first. Completion queries recognize native Toggle roles, and sidebar actions are scoped to the app window.

## Scene audit

| Scene | Native components and appearance | Review result |
| --- | --- | --- |
| Main navigation | NavigationSplitView, List sidebar, compact TabView | Light/dark phone and tablet navigation passes; original representative captures inspected |
| Items and Inbox | List, Menu, Picker, native search, ContentUnavailableView | Same saved Item reread after destination switches and rotation; completion remains operable |
| Lists and child details | List/Table, ProgressView, Form, contextual completion | Readable List heading; rich draft retains fields and originating List through rotation, Save and relaunch on phone/tablet |
| Itineraries and live groups | List, DisclosureGroup, ProgressView, Menu | Catalog archive and per-owner search/filter/collapse lifetime corrected; tablet archive/search and phone search checks pass |
| Calendar | Native mobile month component, segmented Picker, time grid, inspector | Native month light/dark captures inspected; dark tablet Week inspector survives rotation with the same Schedule/Item |
| New Item and labels | Native grouped Form and adaptive label popover/sheet | Inline title; light/dark editor captures and rich-draft compatibility pass; existing label-picker behavior retained |
| Capture, settings, recovery and data administration | Native Form/List/Menu and system surfaces | Source reviewed; no forced theme or fixed light-only surface found; full visual acceptance remains open |
| Mac Agent Control and app menus | Native Form, controls and menus | Source reviewed; local compiler/runtime qualification remains separate |

## Evidence and limits

The [evidence directory](evidence/navigation/native-design-pass/) retains source/product hashes, exact commands, compiler/runtime exits, compressed logs, original selected captures and failure hierarchies. Each runtime verifies that its source and compiled products remain unchanged. The [visual review](evidence/navigation/native-design-pass/visual-review.json) names the representative originals actually inspected; exported captures beyond that list have no implied visual acceptance. The [source reviews](evidence/navigation/native-design-pass/source-reviews.json) record independent Standards/Spec review and its scope.

| Native boundary | Result and packet |
| --- | --- |
| Sidebar regression | [Red](evidence/navigation/native-design-pass/tablet-sidebar-red-qualified/exit.json): missing main Items sidebar destination with the prior tablet shell |
| Catalog archive regression | [Red](evidence/navigation/native-design-pass/tablet-itinerary-filter-red/exit.json): All changed to Active after returning |
| Itinerary search regression | [Red](evidence/navigation/native-design-pass/tablet-itinerary-search-red/exit.json): entered query disappeared after switching destinations |
| iPad light navigation/archive/search | [3 pass](evidence/navigation/native-design-pass/tablet-final-light/exit.json), 112.831 seconds |
| iPad dark draft/Week inspector/navigation/archive/search | [5 pass](evidence/navigation/native-design-pass/tablet-compatibility-dark-qualified/exit.json), 379.517 seconds |
| iPhone dark rich draft | [Draft passes](evidence/navigation/native-design-pass/phone-dark-qualified/exit.json), 252.664 seconds; that packet also retains a failed navigation-controller assertion |
| iPhone dark navigation | [Navigation passes](evidence/navigation/native-design-pass/phone-dark-navigation-final/exit.json), 58.913 seconds; that packet also retains a failed search-revelation assertion |
| iPhone dark search | [1 pass](evidence/navigation/native-design-pass/phone-dark-search-qualified/exit.json), 28.604 seconds, after native search revelation |
| iPhone light navigation | [1 pass](evidence/navigation/native-design-pass/phone-light-qualified/exit.json), 58.765 seconds |
| Final iPad light rich draft/search | [2 pass](evidence/navigation/native-design-pass/tablet-light-draft-final/exit.json), 222.916 seconds, including the final List heading |
| Final iOS Simulator compile | [Pass](evidence/navigation/native-design-pass/native-design-mobile-qualification-build/exit.json); compiler evidence only |
| Final macOS compile | [Pass](evidence/navigation/native-design-pass/native-design-mac-build/exit.json), with local ad hoc signing; compiler evidence only |
| macOS dark native UI attempt | [Exit 65](evidence/navigation/native-design-pass/mac-dark-qualified/exit.json): XCTest timed out while enabling automation mode; zero Test Cases started, with no runtime or visual credit |

The earlier five-function dark iPad run precedes the final List-heading text and phone-only test-controller corrections. The final light draft/search run and phone light/search runs use the final production source. Retained intermediate failures include setup/controller errors and one repaired compiler edit; they are not counted as behavior red tests or passing runs. The native Week journey also exposed an inspector closing on rotation, and the draft journey exposed hidden List-catalog navigation; both passed after the corresponding production corrections. A native Toggle-role lookup, phone Inbox Back navigation and pull-to-reveal search corrected test interactions without weakening the destination, saved-content or entered-query assertions.

### Inspected examples

- [iPad dark, three panes](evidence/navigation/native-design-pass/tablet-compatibility-dark-qualified/9F701DC3-493A-4DA1-B742-A08E39077F1B.png): sidebar, Item catalog and selected details share the available width without an additional floating-tab tier.
- [iPad light, List draft](evidence/navigation/native-design-pass/tablet-light-draft-final/2FB6A1D5-F338-4524-B85E-309ACF21FF9E.png): the originating List heading stays readable beside the rich editor.
- [iPad dark, Calendar inspector](evidence/navigation/native-design-pass/tablet-compatibility-dark-qualified/C7AFA966-E224-4BDB-A33D-9B101F9BE20A.png): the same selected Schedule and Item remain after narrowing.
- [iPhone light details](evidence/navigation/native-design-pass/phone-light-qualified/88CD514A-2E12-416C-9C37-F4567E40A593.png) and [dark details](evidence/navigation/native-design-pass/phone-dark-qualified/FF32B5AE-6CDD-4AC9-95E9-13FC447525AB.png): native Form surfaces follow appearance and tabs remain at the bottom.
- [iPhone dark landscape](evidence/navigation/native-design-pass/phone-dark-navigation-final/80430AF5-4B3B-4A4B-8B6E-71F6453ED52E.png): system tabs remain centered within the phone content; no app-drawn navigation bar or forced compact traits are used.

Early landscape application screenshots were misframed even after successful interaction. The Item journey now records the original screen screenshot on mobile; its final landscape capture is complete. That recorder correction does not alter product layout. Existing draft and Calendar recorders remain unchanged.

### Remaining qualification

Mac compilation passes. Its one bounded runtime attempt failed during automation initialization after a reported 71.417 seconds, before any Test Case started. The earlier [Dynamic Type report](native-new-item-dynamic-type.md) already records pre-discovery Mac automation failures on the base source. The current attempt establishes that the limitation remains; it does not establish Mac behavior or appearance. No permissions, signing-account settings or system protections were changed.

Account signing and physical-device work remain deferred. This slice does not establish whole-app dark-mode, VoiceOver, keyboard, Dynamic Type, Reduce Motion/Transparency or accessibility acceptance. Capture/Share, settings/recovery, provider-preview failures, long-list performance and the final populated/filtered/error-state scene inventory still need their own review. Native floating bars overlay scrolling phone content in the retained editor/agenda captures; final scrolling and large-text acceptance must verify every field and description remains readable and reachable without adding arbitrary safe-area offsets. The [validation record](evidence/navigation/native-design-pass/validation.json), [literal run results](evidence/navigation/native-design-pass/results.json) and [evidence hashes](evidence/navigation/native-design-pass/sha256.json) support this checkpoint. No overall native, polish or map ticket is closed.
