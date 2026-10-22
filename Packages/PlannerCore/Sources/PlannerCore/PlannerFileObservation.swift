import Darwin
import Dispatch
import Foundation

/// The source is immutable after setup; Dispatch supports cancellation from any thread.
final class PlannerFileObservation: @unchecked Sendable {
  private let source: any DispatchSourceFileSystemObject

  init(url: URL, changed: @escaping @Sendable () -> Void) throws {
    let descriptor = open(url.path, O_EVTONLY | O_CLOEXEC)
    guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: descriptor, eventMask: [.write, .delete, .rename, .attrib, .revoke],
      queue: .global(qos: .utility))
    source.setEventHandler(handler: changed)
    source.setCancelHandler { close(descriptor) }
    source.activate()
  }

  deinit { source.cancel() }
}
