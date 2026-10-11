import PlannerCore
import PlannerPreviews
import SwiftUI

extension PlannerRowRead {
  func metadataDescription(presentation: PlannerRowPresentationContext?) -> String {
    var descriptions = [String]()
    if let subtitle, !subtitle.isEmpty { descriptions.append(subtitle) }
    if let locationCaption { descriptions.append(locationCaption) }
    if let address = ownedLocation?.formattedAddress, address != locationCaption {
      descriptions.append(address)
    }
    if let previewLink {
      descriptions.append(previewLink.displayTitle)
    } else if hasLinks {
      descriptions.append("Maps")
    }
    if archived == true { descriptions.append("Archived") }
    if let schedule = scheduleDescription(presentation: presentation) {
      descriptions.append("Scheduled: \(schedule)")
      if additionalScheduleCount > 0 {
        let noun = additionalScheduleCount == 1 ? "schedule" : "schedules"
        descriptions.append("\(additionalScheduleCount) additional \(noun)")
      }
    }
    let categories = labels.sortedLabels(of: .category)
    if !categories.isEmpty {
      descriptions.append("Categories: \(categories.map(\.name).joined(separator: ", "))")
    }
    let tags = labels.sortedLabels(of: .tag)
    if !tags.isEmpty {
      descriptions.append("Tags: \(tags.map(\.name).joined(separator: ", "))")
    }
    return descriptions.joined(separator: ", ")
  }

  var compactLabelDescription: String? {
    let tags = labels.sortedLabels(of: .tag)
    var names = labels.sortedLabels(of: .category).map(\.name) + tags.prefix(2).map(\.name)
    if tags.count > 2 { names.append("+\(tags.count - 2)") }
    return names.isEmpty ? nil : names.joined(separator: " · ")
  }

  var locationCaption: String? {
    guard let location = ownedLocation else { return nil }
    if let name = location.displayName, !name.isEmpty { return name }
    if let address = location.formattedAddress, !address.isEmpty { return address }
    if location.coordinate != nil { return "Location" }
    return nil
  }

  var additionalScheduleCount: Int64 {
    guard case .directItem(_, _, _, let count) = scheduleSummary else { return 0 }
    return count
  }

  func scheduleDescription(presentation: PlannerRowPresentationContext?) -> String? {
    guard case .directItem(_, _, let form, _) = scheduleSummary,
      let presentation,
      let displayTimeZone = TimeZone(identifier: presentation.displayTimeZone)
    else { return nil }
    let dateIntervalFormatter = DateIntervalFormatter()
    dateIntervalFormatter.dateStyle = .medium
    switch form {
    case .timed(let start, let end, _):
      dateIntervalFormatter.timeZone = displayTimeZone
      dateIntervalFormatter.timeStyle = .short
      if let end { return dateIntervalFormatter.string(from: start, to: end) }
      var dateFormatStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)
      dateFormatStyle.timeZone = displayTimeZone
      return start.formatted(dateFormatStyle)
    case .allDay(let start, let end):
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .gmt
      let finalDate = end ?? start
      guard
        let startDate = calendar.date(
          from: DateComponents(year: start.year, month: start.month, day: start.day, hour: 12)),
        let endDate = calendar.date(
          from: DateComponents(
            year: finalDate.year, month: finalDate.month, day: finalDate.day, hour: 12))
      else { return "Date unavailable" }
      dateIntervalFormatter.calendar = calendar
      dateIntervalFormatter.timeZone = .gmt
      dateIntervalFormatter.timeStyle = .none
      return dateIntervalFormatter.string(from: startDate, to: endDate) + " · All day"
    }
  }
}

struct SavedItemRowContent: View {
  let row: PlannerRowRead
  let rowPresentation: PlannerRowPresentationContext?
  @Environment(SavedPlannerStore.self) private var store
  @Environment(PlannerPreviews.self) private var previews

  private var previewRequest: PlannerLinkPreviewRequest? {
    guard let link = row.previewLink, let namespace = store.devicePreferenceNamespace else {
      return nil
    }
    let source: PlannerEntityReference
    switch row.identity {
    case .source(let reference), .appearance(let reference, _): source = reference
    }
    return .init(
      source: .init(
        namespace: namespace, sourceId: source.id, sourceLifetimeId: row.sourceLifetimeId),
      linkId: link.linkId, originalURL: link.originalUrl)
  }

  var body: some View {
    HStack(alignment: .top) {
      textContent
      if let request = previewRequest,
        case .available(let content) = previews.linkState(for: request),
        let imageData = content.imageData
      {
        previewImage(imageData)
          .resizable()
          .scaledToFill()
          .frame(width: 44, height: 44)
          .clipShape(RoundedRectangle(cornerRadius: 6))
          .accessibilityLabel("Website preview")
          .accessibilityIdentifier("saved.item.preview.thumbnail.\(request.linkId.uuidString)")
      }
    }
    .task(id: previewRequest) {
      if let request = previewRequest { await previews.loadLink(request) }
    }
  }

  private func previewImage(_ data: Data) -> Image {
    #if os(macOS)
      guard let image = NSImage(data: data) else { return Image(systemName: "link") }
      return Image(nsImage: image)
    #else
      guard let image = UIImage(data: data) else { return Image(systemName: "link") }
      return Image(uiImage: image)
    #endif
  }

  private var textContent: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(row.title).lineLimit(1)
      if let subtitle = row.subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      if let link = row.previewLink {
        Label(link.displayTitle, systemImage: link.systemImage)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      } else if row.hasLinks {
        Label("Maps", systemImage: "map")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if let location = row.locationCaption {
        Label(location, systemImage: "mappin.and.ellipse")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      if let schedule = row.scheduleDescription(presentation: rowPresentation) {
        let additionalCount = row.additionalScheduleCount
        Label(
          additionalCount > 0 ? "\(schedule) · +\(additionalCount)" : schedule,
          systemImage: "calendar"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      }
      if let labels = row.compactLabelDescription {
        Text(labels)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }
}
