# Opening plans and App Shortcut discovery

Status: Q122 A and Q123 A accepted on 21 October 2026. Reuse one foreground main window with draft protection, and publish four create/find shortcuts. [The four-shortcut provider is implemented locally](prototypes/native-app-shortcut-discovery.md). The concrete single-window handoff and any added test boundary still require review.

## Context and starting state

At 86282767 Planner has 69 native actions, but no OpenIntent or AppShortcutsProvider. List and Itinerary selections belong to each SavedPlannerView. The main scene is an untyped WindowGroup. An edited New Item draft already has Save, Discard and Keep editing navigation protection under Q91.

The [product brief](product-brief.md) lists opening Lists/Itineraries and using modern App Shortcuts where supported. This review makes the first workflows concrete. It does not add Delete, backup, export or recovery administration to agents.

## Verified platform facts

Apple's [OpenIntent](https://developer.apple.com/documentation/appintents/openintent) brings the app forward. Its perform implementation can update app-owned navigation on MainActor. Foregrounding alone does not select a List, deliver a request to one particular window, or protect an unsaved draft. Apple's [runtime guidance](https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents) leaves scene routing to the app.

[OpenURLIntent](https://developer.apple.com/documentation/appintents/openurlintent) and URLRepresentableEntity use universal links. A custom URL scheme accepted by a Foundation.URL initializer is not evidence that either protocol supports it. Planner currently has neither universal-link support nor an associated domain. Plain OpenIntent avoids requiring that infrastructure for these actions.

The installed TargetContentProvidingIntent and SwiftUI onAppIntentExecution route are unavailable on native macOS. A mobile-only scene API therefore cannot be the sole handoff for the accepted native Mac app.

Apple's [App Shortcuts guidance](https://developer.apple.com/videos/play/wwdc2023/10102/) supports one provider with at most ten App Shortcuts. App Intents remain usable in Shortcuts without a provider. A provider supplies an initial discoverable set and phrases; it need not list every ordinary action. Phrases must include the application name and can interpolate at most one parameter.

These facts were checked by a read-only SDK investigation and the primary documentation. Root also fetched the current OpenIntent, OpenURLIntent and runtime-guidance Markdown on 21 October. No system invocation, routing prototype, signing change or platform acceptance is claimed.

## Q122, opening a saved plan

Goal: select an exact saved List or Itinerary from a native action without changing its content, reference identities or completion. Resolve the current dataset and source identity rather than trusting a stale display name. Missing or wrong-kind sources must fail clearly, without choosing a similarly named plan. Archived plans remain valid targets.

A. Reuse one Planner window. Route to the currently focused main window, or the main window brought forward when none is focused. Preserve the existing New Item Save, Discard and Keep editing protection. Save must finish validation and persistence before navigating; Keep editing leaves the requested plan unopened. Other windows retain their selection. The action must distinguish accepting a navigation request from actually showing the target while a draft decision is pending. This is the recommended familiar browsing workflow, but it needs a proved single-window handoff.

B. Open or reuse a separate plan window on Mac and iPad where supported; use the existing pushed navigation on iPhone. Existing windows and drafts remain untouched. Repeated opens should reuse the same target window where native scene APIs support it. This avoids replacing an editor but creates more windows and requires a separate cross-platform scene and restoration contract.

C. Explicitly defer Open List and Open Itinerary beyond the current map. Find/Get remain available as data actions. This reduces current implementation and window qualification, but leaves native opening unavailable.

Recommendation: A. The concrete navigation handoff and any additional production test boundary must follow the selected window policy. No global broadcast to every window, custom URL route, silent draft discard or forced signing setup is implied.

## Q123, the initial discoverable App Shortcuts

This choice is independent of Q122. Every action named below already exists; unfinished Open actions need not block a useful initial provider.

A. Publish four initial shortcuts: Create Item, Find Items, Find Lists and Find Itineraries. Use simple phrases with the application name; retain each action's existing prompted fields, typed results, filters and authority. Other actions remain available in the ordinary Shortcuts action library. This is the recommended small starting set.

B. Publish eight initial shortcuts: the four above plus Set Item Done Everywhere, Set Item archive state, Add Item to List and Move Item between Lists. This exposes organization and global completion immediately, but increases discovery clutter and the phrase/picker journeys to qualify. The completion shortcut must explicitly say Done everywhere; it does not complete one local appearance.

C. Defer a discoverable App Shortcut set until the remaining ordinary adapters are complete. Existing App Intents stay available for manually built shortcuts, but Planner has no initial provider in this slice.

Recommendation: A. This adds discovery metadata for existing actions, with no new data permission, aggregation rule or mutation command. Actual Siri phrasing, discovery and prompted input remain system qualification gates.

## Definition of ready

Both choices are explicitly accepted. Implement the four-shortcut provider independently while preparing the concrete single-window handoff for review. Signing and account setup stay deferred. The existing Q112 production Intent/EntityQuery boundary is approved; any additional controller or scene test boundary requires its own concrete review before tests are written.

## Required tests and definition of done

For opening, test the production action's exact source identity, current dataset, archive acceptance, missing/wrong-kind target, cancellation and unavailable storage. Navigation tests must prove one intended window, unchanged other windows, cold and warm entry, existing draft choices, invalid Save remaining in the editor, compact push behavior and adaptation through resizing. An action result must not falsely report that content opened when a draft decision prevented it. Preserve all saved content, order, state and bookings.

For discovery, inspect the real extracted provider/action metadata and phrase declarations while preserving the existing 69 action contracts. Exercise the underlying production actions at Q112's approved interface. Compile matching affected Mac, Simulator and unsigned device products and run affected lint/type checks. System discovery, voice phrases, parameter prompting and invocation require actual supported system journeys; static metadata is not runtime proof.

Record genuine failures and source epochs. No live service, paid account, device install, new target or test-only navigation argument is authorized by this document. The owning prototype issues remain open until their full DoD and human review are satisfied.
