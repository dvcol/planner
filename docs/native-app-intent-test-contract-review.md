# Native App Intent test boundary review

Status: approved under Q112 A on 19 October 2026. Existing Q33 ordinary Intent authority and public Core/native parity requirements remain unchanged.

## Context and intended outcome

The repository has no Intent source. The first real-system creation/read journey now compiles in the existing native UI target against Xcode 27's public AppIntentsTesting framework. On the installed iOS 27 Simulator, invocation rejects with AppIntentsServicesSecurityErrorDomain 803, "Unable to run internal tests on a Customer build", before any Planner Intent can run. This is unavailable test infrastructure, not a feature red or evidence that developer signing would solve it.

The goal is repeatable local behavior tests while keeping actual system discovery, invocation, lock/restriction and confirmation as distinct native gates.

## Proposed additional boundary

Use the existing app-hosted PlannerMCPTests target to invoke production App Intents and EntityStringQuery methods through their declared interfaces. Use Apple's public `callAsFunction(donate: false)` to resolve parameters and invoke `perform`, rather than assuming a bare `perform()` call initializes dependency wrappers. Register the actual SavedPlannerStore in Apple's AppDependencyManager with a disposable real Core configuration. Use actual Foundation and durable local storage, normal native commands, and the existing real-filesystem recovery failure technique. Do not add an injected Intent environment, test-only parameters, an alternate dependency container, new target or package.

The first vertical slice creates one titled/noted Item, reads the returned stable identity through Core, invokes the read Intent, and verifies relaunch/reopen preservation. Follow with explicit global completion and query resolution. Missing/deleted IDs remain missing; unavailable bootstrap/read errors must not become empty successful results. Applied changes with incomplete recovery must report their real applied status rather than claim a fully saved change or retry creation. Unverified mutations must remain unverified and block further mutation as Core requires.

Core commands and source identities stay canonical. This boundary does not qualify actual Shortcuts/Siri metadata discovery, background process launch, system authentication, locked-device access or system bulk confirmation. Retain the native system test with explicit unavailable/skip evidence on restricted runtime builds and execute it when a supported runtime is available. Ordinary UI and real HTTP compatibility remain separate checks.

## Alternatives and impact

A. Approve this additional production-interface boundary. It permits local /tdd of the adapter and its real storage/outcomes while the actual system gates remain open.

B. Keep only the current real-system boundary. Investigate supported native invocation, then leave adapter behavior unqualified if the installed OS cannot execute it. No direct app-hosted Intent tests would be added.

The installed-service restriction does not authorize signing/account changes, private entitlements, security bypasses or a replacement system test service.

## Supported platform facts

Apple documents [in-app Intent invocation](https://developer.apple.com/documentation/appintents/appintent/callasfunction%28donate%3A%29-3qvbt) separately from system invocation. Its [testing session](https://developer.apple.com/videos/play/wwdc2026/295/) requires matching development-team signatures for app and UI-test runner. The public SDK has no documented Customer-build override. Neither fact proves that paid membership resolves the observed 803 error. The installed Shortcuts CLI runs existing user Shortcuts, and cannot construct an arbitrary new Intent action.
