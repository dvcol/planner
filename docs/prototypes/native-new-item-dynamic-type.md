# New Item at accessibility text sizes

Status: the represented ordinary and maximum-text-size iPhone/iPad journeys pass. The affected mobile and Mac app/UI targets compile successfully; Mac runtime remains open. Signing and whole-app UI polish remain deferred. Q94, Q95 and Q96 remain unanswered.

## Context and starting state

The native rich-creation journey already checks explicit cancellation, owned address fields, two distinct bookmarks with the same URL, originating-List membership and saved identities after relaunch. Its prior results use ordinary simulator text sizes. They do not establish that the full editor remains usable at the largest accessibility text size.

## Goal and expected end state

Qualify the existing New Item flow at ordinary and maximum accessibility text sizes. Keep title, subtitle, notes, location and bookmark inputs reachable by native scrolling. Explicit Save must retain exactly the same authored content and origin as at the ordinary size. Discard must create nothing.

## Definition of ready

Q88 through Q93 approve native creation and its production UI test boundary. This slice uses that existing boundary with disposable real local datasets. Apple's supported Simulator content-size setting controls the environment, with its original value restored afterward. No new unit seam, test-only production parameter, domain behavior or public contract is introduced. Label selection remains outside this journey while Q94 is pending.

## Required tests and definition of done

- Run the existing rich-creation journey at the ordinary and largest accessibility content sizes on the represented simulators. Verify the requested setting and inspect the actual native text and controls.
- Keep native input controls reachable, verify each authored field immediately, save once, and retain the existing source, membership, completion, distinct bookmark and relaunch assertions.
- Retain initial Form and authored address captures in addition to the existing draft and saved-detail captures. Compare actual rendered text geometry across sizes; a successful Simulator setting change alone is insufficient.
- Compile the affected app/UI targets and run affected Swift and Markdown lint. Preserve unsuccessful invocations separately from passing results. Restore each Simulator's original content-size setting.

No new domain logic requires unit or HTTP tests. Passing these represented journeys will not establish whole-app accessibility, VoiceOver, keyboard navigation, physical-device performance, split-screen or Mac runtime qualification.

## Observed results

| Simulator | Ordinary text size | Maximum accessibility text size |
| --- | --- | --- |
| iPad Air 11-inch M4, iOS 27.0 | Pass, 150.873 s | Pass, 183.275 s |
| iPhone 18 Pro, iOS 27.0 | Pass, 149.099 s | Pass, 192.840 s |

Each invocation executes one complete rich-creation function with zero failures or skips. The journey discards an edited draft without creating an Item, then authors title, subtitle, notes, place name, address and two labeled bookmarks sharing one URL. It verifies exactly one source, the original List appearance's identity and local Todo, distinct saved bookmark identities and exact URLs before termination. After relaunch it rechecks the source/appearance identities, local Todo, subtitle/notes and bookmark labels/identities, then reads the retained owned address/name through Edit Item. It also verifies that Other stays empty. No field, save or scrolling failure is observed in these four invocations; no production correction or artificial failing baseline is introduced.

The [run index](evidence/navigation/native-new-item-dynamic-type/historical-run-index.json) retains literal function results, and each run records the requested, observed and restored Simulator content-size values. Both devices start with `large`. Maximum runs use `accessibility-extra-extra-extra-large`; every invocation restores and rechecks `large`. The same mobile build is used for all four runs, with frozen source and product hashes checked before and after execution. XCTest durations include automation and fixture work and are not responsiveness measurements.

## Rendered form and visual limits

All sixteen retained original PNGs were individually inspected. The initial native hierarchies confirm title TextField heights of 22 points at the ordinary size and 64 points at the maximum size on both devices. Window dimensions remain 820 by 1180 points on iPad and 402 by 874 points on iPhone. This comparison establishes that the rendered form responds to the environment setting. It is not a test of a font or padding constant.

At maximum size, the native Form remains scrollable and its controls remain usable in this journey. Long single-line place names, addresses and URLs show truncation or a horizontally scrolled portion; full values remain verified by the UI-value and persistence assertions. The tablet's adjacent estimate/remaining summaries break words, and its selected Item row truncates secondary information. The phone's floating native TabView overlaps portions of scrolled content, which the journey reaches by further scrolling. These observations are retained for [the final native polish pass](../native-ui-polish.md), rather than declared visually accepted.

Saved address maps are visible in the captures. Website cards show Preview unavailable and Retry. These captures supply no controlled provider-success qualification. Category/Tag selection is not exercised and does not resolve Q94.

## Remaining gates

This slice changes only the existing UI journey's diagnostics and immediate field-value checks. It adds no production interface, data model, domain behavior, unit seam or dependency. Core and HTTP contracts are unchanged. The broader Dynamic Type scene inventory, intermediate text sizes, landscape, split-screen, VoiceOver, keyboard navigation, Reduce Motion/Transparency, physical responsiveness and whole-app visual acceptance remain open.

Q94 label presentation, Q95 native catalog windows and Q96 schedule clock input require the pending human decisions. Mac runtime is not rerun after its repeated pre-discovery automation failures. Signing and physical sync/account/Share work remain deferred. No overall Navigation, feature or map gate is closed. Whole-app UI polish follows the remaining features.

## Compiler, lint and evidence checks

Both affected app/UI-target compiler invocations pass with Xcode 27.1. The Mac invocation uses the existing local ad hoc configuration and supplies compiler evidence only. No Mac UI run, developer account setup or physical signing qualification is claimed. Strict affected Swift and Markdown lint pass.

The [evidence packet](evidence/navigation/native-new-item-dynamic-type/) records separate compiler and runtime commands, literal exits, source/product hashes, captures, environment and Simulator restoration. Each compiler freezes 945 source/configuration inputs, while each runtime verifies 469 relevant inputs and six mobile products before and after execution. The packet also retains the six Mac product hashes. The evidence audit rechecks the represented outcomes against raw logs and the current source and products. Source review is independent of native runtime proof.
