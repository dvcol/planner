#if os(iOS)
  import SwiftUI
  import UIKit

  struct SavedCalendarMonthPicker: UIViewRepresentable {
    @Binding var selectedDate: Date
    @Binding var visibleDate: Date
    let calendar: Calendar
    let scheduleCounts: [DateComponents: Int]

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UICalendarView {
      let view = UICalendarView()
      view.accessibilityIdentifier = "saved.calendar.date"
      view.calendar = calendar
      view.timeZone = calendar.timeZone
      view.delegate = context.coordinator
      view.selectionBehavior = UICalendarSelectionSingleDate(delegate: context.coordinator)
      return view
    }

    func updateUIView(_ view: UICalendarView, context: Context) {
      let coordinator = context.coordinator
      let previousDates = Set(coordinator.parent.scheduleCounts.keys)
      coordinator.parent = self
      coordinator.isUpdating = true
      defer { coordinator.isUpdating = false }
      if view.calendar != calendar { view.calendar = calendar }
      view.timeZone = calendar.timeZone
      let selectedComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
      if let selection = view.selectionBehavior as? UICalendarSelectionSingleDate,
        selection.selectedDate?.year != selectedComponents.year
          || selection.selectedDate?.month != selectedComponents.month
          || selection.selectedDate?.day != selectedComponents.day
      {
        selection.setSelected(selectedComponents, animated: false)
      }
      let visibleComponents = calendar.dateComponents([.year, .month, .day], from: visibleDate)
      if view.visibleDateComponents.year != visibleComponents.year
        || view.visibleDateComponents.month != visibleComponents.month
      {
        view.setVisibleDateComponents(visibleComponents, animated: false)
      }
      view.reloadDecorations(
        forDateComponents: Array(previousDates.union(scheduleCounts.keys)), animated: false)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UICalendarView, context: Context)
      -> CGSize?
    {
      uiView.systemLayoutSizeFitting(
        CGSize(
          width: proposal.width ?? uiView.intrinsicContentSize.width,
          height: UIView.layoutFittingCompressedSize.height),
        withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate
    {
      var parent: SavedCalendarMonthPicker
      var isUpdating = false

      init(_ parent: SavedCalendarMonthPicker) { self.parent = parent }

      func dateSelection(
        _ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?
      ) {
        guard !isUpdating, let dateComponents, let date = parent.calendar.date(from: dateComponents)
        else { return }
        parent.selectedDate = date
      }

      func calendarView(
        _ calendarView: UICalendarView,
        didChangeVisibleDateComponentsFrom previousDateComponents: DateComponents
      ) {
        guard !isUpdating, let date = parent.calendar.date(from: calendarView.visibleDateComponents)
        else { return }
        parent.visibleDate = date
        let selectedMonth = parent.calendar.dateComponents(
          [.year, .month], from: parent.selectedDate)
        let visibleMonth = parent.calendar.dateComponents([.year, .month], from: date)
        if selectedMonth != visibleMonth { parent.selectedDate = date }
      }

      func calendarView(
        _ calendarView: UICalendarView, decorationFor dateComponents: DateComponents
      ) -> UICalendarView.Decoration? {
        let day = DateComponents(
          year: dateComponents.year, month: dateComponents.month, day: dateComponents.day)
        guard let count = parent.scheduleCounts[day], count > 0,
          let year = day.year, let month = day.month, let dayNumber = day.day
        else { return nil }
        return .customView {
          let label = UILabel()
          label.text = "•"
          label.font = .preferredFont(forTextStyle: .caption1)
          label.adjustsFontForContentSizeCategory = true
          label.textColor = .tintColor
          label.isAccessibilityElement = true
          label.accessibilityLabel = count == 1 ? "1 scheduled entry" : "\(count) scheduled entries"
          label.accessibilityIdentifier =
            "saved.calendar.day.\(year)-\(month)-\(dayNumber).schedule-count"
          return label
        }
      }
    }
  }
#endif
