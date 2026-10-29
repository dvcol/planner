import Foundation
import MapKit
import UniformTypeIdentifiers

@MainActor public enum PlannerNativeCaptureLoader {
  private enum LoadEvent: Sendable {
    case input(PlannerCaptureRetainedInput)
    case deadline
  }

  public static func load(providers: [NSItemProvider]) async -> PlannerLoadedCaptureInputs {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(10))
    var representations: [PlannerNativeCaptureRepresentation] = []
    for provider in providers.prefix(32) {
      if provider.registeredTypeIdentifiers.contains(UTType.url.identifier) {
        representations.append(
          .init(
            index: Int64(representations.count), provider: provider,
            type: .url, lane: .url, encoding: .utf8))
      }
      for (type, encoding) in [
        (UTType.utf8PlainText, Optional(String.Encoding.utf8)), (.utf16PlainText, .utf16),
        (.plainText, nil),
      ] {
        guard provider.registeredTypeIdentifiers.contains(type.identifier) else { continue }
        representations.append(
          .init(
            index: Int64(representations.count), provider: provider,
            type: type, lane: .text, encoding: encoding))
        break
      }
      if provider.registeredTypeIdentifiers.contains(MKMapItemTypeIdentifier) {
        representations.append(
          .init(
            index: Int64(representations.count), provider: provider,
            type: .init(importedAs: MKMapItemTypeIdentifier), lane: .mapItem, encoding: nil))
      }
      let supportedIdentifiers =
        [UTType.url, .utf8PlainText, .utf16PlainText, .plainText]
        .map(\.identifier) + [MKMapItemTypeIdentifier]
      if provider.registeredTypeIdentifiers.isEmpty
        || provider.registeredTypeIdentifiers.contains(where: { !supportedIdentifiers.contains($0) }
        )
      {
        representations.append(
          .init(
            index: Int64(representations.count), provider: provider,
            type: nil, lane: .unsupported, encoding: .utf8))
      }
    }
    if providers.count > 32, let firstOverflow = providers.dropFirst(32).first {
      let index = Int64(representations.count)
      representations.append(
        .init(
          index: index, provider: firstOverflow, type: nil,
          lane: .unsupported, encoding: .utf8,
          presetIssue: .init(
            inputIndex: index, lane: .unsupported, state: .oversized,
            message:
              "This capture exceeds 32 attachments. The extra attachments were not loaded; remove them or prepare a smaller capture before Add.",
            blocksSave: true)))
    }
    return await load(representations: representations, deadline: deadline)
  }

  static func reload(
    inputs: [PlannerCaptureRetainedInput], maximumDecodedBytes: Int
  ) async -> [PlannerCaptureRetainedInput] {
    let deadline = ContinuousClock().now.advanced(by: .seconds(10))
    return await load(
      representations: inputs.compactMap(\.nativeRepresentation), deadline: deadline,
      maximumDecodedBytes: maximumDecodedBytes
    ).inputs
  }

  private static func load(
    representations: [PlannerNativeCaptureRepresentation], deadline: ContinuousClock.Instant,
    maximumDecodedBytes: Int = PlannerCaptureLimits.maximumDecodedBytes
  ) async -> PlannerLoadedCaptureInputs {
    let clock = ContinuousClock()
    return await withTaskGroup(of: LoadEvent.self) { group in
      group.addTask {
        try? await clock.sleep(until: deadline)
        return .deadline
      }
      var inputs: [PlannerCaptureRetainedInput] = []
      var decodedBytes = 0
      var expired = false
      for beginning in stride(from: 0, to: representations.count, by: 4) {
        let ending = min(beginning + 4, representations.count)
        if expired || Task.isCancelled {
          inputs += representations[beginning..<ending].map {
            issue(
              $0, state: .failed,
              message:
                "Loading stopped before this input was available. Retry it or remove it before Add.",
              blocksSave: true)
          }
          continue
        }
        for representation in representations[beginning..<ending] {
          let loading = Task { await load(representation) }
          group.addTask {
            .input(
              await withTaskCancellationHandler(
                operation: { await loading.value },
                onCancel: { loading.cancel() }))
          }
        }
        var batch: [PlannerCaptureRetainedInput] = []
        while batch.count < ending - beginning, let event = await group.next() {
          switch event {
          case .input(let input): batch.append(input)
          case .deadline:
            expired = true
            group.cancelAll()
          }
        }
        for input in batch.sorted(by: { $0.inputIndex < $1.inputIndex }) {
          let byteCount = input.decodedByteCount
          guard byteCount <= maximumDecodedBytes - decodedBytes else {
            inputs.append(
              .init(
                inputIndex: input.inputIndex, input: nil,
                unavailableIssue: .init(
                  inputIndex: input.inputIndex, lane: input.lane, state: .oversized,
                  message:
                    "This input exceeds the 1 MiB capture limit. Remove it or retry with less content.",
                  blocksSave: true), source: .provider,
                nativeRepresentation: input.nativeRepresentation))
            continue
          }
          decodedBytes += byteCount
          inputs.append(input)
        }
      }
      group.cancelAll()
      return .init(inputs: inputs)
    }
  }

  private static func load(_ representation: PlannerNativeCaptureRepresentation) async
    -> PlannerCaptureRetainedInput
  {
    if let issue = representation.presetIssue {
      return .init(
        inputIndex: representation.index, input: nil, unavailableIssue: issue, source: .provider,
        nativeRepresentation: representation)
    }
    guard let type = representation.type else {
      return issue(
        representation, state: .unsupported,
        message: "This attachment is unsupported and was ignored.", blocksSave: false)
    }
    let continuationState = NativeCaptureContinuation()
    let result: Result<Data, any Error> = await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        continuationState.install(continuation)
        guard !Task.isCancelled else {
          continuationState.cancel()
          return
        }
        let progress = representation.provider.loadDataRepresentation(
          forTypeIdentifier: type.identifier
        ) { data, error in
          if let error {
            continuationState.finish(.failure(error))
            return
          }
          guard let data else {
            continuationState.finish(.failure(CocoaError(.fileReadUnknown)))
            return
          }
          continuationState.finish(.success(data))
        }
        continuationState.setProgress(progress)
      }
    } onCancel: {
      continuationState.cancel()
    }
    guard case .success(let data) = result else {
      return issue(
        representation, state: .failed,
        message: "This input could not be loaded. Retry it or remove it before Add.",
        blocksSave: true)
    }
    if representation.lane == .mapItem {
      guard data.count <= PlannerCaptureLimits.maximumEncodedMapBytes else {
        return issue(
          representation, state: .oversized,
          message:
            "This map input exceeds the 8 MiB encoded limit. Remove it or retry with less content.",
          blocksSave: true)
      }
      do {
        #if os(iOS)
          let mapItem = try MKMapItem.object(
            withItemProviderData: data, typeIdentifier: MKMapItemTypeIdentifier)
        #else
          guard
            let mapItem = try NSKeyedUnarchiver.unarchivedObject(
              ofClass: MKMapItem.self, from: data)
          else { throw CocoaError(.coderReadCorrupt) }
        #endif
        return mapInput(representation, candidate: plannerNativeMapCandidate(mapItem))
      } catch {
        return issue(
          representation, state: .failed,
          message: "This map input could not be loaded. Retry it or remove it before Add.",
          blocksSave: true)
      }
    }
    var maximumRepresentationBytes = PlannerCaptureLimits.maximumDecodedBytes + 3
    if representation.encoding == .utf16 {
      maximumRepresentationBytes = PlannerCaptureLimits.maximumDecodedBytes * 2 + 2
    } else if representation.encoding == nil {
      maximumRepresentationBytes = PlannerCaptureLimits.maximumDecodedBytes * 4 + 4
    }
    guard data.count <= maximumRepresentationBytes else {
      return issue(
        representation, state: .oversized,
        message:
          "This input exceeds the 1 MiB capture limit. Remove it or retry with less content.",
        blocksSave: true)
    }
    let decoded: String?
    if let encoding = representation.encoding {
      decoded = String(data: data, encoding: encoding)
    } else {
      var converted: NSString?
      var usedLossyConversion = ObjCBool(false)
      let detected = NSString.stringEncoding(
        for: data, encodingOptions: [.allowLossyKey: false],
        convertedString: &converted, usedLossyConversion: &usedLossyConversion)
      if detected != 0 && !usedLossyConversion.boolValue {
        decoded = converted.map { $0 as String }
      } else {
        decoded = nil
      }
    }
    guard let text = decoded else {
      if representation.lane == .url { return await loadURLValue(representation) }
      return issue(
        representation, state: .failed,
        message: "This input could not be decoded as plain text. Retry it or remove it before Add.",
        blocksSave: true)
    }
    let input: PlannerCaptureDirectInput
    if representation.lane == .url { input = .url(text) } else { input = .text(text) }
    return .init(
      inputIndex: representation.index, input: input, unavailableIssue: nil, source: .provider,
      nativeRepresentation: representation)
  }

  /// Some native URL providers expose an object instead of a plain-text representation.
  private static func loadURLValue(_ representation: PlannerNativeCaptureRepresentation) async
    -> PlannerCaptureRetainedInput
  {
    let continuationState = NativeCaptureContinuation()
    let result: Result<Data, any Error> = await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        continuationState.install(continuation)
        guard !Task.isCancelled else {
          continuationState.cancel()
          return
        }
        let progress = representation.provider.loadObject(ofClass: NSURL.self) { object, error in
          if let error {
            continuationState.finish(.failure(error))
            return
          }
          guard let url = object as? URL, url.scheme != nil else {
            continuationState.finish(.failure(CocoaError(.coderReadCorrupt)))
            return
          }
          let original = url.absoluteString
          guard original.utf8.count <= PlannerCaptureLimits.maximumDecodedBytes else {
            continuationState.finish(.failure(CocoaError(.fileReadTooLarge)))
            return
          }
          continuationState.finish(.success(Data(original.utf8)))
        }
        continuationState.setProgress(progress)
      }
    } onCancel: {
      continuationState.cancel()
    }
    if case .failure(let error) = result,
      (error as? CocoaError)?.code == .fileReadTooLarge
    {
      return issue(
        representation, state: .oversized,
        message:
          "This input exceeds the 1 MiB capture limit. Remove it or retry with less content.",
        blocksSave: true)
    }
    guard case .success(let data) = result, let original = String(data: data, encoding: .utf8)
    else {
      return issue(
        representation, state: .failed,
        message: "This URL could not be loaded. Retry it or remove it before Add.",
        blocksSave: true)
    }
    return .init(
      inputIndex: representation.index, input: .url(original), unavailableIssue: nil,
      source: .provider, nativeRepresentation: representation)
  }

  private static func mapInput(
    _ representation: PlannerNativeCaptureRepresentation, candidate: PlannerCapturePreviewCandidate
  ) -> PlannerCaptureRetainedInput {
    .init(
      inputIndex: representation.index, input: nil,
      unavailableIssue: .init(
        inputIndex: representation.index, lane: .mapItem, state: .held,
        message: "Shared place: \(candidate.displayName ?? "Unnamed place")", blocksSave: false),
      source: .provider, nativeRepresentation: representation, mapCandidate: candidate)
  }

  private static func issue(
    _ representation: PlannerNativeCaptureRepresentation, state: PlannerCaptureInputIssue.State,
    message: String, blocksSave: Bool
  ) -> PlannerCaptureRetainedInput {
    .init(
      inputIndex: representation.index, input: nil,
      unavailableIssue: .init(
        inputIndex: representation.index, lane: representation.lane,
        state: state, message: message, blocksSave: blocksSave), source: .provider,
      nativeRepresentation: representation)
  }
}

