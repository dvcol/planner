# Native navigation prototype review

Readiness proposal for [Navigation prototype](https://github.com/dvcol/planner/issues/14), claimed after [Shared command contracts](https://github.com/dvcol/planner/issues/13#issuecomment-6070841289) resolved. This is a concrete public UI test proposal, not runnable code or accepted final layouts. Q33 accepts the underlying Core/adapter interfaces. Existing domain behavior and quality gates carry forward.

The starting state below describes when this proposal was prepared. The prototype/mcp branch now contains a native Xcode project, shared Core package and runnable local Core/HTTP qualification, recorded in the [native build](prototypes/mcp-native-build.md), [Core](prototypes/core-local-qualification.md) and [MCP](prototypes/mcp-http-qualification.md) reports. The navigation comparison and its new UI test boundary still await Q34/Q35. Native test-host launches do not establish reviewed navigation or physical-device behavior.

## Context, starting state and goal

The app needs native iPhone, iPad and Mac navigation for both capture/organization and itinerary/scheduling. The checkout contains accepted contracts and fixed data, with no Xcode project or running app. Navigation prototype must commit the native app/package/test setup and demonstrate its interactions before a production implementation begins.

The goal is to agree observable UI journeys and fixture inputs, then use `/tdd` for executable behavior at those seams. Choosing the final layouts follows a runnable comparison and human review. This review does not ask the human to choose a UI from prose or reopen domain policies.

## Public seams and expected end

The UI seam is the running native Planner app driven through its visible navigation, controls, accessible labels, selections, sheets and confirmation results. XCUITest observes those public effects. Core read/query/execute, capture/review, status and native portability seams are already accepted under A21/A22/Q33. Separate Core/store suites verify final domain values through that facade with real disposable stores. XCUITest verifies those effects by opening the normal native views. Do not query private model internals or assert internal navigation call counts.

Use a normal local prototype configuration with fixed fixture selection, never a production test-only UUID factory or dependency-injection callback. Each journey starts from its named fixture and isolated disposable data. Native UI tests agree the actions and outcome first, then implement one failing behavior and its minimum passing slice. Record fixture, red/green command, discovered/executed counts, result artifacts and limits.

The expected end is a runnable native comparison plus a walkthrough on phone, tablet and Mac. The human chooses or combines layouts after using them. The prototype decision stays open until required build/test, accessibility, persistence/reopen and physical-device performance evidence, and human layout review pass.

## Fixed fixture catalog

The [literal catalog](fixtures/navigation-fixture-catalog-v1.json) supplies public IDs and recipe inputs; it introduces no domain schema or production UUID seam.

| Fixture | Concrete purpose |
| --- | --- |
| Full graph | Existing [portable backup](fixtures/portable-backup-v1.json): X Nezu Museum, Y Ramen lunch archived, Lists A/B, one itinerary, independent appearance flags, labels, owned links and Schedules. A starts 1/2, B 0/1 and itinerary 0/3. |
| Search A-I | Accepted [nine-item dataset and literal results](search-fixtures.md), with stable UUID mapping in the catalog. Keep its global flags, Todo local contexts, literal text, timestamps and saved Manual order D/G/A/C/B. |
| Repeated stops | Full graph with X titled Hotel, Y titled Museum, and itinerary entries X/Y/X. Three independently completed appearances; global flags Todo and local flags Todo. Source Lists keep their own state. |
| Partial capture | Independent text `食事 🥢\nhttps://example.com/menu\nBring umbrella`; one editable Item draft with the exact original URL. A separate provider-only Maps lane is held preview data and never supplies saved name/address/coordinates. Existing capture fixtures define OS-provider representation/limit cases. |
| Dates | Exact October 9-11 inclusive civil dates; Tokyo October 9 10:00-11:00; accepted New York March gap/November repeated and coupled endpoints. No guessed end or silent time adjustment. |
| Recovery evidence | Existing [seven exact evidence inputs](fixtures/recovery-evidence-expectations-v1.json), separate namespace inspection and current-account W. Preview presentation is explicitly simulated when native ownership/durability has not yet been proved. Sync/share owns actual account-transition evidence. |
| Long lists | Exactly 5,000 Todo/Active Items and 200 Lists, 25 members each, stable catalog IDs. Only the final Item has title Needle fixture. Query `needle` returns that one identity despite its position beyond the initial window. This is an acceptance dataset, not an app limit. |

## Native comparisons

Keep fixture/domain meaning identical across variants. The default comparison contains three structural alternatives: library first, itinerary/calendar first, and map alongside the selected list. Each uses native platform scenes rather than enlarged phone views. Variants and scenario selection belong in a clearly marked prototype menu. They are temporary controls and do not add a product settings requirement.

- iPhone uses navigation stacks and native sheets for editing. Frequent sections remain reachable through native tab navigation; Add remains an action rather than a navigation tab.
- iPad compares native top tabs with optional sidebar adaptation against an always-available split layout. Inspect portrait, landscape and compact-width behavior, detail visibility and retained selection.
- Mac uses a native sidebar/list/detail window, toolbar, menus, focus and keyboard navigation. Compare a detail inspector/map with a larger central content area. Resizing must preserve useful context rather than expand phone-sized content.

Apple's [tab guidance](https://developer.apple.com/design/human-interface-guidelines/tab-bars) distinguishes navigation from actions and describes iPad tab/sidebar alternatives. The exact controls and final layout are prototype candidates; source guidance is not proof that this implementation feels native. Native Xcode configuration and the accepted OS 27 deployment minimum remain authoritative.

## Journey expectations for /tdd

| Journey and initial fixture | Public action | Required visible/domain result |
| --- | --- | --- |
| Open/select, full graph | Open Lists → Tokyo Food; set completion/archive filters to All so X and archived Y are visible; select X's local appearance. Open the source Item view separately. | Local detail retains membership 401; Item view identifies source 101. Context actions never retarget to global. A is 1/2 including archived Y; itinerary remains 0/3. |
| Completion precedence, full graph | Complete X globally in Item view, then globally reopen. | Global Done displays X Done in all appearances without changing local flags. A is 1/2, B 1/1, itinerary 2/3; Reopen restores A 1/2, B 0/1, itinerary 0/3. Container screens offer only local actions. |
| Selection refresh, full graph | Select Todo X in itinerary; complete only the direct appearance while Todo filtering is active. | That row leaves the query, while its valid detail remains selected and shows local Done. No switch to source-global completion. Removing that exact reference clears its invalid selection with explanation. |
| Bulk, full graph | Keep archived Y hidden; review Mark all Done for itinerary, then cancel or confirm. | Preview has three child appearances. Cancel retains 0/3; confirm gives 3/3, retaining global flags, Y's archive and source List state. Changed targets require refreshed confirmation; precommit failure retains prior display. |
| Repeated stops | Show All states to include archived Museum; open Hotel/Museum/Hotel; complete first Hotel, then second. | Progress is 1/3, then 2/3; one shared Hotel source, independent local states. Global Hotel Done also gives 2/3 without changing local flags. Source List completion remains separate. |
| Search/filter, A-I | Type `cafe`; choose Any completion/archive; combine Food, rainy-day and reservation-required Any/All. | Ordinary cafe gives C; Any states gives C/G. Ordinary Food plus those tags Any gives A/C/D, All gives C. All active filter groups narrow cumulatively; shared-label selection uses IDs. |
| Duration/sort, A-I | Pick 1 hour 31 minutes, save/reopen; clear estimate; try the named shortcuts and duration bounds. Change sorts and return to Manual. | Exact 91 minutes, then No estimate; shortcuts 720/1440/2880 minutes. A 120-minute maximum admits 119/120 and excludes 121; unknowns need explicit inclusion. Saved Todo Manual order returns D/A/C/B; other sort modes never rewrite it. |
| Map and generic Item | Select X's coordinate pin, then a generic Item without location. | Selection attaches to the same source/appearance. Map selection does not duplicate X; the generic Item remains editable with a useful no-location state. Provider preview never overwrites independently owned content. |
| Capture | Open the partial capture editor; edit independent title/notes; cancel or Add. Exercise explicit reuse with existing exact-URL candidates. | Cancel creates no Item. Add creates one Todo/Active Item with exact retained text/URL and reviewed destinations. Reuse adds only missing reviewed links/memberships without replacing fields or resetting state. No Saved acknowledgement before Core's complete recovery outcome. |
| Calendar and native pickers | View October 9-11 all-day; switch display between Tokyo/Paris; edit timed end and planning zone. Use gap/repeat fixtures. | Civil dates remain all three days. Timed display is 10:00 Tokyo or 03:00 Paris for one instant. End absent is valid; supplied end must be later. Zone-only edit preserves endpoints. Missing time rejects unchanged; repeated occurrence requires explicit offset choice. Coupled earlier-start/later-end remains valid. |
| Delete and Undo, full graph | Cancel or confirm Item/container Delete; remove/re-add or Undo the original association. | Impact is visible. Item X Delete removes only X/references/S1, retaining Y/containers/S2/labels. Container Delete preserves source Items/Lists. Ordinary re-add has new association/Todo; original Undo preserves public association/local state with authorized lifetime. No Trash or expiry timer. Final Undo affordance follows runnable native review. |
| Shared labels | Rename one of two distinct rainy-day labels; delete an Item-associated label and cancel or confirm. | Rename changes only that identity's owners. Cancel retains label/associations; confirmation detaches owners without deleting them. Itinerary-only label confirmation is the independent open decision below. |
| Backup/import/recovery | Preview the existing Skip/Overwrite fixtures and separate old-account recovery; cancel, apply, repeat or supply invalid data. | Matching Skip retains whole owners and adds Z once; Overwrite preserves omitted W. Invalid files/precommit failure change nothing. Postcommit copy failure remains applied/incomplete. Old-account inspection/export changes no current W and never auto-uploads. Explicit restore has its exact preview. |
| Status | Display acknowledged, unapplied, applied/incomplete, prepared-only, unknown and generic cloud-error inputs. | Complete local recovery permits Saved on this device. Applied/incomplete is not rollback; prepared-only is unverified. Reads remain available under mutation block. No invented cloud freshness, quota diagnosis, Sync now or retry deadline. Simulated inputs cannot establish native recovery feasibility. |
| Long-list completeness/performance | Query needle; traverse all rows; change query/state while selected/scrolled; switch accepted sorts. | Sole result ID 25000 remains findable. Every current match appears once; obsolete generations cannot replace current results. Keep valid detail and a surviving scroll anchor where possible. Measure cold/warm input-to-visible latency including debounce/query/fetch/render, hitches and memory on iPhone/iPad/Mac. Required 300 ms gate remains unchanged. |

Core read/query/execute tests observe independently specified IDs/values through accepted interfaces. UI tests observe accessible controls and visible outcomes. Persistence/reopen and real I/O failure are separate from a UI preview. Mock genuine external boundaries only. A runnable comparison, simulator test or seeded status label is not physical sync/account/Share proof.

## Readiness and first slice

The 2026-10-09 read-only refresh matches Apple test access: macOS 27.0.1/arm64, Xcode 27.0 build 27A266a, Swift 6.4, iOS/iOS Simulator/macOS 27 SDKs, available iOS 27 runtime, five iPhone and six iPad simulators. First-launch check exits 0. Scope DEVELOPER_DIR to the installed Xcode; the global selection remains Command Line Tools. No build, scheme discovery, boot or launch has happened.

Use iPhone 18 Pro, iPad Air 11-inch M4 and native arm64 Mac as initial local destinations. Verify project-specific destinations after committing native configuration. Compact phone, iPad orientations/resizing, Dynamic Type and VoiceOver checks remain required. Physical provisioning, pairing, Developer Mode, signing and the measured real-device dataset remain human/device gates before this prototype can close; private CloudKit setup does not block local fixture work.

First establish a minimal runnable native project/package, shared schemes and test discovery. A missing project, compile error or undiscovered test is setup failure, not a failing behavior test. The first behavior slice after UI-seam acceptance is opening List A, selecting All completion/archive filters and selecting X's local appearance. The initial ordinary filter hides locally Done X and archived Y; tests must not silently alter that accepted default. Write that public journey test, establish its focused failing result, and implement its minimum native path. Add further journeys one at a time. Do not generate the entire test suite before any implementation. Prototype code belongs on an isolated `prototype/navigation` branch; main retains accepted decisions and pointers. Follow the approved native paths/shared schemes and focused commands in the architecture blueprint.

## Open review frontier

- UI test seam: accept the above public journeys/fixed inputs or specify corrections before their UI tests. Core A21/A22/Q33 approval carries forward.
- Itinerary-only label Delete: a label used by at least one Item already requires confirmation. For T used only by Itinerary I, choose confirmation with impact, immediate detach/delete without a prompt, or preventing deletion until manual detachment. Recommend confirmation for any association. It adds one prompt and makes reference removal consistent without changing the confirmed container-only/shared-owner rules.

Layout, picker arrangement, Manual-sort controls, destructive Undo affordances and status placement remain comparisons for actual runnable human review. Do not record them as final choices from this readiness proposal.

## Definition of ready and done

- [x] Contract public interfaces accepted, prerequisite resolutions reviewed, local toolchain inventory refreshed and fixture inputs/expected transitions specified.
- [ ] Human accepts the new UI test seam/journeys and settles itinerary-only label confirmation.
- [ ] Runnable native prototype, shared schemes, focused red/green/build/launch results, discovered/executed counts and artifacts are committed on its isolated branch.
- [ ] Native journeys, accessibility, persistence/reopen and accepted performance gates pass on their required platforms; relevant physical setup is completed.
- [ ] Human reviews actual layouts/interactions, accepted decisions are captured, limitations are explicit, and only then is the prototype ticket resolved/indexed.
