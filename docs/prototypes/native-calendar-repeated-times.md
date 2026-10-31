# Native repeated-hour Calendar previews

Calendar's start-only previews distinguish repeated local clock times using native timezone names. Compact Day/Week cards keep the distinguishing name visible; their full date remains in the accessibility description. A late-card regression also corrects the scrollable bottom allowance.

## Context and goal

Before: two independently saved New York Schedules at 05:30 and 06:30 UTC on 1 November 2026 both showed `Start only · Nov 1, 2026 at 1:30 AM`. Their separate rows and tap targets survived, but their descriptions were identical. After: the native Foundation format includes EDT or EST on a day whose timezone offset changes. The same names distinguish the repeated hour labels.

The first Week capture then showed that a long date caption hid the suffix in a narrow card. Start-only grid previews now show the time without repeating the already displayed day. Their scaled minimum height accommodates the preview; Month and accessibility descriptions keep the full date. This is presentation only, with no Schedule, source, Core, schema or wire changes.

Review found that the taller card could overrun the old 44-point day-column allowance. The native 23:59 tracer reproduced a bottom frame of 1194 points against a viewport ending at 1180. The allowance now uses the same scaled card minimum.

## Definition of ready

Day/Week/Month and per-device display-zone behavior are accepted. The existing public Core and native UI seams are approved. Fixture seeding uses actual Core Item/Schedule commands in the existing separate fixture app, which hosts production planner views. No production testing parameter or preview provider is added.

The timezone text uses Apple's [specific timezone name format](https://developer.apple.com/documentation/foundation/date/formatstyle/symbol/timezone/specificname(_:)). Clock-change detection compares native offsets at the actual local day's boundaries. Saved instants, planning zones and all-day civil dates remain unchanged.

## Definition of done for this step

- Reproduce identical descriptions through the native UI before changing formatting.
- Distinguish both 01:30 instants and hour labels without editing the saved forms or identities.
- Show useful compact start-only captions in Day/Week and retain full descriptions for accessibility and Month.
- Reproduce and correct the late-card boundary through native UI geometry, beyond existence or hittability alone.
- Qualify the native phone/tablet cases, relevant existing Calendar behavior, lint/type checks and separate review axes. Inspect and retain original captures with hashes.

## TDD and qualification

The repeated-hour phone tracer first failed because both native descriptions were equal. The later iPad late-point tracer failed because its complete card could not fit in the scrollable viewport. These are distinct observed failures; the first setup attempt also caught a missing Swift `try` before a UI journey ran and provides no runtime qualification.

The repeated-hour journey checks two Schedule identities, independent hit targets, EDT/EST descriptions and consistent full descriptions across Day, Week and Month. The late-point journey checks that the complete 23:59 card fits inside the Day viewport. Both fixtures use literal UTC instants and native controls to choose New York and the display date.

The final fixture pair passes on both simulators, two functions per device with no failures or skips. Seven existing Calendar functions also pass on each simulator. The phone regression run preceded the bottom-allowance fix; the iPad regression run and both final fixture runs include it. The iPad fixture run preceded a test-only readiness wait added to the setup helper. The final phone fixture run includes that wait. The assertions and production views are unchanged between those two fixture runs.

An earlier phone pair had one setup failure before entering Calendar. Its captured hierarchy showed the Calendar tab arriving after the navigation helper had already checked for it. The fixture helper now waits for the native tab before navigating. This is separate from the reproduced late-card geometry failure and changes no production behavior.

The affected iOS app/fixture/test products and Mac app/UI-test host compile. Strict Swift formatting lint, Markdown lint and whitespace checks pass. Standards and Spec reviews have no remaining confirmed findings. Core and HTTP behavior are unchanged by this step; their prior qualification remains in [Calendar capture retention](calendar-capture-retention.md), without claiming a new invocation here.

Execution evidence records the actual commands, counts, current source/product hashes and raw report summaries. It retains original red/green screenshots, the phone readiness failure and compressed execution logs. All four final captures per device were inspected individually at their original resolution. Day/Week show separate readable EDT/EST captions, Month shows the full dated descriptions, and the complete late card fits above the phone tab bar and inside the iPad viewport.

## Remaining work

[Q83 hour alignment](../calendar-time-grid-alignment-question.md) remains pending. The current columns still use elapsed time; this step does not choose clock alignment or gap rows. Booked-span formatting across clock changes, other temporal cases, Dynamic Type, broader accessibility/keyboard/adaptive checks and Mac native runtime retain their gates. Physical sync/account/Share and whole-app polish remain open. Apple Calendar export stays outside the map.
