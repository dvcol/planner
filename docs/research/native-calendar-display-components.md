# Native Calendar display components

Verified **2026-10-13** against Apple's primary documentation and the installed **Xcode 27.0, build 27A266a**, iPhoneOS 27.0 and macOS 27.0 SDKs. This note supports the accepted Planner-only Calendar destination with Day, Week and Month views, native phone tabs and large-screen navigation, fixed timed instants in a display time zone, and inclusive all-day civil dates. It selects no additional product policy.

The inspected public APIs provide native date selection, navigation, layout, scrolling, focus and accessibility components. **No public pre-made Calendar event time grid was found** in these SwiftUI, SwiftUICore, AppKit or UIKit SDK declarations or their corresponding Apple documentation. This is a scoped finding from the inspected APIs, not an Apple statement that no future framework can provide one. Planner-owned event placement, overlapping-event layout and multi-day presentation still need app logic. [SwiftUI controls](https://developer.apple.com/documentation/swiftui/controls-and-indicators), [SwiftUI layout](https://developer.apple.com/documentation/swiftui/layout-fundamentals), [UIKit calendar view](https://developer.apple.com/documentation/uikit/uicalendarview)

## Pre-made calendar and date controls

| Component | Public capability | Precise limit for this task |
| --- | --- | --- |
| SwiftUI `DatePicker` | Binds one `Date`; selects a calendar date and optionally time. `.graphical` supplies an interactive calendar or clock. | No event collection, per-date event content builder, hour-axis event placement, overlap layout, or Day/Week/Month event-view mode is exposed. It can select the date being displayed. [DatePicker](https://developer.apple.com/documentation/swiftui/datepicker), [Graphical style](https://developer.apple.com/documentation/swiftui/datepickerstyle/graphical) |
| SwiftUI `MultiDatePicker` | Binds `Set<DateComponents>` and displays a calendar for multiple date selection. | The SDK explicitly marks native macOS unavailable. Multiple selected dates are not a collection of scheduled events. [MultiDatePicker](https://developer.apple.com/documentation/swiftui/multidatepicker) |
| UIKit `UICalendarView` | Displays dates, single/multiple/week selection, and per-date decorations supplied by a delegate. Decorations can be a dot, image or custom `UIView`. | Apple describes it as only displaying and selecting dates. Its custom decoration API annotates one date; it exposes no event start/end layout, time axis or collision lanes. It is a UIKit control, requiring a SwiftUI bridge on iOS/iPadOS, and is not a native AppKit control. [UICalendarView](https://developer.apple.com/documentation/uikit/uicalendarview), [Decorations](https://developer.apple.com/documentation/uikit/uicalendarview/decoration) |
| UIKit `UICalendarSelectionWeekOfYear` | Selects a week described by `.yearForWeekOfYear` and `.weekOfYear`; available since iOS 18 in the inspected header. | It changes date selection within `UICalendarView`; it does not add a week event time grid. [Week selection](https://developer.apple.com/documentation/uikit/uicalendarselectionweekofyear) |
| AppKit `NSDatePicker` | Native Mac date/time selection, including `.clockAndCalendar`, a selected date or range, locale/calendar/time zone and selectable bounds. | The public value is `dateValue` plus `timeInterval` for range mode. No app event collection or decorated event grid is exposed. [NSDatePicker](https://developer.apple.com/documentation/appkit/nsdatepicker), [Clock/calendar style](https://developer.apple.com/documentation/appkit/nsdatepicker/style/clockandcalendar) |
| SwiftUI `TimelineView` | Redraws contained app views at scheduled update instants; has no appearance of its own. | Its schedule controls refreshing, not calendar event placement. It can update a time-dependent indicator if that behavior is wanted. [TimelineView](https://developer.apple.com/documentation/swiftui/timelineview) |

These date controls accept app-owned Foundation date values without calling `EKEventStore`. The distinction follows their public input contracts. Apple's Calendar database permission applies to accessing the system event store, which this accepted Planner-only display does not need. EventKitUI supplies event detail/edit and calendar-chooser controllers, rather than a Planner-owned Day/Week/Month time grid. Although some EventKitUI editors can run without requesting access on iOS 17+, they interact with system calendars and are not the requested display component. [EventKitUI](https://developer.apple.com/documentation/eventkitui), [Event-store access](https://developer.apple.com/documentation/eventkit/accessing-the-event-store)

## Native navigation and layout building blocks

`TabView` with `.tabViewStyle(.sidebarAdaptable)` already has the accepted native platform forms: bottom tabs on iOS, a top tab bar that can become a sidebar on iPadOS, and a sidebar on macOS. Its availability is iOS 18/macOS 15 in the inspected SDK. It supplies the destination container, without supplying a calendar event layout. `NavigationSplitView` separately provides native two/three-column navigation and collapses columns into a stack at narrow sizes; that collapse alone does not create a phone tab bar. [Sidebar-adaptable style](https://developer.apple.com/documentation/swiftui/sidebaradaptabletabviewstyle), [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)

`Grid` and `GridRow` provide a two-dimensional view layout, row/column alignment and column spanning. They can hold app-owned day cells or aligned day/hour headings. They do not know calendar dates, event durations or overlap rules. A `Grid` renders every child immediately. Apple's guidance is to change to `LazyVGrid`/`LazyHGrid` only when profiling shows a worthwhile benefit; lazy containers have less information for sizing and alignment. The choice therefore depends on measured content, not a native calendar capability. [Grid](https://developer.apple.com/documentation/swiftui/grid), [LazyVGrid](https://developer.apple.com/documentation/swiftui/lazyvgrid)

`ScrollView` supplies native horizontal, vertical or both-axis scrolling and does not supply zooming. Grids and stacks do not inherently scroll. `ScrollViewReader` provides programmatic scrolling to identified content. Existing SwiftUI view composition can place app event views within day columns, but clipping, time-to-position calculation, simultaneous-event lanes, hit targets and minimum readable size remain app responsibilities. These generic layout APIs cannot establish those behaviors by themselves. [ScrollView](https://developer.apple.com/documentation/swiftui/scrollview), [Container guidance](https://developer.apple.com/documentation/swiftui/picking-container-views-for-your-content)

## Calendar arithmetic and time-zone boundaries

Foundation `Date` represents an absolute instant independent of calendar or time zone. Changing the display zone should change component extraction and formatting, not the stored timed `start`/`end`. `Calendar.timeZone`, the formatter's time zone and SwiftUI's `EnvironmentValues.timeZone` can explicitly carry the display zone; `Calendar.locale` supplies localized conventions. This follows the accepted fixed-instant requirement. [Date](https://developer.apple.com/documentation/foundation/date), [Calendar](https://developer.apple.com/documentation/foundation/calendar), [SwiftUI time zone](https://developer.apple.com/documentation/swiftui/environmentvalues/timezone)

Useful public arithmetic APIs are:

- `dateInterval(of:for:)` for the boundaries of `.day`, `.weekOfYear` or `.month` containing the displayed date; it returns an optional interval. [Calendar interval APIs](https://developer.apple.com/documentation/foundation/calendar/dateinterval(of:start:interval:for:))
- `date(byAdding:value:to:wrappingComponents:)` for moving by calendar days/weeks/months, with `wrappingComponents: false`; it returns an optional date. [Adding components](https://developer.apple.com/documentation/foundation/calendar/date(byadding:to:wrappingcomponents:))
- `dateComponents(_:from:)` and `range(of:in:for:)` for date components, weekday position and the actual day range of a month. [Calendar components](https://developer.apple.com/documentation/foundation/calendar)
- `firstWeekday` and `minimumDaysInFirstWeek` for the display calendar's week conventions. `firstWeekday` is one-based and its default depends on calendar and locale. For Gregorian/ISO calendars, Sunday is `1`. [Week conventions](https://developer.apple.com/documentation/foundation/calendar/firstweekday)

Calendar days must not be assumed to equal 86,400 elapsed seconds. Apple's `startOfDay(for:)` explicitly handles duplicated or missing midnights, and calendar matching APIs distinguish repeated local times with `RepeatedTimePolicy`. Using calendar interval boundaries avoids a fixed-length assumption. An hour/minute-only vertical position can map two distinct instants onto the same wall time during a repeated hour; a time grid still needs deliberate rendering and accessible descriptions for that case. This is an arithmetic limit, not a new choice of DST presentation. [Start of day](https://developer.apple.com/documentation/foundation/calendar/startofday(for:)), [Calendar matching](https://developer.apple.com/documentation/foundation/calendar)

The existing model distinguishes `timed(start: Date, end: Date?, planningTimeZone: String)` from `allDay(start: PlannerCivilDate, end: PlannerCivilDate?)`. Civil dates contain Gregorian year/month/day, and existing validation uses Gregorian/GMT noon plus a component round trip. Native `DatePicker` binds an instant; a civil-date picker needs an explicit conversion that preserves those civil fields. The bound picker date must not silently redefine an all-day schedule's stored time-zone-independent dates. `DateComponents` become an absolute date only when interpreted in a calendar and time zone. [Planner schedule values](../../Packages/PlannerCore/Sources/PlannerCore/PlannerScheduleValues.swift), [Planner civil dates](../../Packages/PlannerCore/Sources/PlannerCore/PlannerCivilDate.swift), [DateComponents](https://developer.apple.com/documentation/foundation/datecomponents)

For the accepted inclusive all-day range, a cell's civil date belongs when `start <= cellDate <= end`, treating an absent end as the start date. Gregorian calendar addition can calculate successive civil dates and the day following an inclusive final date if an internal exclusive boundary is needed. That exclusive boundary is a display calculation; it must not replace the stored inclusive end. Timed day-bucketing also needs explicit comparisons at period boundaries so midnight is assigned once. This note does not select a new schedule endpoint, open-end height or first-weekday policy.

## Accessibility and keyboard support

SwiftUI includes accessibility support in its standard controls. Event content can use native `Button` or `NavigationLink` where appropriate, with descriptive labels, values and hints rather than gesture-only rectangles. Date/time descriptions can include the display zone and distinguish all-day content. Decorative grid lines can be hidden with `accessibilityHidden(true)`. These APIs support an accessible representation; they do not prove the finished grid's VoiceOver order, contrast, Dynamic Type fit or hardware-keyboard operation. [Accessibility fundamentals](https://developer.apple.com/documentation/swiftui/accessibility-fundamentals), [Accessibility modifiers](https://developer.apple.com/documentation/swiftui/view-accessibility)

`accessibilityElement(children: .contain)` groups a day's elements while retaining individual children. `.combine` merges child properties and `.ignore` hides children, so applying them to multiple actionable events changes what assistive technology can reach. `accessibilityChildren` supplies synthetic child elements, and `accessibilityRepresentation` replaces the accessible representation if a custom drawing needs one. A visual layout does not itself establish a chronological accessible order. [Contain behavior](https://developer.apple.com/documentation/swiftui/accessibilitychildbehavior/contain), [Element behavior](https://developer.apple.com/documentation/swiftui/view/accessibilityelement(children:))

`FocusState` plus `focused` can track and move keyboard focus; `focusable` allows custom views to participate. `onKeyPress` handles hardware keyboard input only while the view has focus and returns `.handled` or `.ignored` to control further dispatch. `keyboardShortcut` attaches a shortcut to a native control. These are sufficient public mechanisms for supported keyboard actions; they do not select shortcut mappings or calendar movement rules. [Focus](https://developer.apple.com/documentation/swiftui/focus), [Keyboard input](https://developer.apple.com/documentation/swiftui/input-events), [Key dispatch](https://developer.apple.com/documentation/swiftui/view/onkeypress(keys:phases:action:))

## SDK evidence and limits

Both SDKs are under `/Applications/Xcode.app/Contents/Developer/Platforms/<Platform>.platform/Developer/SDKs/<SDK>.sdk`. Reads used scoped `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; the global Xcode selection was not changed. The default command-line-tools selection cannot locate iPhoneOS, which is not evidence that the installed Xcode lacks that SDK.

The arm64e public `SwiftUI.framework/Modules/SwiftUI.swiftmodule/*.swiftinterface` declarations establish these relevant availability boundaries:

| API | iOS minimum | Native macOS minimum | iOS / macOS declaration line |
| --- | --- | --- | --- |
| `DatePicker` | 13.0 | 10.15 | 25348 / 25895 |
| `GraphicalDatePickerStyle` | 14.0 | 10.15 | 24301 / 24936 |
| `MultiDatePicker` | 16.0 | Explicitly unavailable | 17329 / 17769 |
| `Grid` | 16.0 | 13.0 | 23198 / 23800 |
| `SidebarAdaptableTabViewStyle` | 18.0 | 15.0 | 9268 / 9602 |
| `FocusState` | 15.0 | 12.0 | 10706 / 11001 |
| `focusable(_:)` | 17.0 | 12.0 | 28968 / 29368 |
| `onKeyPress` | 17.0 | 14.0 | 25188 / 25735 |
| `keyboardShortcut` | 14.0 | 11.0 | 26821 / 27359 |
| `accessibilityChildren` | 15.0 | 12.0 | 24947 / 25494 |
| `accessibilityElement` | 13.0 | 10.15 | 30312 / 30717 |

An exported declaration may still be unavailable on a particular platform, as `MultiDatePicker` demonstrates. The inspected AppKit date/calendar class declarations are `NSDatePicker` and `NSDatePickerCell`. UIKit declares `UIDatePicker`, `UICalendarView`, its decoration and selection classes. SwiftUI/SwiftUICore calendar-related public types are date pickers and timeline-update schedules; none of the inspected candidates exposes an event-grid contract.

Selected SHA-256 fingerprints:

| SDK artifact | SHA-256 |
| --- | --- |
| iPhoneOS SwiftUI arm64e interface | `6118439a36ebb4940814e899c98226d644ea5da4a248ef3ac40c261af58b79f4` |
| macOS SwiftUI arm64e interface | `155b00c7d8fa9e9696b96b4bd3291b4c910207b480025d13ba6482f7b9940d38` |
| iPhoneOS `UIKit.framework/Headers/UICalendarView.h` | `660e5a5b9b20e2594b79683c6e2dd76bdf9c3a78d805dd42b09005d821ca9d9d` |
| iPhoneOS `UIKit.framework/Headers/UICalendarSelectionWeekOfYear.h` | `cfd701499f91f52460f2a74f2ca69a1628988c9e7e0edb56c7b108469dc73207` |
| macOS `AppKit.framework/Headers/NSDatePicker.h` | `e2993d891d631e5c79695ad8bf84fd06a4e1f3f6a17bdf38a7589fc8b31f3f31` |

Validation ran markdownlint **0.41.1** against this actual file, with **one file checked and zero issues**. MD013 line-length checking was disabled to match the existing research notes' long prose and table rows; other default rules remained enabled. The two relative source links resolve to real repository files. A direct whitespace check found no trailing whitespace or tabs and confirmed a final newline.

This was documentation and declaration inspection only. No application tests, runtime date/DST probes, UI accessibility checks, performance profiling, system Calendar access, exports, commits or GitHub changes were performed. The requested research note is the only repository file changed by this task. Compilation and runtime behavior of a future Calendar implementation remain to be verified against its real views and arithmetic.
