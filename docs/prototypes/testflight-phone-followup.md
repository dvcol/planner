# TestFlight phone follow-up, 1 November 2026

The owner supplied five build 1 crash reports with the same termination:
`RUNNINGBOARD 0xdead10cc`. Apple's [SIGKILL documentation](https://developer.apple.com/documentation/xcode/sigkill)
identifies a file/database lock retained during suspension. The private-sync
worker held an App Group `flock` until it stopped, including while the app was
backgrounded.

iOS now keeps exclusive worker ownership in process memory. Its one main app
process owns synchronization; Share extensions never claim it. macOS retains
the existing file lock for independent app processes. Account binding, records,
serialization, local storage and cloud database selection are unchanged.

The focused ownership regression first reproduced the retained lock on iOS,
then passed with exclusivity, release and successor checks. The corresponding
Mac test also passes with its original kernel lock still exclusive. Actual iPhone
Home/lock-screen suspension still needs confirmation in the updated build;
Simulator coverage does not establish that OS behavior. No repeat iCloud off/on
or stress session is required.

Phone catalogs now use consistent leading headers, with full title width in
landscape and one Lists heading. Calendar uses a native toolbar mode menu and
date chooser on compact layouts. Its empty agenda has no card background;
dark event fills and quieter hour lines improve the time grid. The native
month picker remains scrollable in short landscape layouts.

Focused dark-mode iPhone Simulator journeys pass for all five tab headers in
both orientations, Calendar mode/date controls, List title consistency across
empty/populated/Map/relaunch states, and rotation with an exact saved Schedule.
Screenshots were visually inspected and remain temporary. Raw crash reports,
logs, screenshots and result bundles are excluded from the repository.

One existing clock-change fixture also passes through Day/Week and the exact
saved Schedule. Its obsolete pixel-height expectation was reproduced against
the committed UI before updating it for the existing denser grid. The fixture
now scrolls the complete card below the pinned header before tapping and checks
the current friendly timezone caption. No clock-placement rule changed.

The affected Mac app views also compile successfully. Build 2 keeps version
1.0.0 and is prepared for internal TestFlight, with App Store drafts paused.
