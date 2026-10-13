import Foundation

public enum PlannerCaptureDirectInput: Sendable, Equatable {
  case url(String)
  case text(String)
}

public enum PlannerCaptureInput: Sendable {
  case direct([PlannerCaptureDirectInput])
}

public enum PlannerCaptureDraftResult: Sendable {
  case draft(PlannerCaptureDraftRead)
  case rejected(PlannerFailure)
}

public enum PlannerCaptureCancelResult: Sendable {
  case cancelled
  case rejected(PlannerFailure)
}

public struct PlannerCaptureDraftRead: Sendable {
  public let draftId: UUID
  public let generation: UUID
  public let content: PlannerItemContentInput
  public let links: [PlannerCaptureDraftLink]
  public let inputIssues: [PlannerCaptureInputIssue]
  public let preview: PlannerCapturePreview
  public let reuseCandidates: [PlannerCaptureReuseCandidate]
  public let saveAllowed: Bool
}

public struct PlannerCaptureDraftLink: Sendable, Equatable {
  public let linkId: UUID
  public let originalUrl: String
  public let label: String?
  public let kind: PlannerLinkKind
  public let providerReference: PlannerProviderReference?
}

public struct PlannerCaptureInputIssue: Sendable, Equatable {
  public enum Lane: String, Sendable { case url, text, mapItem, unsupported }
  public enum State: String, Sendable { case failed, oversized, unsupported, held }
  public let inputIndex: Int64
  public let lane: Lane
  public let state: State
  public let message: String
  public let blocksSave: Bool
}

public struct PlannerCapturePreview: Sendable {
  public enum State: String, Sendable { case notRequested, loading, available, unavailable }
  public let state: State
  public let linkId: UUID?
  public let candidate: PlannerCapturePreviewCandidate?
}

public struct PlannerCapturePreviewCandidate: Sendable {
  public enum Provider: String, Sendable { case appleMaps, googleMaps }
  public let provider: Provider
  public let displayName: String?
  public let formattedAddress: String?
  public let coordinate: PlannerCoordinate?
  public let providerReference: PlannerProviderReference?
  public let uncertaintyReasons: [String]
  public let attributionText: String?
}

public struct PlannerCaptureReuseCandidate: Sendable, Equatable {
  public let itemId: UUID
  public let title: String
  public let globalDone: Bool
  public let archived: Bool
  public let matchingLinkIds: [UUID]
  public let matchingOriginalUrls: [String]
}

struct PlannerPreparedCapture {
  let session: PlannerDatasetSession
  let read: PlannerCaptureDraftRead
  let contentOrigins: [String: String]
}

struct PlannerCapturePreparation {
  let read: PlannerCaptureDraftRead
  let contentOrigins: [String: String]
}

private enum PlannerDirectCaptureLimits {
  static let maximumDecodedBytes = 1_048_576
  static let maximumDistinctLinks = 128
}

