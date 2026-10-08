# Native calendar date capabilities

Research for [Native calendar date capabilities](https://github.com/dvcol/planner/issues/21), verified **2026-10-08**. Context is the [current decision map](https://github.com/dvcol/planner/issues/1), [product brief](../product-brief.md), [glossary](../../GLOSSARY.md) and [accepted estimate distinction](../duration-and-search.md). The [Apple capabilities report at 05d11b2](https://github.com/dvcol/planner/blob/05d11b267af95630dcfebcecf37695597c0e78ba/docs/research/apple-capabilities.md) already establishes EventKit access, required event fields and unstable Calendar identifiers. Those findings remain the prerequisite; this report investigates date handling only.

Foundation provides explicit civil-date, time-zone, missing-time and repeated-time capabilities. EventKit accepts absolute start/end values and a floating or explicit time-zone setting. Its all-day end representation has a documented macOS distinction, so a universal exclusive-midnight EventKit contract is unsupported.

No calendar/account access, writes, Foundation execution, EventKit execution, production Swift code or application tests occurred. Worked UTC values are independently checked documentary arithmetic. They are neither selected Planner outcomes nor passing native runtime tests. The unanswered itinerary questions, supported forms, default end, zone/display behavior and ambiguous-time policy remain with [Itineraries and scheduling](https://github.com/dvcol/planner/issues/9).

## Installed and first-party evidence

Read-only tool commands used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` per command. Xcode reports **27.0**, build **27A266a**; Swift reports **6.4**, `swiftlang-6.4.0.34.1`. No global developer selection changed. Both SDKs were inspected:

- `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk`
- `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk`

| Capability | Introduced: iOS/iPadOS; macOS | Installed evidence and boundary |
| --- | --- | --- |
| Date / Calendar / TimeZone | 8; 10.10 for the Swift value APIs discussed | Foundation interfaces include Calendar at line 1941, construction/arithmetic at 2054 to 2073, and matching policies at 2105 to 2128 in both SDKs. [Date](https://developer.apple.com/documentation/foundation/date), [Calendar](https://developer.apple.com/documentation/foundation/calendar) |
| DateComponents and validity | 8; 10.9 | Supports optional fields and an explicit calendar/zone. Validity checks existence, not which repeated occurrence to use. [Components](https://developer.apple.com/documentation/foundation/datecomponents), [Validity](https://developer.apple.com/documentation/foundation/datecomponents/isvaliddate(in:)) |
| Calendar date interval | 10; 10.12 | Provides component start/duration; no fixed 24-hour-day contract. [Calendar interval](https://developer.apple.com/documentation/foundation/calendar/dateinterval(of:for:)) |
| EKEvent start/end/all-day | 4; 10.8 | `EKEvent.h:64–86`, both SDKs. Start/end are initially nil; property presence does not prove omitted/equal-end save support. [Start](https://developer.apple.com/documentation/eventkit/ekevent/startdate), [End](https://developer.apple.com/documentation/eventkit/ekevent/enddate) |
| Calendar-item timeZone | 5; 10.8 | `EKCalendarItem.h:84`, both SDKs; nil has documented floating semantics. [Event time zone](https://developer.apple.com/documentation/eventkit/ekcalendaritem/timezone) |
| Missing/reversed endpoint errors | Available in both OS 27 SDKs | `EKError.h:27–29,67–69` declares noStartDate, noEndDate and datesInverted. These are documented error meanings, not observed saves. [No end](https://developer.apple.com/documentation/eventkit/ekerror/code/noenddate), [Reversed dates](https://developer.apple.com/documentation/eventkit/ekerror/code/datesinverted) |

The first-party Swift Foundation source was read at immutable commit `2df17f28d6cd4aa0cf27cc66598fcabbcde8292c`. Its public `date(from:)` delegates to a backend; the inspected ICU backend copies the calendar when components specify another zone. Its validity method reconstructs and compares supplied civil fields. This supports the distinction between construction and validation, but the open-source revision is not proof of the implementation or results inside the installed Apple binaries. [Public construction](https://github.com/swiftlang/swift-foundation/blob/2df17f28d6cd4aa0cf27cc66598fcabbcde8292c/Sources/FoundationEssentials/Calendar/Calendar.swift#L695), [ICU zone handling](https://github.com/swiftlang/swift-foundation/blob/2df17f28d6cd4aa0cf27cc66598fcabbcde8292c/Sources/FoundationInternationalization/Calendar/Calendar_ICU.swift#L1136), [Validity source](https://github.com/swiftlang/swift-foundation/blob/2df17f28d6cd4aa0cf27cc66598fcabbcde8292c/Sources/FoundationEssentials/Calendar/DateComponents.swift#L406)

## Absolute instants and civil components

Date identifies an instant independently of calendar or zone. It does not retain the user's intended zone, omitted clock fields or date-only meaning. DateComponents can hold year/month/day with or without hour/minute and is interpreted using a calendar and zone. Missing component fields are nil. A nil component calendar has API-dependent behavior; it is not a portable instruction to use Gregorian or UTC. [Absolute date](https://developer.apple.com/documentation/foundation/date), [Civil components](https://developer.apple.com/documentation/foundation/datecomponents), [Optional calendar](https://developer.apple.com/documentation/foundation/datecomponents/calendar)

`Calendar.date(from:)` returns a Date or nil. It exposes no matching/repeated-time arguments. Obtaining a value must not alone be treated as proof that all requested civil fields existed unchanged. DateComponents validity and explicit component round-tripping are native validation candidates; the eventual public conversion must also resolve repeated times and bound matching to the intended day. Keep calendar and zone inputs consistent when comparing returned components. [Construction](https://developer.apple.com/documentation/foundation/calendar/date(from:)), [Existence validation](https://developer.apple.com/documentation/foundation/datecomponents/isvaliddate(in:))

TimeZone.current represents the system zone; autoupdatingCurrent tracks preference changes unless mutated. These are environment-dependent inputs. Explicit identifiers and an explicit calendar make a conversion's assumptions recordable. `dateComponents(in:from:)` overrides the receiving calendar's zone for that calculation. Formatting is a separate display operation. Whether Planner follows the device, preserves an entry's place zone, or shows both remains a product decision. [Current zone](https://developer.apple.com/documentation/foundation/timezone/current), [Updating zone](https://developer.apple.com/documentation/foundation/timezone/autoupdatingcurrent), [Explicit-zone components](https://developer.apple.com/documentation/foundation/calendar/datecomponents(in:from:))

### Tokyo-to-Paris candidate fixture

Assume Gregorian civil dates and the named zones below. The UTC values are arithmetic, not results from Foundation or EventKit.

| Interpretation | Civil display/input | Absolute candidate |
| --- | --- | --- |
| Tokyo appointment | 2026-10-09 10:00, Asia/Tokyo, UTC+09:00 | 2026-10-09T01:00:00Z |
| Same instant displayed in Paris | 2026-10-09 03:00, Europe/Paris, UTC+02:00 | The same 01:00Z instant |
| A floating 10:00 interpreted in Paris | 2026-10-09 10:00, Europe/Paris, UTC+02:00 | 2026-10-09T08:00:00Z |

The third row preserves the local clock rather than the instant. Neither interpretation is selected. A Date formatted as UTC does not itself persist the originating zone or floating intent. Offsets must be evaluated for the particular date, rather than fixed forever from an abbreviation or today's offset. [Date-dependent offset API](https://developer.apple.com/documentation/foundation/timezone/secondsfromgmt(for:))

## Missing and repeated wall-clock times

Calendar.nextDate accepts matchingPolicy, repeatedTimePolicy and direction. Its documented defaults are nextTime, first and forward. Defaults are native API behavior, not approval to apply them silently in Planner. Strict matching can search farther for an exact occurrence, subject to implementation limits. A search for only hour/minute may find another day; date-bounded or fully specified validation is required if the question is about one particular day. [Date search](https://developer.apple.com/documentation/foundation/calendar/nextdate(after:matching:matchingpolicy:repeatedtimepolicy:direction:)), [Strict matching](https://developer.apple.com/documentation/foundation/calendar/matchingpolicy/strict)

For Gregorian **America/New_York 2026-03-08 02:30**, the wall clock is in the spring gap. Apple describes these missing-clock policies; the rows give corresponding candidate civil/UTC values for this dated example. No policy invocation was executed.

| Documented policy | Candidate interpretation for this gap | UTC arithmetic |
| --- | --- | --- |
| strict | Require the exact components; no exact instant exists for this specified local date/time. An unconstrained search may continue to another matching date. | No exact 02:30 candidate |
| nextTime | Use the next existing clock time, dropping smaller-component preservation. | 03:00 EDT, UTC−04:00, gives 07:00Z |
| nextTimePreservingSmallerComponents | Move to the next existing hour while retaining minute 30. | 03:30 EDT gives 07:30Z |
| previousTimePreservingSmallerComponents | Move to the earlier existing hour while retaining minute 30. | 01:30 EST, UTC−05:00, gives 06:30Z |

The policy meanings are documented in [nextTime](https://developer.apple.com/documentation/foundation/calendar/matchingpolicy/nexttime), [later preservation](https://developer.apple.com/documentation/foundation/calendar/matchingpolicy/nexttimepreservingsmallercomponents) and [earlier preservation](https://developer.apple.com/documentation/foundation/calendar/matchingpolicy/previoustimepreservingsmallercomponents). An actual OS 27 conversion must verify its anchor, supplied components, result day and chosen policy through the future public interface.

For **America/New_York 2026-11-01 01:30**, two instants exist:

| Repeated occurrence | Offset | UTC candidate |
| --- | --- | --- |
| First occurrence | EDT, UTC−04:00 | 2026-11-01T05:30:00Z |
| Last occurrence | EST, UTC−05:00 | 2026-11-01T06:30:00Z |

RepeatedTimePolicy.first and last select the corresponding occurrence when multiple matching times exist. Existence validation does not select one. The human must choose whether Planner asks, rejects ambiguity, or applies a recorded policy; the report selects none. [First occurrence](https://developer.apple.com/documentation/foundation/calendar/repeatedtimepolicy/first), [Last occurrence](https://developer.apple.com/documentation/foundation/calendar/repeatedtimepolicy/last)

Merely attaching a zone is not existence validation. Scratch Python attachment of the nonexistent 02:30 with its two fold settings round-tripped through UTC to 03:30 or 01:30. That demonstrates a limitation of that calculation technique, not Foundation's runtime result or Planner's handling.

## Date-only, all-day and calendar-day ranges

A date-only assignment can retain civil year/month/day and its calendar interpretation. Resolving it to midnight creates an instant and does not by itself turn the domain assignment into an all-day event. EventKit's isAllDay is an explicit flag. Planner must choose which forms it supports and how precision/zone intent survive storage and export; an activity estimate is not automatically a scheduled end. [Components](https://developer.apple.com/documentation/foundation/datecomponents), [All-day property](https://developer.apple.com/documentation/eventkit/ekevent/isallday)

Calendar arithmetic adds calendar components; fixed elapsed arithmetic adds seconds. `startOfDay(for:)` returns the first actual moment of the day, including days with repeated or missing midnight. `dateInterval(of:for:)` supplies that component's actual start/duration. Therefore midnight and 86,400 seconds are not universal definitions of a civil day. Foundation DateInterval is documented as closed, permits zero duration and rejects reverse intervals. It is not a half-open event-range convention. [Calendar addition](https://developer.apple.com/documentation/foundation/calendar/date(byadding:value:to:wrappingcomponents:)), [Start of day](https://developer.apple.com/documentation/foundation/calendar/startofday(for:)), [Component interval](https://developer.apple.com/documentation/foundation/calendar/dateinterval(of:for:)), [Closed DateInterval](https://developer.apple.com/documentation/foundation/dateinterval)

A candidate representation for **Friday 2026-10-09 through Sunday 2026-10-11** is three included Gregorian civil dates. If an implementation chooses a half-open interval in America/New_York, it can use Friday's local day boundary through Monday 2026-10-12's local boundary. This is an illustrative representation, not a selected Planner zone/range convention or an EventKit end-date rule.

| Three included New York dates | Candidate start UTC | Candidate exclusive next-day end UTC | Elapsed time |
| --- | --- | --- | --- |
| 2026-10-09 through 2026-10-11 | 2026-10-09T04:00:00Z | 2026-10-12T04:00:00Z | 72 hours |
| 2026-03-06 through 2026-03-08 | 2026-03-06T05:00:00Z | 2026-03-09T04:00:00Z | 71 hours |
| 2026-10-30 through 2026-11-01 | 2026-10-30T04:00:00Z | 2026-11-02T05:00:00Z | 73 hours |

All rows cover three civil dates. Multiplying three by a fixed 24-hour estimate cannot reproduce both DST intervals. The accepted estimate units remain fixed elapsed quantities; calendar spans require their separate agreed meaning.

## EventKit conversion and endpoint limits

For a floating event, EKCalendarItem.timeZone is nil. Apple says its start/end values should be set as if in the system zone; the event occurs at its local clock regardless of zone. EKEvent.startDate says floating events, including all-day events, are returned in the default zone. This makes the returned Date representation environment-dependent; it does not justify treating returned UTC midnight as the canonical date-only value. [Floating events](https://developer.apple.com/documentation/eventkit/ekcalendaritem/timezone), [Returned start](https://developer.apple.com/documentation/eventkit/ekevent/startdate)

| Input or situation | Documentary conclusion | Remaining native check/product choice |
| --- | --- | --- |
| Timed entry with an explicit end | Set the required start/end and explicit/floating zone according to the resolved semantics; save can throw. | With other required fields valid, test a candidate New York 2026-10-09 10:00 to 11:00, 14:00Z to 15:00Z, then read/reopen it under the selected access path. |
| Timed entry without an end | New EKEvent.endDate remains nil until assigned; noEndDate is a documented error. No reviewed contract supplies Planner's default end. | Choose a product export policy for an optional Planner end. Test missing-end validation/save behavior without assuming one-hour or estimate-based synthesis. |
| End equals start | The date properties can hold equal Date values. datesInverted describes end before start; DateInterval separately permits zero duration. Neither fact establishes EventKit/backend acceptance of zero-duration events. | Test a provided equal endpoint, such as 14:00Z/14:00Z, with the chosen source/backend and UI path. Record rejection, normalization or readback; product behavior remains undecided. |
| End before start | datesInverted describes this error condition. | Exercise explicit validation and actual save failure with a candidate 14:00Z start / 13:59Z end. Preserve canonical Planner data on failure. |
| All-day/multi-day range | No reviewed cross-platform contract establishes one exclusive-midnight setter/readback rule. | Exercise candidate civil ranges on each platform; verify inputs, save result, returned dates and displayed included days independently. |

These limits come from the inspected headers and [missing end](https://developer.apple.com/documentation/eventkit/ekerror/code/noenddate), [reversed dates](https://developer.apple.com/documentation/eventkit/ekerror/code/datesinverted), [endDate](https://developer.apple.com/documentation/eventkit/ekevent/enddate) and [save](https://developer.apple.com/documentation/eventkit/ekeventstore/save(_:span:commit:)). Error declarations are not a complete backend validation matrix. No save or editor acceptance was observed.

### macOS getter behavior is not a universal end convention

Apple TN3130 documents that, for its macOS 13-linked behavior, an all-day endDate getter returns **23:59:59 on the final day**. Legacy behavior returned **00:00:00 on the following day**. For the October New York example, those conditional representations correspond to 2026-10-12T03:59:59Z and 2026-10-12T04:00:00Z. This is getter documentation, not proof that either setter value produces the intended saved three-day event on OS 27. [macOS EventKit changes](https://developer.apple.com/documentation/technotes/tn3130-changes-to-eventkit-in-macos13-ventura)

The same technote documents that changing timeZone no longer changes an event's absolute time for that linked macOS behavior. Its iOS companion TN3132 covers other changes, including rollback after failed commit=true, but does not establish a corresponding all-day end or timeZone-setter rule. Do not infer iOS/iPadOS parity from the Mac note or treat absent documentation as a contrary guarantee. Each OS 27 platform and chosen store/source needs actual round-trip evidence. Avoid a universal one-second adjustment or an unverified export default. [macOS distinction](https://developer.apple.com/documentation/technotes/tn3130-changes-to-eventkit-in-macos13-ventura), [iOS companion](https://developer.apple.com/documentation/technotes/tn3132-changes-eventkit-and-eventkitui-in-ios16)

## Arithmetic provenance and evidence limits

The worked examples assume Gregorian dates and the named Asia/Tokyo, Europe/Paris and America/New_York zones. They were independently computed using explicit UTC offset subtraction, Python datetime/zoneinfo, then read back using macOS `/bin/date -r <Unix-seconds>` with per-command TZ. The installed system zoneinfo version was **2026d**. Scratch evidence is `/private/tmp/planner-calendar-independent-arithmetic.json`; it is a calculation log, not application source or a repository test fixture. Root independently prepared a separate reference calculation for comparison.

For example, Tokyo 10:00 minus nine hours gives 01:00Z; Paris 03:00 minus two gives the same instant. Subtracting the UTC−04:00/UTC−05:00 offsets from New York 01:30 gives 05:30Z/06:30Z. Candidate range endpoint subtraction gives 259,200 / 255,600 / 262,800 seconds. Zoneinfo attachment and BSD readback do not establish Foundation matching or EventKit behavior. Time-zone rules can change; later tests must record the actual OS/time-zone data versions and explicit zone/calendar inputs.

## Required later public-boundary tests

Agree schedule conversion, validation, rescheduling and export interfaces under `/tdd` before Swift implementation. The human resolution must select exact expectations for open cases. Then implement one failing behavior and its minimal passing implementation at a time.

| Layer | Concrete obligations and expected boundary |
| --- | --- |
| Civil/instant unit tests | With an explicit Gregorian calendar and zone, test the Tokyo/Paris candidates and preservation of the selected precision/zone intent. Test that date-only metadata survives without silently becoming a timed appointment. Same instant and floating-clock scenarios receive separate human-approved expectations. |
| Missing/repeated-time unit tests | Include New York 2026-03-08 02:30 and 2026-11-01 01:30. Assert the chosen reject/prompt/resolve policy and exact instant or structured ambiguity result. Test requested-day bounds, invalid components and broad-search results so another day cannot masquerade as the chosen date. |
| Calendar-day unit tests | Verify the selected inclusive/half-open convention and included Gregorian dates for October, spring and fall Friday-Sunday inputs. If converted in New York as shown, independently assert 72/71/73-hour endpoint differences. Also test missing/repeated midnight behavior under a documented fixture zone without replacing calendar-day arithmetic with fixed estimate units. |
| Persistence/sync integration | Save/reopen on two devices using different device zones. Preserve the canonical UUID reference, date fields, optional end, precision, explicit/floating intent and chosen ambiguous occurrence. Changing a device zone must follow the selected display policy without unapproved domain mutation. Verify imported remote changes and rescheduling through the shared operation. |
| Native EventKit integration | For each supported export form, test provided, absent, equal and reversed ends. Record actual save errors, normalized fields and readback on OS 27 iOS/iPadOS/Mac with the selected source/calendar. Test isAllDay, explicit and nil timeZone, multi-day setters and returned endpoints, including TN3130's Mac distinction. No endpoint convention is deemed portable before this check. |
| Device/UI and failures | Exercise travel display, 12/24-hour locale presentation, time-zone changes, DST ambiguity prompts if selected, all-day included dates, editor cancellation and authorization/save failure. Preserve Planner's canonical schedule after failed/cancelled export. Verification needing Calendar readback must use the access path chosen in the existing policy; write-only access cannot supply that proof. |

No test row chooses unanswered itinerary semantics or claims native success. Permission and identifier details remain in the prerequisite report; this research adds no calendar-write authorization. [Core architecture](https://github.com/dvcol/planner/issues/12), [Navigation prototype](https://github.com/dvcol/planner/issues/14) and [Specification handoff](https://github.com/dvcol/planner/issues/17) must retain these documentary/runtime boundaries.

## Reproduction and document checks

Inspect NSCalendar.h, EKEvent.h, EKCalendarItem.h and EKError.h under each SDK's `System/Library/Frameworks/<Framework>.framework/Headers`. Selected SHA-256 fingerprints identify the exact inspected declarations without copying SDK content:

| Header | iPhoneOS SHA-256 | macOS SHA-256 |
| --- | --- | --- |
| NSCalendar.h | `9fffcbd417215185da10932f3db725d1ae1cbf02847007a811f0483f58eb7e06` | `5fcd6ae0fe87a81fd861abb39c8be73e4bf097b0f7f8dd25d5d2f319b6326100` |
| EKEvent.h | `b2f71613e98f0f58e7c8d366cc9139ecf169512608738cf4a098da02f1ebc36b` | Same |
| EKCalendarItem.h | `e7a810b989480305fccf1fa2dde439d25042b8b49b580187bfed12ccf41fedf0` | Same |
| EKError.h | `b53bf9d8424b2f588487c91bbdb525b5300bba9262ff7ae616a955dd0d75c649` | Same |

Document validation covers affected Markdown lint, local references, cited external destinations, whitespace and local/committed/immutable GitHub byte equality. Swift type checks and application tests are inapplicable. The map owner publishes the evidence-backed resolution and owns closure; this report leaves the issue open and changes no main-branch decision or map.