@MainActor final class PlannerNativeCaptureRepresentation {
  let index: Int64
  let provider: NSItemProvider
  let type: UTType?
  let lane: PlannerCaptureInputIssue.Lane
  let encoding: String.Encoding?
  let presetIssue: PlannerCaptureInputIssue?

  init(
    index: Int64, provider: NSItemProvider, type: UTType?,
    lane: PlannerCaptureInputIssue.Lane, encoding: String.Encoding?,
    presetIssue: PlannerCaptureInputIssue? = nil
  ) {
    self.index = index
    self.provider = provider
    self.type = type
    self.lane = lane
    self.encoding = encoding
    self.presetIssue = presetIssue
  }
}

private final class NativeCaptureContinuation: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Result<Data, any Error>, Never>?
  private var pendingResult: Result<Data, any Error>?
  private var completed = false
  private var cancellationRequested = false
  private var progress: Progress?

  func install(_ continuation: CheckedContinuation<Result<Data, any Error>, Never>) {
    let pending: Result<Data, any Error>? = lock.withLock {
      if completed { return pendingResult }
      self.continuation = continuation
      return nil
    }
    if let pending { continuation.resume(returning: pending) }
  }

  func setProgress(_ progress: Progress) {
    let cancel = lock.withLock {
      self.progress = progress
      return cancellationRequested
    }
    if cancel { progress.cancel() }
  }

  func finish(_ result: Result<Data, any Error>) {
    let waiting: CheckedContinuation<Result<Data, any Error>, Never>? = lock.withLock {
      guard !completed else { return nil }
      completed = true
      let waiting = continuation
      continuation = nil
      if waiting == nil { pendingResult = result }
      return waiting
    }
    waiting?.resume(returning: result)
  }

  func cancel() {
    let activeProgress = lock.withLock {
      cancellationRequested = true
      return progress
    }
    finish(.failure(CancellationError()))
    activeProgress?.cancel()
  }
}
