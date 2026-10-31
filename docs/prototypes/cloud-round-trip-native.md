# Native private CloudKit content round trip

Native checkpoint, 27 October 2026, following
[asynchronous setup](cloud-setup-native.md).

Six signed native app executions now pass two complete synthetic transport
cohorts in the approved private Development database. Each cohort uses separate
fresh native stores for reading and deletion verification:

1. A writer saves or resumes one exact synthetic Item and observes export.
2. A fresh store imports that Item, verifies its public identity, lifetime, title,
   notes, global Done and archive state, then removes only that fixture and
   observes a subsequent export.
3. Another fresh store completes initial import and verifies the fixture's
   absence. An empty read before initial import is not accepted as deletion proof.

The first successful cohort resumes the exact fixture retained by the failed
direct-launch attempt. The second creates a new fixture through the final launch
path, so it separately qualifies insertion without relying on reopening.
The fresh writer, reader/cleanup and deletion verifier finish in 2.826, 3.052 and
1.773 seconds. These measurements are observations, not a synchronization SLA.

## Diagnostic corrections

The first window-appearance task stalls without producing a result. Its writer
reaches the external 210-second deadline; the follow-on phase is stopped instead
of repeating that startup path. Execution is moved into diagnostic App
initialization with progress markers. The native cleanup check later finds the
first attempt's run directory absent.

With initialization-owned execution but direct executable startup, the fixture
does save locally. No export beginning after that save completes within the
60-second observation window, and a fresh reader cannot find it. The process's
actual unified logs report `BGSystemTaskSchedulerErrorDomain Code=3` and failure
to find the background task service. That cohort remains failed; its later empty
read is not claimed as successful cleanup.

The next run uses normal macOS Launch Services through `/usr/bin/open`, preserving
stdout/stderr capture and bounded runtime. It resumes and exports the exact
previously saved fixture, then passes remote read and cleanup. A separate fresh
insertion cohort passes through the same final launch path. No service restart,
private framework hook, trust override or production workaround is introduced.
This proves the final native launch path; it does not claim the earlier system
diagnostics are universally resolved.

## Evidence and cleanup

Evidence preserves the failed
startup and direct-launch attempts, final diagnostic source and commands, exact
event/results and a verified 90-member archive. Hashes cover all 90 actual Core
sources, three probe inputs and seven actual signed bundle files. The exact
fresh results and
resumed results are
separately readable. The final signature/profile checks pass before execution.

Both cloud fixtures are confirmed deleted before local scratch cleanup. A
separately signed App Group cleanup app removes only four known completed probe
directories: 30 regular files, 7,859,208 logical bytes. It verifies that the stalled
run's directory is absent. Its native result
and verified cleanup source/build/launch archive are retained. It opens no normal
Planner store, changes no cloud data and leaves reusable build caches intact.
Shell access to App Group data was denied; cleanup uses the app's approved group
access without expanding shell permissions.

## Remaining scope

This is real native SwiftData/private-CloudKit Item transport on one Mac/account,
using actual production model types. It bypasses Planner commands, domain
validation and independent recovery publication. It therefore does not qualify
Planner save acknowledgement, transaction/conflict behavior, coherent account
ownership, installed Share, physical devices or production sync integration.

Production Planner remains local-only. The user initially defers account testing,
then resumes Planner-only off/on on 29 October. The
[read-only availability check](cloud-account-availability-native.md) verifies the
actual loss/restoration signal and same account without opening Planner data.
Its subsequent managed-store off/on check verifies cache clearing while disabled
and exact reimport after restoration. Production still must preserve local plans
independently of that cache reset. Ownership integration and different-account
behavior retain their own gates. The user changes settings manually; this does
not authorize whole-account sign-out or production sync activation. Native and
final UI gates remain separate; advanced export/import remains outside MVP.
