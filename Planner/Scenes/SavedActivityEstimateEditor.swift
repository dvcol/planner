import PlannerCore
import SwiftUI

struct SavedActivityEstimateEditor: View {
  @Binding var estimate: PlannerEstimate?
  let accessibilityIdentifierPrefix: String
  @State private var selectedUnit: PlannerEstimateUnit

  init(estimate: Binding<PlannerEstimate?>, accessibilityIdentifierPrefix: String) {
    _estimate = estimate
    self.accessibilityIdentifierPrefix = accessibilityIdentifierPrefix
    _selectedUnit = State(initialValue: estimate.wrappedValue?.displayUnit ?? .hour)
  }

  var body: some View {
    Section("Activity estimate") {
      Toggle(
        "Include estimate",
        isOn: Binding(
          get: { estimate != nil },
          set: { enabled in
            if enabled {
              estimate = .init(minutes: selectedUnit.estimateMinutes, displayUnit: selectedUnit)
            } else {
              estimate = nil
            }
          })
      )
      .accessibilityIdentifier(accessibilityIdentifierPrefix + ".enabled")
      if let estimate {
        Picker("Display unit", selection: $selectedUnit) {
          ForEach(PlannerEstimateUnit.editorUnits, id: \.rawValue) { unit in
            Text(unit.estimateTitle).tag(unit)
          }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier(accessibilityIdentifierPrefix + ".unit")
        .onChange(of: selectedUnit) {
          self.estimate = .init(minutes: estimate.minutes, displayUnit: selectedUnit)
        }
        quantityControl(selectedUnit, identifier: accessibilityIdentifierPrefix + ".quantity")
        ForEach(selectedUnit.remainderUnits.filter { quantity($0) > 0 }, id: \.rawValue) { unit in
          quantityControl(
            unit, identifier: accessibilityIdentifierPrefix + ".remainder." + unit.rawValue)
        }
        Text("Changing the display unit keeps the same duration.")
          .font(.footnote).foregroundStyle(.secondary)
      } else {
        Text("No estimate").foregroundStyle(.secondary)
      }
    }
  }

  private func quantity(_ unit: PlannerEstimateUnit) -> Int64 {
    var remaining = estimate?.minutes ?? 0
    for component in [selectedUnit] + selectedUnit.remainderUnits {
      let quantity = remaining / component.estimateMinutes
      if component == unit { return quantity }
      remaining %= component.estimateMinutes
    }
    return 0
  }

  private func quantityControl(_ unit: PlannerEstimateUnit, identifier: String) -> some View {
    Stepper(
      onIncrement: incrementAction(unit), onDecrement: decrementAction(unit)
    ) {
      LabeledContent(unit.estimateTitle, value: quantity(unit).formatted())
    }
    .accessibilityValue(String(quantity(unit)))
    .accessibilityIdentifier(identifier)
  }

  private func incrementAction(_ unit: PlannerEstimateUnit) -> (() -> Void)? {
    guard let estimate, estimate.minutes <= Int64.max - unit.estimateMinutes else { return nil }
    return { changeMinutes(by: unit.estimateMinutes) }
  }

  private func decrementAction(_ unit: PlannerEstimateUnit) -> (() -> Void)? {
    guard let estimate, quantity(unit) > 0, estimate.minutes > unit.estimateMinutes else {
      return nil
    }
    return { changeMinutes(by: -unit.estimateMinutes) }
  }

  private func changeMinutes(by difference: Int64) {
    guard let estimate else { return }
    let (minutes, overflow) = estimate.minutes.addingReportingOverflow(difference)
    guard !overflow, minutes > 0 else { return }
    self.estimate = .init(minutes: minutes, displayUnit: selectedUnit)
  }
}

struct SavedItemEstimateSection: View {
  let estimate: PlannerEstimate?

  var body: some View {
    Section("Activity estimate") {
      LabeledContent("Duration", value: estimate?.nativeEstimateDescription ?? "No estimate")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity estimate")
        .accessibilityValue(estimate.map { "\($0.minutes) minutes" } ?? "No estimate")
        .accessibilityIdentifier("saved.item.estimate")
    }
  }
}

extension PlannerEstimateUnit {
  fileprivate static let editorUnits: [Self] = [.minute, .hour, .day, .week, .month, .year]

  fileprivate var estimateTitle: String { rawValue.capitalized + "s" }

  fileprivate var estimateMinutes: Int64 {
    switch self {
    case .minute: 1
    case .hour: 60
    case .day: 1_440
    case .week: 10_080
    case .month: 43_200
    case .year: 525_600
    }
  }

  fileprivate var remainderUnits: [Self] {
    switch self {
    case .minute: []
    case .hour: [.minute]
    case .day: [.hour, .minute]
    case .week, .month: [.day, .hour, .minute]
    case .year: [.month, .day, .hour, .minute]
    }
  }
}

extension PlannerEstimate {
  var nativeEstimateDescription: String {
    var remaining = minutes
    var descriptions: [String] = []
    for unit in [displayUnit] + displayUnit.remainderUnits {
      let quantity = remaining / unit.estimateMinutes
      remaining %= unit.estimateMinutes
      guard quantity > 0 else { continue }
      let name = quantity == 1 ? unit.rawValue : unit.rawValue + "s"
      descriptions.append("\(quantity.formatted()) \(name)")
    }
    return descriptions.joined(separator: " · ")
  }
}
