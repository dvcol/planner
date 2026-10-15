# Native file delivery with an unavailable store

## Context, before and goal

The [unavailable-store recovery journey](native-unavailable-store-recovery.md) proves inspection, exporter handoff and cancellation while the initialized SQLite database is missing. It does not prove actual file delivery from that state. Existing ready-store exports establish the native file destination and public JSON boundary.

The goal is to export the retained generation's Item, Tag, notes and association through the native picker without opening or replacing the unavailable dataset. Compare the delivered file with identities observed in the native selection. After relaunch, the same saved generation remains separate and the main store remains unavailable.

## Definition of ready

R13/R20 and Q52 already approve independent recovery, explicit manual export and real local fixtures using production views. Reuse the acknowledged generation-2 missing-store fixture and existing public file destination. This qualifies an implemented behavior; no functional feature red is claimed. Production Core, HTTP, native views, schema and portable format must remain unchanged.

## Required qualification and definition of done

- Observe the unavailable screen and one acknowledged snapshot. Inspect saved generation 2, Item/Tag identities, one association and disabled Restore.
- Save through the native local file picker. The successful filename must identify the selected namespace and generation. Attach native-observed identities and the disposable fixture identifier for output provenance.
- Read the actual delivered JSON. Verify portable format 2, exactly the observed Item/Tag, expected notes and association, with other data groups empty. Exclude internal recovery envelopes, account credentials and UI state.
- Relaunch and verify that the store remains unavailable and the same snapshot generation and source identities remain inspectable. Export must not initialize or restore a dataset.
- Run both unavailable-store journeys on phone/tablet, affected strict lint and the fixture Mac test-host build. Inspect original captures and record actual commands, source/product hashes and file provenance.

Exact byte fidelity requires a separate original selected-byte comparison. This small fixture does not qualify full-graph exports, proposal export, file-write failures, replacement-dataset restoration, Mac runtime, physical account/sync/Share, broader accessibility/scale or whole-app polish. Q85 sorting stays independent and pending.

## Execution

Production and the disposable fixture are unchanged from `f1c6b11`. The native test file adds one delivery journey and reuses the existing inspection, visibility and missing-store assertions. The cancellation/retry journey is unchanged and runs beside it. Six qualification source hashes remain frozen across the runs.

| Boundary | Executed result |
| --- | --- |
| iPhone 18 Pro simulator, iOS 27 | Two functions in one suite passed, zero failures or skips. |
| iPad simulator, iOS 27 | Two functions in one suite passed, zero failures or skips. |
| Mac fixture and UI test host | Test build succeeded. No native Mac journey ran. |
| Strict Swift formatting | One changed Swift file passed. |

The delivery journey observes the selected namespace, generation 2 and source identities before using the native local destination. It checks the reported filename, disabled Restore and absence of an export error. After delivery and relaunch, Planner still reports its initialized database missing and exposes the same saved generation and source identities.

The actual delivered phone and tablet files are each 1,317 bytes. Each has its own native-observed identities and destination/hash provenance. Each portable-format-2 root contains exactly the permitted data groups. The two sources match the native-observed Item and Tag identities and expected names. The Item retains its saved notes, global Todo and Active state. One association binds that Item and Tag with their matching lifetime identities. All other portable groups are empty. The file contains no internal recovery envelope or extra root fields for account credentials or UI state.

[Execution evidence](evidence/navigation/native-unavailable-store-export/) retains the delivered public file and its destination/hash provenance, native-observed expectations, original captures, raw results and exact checks. These checks compare semantic output with the native observation. They do not compare bytes with a separately issued Core selection or qualify full-graph fidelity.

All twenty original captures were inspected individually. Each device has ten files comprising six distinct images. The phone duplicate groups contain four and two files; the tablet groups contain three and three. The explanation, picker, successful filename and retained-copy screens are readable. Both actual delivered files pass the recorded checks. This is qualification of existing behavior; no functional red or new production implementation is claimed. Core and HTTP receive no new runtime-test credit. Mac evidence is build-only. The broader gates in the definition of done remain open, and Q85 requires a human choice.
