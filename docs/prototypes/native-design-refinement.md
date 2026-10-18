# Native UI refinement

Status: native design corrections and a consistency follow-up are implemented. The original checkpoint has ten passing mobile journey executions across light/dark iPhone and iPad checks; the follow-up results are recorded below. Final iOS Simulator and macOS compiler checks pass. Mac UI runtime and the final release qualifications remain open. This follows the [navigation and appearance checkpoint](native-design-pass.md), with signing deferred. It does not close the map's final physical-device or accessibility gates.

## Context and goal

The user requests another UI pass inspired by Notes, Reminders and Music, with native pane navigation, appropriate tab placement, consistent dark appearance and less empty space above controls. The installed design checklist supplies readability, focus, overflow and interaction prompts; HTML-specific rules do not apply to SwiftUI. Apple design guidance governs the native components.

Before: wide iPad/Mac already use NavigationSplitView and a shared sidebar; phone uses system TabView. The sidebar repeats the Planner heading, catalog rows use automatic grouping, and global Item-row completion circles are decorative. The month agenda's large empty view pushes its description under the phone's floating tabs in the retained initial capture.

After: preserve the established native shell and contextual selection. Remove redundant hierarchy, distinguish compact collection rows from grouped detail Forms, support completion directly in global Item/Inbox rows, and keep empty agenda guidance compact. Review original light/dark captures after the changes rather than equating compiler or test success with visual acceptance.

## Definition of ready

- Existing native UI journeys exercise real saved Planner data and provide the approved interaction boundary. Add no production test controls or dependencies.
- Preserve source versus appearance completion scopes, draft navigation guards, saved identities, filter semantics and confirmed deletion behavior.
- Retain the prior captures and a genuine failing Item-row interaction before the completion change.
- Use serial Simulator/local Mac compilation and runtime checks. Signing-account configuration remains deferred.

## Definition of done

- Use system sidebar, tabs, List/Table, Form/Section, Menu, ProgressView and GroupBox components where they fit.
- Prove Item-row completion without opening details and reread the same Item after relaunch. Verify contextual List completion remains local.
- Review phone/tablet portrait and landscape, search/filter visibility, rich draft navigation and Calendar details with light/dark system appearance.
- Run affected strict Swift formatting and mobile/Mac compiler checks; record runtime limits separately.
- Record the scene review, original captures actually inspected and outstanding full-app states/accessibility/physical checks. Keep the separate List-window adoption work open.

## Design references

- [Apple tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars): phone tabs float at the bottom; iPad tabs appear at the top. A NavigationSplitView provides a sidebar without tab conversion.
- [Apple sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars): collection navigation and content hierarchy in pane layouts.
- [Apple toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars): group related controls, prioritize frequent actions and use overflow for secondary actions.
- [Apple Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode): semantic foregrounds, backgrounds and system materials follow appearance.
- [Design checklist](https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md): inspect labels, focus, overflow, empty/loading/error states and gesture alternatives.

## Evidence and limits

The [evidence directory](evidence/navigation/native-design-refinement/) records selected commands, source/product hashes, exits, logs and original captures. A failed setup or test-controller interaction is not a product regression. Simulator results do not establish physical performance, VoiceOver or release signing. The final whole-app pass in ticket 23 still requires its complete scene/state and accessibility inventory.

## Scene review

| Area | Review and change |
| --- | --- |
| Sidebar and pane shell | Remove the duplicate Planner section heading. Retain native NavigationSplitView, selected-pane details, system safe areas and per-platform bar placement. |
| Item/Inbox catalogs | Use plain native List rows, separate checkable completion controls and navigation links. Global actions explicitly say everywhere in their accessible labels and Mac help. |
| List contents | Use plain native collection rows while retaining full-scope progress/estimate headings. Existing membership controls keep their local command scope. |
| Shared row previews | Allow two title lines, keep metadata secondary, align thumbnails at the trailing edge and strike through completed titles without hiding details. This also reaches itinerary appearances. |
| Item/appearance details | Retain grouped native Forms, readable notes and existing map/link sections. No diagnostic identities are introduced. |
| Itineraries and live Lists | Retain DisclosureGroup headers, independent child controls and roomy group headings. Shared row typography receives the title treatment; route semantics remain unchanged. |
| Calendar | Replace the oversized empty agenda with a native GroupBox. Retain system mobile month selection, native mode Picker and wide inspector. |
| Estimate warnings | Keep the native warning symbol orange and use semantic primary text for its message, avoiding orange small text on light surfaces. |
| Schedule editor | Replace technical resolved-time wording with appointment wording. Civil-time validation and occurrence controls remain unchanged. |
| Capture, labels, Settings, recovery, data administration, Agent Control | Source audit retains system Forms, Lists, Menus and semantic colors. No new visual runtime credit is claimed for these scenes. |

