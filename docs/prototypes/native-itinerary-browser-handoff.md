# Itinerary browser fallback qualification

The accepted native reader can open a saved guide from an Item or an Itinerary.
The existing external-fallback journeys cover Item guides. This follow-up uses
the same native UI and loopback HTTP boundary for an Itinerary with two saved
links. No production behavior, package, target or public interface changes.

## Represented workflow

Each journey opens the Itinerary's Museum guide, verifies its Return to
itinerary action, then selects either a requested download or unsupported
content. The native explanation displays that exact target. Explicit external
opening brings Simulator Safari forward and produces a new GET for that target,
with a Safari user agent distinct from Planner's observed requests.

Returning to Planner retains the rendered guide. Garden, Back and Return still
work. Both original saved bookmark identities and URLs remain, and the same
Itinerary name is available. The test makes no claim about a completed download,
file delivery or rendering unsupported content in Safari.

## Current local checkpoint

Both Itinerary cases pass on light iPhone and dark iPad. The two original Item
cases also pass after the shared test-helper extension. These are six native
executions across four functions, with zero failures, skips or SQLite-unlink
diagnostics. All 1160 input hashes reconcile across the three mobile cohorts,
the workspace and matching Mac compilation. Temporary appearance settings are
restored. Strict affected Swift and Markdown lint pass.

Eight original Itinerary alert/return captures are inspected. The evidence
retains the actual Safari request records and other screenshots separately.
These checks establish the represented linked-content handoff and current
return context, not all browser policies or whole-app accessibility.

[Final verification](evidence/native-itinerary-browser-handoff/final-validation.json)
records the exact cohort and scope. First-party cookie persistence already has
its own [viewer-closure and relaunch qualification](native-webpage-cookies.md#final-local-qualification),
so it is not rerun for this source-only test extension.

## Remaining gates

Actual Mac UI and window interaction, physical website behavior and final
human/assistive review remain open. The host still reports its 14 October boot
and 17 October native test-broker start; an unchanged external Mac UI startup
attempt is not repeated. This is separate from signing. Signing stays deferred,
and advanced manual portability remains post-MVP.