func plannerPrepareDirectCapture(_ inputs: [PlannerCaptureDirectInput], items: [ItemSnapshot])
  throws
  -> PlannerCapturePreparation
{
  var links: [PlannerCaptureDraftLink] = []
  var originals = Set<String>()
  var independentTexts: [String] = []
  var hasIndependentProse = false
  var inputIssues: [PlannerCaptureInputIssue] = []
  var decodedBytes = 0
  for (index, input) in inputs.enumerated() {
    let text: String
    let lane: PlannerCaptureInputIssue.Lane
    switch input {
    case .url(let value):
      text = value
      lane = .url
    case .text(let value):
      text = value
      lane = .text
    }
    let byteCount = text.utf8.count
    guard byteCount <= PlannerDirectCaptureLimits.maximumDecodedBytes - decodedBytes else {
      inputIssues.append(
        .init(
          inputIndex: Int64(index), lane: lane, state: .oversized,
          message:
            "This input exceeds the 1 MiB capture limit. Remove it or retry with less content.",
          blocksSave: true))
      continue
    }
    decodedBytes += byteCount
    if lane == .url,
      (try? PlannerLinkInput(originalUrl: text).validatedKind(propertyPath: "/inputs/\(index)"))
        == nil
    {
      inputIssues.append(
        .init(
          inputIndex: Int64(index), lane: .url, state: .unsupported,
          message: "This URL is unsupported. Use an absolute HTTP or HTTPS bookmark.",
          blocksSave: false))
      continue
    }
    let inputOriginals: [String]
    var independentText: String?
    var hasProse = false
    switch input {
    case .url(let original): inputOriginals = [original]
    case .text(let text):
      let detected = try plannerCaptureTextLinks(text)
      inputOriginals = detected.originals
      independentText = text
      hasProse = detected.hasProse
    }
    guard
      Set(inputOriginals).union(originals).count <= PlannerDirectCaptureLimits.maximumDistinctLinks
    else {
      inputIssues.append(
        .init(
          inputIndex: Int64(index), lane: lane, state: .oversized,
          message:
            "This input exceeds the 128-link capture limit. Remove it or retry with fewer links.",
          blocksSave: true))
      continue
    }
    for original in inputOriginals {
      let kind = try PlannerLinkInput(originalUrl: original).validatedKind(
        propertyPath: "/inputs/\(index)")
      if originals.insert(original).inserted {
        links.append(
          .init(
            linkId: UUID(), originalUrl: original, label: nil, kind: kind, providerReference: nil))
      }
    }
    if let independentText {
      independentTexts.append(independentText)
      hasIndependentProse = hasIndependentProse || hasProse
    }
  }
  var independentText = ""
  if hasIndependentProse { independentText = independentTexts.joined(separator: "\n") }
  let textFields = plannerCaptureTextFields(independentText)
  var title = textFields.title ?? ""
  var titleOrigin = "independent"
  if textFields.title == nil && !links.isEmpty {
    title = "Saved link"
    titleOrigin = "appFallback"
  }
  let content = PlannerItemContentInput(
    title: title, notes: textFields.notes,
    links: links.map { .init(originalUrl: $0.originalUrl, label: $0.label) })
  let draft = PlannerCaptureDraftRead(
    draftId: UUID(), generation: UUID(), content: content, links: links, inputIssues: inputIssues,
    preview: .init(
      state: .notRequested,
      linkId: links.first { $0.kind == .appleMaps || $0.kind == .googleMaps }?.linkId,
      candidate: nil),
    reuseCandidates: plannerCaptureReuseCandidates(originals: originals, items: items),
    saveAllowed: !title.isEmpty && !inputIssues.contains(where: \.blocksSave))
  var origins = ["title": titleOrigin]
  if textFields.notes != nil { origins["notes"] = "independent" }
  return .init(read: draft, contentOrigins: origins)
}

private func plannerCaptureReuseCandidates(originals: Set<String>, items: [ItemSnapshot])
  -> [PlannerCaptureReuseCandidate]
{
  items.compactMap { item in
    let matching = item.links.filter { originals.contains($0.originalUrl) }
    guard !matching.isEmpty else { return nil }
    return .init(
      itemId: item.id, title: item.input.title, globalDone: item.globalDone,
      archived: item.archived,
      matchingLinkIds: matching.map(\.id), matchingOriginalUrls: matching.map(\.originalUrl))
  }.sorted { $0.itemId.uuidString < $1.itemId.uuidString }
}

private func plannerCaptureTextLinks(_ text: String) throws
  -> (originals: [String], hasProse: Bool)
{
  let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
  let source = text as NSString
  var originals: [String] = []
  var distinctOriginals = Set<String>()
  var ranges: [NSRange] = []
  detector.enumerateMatches(in: text, range: NSRange(location: 0, length: source.length)) {
    result, _, stop in
    guard let result else { return }
    let original = source.substring(with: result.range)
    guard
      (try? PlannerLinkInput(originalUrl: original).validatedKind(propertyPath: "/inputs")) != nil
    else { return }
    originals.append(original)
    distinctOriginals.insert(original)
    ranges.append(result.range)
    if distinctOriginals.count > PlannerDirectCaptureLimits.maximumDistinctLinks {
      stop.pointee = true
    }
  }
  let remainder = NSMutableString(string: text)
  for range in ranges.reversed() { remainder.deleteCharacters(in: range) }
  return (
    originals: originals,
    hasProse: !remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  )
}

private func plannerCaptureTextFields(_ text: String) -> (title: String?, notes: String?) {
  let source = text as NSString
  var lineOffset = 0
  while lineOffset < source.length {
    var lineStartOffset = 0
    var lineEndOffset = 0
    var lineContentsEndOffset = 0
    source.getLineStart(
      &lineStartOffset, end: &lineEndOffset, contentsEnd: &lineContentsEndOffset,
      for: NSRange(location: lineOffset, length: 0))
    let title = source.substring(
      with: NSRange(location: lineStartOffset, length: lineContentsEndOffset - lineStartOffset))
    if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      let notes = source.substring(from: lineEndOffset)
      return (title, notes.isEmpty ? nil : notes)
    }
    lineOffset = lineEndOffset
  }
  return (nil, nil)
}