No forced product color scheme, fixed white/black page surface, negative safe-area offset or custom floating bar was added. Full scene/state accessibility and physical acceptance remain the final ticket's work.

## Executed checks

The qualified [Item-row red](evidence/navigation/native-design-refinement/phone-catalog-completion-qualified-red/exit.json) reaches the saved Item catalog and fails because no completion button exists. The earlier first attempt incorrectly looked for the detail Toggle as a Button and is a test-controller failure, not behavior-red evidence.

- [iPhone light](evidence/navigation/native-design-refinement/phone-refinement-light/exit.json): two native journeys pass in 86.121 seconds, covering direct row completion, relaunch, destination switching and rotation.
- [iPad dark](evidence/navigation/native-design-refinement/tablet-refinement-dark/exit.json): four native journeys pass in 464.623 seconds, including independent List/global completion, rich draft resizing/relaunch, direct row completion and adaptive navigation.
- Source and compiled products stay frozen throughout each runtime. Simulator appearance is restored after the runs.

The first dark iPad inspection found that hierarchical primary styling still inherited the List Section header's secondary color. The final source uses semantic Color.primary explicitly for that heading. Earlier runtime packets retain their exact source epochs and do not imply visual approval of that final correction.

The [visual review](evidence/navigation/native-design-refinement/visual-review.json) lists only original captures actually inspected. The compact [phone agenda](evidence/navigation/native-design-refinement/phone-refinement-light/205F60FC-5C91-4770-BC68-CD99A741F49C.png) now fits its entire guidance above the bottom tabs. The [dark iPad panes](evidence/navigation/native-design-refinement/tablet-refinement-dark/0E1885D4-01F2-41FB-A7E2-5AFCFB32C9A7.png) remove the duplicate sidebar heading and distinguish plain collections from grouped details.

