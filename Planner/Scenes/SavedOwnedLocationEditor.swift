import PlannerCore
import SwiftUI

struct SavedOwnedLocationDraft {
  let originalLocation: PlannerOwnedLocation?
  var name: String
  var address: String
  var keepsSavedPin: Bool

  init(_ location: PlannerOwnedLocation?) {
    originalLocation = location
    name = location?.displayName ?? ""
    address = location?.formattedAddress ?? ""
    keepsSavedPin = location?.coordinate != nil
  }

  var value: PlannerOwnedLocation? {
    if name == (originalLocation?.displayName ?? ""),
      address == (originalLocation?.formattedAddress ?? ""),
      keepsSavedPin == (originalLocation?.coordinate != nil)
    {
      return originalLocation
    }
    let coordinate = keepsSavedPin ? originalLocation?.coordinate : nil
    let displayName = locationText(name, original: originalLocation?.displayName)
    let formattedAddress = locationText(address, original: originalLocation?.formattedAddress)
    if coordinate == nil && displayName == nil && formattedAddress == nil { return nil }
    return .init(
      displayName: displayName, formattedAddress: formattedAddress, coordinate: coordinate)
  }

  private func locationText(_ text: String, original: String?) -> String? {
    if text == (original ?? "") { return original }
    return text.isEmpty ? nil : text
  }
}

struct SavedOwnedLocationEditor: View {
  @Binding var draft: SavedOwnedLocationDraft
  let title: String
  let accessibilityIdentifierPrefix: String

  var body: some View {
    Section {
      TextField("Place name", text: $draft.name)
        .accessibilityIdentifier("\(accessibilityIdentifierPrefix).name")
      TextField("Address", text: $draft.address)
        .accessibilityIdentifier("\(accessibilityIdentifierPrefix).address")
      if draft.originalLocation?.coordinate != nil {
        Picker("Saved pin", selection: $draft.keepsSavedPin) {
          Text("Keep saved pin").tag(true)
          Text("Remove saved pin").tag(false)
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("\(accessibilityIdentifierPrefix).pin")
      }
      if let coordinate = draft.value?.coordinate {
        ItemLocationMap(
          title: title,
          coordinate: .init(latitude: coordinate.latitude, longitude: coordinate.longitude),
          accessibilityIdentifier: "\(accessibilityIdentifierPrefix).map")
      }
    } header: {
      Text("Location")
    } footer: {
      if draft.originalLocation?.coordinate != nil {
        if draft.keepsSavedPin {
          Text("Place name and address changes keep this pin until you choose Remove saved pin.")
        } else {
          Text("Removing the pin keeps the place name and address. Save applies the change.")
        }
      }
    }
  }
}
