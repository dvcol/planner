# Native UI refinement

Status: native design corrections implemented. Ten selected mobile journey executions pass across light/dark iPhone and iPad checks. Final iOS Simulator and macOS compiler checks pass. Mac UI runtime and the final release qualifications remain open. This follows the [navigation and appearance checkpoint](native-design-pass.md), with signing deferred. It does not close the map's final physical-device or accessibility gates.

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