Mac compilation succeeds on the first source epoch. Native Mac UI remains unqualified because the [preceding bounded attempt](native-design-pass.md#remaining-qualification) failed before test discovery while enabling automation. This pass does not repeat that unchanged startup failure or alter permissions/signing-account settings. The [final Mac compiler check](evidence/navigation/native-design-refinement/native-refinement-final-mac-build/exit.json) passes against the final appearance source with local ad hoc signing. This is compiler evidence only. Physical devices, complete VoiceOver/Dynamic Type/keyboard/contrast and the full populated/filtered/loading/error/offline inventory remain open. Source review of those additional scenes is not visual acceptance.

A further [light List check](evidence/navigation/native-design-refinement/tablet-refinement-light-final/exit.json) passes in 61.015 seconds. Its inspected capture confirms the heading correction and exposed low-contrast orange warning text. The final appearance source keeps the warning symbol orange and renders the warning message in semantic primary text. Earlier captures remain diagnostic evidence; the final warning style requires its own recorded capture.

The [final light List check](evidence/navigation/native-design-refinement/tablet-refinement-contrast-final/exit.json) passes in 60.920 seconds. Its [inspected final capture](evidence/navigation/native-design-refinement/tablet-refinement-contrast-final/1C65358D-8A8D-403B-B617-67B098D70CE8.png) confirms readable primary text for both the List heading and missing-estimate warning, with the orange warning symbol retained.

The [final dark iPhone check](evidence/navigation/native-design-refinement/phone-refinement-dark-final/exit.json) passes both journeys in 87.100 seconds, including the strengthened row-identity check after relaunch. Its inspected catalog, empty Calendar agenda and New Item Form follow system dark appearance. The [literal results](evidence/navigation/native-design-refinement/results.json) retain all ten passing executions and their source epochs. Final [mobile](evidence/navigation/native-design-refinement/native-refinement-final-appearance-build/exit.json) and Mac compiler checks, affected strict Swift/Markdown lint and whitespace checks pass. No full-repository validation was run.

This is a requested UI refinement checkpoint. Full scene-state/accessibility acceptance, native Mac runtime, signing/physical-device work and Q97 standalone List/Table window adoption remain open. The [shared loader checkpoint](native-list-windows.md) is committed independently as `6f2ce0b`; its 13 real-Core tests do not establish native List adoption or performance.

## Native pane consistency follow-up

The next source pass reviews the current saved app against the same Notes, Reminders and Music hierarchy. The existing shell already uses native sidebar panes on wide iPad/Mac and native phone tabs. Keep that shell, native safe areas, grouped detail Forms, disclosure groups and context menus. This follow-up brings List and Itinerary row controls into line with the Item catalog rather than introducing another navigation style.

- Align contextual completion controls with each row's title and provide the same 44-point mobile touch area used by catalog controls. Keep source/global and appearance/local actions separate, with their existing accessibility labels and disabled states.
- Use semantic completion and archive styling. Full-scope ProgressView labels use primary text so a native List Section header does not make the principal count look disabled.
- Use an inline native toolbar title for itinerary child details, matching Item and List details and avoiding another large title tier above the Form.
- Keep native LabeledContent at ordinary text sizes. At accessibility sizes, stack each estimate label above its value so the available column width does not split duration words. Readability remains a visual check, not a test for a width constant.

The source audit also checks Calendar, rich capture, maps/links, label management, Settings, recovery and manual data administration. Their existing system Forms/Lists, Menu/Picker controls, loading/error views and semantic appearance remain in place. No forced product color scheme, fixed light/dark surface, extra floating navigation overlay or manual negative safe-area inset is introduced. Final runtime credit will be recorded per executed scene; this source audit does not establish whole-app visual or accessibility acceptance.

The dark iPad follow-up passes the ordered Itinerary journey in 101.497 seconds and the filtered Manual List drag journey in 136.571 seconds. The [Itinerary detail capture](evidence/navigation/native-design-refinement/tablet-pane-consistency-overflow-dark/80780CBB-1B95-47FE-9155-B1FF188E3D20.png) shows inline detail navigation, independent contextual checks and a readable grouped Form. The [List capture](evidence/navigation/native-design-refinement/tablet-pane-consistency-overflow-dark/AC5A604F-B150-42BD-A866-2A8ECD70EA6A.png) confirms full progress through filtering and exposed overly faint matching-count text. The final source uses explicit semantic secondary colors for those header labels rather than inheriting the Section's hierarchical style again. That final correction needs its own capture below.

The phone dark follow-up passes direct catalog completion and adaptive navigation in 87.950 seconds. Inspected [New Item](evidence/navigation/native-design-refinement/phone-pane-consistency-dark/C8383104-5EDF-4A70-898D-6C3C496B18EF.png) and [Calendar](evidence/navigation/native-design-refinement/phone-pane-consistency-dark/E1D71243-07A5-4919-865F-D028E08CD85E.png) captures retain native bottom tabs, semantic Form surfaces and the compact agenda. These samples do not establish every phone scroll position or whole-app accessibility acceptance.

Two earlier follow-up runs are retained as controller failures. The old journeys looked for former tablet tab buttons and then missed New List in the narrow sidebar's system overflow menu, before exercising their target workflows. The controllers now reuse shared adaptive section navigation and the newer journey's native New List handling. The product commands and state assertions remain unchanged. The passing Itinerary/List retry supplies functional credit; the failed controller attempts are not product-red evidence.

The first maximum-text-size journey passes its saved-content and identity assertions in 172.865 seconds, but its inspected [live Simulator capture](evidence/navigation/native-design-refinement/tablet-pane-consistency-accessibility-maximum/metric-wrapping-before.png) still splits duration words in the narrow List column. This is a visual finding despite functional success. The next source uses a native VStack for each metric at accessibility text sizes, preserving ordinary LabeledContent and the same accessible labels, values and identities. A repeated journey and capture are required for that correction.

The stacked-metric retry passes in 171.554 seconds. Its [inspected saved-detail capture](evidence/navigation/native-design-refinement/tablet-pane-consistency-stacked-accessibility-maximum/D80A35FF-B423-4B9C-8A6E-C11694BD3932.png) preserves whole duration words and the selected Item/map. It also exposes a truncated missing-estimate warning. The final source explicitly permits that warning to wrap at its intrinsic height. The [dark phone filter journey](evidence/navigation/native-design-refinement/phone-pane-count-contrast-dark/exit.json) passes in 134.072 seconds against the semantic count-label correction, retaining full progress through cumulative search/archive filters.

The final maximum-size journey passes in 171.870 seconds. Its [inspected capture](evidence/navigation/native-design-refinement/tablet-pane-consistency-wrapped-warning-maximum/260B73D4-F8E8-4BBE-B138-D3D5F83B7FE3.png) shows complete duration words and the full missing-estimate warning without shrinking the selected text size. The saved address map remains embedded in details. The [final dark count capture](evidence/navigation/native-design-refinement/phone-pane-count-contrast-dark/89E26D84-88AC-45D1-9996-E372D65D5074.png) shows readable matching-count text beside unchanged full-scope progress. Original settings are restored after every appearance/content-size run. The [follow-up run index](evidence/navigation/native-design-refinement/pane-consistency-results.json) and [visual review](evidence/navigation/native-design-refinement/pane-consistency-visual-review.json) preserve source epochs and distinguish controller failures, functional success and visual findings.

The [final Mac compiler check](evidence/navigation/native-design-refinement/native-pane-consistency-final-mac-build/exit.json) passes with local ad hoc signing and no developer-account configuration. Final mobile compilation, eight-file strict Swift lint, three-document Markdown lint and whitespace checks pass. This checkpoint keeps Mac native UI runtime, physical/signing work and full scene-state/accessibility acceptance open. The represented maximum-size capture still wraps long addresses within a word and intentionally truncates compact row metadata; it does not certify all large-text presentation.
